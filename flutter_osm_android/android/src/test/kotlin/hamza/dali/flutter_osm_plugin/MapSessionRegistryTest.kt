package hamza.dali.flutter_osm_plugin

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import hamza.dali.flutter_osm_plugin.mapscore.MapEventSink
import hamza.dali.flutter_osm_plugin.mapscore.MapSession
import hamza.dali.flutter_osm_plugin.mapscore.models.Anchor
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class MapSessionRegistryTest {
    @Test
    fun `routes typed commands to the requested map only`() {
        val first = FakeMapSession(viewId = 1)
        val second = FakeMapSession(viewId = 2)
        val registry = MapSessionRegistry()
        registry.register(first)
        registry.register(second)

        registry.get(1)?.moveTo(latitude = 48.85, longitude = 2.35, animate = true)
        registry.get(2)?.addMarker(
            markerId = "marker-2",
            latitude = 40.71,
            longitude = -74.0,
        )

        assertEquals(48.85, requireNotNull(first.lastLatitude), 0.0)
        assertNull(first.lastMarkerId)
        assertEquals("marker-2", second.lastMarkerId)
        assertNull(second.lastMoveAnimation)
    }

    @Test
    fun `routes Phase 4 overlays and bulk commands to one map only`() {
        val first = FakeMapSession(viewId = 21)
        val second = FakeMapSession(viewId = 22)
        val registry = MapSessionRegistry()
        registry.register(first)
        registry.register(second)

        registry.get(22)?.addMarkers(
            markerIds = arrayOf("one", "two"),
            coordinates = doubleArrayOf(1.0, 2.0, 3.0, 4.0),
        )
        registry.get(22)?.addCircle(
            shapeId = "circle",
            latitude = 1.0,
            longitude = 2.0,
            radius = 20.0,
            fillColor = 1,
            borderColor = 2,
            strokeWidth = 3.0,
        )
        registry.get(22)?.drawRoad(
            roadId = "road",
            coordinates = doubleArrayOf(1.0, 2.0, 3.0, 4.0),
            roadColor = 1,
            roadWidth = 5.0,
            borderColor = 2,
            borderWidth = 1.0,
            zoomInto = false,
            dotted = true,
        )
        registry.get(22)?.setOverlaysVisible(false)

        assertNull(first.lastBatchMarkerIds)
        assertEquals(listOf("one", "two"), second.lastBatchMarkerIds)
        assertEquals("circle", second.lastShapeId)
        assertEquals("road", second.lastRoadId)
        assertEquals(false, second.overlaysVisible)
    }

    @Test
    fun `stale disposal cannot unregister a replacement session`() {
        val stale = FakeMapSession(viewId = 7)
        val replacement = FakeMapSession(viewId = 7)
        val registry = MapSessionRegistry()

        registry.register(stale)
        registry.unregister(stale.viewId, stale)
        registry.register(replacement)
        registry.unregister(stale.viewId, stale)

        assertSame(replacement, registry.get(replacement.viewId))
    }

    @Test
    fun `duplicate IDs do not replace the live session`() {
        val live = FakeMapSession(viewId = 3)
        val duplicate = FakeMapSession(viewId = 3)
        val registry = MapSessionRegistry()
        registry.register(live)

        assertThrows(IllegalStateException::class.java) {
            registry.register(duplicate)
        }

        assertSame(live, registry.get(live.viewId))
    }

    @Test
    fun `JNI lookup resolves one exposed registry`() {
        val session = FakeMapSession(viewId = 12)
        val registry = MapSessionRegistry()
        registry.register(session)
        MapSessionRegistry.expose(registry)

        try {
            assertSame(session, MapSessionRegistry.resolve(12))
        } finally {
            MapSessionRegistry.hide(registry)
        }
        assertNull(MapSessionRegistry.resolve(12))
    }

    @Test
    fun `JNI lookup fails closed for colliding engine view IDs`() {
        val first = MapSessionRegistry().apply {
            register(FakeMapSession(viewId = 13))
        }
        val second = MapSessionRegistry().apply {
            register(FakeMapSession(viewId = 13))
        }
        MapSessionRegistry.expose(first)
        MapSessionRegistry.expose(second)

        try {
            assertNull(MapSessionRegistry.resolve(13))
        } finally {
            MapSessionRegistry.hide(first)
            MapSessionRegistry.hide(second)
        }
    }

    @Test
    fun `clear disposes every session once`() {
        val first = FakeMapSession(viewId = 1)
        val second = FakeMapSession(viewId = 2)
        val registry = MapSessionRegistry()
        registry.register(first)
        registry.register(second)

        registry.clear()

        assertEquals(1, first.disposeCount)
        assertEquals(1, second.disposeCount)
        assertEquals(0, registry.size)
    }

    @Test
    fun `attachActivity wires save and restore for sessions that support it`() {
        val session = SaveRestoreFakeSession(viewId = 1)
        val plain = FakeMapSession(viewId = 2)
        val registry = MapSessionRegistry()
        registry.register(session)
        registry.register(plain)
        val binding = FakeActivityBinding()

        registry.attachActivity(binding)

        assertEquals(listOf(session), binding.saveStateListeners)
        assertEquals(2, binding.activityResultListeners.size)
    }

    @Test
    fun `sessions registered while attached get save and restore wiring`() {
        val registry = MapSessionRegistry()
        val binding = FakeActivityBinding()
        registry.attachActivity(binding)

        val session = SaveRestoreFakeSession(viewId = 3)
        registry.register(session)

        assertTrue(binding.saveStateListeners.contains(session))
        assertTrue(binding.activityResultListeners.contains(session))
    }

    @Test
    fun `detachActivity removes save and restore listeners`() {
        val session = SaveRestoreFakeSession(viewId = 1)
        val registry = MapSessionRegistry()
        registry.register(session)
        val binding = FakeActivityBinding()
        registry.attachActivity(binding)

        registry.detachActivity()

        assertTrue(binding.saveStateListeners.isEmpty())
        assertTrue(binding.activityResultListeners.isEmpty())
    }

    @Test
    fun `unregister removes only that session's save and restore listener`() {
        val first = SaveRestoreFakeSession(viewId = 1)
        val second = SaveRestoreFakeSession(viewId = 2)
        val registry = MapSessionRegistry()
        registry.register(first)
        registry.register(second)
        val binding = FakeActivityBinding()
        registry.attachActivity(binding)

        registry.unregister(first.viewId, first)
        // A stale unregister must not touch the live session's wiring.
        registry.unregister(first.viewId, first)

        assertEquals(listOf(second), binding.saveStateListeners)
    }

    @Test
    fun `reattachment moves save and restore listeners to the new binding`() {
        val session = SaveRestoreFakeSession(viewId = 1)
        val registry = MapSessionRegistry()
        registry.register(session)
        val first = FakeActivityBinding()
        val second = FakeActivityBinding()

        registry.attachActivity(first)
        registry.attachActivity(second)

        assertTrue(first.saveStateListeners.isEmpty())
        assertTrue(first.activityResultListeners.isEmpty())
        assertEquals(listOf(session), second.saveStateListeners)
    }
}

private open class FakeMapSession(
    override val viewId: Int,
) : MapSession {
    var lastLatitude: Double? = null
    var lastMoveAnimation: Boolean? = null
    var lastMarkerId: String? = null
    var lastBatchMarkerIds: List<String>? = null
    var lastShapeId: String? = null
    var lastRoadId: String? = null
    var overlaysVisible: Boolean? = null
    var disposeCount = 0

    override fun setActivity(activity: Activity?) = Unit

    override fun setEventSink(sink: MapEventSink) = Unit

    override fun initialize(latitude: Double, longitude: Double): Boolean = true

    override fun emitReady(isReady: Boolean) = Unit

    override fun setZoom(
        zoomLevel: Double?,
        stepZoom: Double?,
        animated: Boolean,
    ): Boolean = true

    override fun getZoom(): Double? = null

    override fun getZoomSnapshot(): Double? = null

    override fun getCameraPositionSnapshot(): DoubleArray? = null

    override fun moveTo(latitude: Double, longitude: Double, animate: Boolean): Boolean {
        lastLatitude = latitude
        lastMoveAnimation = animate
        return true
    }

    override fun setRotation(angle: Double, animate: Boolean): Boolean = true

    override fun getBoundsSnapshot(): DoubleArray? = null

    override fun zoomToBoundingBox(
        north: Double,
        south: Double,
        east: Double,
        west: Double,
        paddingInPixel: Int,
    ): Boolean = true

    override fun setBoundsLimit(
        north: Double,
        east: Double,
        south: Double,
        west: Double,
    ): Boolean = true

    override fun removeBoundsLimit(): Boolean = true

    override fun configureZoom(
        initZoom: Double,
        minZoomLevel: Double,
        maxZoomLevel: Double,
        stepZoom: Double,
    ): Boolean = true

    override fun addMarker(
        markerId: String,
        latitude: Double,
        longitude: Double,
        icon: ByteArray?,
        angleDegrees: Double,
        anchor: Anchor?,
    ): Boolean {
        lastMarkerId = markerId
        return true
    }

    override fun addMarkers(markerIds: Array<String>, coordinates: DoubleArray): Boolean {
        lastBatchMarkerIds = markerIds.toList()
        return true
    }

    override fun updateMarkerIcon(markerId: String, icon: ByteArray): Boolean = true

    override fun moveMarker(markerId: String, latitude: Double, longitude: Double): Boolean = true

    override fun rotateMarker(markerId: String, angleDegrees: Double): Boolean = true

    override fun setMarkerAnchor(markerId: String, anchor: Anchor): Boolean = true

    override fun removeMarker(markerId: String): Boolean = false

    override fun removeMarkers(markerIds: Array<String>): Boolean = true

    override fun addCircle(
        shapeId: String,
        latitude: Double,
        longitude: Double,
        radius: Double,
        fillColor: Int,
        borderColor: Int,
        strokeWidth: Double,
    ): Boolean {
        lastShapeId = shapeId
        return true
    }

    override fun addRectangle(
        shapeId: String,
        latitude: Double,
        longitude: Double,
        distance: Double,
        fillColor: Int,
        borderColor: Int,
        strokeWidth: Double,
    ): Boolean = true

    override fun removeShape(shapeId: String): Boolean = true

    override fun clearShapes(): Boolean = true

    override fun removeCircles(): Boolean = true

    override fun removeRectangles(): Boolean = true

    override fun setStaticPositions(
        groupId: String,
        coordinates: DoubleArray,
        icon: ByteArray?,
    ): Boolean = true

    override fun removeStaticPositions(groupId: String): Boolean = true

    override fun drawRoad(
        roadId: String,
        coordinates: DoubleArray,
        roadColor: Int,
        roadWidth: Double,
        borderColor: Int,
        borderWidth: Double,
        zoomInto: Boolean,
        dotted: Boolean,
    ): Boolean {
        lastRoadId = roadId
        return true
    }

    override fun removeRoad(roadId: String): Boolean = true

    override fun clearRoads(): Boolean = true

    override fun setRasterTile(
        url: String,
        sourceName: String,
        tileExtension: String,
        minZoom: Int,
        maxZoom: Int,
        apiKey: String?,
        apiValue: String?,
    ): Boolean = true

    override fun setVectorTile(
        styleUrl: String,
        sourceName: String,
        minZoom: Int,
        maxZoom: Int,
    ): Boolean = true

    override fun resetTile(): Boolean = true

    override fun setOverlaysVisible(visible: Boolean): Boolean {
        overlaysVisible = visible
        return true
    }

    override fun enableUserLocationLayer(): Boolean = true

    override fun requestLocationFix(listener: MapSession.LocationFixListener) = Unit

    override fun startLocationUpdates(listener: MapSession.LocationCommandListener) {
        listener.onComplete(null, null)
    }

    override fun stopLocationUpdates() = Unit


    override fun enableTracking(
        stopFollowInDrag: Boolean,
        disableMarkerRotation: Boolean,
        useDirectionMarker: Boolean,
        anchor: List<Double>?,
        listener: MapSession.LocationCommandListener,
    ) {
        listener.onComplete(null, null)
    }

    override fun disableTracking() = Unit

    override fun setUserLocationIcons(
        personIcon: ByteArray,
        directionIcon: ByteArray,
        personAnchor: List<Double>?,
        directionAnchor: List<Double>?,
        personLogicalSize: List<Int>?,
        directionLogicalSize: List<Int>?,
    ) = true

    override fun resetUserLocationIcons() = true

    override fun emitAcknowledgement(requestId: String, operation: String) = Unit

    override fun emitError(
        requestId: String,
        operation: String,
        code: String,
        message: String?,
    ) = Unit

    override fun emitMarkerTap(markerId: String, latitude: Double, longitude: Double) = Unit

    override fun dispose() {
        disposeCount += 1
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean = false
}

/** Session that also owns activity save/restore, like MapscoreMapSession. */
private class SaveRestoreFakeSession(viewId: Int) :
    FakeMapSession(viewId), ActivityPluginBinding.OnSaveInstanceStateListener {
    override fun onSaveInstanceState(bundle: Bundle) = Unit
    override fun onRestoreInstanceState(bundle: Bundle?) = Unit
}

/** Records listener registration; the activity itself is never touched. */
private class FakeActivityBinding : ActivityPluginBinding {
    val activityResultListeners = mutableListOf<PluginRegistry.ActivityResultListener>()
    val saveStateListeners = mutableListOf<ActivityPluginBinding.OnSaveInstanceStateListener>()

    override fun getActivity(): Activity = Activity()
    override fun getLifecycle(): Any = Any()

    override fun addActivityResultListener(listener: PluginRegistry.ActivityResultListener) {
        activityResultListeners += listener
    }

    override fun removeActivityResultListener(listener: PluginRegistry.ActivityResultListener) {
        activityResultListeners -= listener
    }

    override fun addOnSaveStateListener(listener: ActivityPluginBinding.OnSaveInstanceStateListener) {
        saveStateListeners += listener
    }

    override fun removeOnSaveStateListener(listener: ActivityPluginBinding.OnSaveInstanceStateListener) {
        saveStateListeners -= listener
    }

    override fun addRequestPermissionsResultListener(listener: PluginRegistry.RequestPermissionsResultListener) = Unit
    override fun removeRequestPermissionsResultListener(listener: PluginRegistry.RequestPermissionsResultListener) = Unit
    override fun addOnNewIntentListener(listener: PluginRegistry.NewIntentListener) = Unit
    override fun removeOnNewIntentListener(listener: PluginRegistry.NewIntentListener) = Unit
    override fun addOnUserLeaveHintListener(listener: PluginRegistry.UserLeaveHintListener) = Unit
    override fun removeOnUserLeaveHintListener(listener: PluginRegistry.UserLeaveHintListener) = Unit
    override fun addOnWindowFocusChangedListener(listener: PluginRegistry.WindowFocusChangedListener) = Unit
    override fun removeOnWindowFocusChangedListener(listener: PluginRegistry.WindowFocusChangedListener) = Unit
}

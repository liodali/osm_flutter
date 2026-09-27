package hamza.dali.flutter_osm_plugin

import android.app.Activity
import android.content.Intent
import hamza.dali.flutter_osm_plugin.mapscore.MapEventSink
import hamza.dali.flutter_osm_plugin.mapscore.MapSession
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
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
}

private class FakeMapSession(
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

    override fun moveTo(latitude: Double, longitude: Double, animate: Boolean): Boolean {
        lastLatitude = latitude
        lastMoveAnimation = animate
        return true
    }

    override fun setRotation(angle: Double, animate: Boolean): Boolean = true

    override fun addMarker(
        markerId: String,
        latitude: Double,
        longitude: Double,
        icon: ByteArray?,
    ): Boolean {
        lastMarkerId = markerId
        return true
    }

    override fun addMarkers(markerIds: Array<String>, coordinates: DoubleArray): Boolean {
        lastBatchMarkerIds = markerIds.toList()
        return true
    }

    override fun updateMarkerIcon(markerId: String, icon: ByteArray): Boolean = true

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

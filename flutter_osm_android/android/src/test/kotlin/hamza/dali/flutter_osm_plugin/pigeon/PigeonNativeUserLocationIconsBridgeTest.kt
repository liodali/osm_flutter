package hamza.dali.flutter_osm_plugin.pigeon

import hamza.dali.flutter_osm_plugin.mapscore.MapEventSink
import hamza.dali.flutter_osm_plugin.mapscore.MapSession
import hamza.dali.flutter_osm_plugin.mapscore.models.Anchor
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Delegation contract for the generated user-location icon host: the typed
 * configuration (PNG bytes, anchors) reaches the shared session, the reset
 * route restores defaults, stale sessions are rejected before delegation,
 * and swapping icons never disturbs follow-me tracking, continuous updates
 * or pending one-shot fixes.
 */
class PigeonNativeUserLocationIconsBridgeTest {
    private class RecordingMapSession : MapSession {
        override val viewId: Int = 5

        val calls = mutableListOf<String>()

        /** Last applied icon payload, retained for delegation assertions. */
        var lastPersonIcon: ByteArray? = null
        var lastDirectionIcon: ByteArray? = null
        var lastPersonAnchor: List<Double>? = null
        var lastDirectionAnchor: List<Double>? = null
        var lastPersonLogicalSize: List<Int>? = null
        var lastDirectionLogicalSize: List<Int>? = null

        /** Live consumer state the icon swap must never disturb. */
        var trackingActive = false
        var updatesActive = false
        var pendingFixCount = 0

        /** Simulates a session that cannot accept icons yet. */
        var iconsAvailable = true

        override fun enableTracking(
            stopFollowInDrag: Boolean,
            disableMarkerRotation: Boolean,
            useDirectionMarker: Boolean,
            anchor: List<Double>?,
            listener: MapSession.LocationCommandListener,
        ) {
            calls += "enableTracking"
            trackingActive = true
            listener.onComplete(null, null)
        }

        override fun disableTracking() {
            calls += "disableTracking"
            trackingActive = false
        }

        override fun startLocationUpdates(listener: MapSession.LocationCommandListener) {
            calls += "startLocationUpdates"
            updatesActive = true
            listener.onComplete(null, null)
        }

        override fun stopLocationUpdates() {
            calls += "stopLocationUpdates"
            updatesActive = false
        }

        override fun requestLocationFix(listener: MapSession.LocationFixListener) {
            calls += "requestLocationFix"
            pendingFixCount++
        }

        override fun setUserLocationIcons(
            personIcon: ByteArray,
            directionIcon: ByteArray,
            personAnchor: List<Double>?,
            directionAnchor: List<Double>?,
            personLogicalSize: List<Int>?,
            directionLogicalSize: List<Int>?,
        ): Boolean {
            calls += "setUserLocationIcons"
            if (!iconsAvailable) return false
            lastPersonIcon = personIcon
            lastDirectionIcon = directionIcon
            lastPersonAnchor = personAnchor
            lastDirectionAnchor = directionAnchor
            lastPersonLogicalSize = personLogicalSize
            lastDirectionLogicalSize = directionLogicalSize
            return true
        }

        override fun resetUserLocationIcons(): Boolean {
            calls += "resetUserLocationIcons"
            lastPersonIcon = null
            lastDirectionIcon = null
            lastPersonAnchor = null
            lastDirectionAnchor = null
            return iconsAvailable
        }

        override fun setActivity(activity: android.app.Activity?) = Unit

        override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?): Boolean =
            false

        override fun setEventSink(sink: MapEventSink) = Unit

        override fun initialize(latitude: Double, longitude: Double) = true

        override fun emitReady(isReady: Boolean) = Unit

        override fun setZoom(zoomLevel: Double?, stepZoom: Double?, animated: Boolean) = true

        override fun getZoom(): Double? = null

        override fun getZoomSnapshot(): Double? = null

        override fun getCameraPositionSnapshot(): DoubleArray? = null

        override fun moveTo(latitude: Double, longitude: Double, animate: Boolean) = true

        override fun setRotation(angle: Double, animate: Boolean) = true

        override fun getBoundsSnapshot(): DoubleArray? = null

        override fun zoomToBoundingBox(
            north: Double,
            south: Double,
            east: Double,
            west: Double,
            paddingInPixel: Int,
        ) = true

        override fun setBoundsLimit(
            north: Double,
            east: Double,
            south: Double,
            west: Double,
        ) = true

        override fun removeBoundsLimit() = true

        override fun configureZoom(
            initZoom: Double,
            minZoomLevel: Double,
            maxZoomLevel: Double,
            stepZoom: Double,
        ) = true

        override fun addMarker(
            markerId: String,
            latitude: Double,
            longitude: Double,
            icon: ByteArray?,
            angleDegrees: Double,
            anchor: Anchor?,
        ) = true

        override fun addMarkers(markerIds: Array<String>, coordinates: DoubleArray) = true

        override fun updateMarkerIcon(markerId: String, icon: ByteArray) = true

        override fun moveMarker(markerId: String, latitude: Double, longitude: Double) = true

        override fun rotateMarker(markerId: String, angleDegrees: Double) = true

        override fun setMarkerAnchor(markerId: String, anchor: Anchor) = true

        override fun removeMarker(markerId: String) = true

        override fun removeMarkers(markerIds: Array<String>) = true

        override fun addCircle(
            shapeId: String,
            latitude: Double,
            longitude: Double,
            radius: Double,
            fillColor: Int,
            borderColor: Int,
            strokeWidth: Double,
        ) = true

        override fun addRectangle(
            shapeId: String,
            latitude: Double,
            longitude: Double,
            distance: Double,
            fillColor: Int,
            borderColor: Int,
            strokeWidth: Double,
        ) = true

        override fun removeShape(shapeId: String) = true

        override fun removeCircles() = true

        override fun removeRectangles() = true

        override fun clearShapes() = true

        override fun setStaticPositions(
            groupId: String,
            coordinates: DoubleArray,
            icon: ByteArray?,
        ) = true

        override fun removeStaticPositions(groupId: String) = true

        override fun drawRoad(
            roadId: String,
            coordinates: DoubleArray,
            roadColor: Int,
            roadWidth: Double,
            borderColor: Int,
            borderWidth: Double,
            zoomInto: Boolean,
            dotted: Boolean,
        ) = true

        override fun removeRoad(roadId: String) = true

        override fun clearRoads() = true

        override fun setRasterTile(
            url: String,
            sourceName: String,
            tileExtension: String,
            minZoom: Int,
            maxZoom: Int,
            apiKey: String?,
            apiValue: String?,
        ) = true

        override fun setVectorTile(
            styleUrl: String,
            sourceName: String,
            minZoom: Int,
            maxZoom: Int,
        ) = true

        override fun resetTile() = true

        override fun setOverlaysVisible(visible: Boolean) = true

        override fun enableUserLocationLayer() = true


        override fun emitAcknowledgement(requestId: String, operation: String) = Unit

        override fun emitError(requestId: String, operation: String, code: String, message: String?) = Unit

        override fun emitMarkerTap(markerId: String, latitude: Double, longitude: Double) = Unit

        override fun dispose() = Unit
    }

    private fun wireSession() = NativeCameraSession(sessionToken = "token-5", generation = 2)

    private fun bridge(session: MapSession) =
        PigeonNativeUserLocationIconsBridge(session, sessionToken = "token-5", generation = 2L)

    private fun icon(
        bytes: ByteArray,
        width: Int? = null,
        height: Int? = null,
        anchorX: Double? = null,
        anchorY: Double? = null,
    ) = NativeUserLocationIcon(
        iconBytes = bytes,
        logicalSize = if (width != null && height != null) NativeMarkerSize(width.toLong(), height.toLong()) else null,
        anchor = if (anchorX != null && anchorY != null) NativeMarkerAnchor(anchorX, anchorY) else null,
    )

    private fun icons(
        personAnchorX: Double? = null,
        personAnchorY: Double? = null,
        directionAnchorX: Double? = null,
        directionAnchorY: Double? = null,
    ) = NativeUserLocationIcons(
        person = icon(byteArrayOf(1, 2, 3), 12, 20, personAnchorX, personAnchorY),
        direction = icon(byteArrayOf(4, 5, 6), 8, 14, directionAnchorX, directionAnchorY),
    )

    @Test
    fun `icon replacement delegates prepared bytes and anchors`() {
        val session = RecordingMapSession()
        bridge(session).setUserLocationIcons(
            wireSession(),
            icons(personAnchorX = 0.5, personAnchorY = 1.0),
        )
        assertEquals(listOf("setUserLocationIcons"), session.calls)
        assertArrayEquals(byteArrayOf(1, 2, 3), session.lastPersonIcon)
        assertArrayEquals(byteArrayOf(4, 5, 6), session.lastDirectionIcon)
        assertEquals(listOf(0.5, 1.0), session.lastPersonAnchor)
        assertNull(session.lastDirectionAnchor)
        // Logical (pre-scale) sizes reach the host so it renders at the
        // intended display size instead of the PNG pixel dimensions.
        assertEquals(listOf(12, 20), session.lastPersonLogicalSize)
        assertEquals(listOf(8, 14), session.lastDirectionLogicalSize)
    }

    @Test
    fun `repeated replacement stays idempotent and carries the newest anchors`() {
        val session = RecordingMapSession()
        val bridge = bridge(session)
        bridge.setUserLocationIcons(wireSession(), icons())
        bridge.setUserLocationIcons(
            wireSession(),
            icons(personAnchorX = 0.0, personAnchorY = 0.0),
        )
        assertEquals(
            listOf("setUserLocationIcons", "setUserLocationIcons"),
            session.calls,
        )
        assertEquals(listOf(0.0, 0.0), session.lastPersonAnchor)
    }

    @Test
    fun `icons without logical sizes keep the png pixel dimensions`() {
        val session = RecordingMapSession()
        val noSize = NativeUserLocationIcons(
            person = icon(byteArrayOf(1, 2, 3)),
            direction = icon(byteArrayOf(4, 5, 6)),
        )
        bridge(session).setUserLocationIcons(wireSession(), noSize)
        assertNull(session.lastPersonLogicalSize)
        assertNull(session.lastDirectionLogicalSize)
    }

    @Test
    fun `a null configuration restores the platform defaults`() {
        val session = RecordingMapSession()
        bridge(session).setUserLocationIcons(wireSession(), icons())
        bridge(session).setUserLocationIcons(wireSession(), null)
        assertEquals(
            listOf("setUserLocationIcons", "resetUserLocationIcons"),
            session.calls,
        )
        assertNull(session.lastPersonIcon)
        assertNull(session.lastDirectionIcon)
    }

    @Test
    fun `icon swaps preserve tracking updates and pending fixes`() {
        val session = RecordingMapSession()
        val bridge = bridge(session)
        val listener = MapSession.LocationCommandListener { _, _ -> }
        session.enableTracking(false, false, true, listOf(0.5, 0.5), listener)
        session.startLocationUpdates(listener)
        session.requestLocationFix { }

        bridge.setUserLocationIcons(wireSession(), icons())

        // Icon replacement never starts, stops or restarts a consumer.
        assertEquals(
            listOf("enableTracking", "startLocationUpdates", "requestLocationFix", "setUserLocationIcons"),
            session.calls,
        )
        assertTrue(session.trackingActive)
        assertTrue(session.updatesActive)
        assertEquals(1, session.pendingFixCount)
    }

    @Test
    fun `a session that cannot accept icons stays a silent no-op`() {
        val session = RecordingMapSession().apply { iconsAvailable = false }
        // The legacy route reported failures as success values; the typed
        // route keeps that non-failing behavior instead of surfacing an
        // error during map initialization.
        bridge(session).setUserLocationIcons(wireSession(), icons())
        assertEquals(listOf("setUserLocationIcons"), session.calls)
        assertNull(session.lastPersonIcon)
    }

    @Test
    fun `stale sessions are rejected before delegation`() {
        val session = RecordingMapSession()
        val stale = NativeCameraSession(sessionToken = "other", generation = 9)
        val error = runCatching {
            bridge(session).setUserLocationIcons(stale, icons())
        }.exceptionOrNull()
        assertTrue(error is FlutterError)
        assertEquals("stale_session", (error as FlutterError).code)
        assertEquals(emptyList<String>(), session.calls)
    }

    @Test
    fun `two sessions keep their own icon state`() {
        val first = RecordingMapSession()
        val second = RecordingMapSession()
        val firstBridge = PigeonNativeUserLocationIconsBridge(first, "token-5", 2L)
        val secondBridge = PigeonNativeUserLocationIconsBridge(second, "token-5", 2L)

        firstBridge.setUserLocationIcons(wireSession(), icons())
        secondBridge.setUserLocationIcons(wireSession(), null)

        assertEquals(listOf("setUserLocationIcons"), first.calls)
        assertEquals(listOf("resetUserLocationIcons"), second.calls)
        assertNull(second.lastPersonIcon)
    }
}

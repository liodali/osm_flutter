package hamza.dali.flutter_osm_plugin.pigeon

import hamza.dali.flutter_osm_plugin.mapscore.MapEventSink
import hamza.dali.flutter_osm_plugin.mapscore.MapSession
import hamza.dali.flutter_osm_plugin.mapscore.models.Anchor
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Delegation and exactly-once contract for the generated location host:
 * after the token/generation guard passes, the my-location toggle and
 * single-shot fixes reach the shared typed [MapSession]; every pending
 * request completes exactly once and late callbacks are ignored.
 */
class PigeonNativeLocationBridgeTest {
    private class RecordingMapSession : MapSession {
        override val viewId: Int = 5

        val calls = mutableListOf<String>()
        var enableLayerResult = true
        var fixOutcome: MapSession.LocationFixOutcome? = null
        var fixOutcomeRepeats = 0
        val registeredListeners = mutableListOf<MapSession.LocationFixListener>()

        override fun enableUserLocationLayer(): Boolean {
            calls += "enableUserLocationLayer"
            return enableLayerResult
        }

        override fun requestLocationFix(listener: MapSession.LocationFixListener) {
            calls += "requestLocationFix"
            registeredListeners += listener
            val outcome = fixOutcome ?: return
            listener.onOutcome(outcome)
            repeat(fixOutcomeRepeats) { listener.onOutcome(outcome) }
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

        override fun emitAcknowledgement(requestId: String, operation: String) = Unit

        override fun emitError(requestId: String, operation: String, code: String, message: String?) = Unit

        override fun emitMarkerTap(markerId: String, latitude: Double, longitude: Double) = Unit

        override fun dispose() = Unit
    }

    private fun wireSession() = NativeCameraSession(sessionToken = "token-5", generation = 2)

    private fun bridge(session: MapSession) =
        PigeonNativeLocationBridge(session, sessionToken = "token-5", generation = 2L)

    @Test
    fun `show my location delegates and completes once`() = runBlocking {
        val session = RecordingMapSession()
        bridge(session).showMyLocation(wireSession())
        assertEquals(listOf("enableUserLocationLayer"), session.calls)
    }

    @Test
    fun `show my location without an activity fails explicitly`() = runBlocking {
        val session = RecordingMapSession().apply { enableLayerResult = false }
        val error = runBlocking {
            try {
                bridge(session).showMyLocation(wireSession())
                null
            } catch (error: FlutterError) {
                error
            }
        } ?: throw AssertionError("expected a FlutterError")
        assertEquals(PigeonNativeLocationBridge.CODE_ACTIVITY_UNAVAILABLE, error.code)
    }

    @Test
    fun `fix returns the wire shape at full precision`() = runBlocking {
        val session = RecordingMapSession().apply {
            fixOutcome = MapSession.LocationFixOutcome.Fixed(47.376912345, 8.541712345)
        }
        val fix = bridge(session).getCurrentLocation(wireSession())

        assertEquals(47.376912345, fix.latitude, 0.0)
        assertEquals(8.541712345, fix.longitude, 0.0)
        assertEquals(listOf("requestLocationFix"), session.calls)
        assertEquals(1, session.registeredListeners.size)
    }

    @Test
    fun `late repeated outcomes are ignored`() = runBlocking {
        val session = RecordingMapSession().apply {
            fixOutcome = MapSession.LocationFixOutcome.Fixed(1.0, 2.0)
            fixOutcomeRepeats = 2
        }
        // Must not throw IllegalStateException from double resume.
        val fix = bridge(session).getCurrentLocation(wireSession())
        assertEquals(1.0, fix.latitude, 0.0)
    }

    @Test
    fun `failures carry the session codes verbatim`() {
        val session = RecordingMapSession().apply {
            fixOutcome = MapSession.LocationFixOutcome.Failed(
                code = "location_timeout",
                message = "timed out waiting for a foreground location fix.",
            )
        }
        val error = runBlocking {
            try {
                bridge(session).getCurrentLocation(wireSession())
                null
            } catch (error: FlutterError) {
                error
            }
        } ?: throw AssertionError("expected a FlutterError")
        assertEquals("location_timeout", error.code)
        assertNotNull(error.message)
    }

    @Test
    fun `stale session is rejected before any delegation`() = runBlocking {
        val session = RecordingMapSession()
        val stale = NativeCameraSession(sessionToken = "other-token", generation = 9)

        val error = runBlocking {
            try {
                bridge(session).showMyLocation(stale)
                null
            } catch (error: FlutterError) {
                error
            }
        } ?: throw AssertionError("expected a FlutterError")
        assertEquals(PigeonNativeLocationBridge.CODE_STALE_SESSION, error.code)
        assertEquals(emptyList<String>(), session.calls)
        assertNull(session.fixOutcome)
    }
}

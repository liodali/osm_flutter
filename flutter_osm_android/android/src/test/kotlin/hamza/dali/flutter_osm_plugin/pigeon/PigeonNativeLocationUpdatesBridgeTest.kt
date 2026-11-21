package hamza.dali.flutter_osm_plugin.pigeon

import hamza.dali.flutter_osm_plugin.mapscore.MapEventSink
import hamza.dali.flutter_osm_plugin.mapscore.MapSession
import hamza.dali.flutter_osm_plugin.mapscore.models.Anchor
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * Delegation and completion contract for the generated continuous-updates
 * host: start is idempotent and surfaces platform denial codes verbatim;
 * stop is idempotent, never prompts and never fails.
 */
class PigeonNativeLocationUpdatesBridgeTest {
    private class RecordingMapSession : MapSession {
        override val viewId: Int = 5

        val calls = mutableListOf<String>()
        var startFailureCode: String? = null
        var startFailureMessage: String? = null

        override fun startLocationUpdates(listener: MapSession.LocationCommandListener) {
            calls += "startLocationUpdates"
            listener.onComplete(startFailureCode, startFailureMessage)
        }

        override fun stopLocationUpdates() {

            calls += "stopLocationUpdates"
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

        override fun requestLocationFix(listener: MapSession.LocationFixListener) = Unit

        override fun emitAcknowledgement(requestId: String, operation: String) = Unit

        override fun emitError(requestId: String, operation: String, code: String, message: String?) = Unit

        override fun emitMarkerTap(markerId: String, latitude: Double, longitude: Double) = Unit

        override fun dispose() = Unit
    }

    private fun wireSession() = NativeCameraSession(sessionToken = "token-5", generation = 2)

    private fun bridge(session: MapSession) =
        PigeonNativeLocationUpdatesBridge(session, sessionToken = "token-5", generation = 2L)

    @Test
    fun `start delegates and completes once`() = runBlocking {
        val session = RecordingMapSession()
        bridge(session).startLocationUpdates(wireSession())
        assertEquals(listOf("startLocationUpdates"), session.calls)
    }

    @Test
    fun `repeated start stays idempotent`() = runBlocking {
        val session = RecordingMapSession()
        val updates = bridge(session)
        updates.startLocationUpdates(wireSession())
        updates.startLocationUpdates(wireSession())
        assertEquals(
            listOf("startLocationUpdates", "startLocationUpdates"),
            session.calls,
        )
    }

    @Test
    fun `service-disabled denial carries the session code`() {
        val session = RecordingMapSession().apply {
            startFailureCode = "location_service_disabled"
            startFailureMessage = "Location services are disabled."
        }
        val error = runBlocking {
            try {
                bridge(session).startLocationUpdates(wireSession())
                null
            } catch (error: FlutterError) {
                error
            }
        } ?: throw AssertionError("expected a FlutterError")
        assertEquals("location_service_disabled", error.code)
    }

    @Test
    fun `stop delegates and never fails`() = runBlocking {
        val session = RecordingMapSession()
        bridge(session).stopLocationUpdates(wireSession())
        assertEquals(listOf("stopLocationUpdates"), session.calls)
    }

    @Test
    fun `stop without start stays a harmless no-op`() = runBlocking {
        val session = RecordingMapSession()
        val updates = bridge(session)
        updates.stopLocationUpdates(wireSession())
        updates.stopLocationUpdates(wireSession())
        assertEquals(listOf("stopLocationUpdates", "stopLocationUpdates"), session.calls)
    }

    @Test
    fun `stale session is rejected before any delegation`() {
        val session = RecordingMapSession()
        val stale = NativeCameraSession(sessionToken = "other-token", generation = 9)

        val error = assertThrows(FlutterError::class.java) {
            runBlocking { bridge(session).startLocationUpdates(stale) }
        }
        assertEquals(PigeonNativeLocationUpdatesBridge.CODE_STALE_SESSION, error.code)
        assertEquals(emptyList<String>(), session.calls)
    }
}

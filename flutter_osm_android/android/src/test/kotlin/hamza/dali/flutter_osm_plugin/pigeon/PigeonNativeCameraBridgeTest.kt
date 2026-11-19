package hamza.dali.flutter_osm_plugin.pigeon

import hamza.dali.flutter_osm_plugin.mapscore.MapEventSink
import hamza.dali.flutter_osm_plugin.mapscore.MapSession
import hamza.dali.flutter_osm_plugin.mapscore.models.Anchor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * Delegation contract for the generated camera host, focused on the bounds
 * and zoom-configuration operations: after the token/generation guard
 * passes, every operation reaches the shared typed [MapSession] untouched.
 */
class PigeonNativeCameraBridgeTest {
    private class RecordingMapSession : MapSession {
        override val viewId: Int = 5

        val calls = mutableListOf<String>()
        val failingOperations = mutableSetOf<String>()

        private fun record(operation: String): Boolean {
            calls += operation
            return failingOperations.none { operation.startsWith(it) }
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

        override fun getBoundsSnapshot(): DoubleArray? =
            doubleArrayOf(49.0, 47.0, 4.0, 1.0)

        override fun zoomToBoundingBox(
            north: Double,
            south: Double,
            east: Double,
            west: Double,
            paddingInPixel: Int,
        ): Boolean = record("zoomToBoundingBox:$north:$south:$east:$west:$paddingInPixel")

        override fun setBoundsLimit(
            north: Double,
            east: Double,
            south: Double,
            west: Double,
        ): Boolean = record("setBoundsLimit:$north:$east:$south:$west")

        override fun removeBoundsLimit(): Boolean = record("removeBoundsLimit")

        override fun configureZoom(
            initZoom: Double,
            minZoomLevel: Double,
            maxZoomLevel: Double,
            stepZoom: Double,
        ): Boolean = record("configureZoom:$initZoom:$minZoomLevel:$maxZoomLevel:$stepZoom")

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

        override fun removeCircles() = true

        override fun removeRectangles() = true

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
        PigeonNativeCameraBridge(session, sessionToken = "token-5", generation = 2L)

    @Test
    fun `bounds query maps the snapshot to the wire shape`() {
        val session = RecordingMapSession()
        val bounds = bridge(session).getBounds(wireSession())

        assertEquals(49.0, bounds.north, 0.0)
        assertEquals(47.0, bounds.south, 0.0)
        assertEquals(4.0, bounds.east, 0.0)
        assertEquals(1.0, bounds.west, 0.0)
    }

    @Test
    fun `zoom to bounds forwards box and padding`() {
        val session = RecordingMapSession()
        bridge(session).zoomToBoundingBox(
            wireSession(),
            NativeBounds(north = 49.0, south = 47.0, east = 4.0, west = 1.0),
            paddingInPixel = 24L,
        )

        assertEquals(
            listOf("zoomToBoundingBox:49.0:47.0:4.0:1.0:24"),
            session.calls,
        )
    }

    @Test
    fun `limits forward the degree box in legacy field order`() {
        val session = RecordingMapSession()
        bridge(session).setBoundsLimit(
            wireSession(),
            NativeBounds(north = 49.0, south = 47.0, east = 4.0, west = 1.0),
        )
        bridge(session).removeBoundsLimit(wireSession())

        assertEquals(
            listOf("setBoundsLimit:49.0:4.0:47.0:1.0", "removeBoundsLimit"),
            session.calls,
        )
    }

    @Test
    fun `zoom configuration forwards all four levels`() {
        val session = RecordingMapSession()
        bridge(session).configureZoom(
            wireSession(),
            NativeZoomConfiguration(
                initZoom = 8.0,
                minZoomLevel = 2.0,
                maxZoomLevel = 19.0,
                stepZoom = 1.0,
            ),
        )

        assertEquals(
            listOf("configureZoom:8.0:2.0:19.0:1.0"),
            session.calls,
        )
    }

    @Test
    fun `session rejection maps to camera not ready`() {
        val session = RecordingMapSession().apply {
            failingOperations += "zoomToBoundingBox"
            failingOperations += "setBoundsLimit"
            failingOperations += "configureZoom"
        }
        val camera = bridge(session)

        val zoomError = assertThrows(FlutterError::class.java) {
            camera.zoomToBoundingBox(
                wireSession(),
                NativeBounds(north = 1.0, south = 0.0, east = 1.0, west = 0.0),
                paddingInPixel = 0L,
            )
        }
        assertEquals(PigeonNativeCameraBridge.CODE_CAMERA_NOT_READY, zoomError.code)

        val limitError = assertThrows(FlutterError::class.java) {
            camera.setBoundsLimit(
                wireSession(),
                NativeBounds(north = 1.0, south = 0.0, east = 1.0, west = 0.0),
            )
        }
        assertEquals(PigeonNativeCameraBridge.CODE_CAMERA_NOT_READY, limitError.code)

        val zoomConfigError = assertThrows(FlutterError::class.java) {
            camera.configureZoom(
                wireSession(),
                NativeZoomConfiguration(
                    initZoom = 8.0,
                    minZoomLevel = 2.0,
                    maxZoomLevel = 19.0,
                    stepZoom = 1.0,
                ),
            )
        }
        assertEquals(PigeonNativeCameraBridge.CODE_CAMERA_NOT_READY, zoomConfigError.code)
    }

    @Test
    fun `wrong session token fails with stale session error`() {
        val bridge = bridge(RecordingMapSession())
        val error = assertThrows(FlutterError::class.java) {
            bridge.getBounds(
                NativeCameraSession(sessionToken = "other", generation = 2),
            )
        }
        assertEquals(PigeonNativeCameraBridge.CODE_STALE_SESSION, error.code)
    }
}

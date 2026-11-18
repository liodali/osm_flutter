package hamza.dali.flutter_osm_plugin.pigeon

import hamza.dali.flutter_osm_plugin.mapscore.MapEventSink
import hamza.dali.flutter_osm_plugin.mapscore.MapSession
import hamza.dali.flutter_osm_plugin.mapscore.models.Anchor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * Delegation contract for the generated markers host: after the
 * token/generation guard passes, every operation reaches the shared typed
 * [MapSession] untouched, so legacy and generated marker endpoints keep one
 * native owner.
 */
class PigeonNativeMarkersBridgeTest {
    private class RecordingMapSession : MapSession {
        override val viewId: Int = 7

        val calls = mutableListOf<String>()

        /** Operations returning false simulate a not-ready native engine. */
        val failingOperations = mutableSetOf<String>()

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
            calls += "addMarker:$markerId:$latitude:$longitude:" +
                icon?.joinToString(separator = "") + ":$angleDegrees:" +
                anchor?.let { "${it.x},${it.y}" }
            return "addMarker" !in failingOperations
        }

        override fun addMarkers(markerIds: Array<String>, coordinates: DoubleArray): Boolean {
            calls += "addMarkers:${markerIds.toList()}:${coordinates.toList()}"
            return "addMarkers" !in failingOperations
        }

        override fun updateMarkerIcon(markerId: String, icon: ByteArray): Boolean {
            calls += "updateMarkerIcon:$markerId:${icon.size}"
            return "updateMarkerIcon" !in failingOperations
        }

        override fun moveMarker(markerId: String, latitude: Double, longitude: Double): Boolean {
            calls += "moveMarker:$markerId:$latitude:$longitude"
            return "moveMarker" !in failingOperations
        }

        override fun rotateMarker(markerId: String, angleDegrees: Double): Boolean {
            calls += "rotateMarker:$markerId:$angleDegrees"
            return "rotateMarker" !in failingOperations
        }

        override fun setMarkerAnchor(markerId: String, anchor: Anchor): Boolean {
            calls += "setMarkerAnchor:$markerId:${anchor.x},${anchor.y}"
            return "setMarkerAnchor" !in failingOperations
        }

        override fun removeMarker(markerId: String): Boolean {
            calls += "removeMarker:$markerId"
            return "removeMarker" !in failingOperations
        }

        override fun removeMarkers(markerIds: Array<String>): Boolean {
            calls += "removeMarkers:${markerIds.toList()}"
            return "removeMarkers" !in failingOperations
        }

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

        override fun removeCircles() = true

        override fun removeRectangles() = true

        override fun setStaticPositions(
            groupId: String,
            coordinates: DoubleArray,
            icon: ByteArray?,
        ): Boolean {
            calls += "setStaticPositions:$groupId:${coordinates.toList()}:" +
                icon?.size
            return "setStaticPositions" !in failingOperations
        }

        override fun removeStaticPositions(groupId: String): Boolean {
            calls += "removeStaticPositions:$groupId"
            return "removeStaticPositions" !in failingOperations
        }

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

        override fun dispose() {
            calls += "dispose"
        }
    }

    private fun wireSession() = NativeCameraSession(sessionToken = "token-7", generation = 3)

    private fun bridge(session: MapSession) =
        PigeonNativeMarkersBridge(session, sessionToken = "token-7", generation = 3L)

    @Test
    fun `add marker forwards id coordinates icon angle and anchor`() {
        val session = RecordingMapSession()
        bridge(session).addMarker(
            wireSession(),
            "m-1",
            48.85,
            2.35,
            byteArrayOf(1, 2, 3),
            90.0,
            NativeMarkerAnchor(x = 0.5, y = 1.0),
            NativeMarkerSize(width = 32, height = 48),
        )

        assertEquals(
            listOf("addMarker:m-1:48.85:2.35:123:90.0:0.5,1.0"),
            session.calls,
        )
    }

    @Test
    fun `add marker without icon keeps default marker`() {
        val session = RecordingMapSession()
        bridge(session).addMarker(
            wireSession(),
            "m-2",
            1.0,
            2.0,
            null,
            0.0,
            null,
            null,
        )

        assertEquals(listOf("addMarker:m-2:1.0:2.0:null:0.0:null"), session.calls)
    }

    @Test
    fun `batch add forwards parallel id list and coordinate pairs`() {
        val session = RecordingMapSession()
        bridge(session).addMarkers(
            wireSession(),
            listOf("a", "b"),
            doubleArrayOf(1.0, 2.0, 3.0, 4.0),
        )

        assertEquals(listOf("addMarkers:[a, b]:[1.0, 2.0, 3.0, 4.0]"), session.calls)
    }

    @Test
    fun `icon update move rotation and anchor reuse the typed session ops`() {
        val session = RecordingMapSession()
        val marker = bridge(session)

        marker.updateMarkerIcon(
            wireSession(),
            "m-1",
            byteArrayOf(9, 9),
            iconLogicalSize = NativeMarkerSize(width = 16, height = 16),
        )
        marker.moveMarker(wireSession(), "m-1", 10.0, 20.0)
        marker.rotateMarker(wireSession(), "m-1", 45.0)
        marker.setMarkerAnchor(wireSession(), "m-1", NativeMarkerAnchor(x = 1.0, y = 0.0))

        assertEquals(
            listOf(
                "updateMarkerIcon:m-1:2",
                "moveMarker:m-1:10.0:20.0",
                "rotateMarker:m-1:45.0",
                "setMarkerAnchor:m-1:1.0,0.0",
            ),
            session.calls,
        )
    }

    @Test
    fun `static group set and remove delegate with degrees triples and icon bytes`() {
        val session = RecordingMapSession()
        val marker = bridge(session)

        marker.setStaticPositions(
            wireSession(),
            "group-1",
            doubleArrayOf(1.0, 2.0, 30.0, 3.0, 4.0, 60.0),
            byteArrayOf(7),
            NativeMarkerSize(width = 12, height = 12),
        )
        marker.removeStaticPositions(wireSession(), "group-1")

        assertEquals(
            listOf(
                "setStaticPositions:group-1:[1.0, 2.0, 30.0, 3.0, 4.0, 60.0]:1",
                "removeStaticPositions:group-1",
            ),
            session.calls,
        )
    }

    @Test
    fun `remove operations forward stable ids`() {
        val session = RecordingMapSession()
        val marker = bridge(session)

        marker.removeMarker(wireSession(), "m-1")
        marker.removeMarkers(wireSession(), listOf("m-1", "m-2"))

        assertEquals(
            listOf("removeMarker:m-1", "removeMarkers:[m-1, m-2]"),
            session.calls,
        )
    }

    @Test
    fun `wrong session token fails with stale session error`() {
        val bridge = bridge(RecordingMapSession())
        val error = assertThrows(FlutterError::class.java) {
            bridge.addMarker(
                NativeCameraSession(sessionToken = "other", generation = 3),
                "m-1",
                0.0,
                0.0,
                null,
                0.0,
                null,
                null,
            )
        }
        assertEquals(PigeonNativeCameraBridge.CODE_STALE_SESSION, error.code)
    }

    @Test
    fun `wrong generation fails with stale session error`() {
        val bridge = bridge(RecordingMapSession())
        val error = assertThrows(FlutterError::class.java) {
            bridge.moveMarker(
                NativeCameraSession(sessionToken = "token-7", generation = 4),
                "m-1",
                0.0,
                0.0,
            )
        }
        assertEquals(PigeonNativeCameraBridge.CODE_STALE_SESSION, error.code)
    }

    @Test
    fun `session rejection maps to markers not ready error`() {
        val session = RecordingMapSession().apply {
            failingOperations += "addMarker"
            failingOperations += "setStaticPositions"
        }
        val marker = bridge(session)

        val addError = assertThrows(FlutterError::class.java) {
            marker.addMarker(wireSession(), "m-1", 0.0, 0.0, null, 0.0, null, null)
        }
        assertEquals(PigeonNativeCameraBridge.CODE_MARKERS_NOT_READY, addError.code)

        val staticError = assertThrows(FlutterError::class.java) {
            marker.setStaticPositions(
                wireSession(), "g", doubleArrayOf(1.0, 2.0, 0.0), null, null)
        }
        assertEquals(PigeonNativeCameraBridge.CODE_MARKERS_NOT_READY, staticError.code)

        assertNull(null)
    }
}

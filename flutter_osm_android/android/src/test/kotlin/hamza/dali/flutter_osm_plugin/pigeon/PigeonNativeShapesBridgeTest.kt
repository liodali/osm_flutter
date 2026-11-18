package hamza.dali.flutter_osm_plugin.pigeon

import hamza.dali.flutter_osm_plugin.mapscore.MapEventSink
import hamza.dali.flutter_osm_plugin.mapscore.MapSession
import hamza.dali.flutter_osm_plugin.mapscore.models.Anchor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * Delegation contract for the generated shapes host (circles and
 * rectangles): after the token/generation guard passes, every operation
 * reaches the shared typed [MapSession] untouched — ids, full coordinate
 * precision, packed ARGB colors and widths included. Removal by id and the
 * kind/full clears mirror the legacy silent no-op behavior.
 */
class PigeonNativeShapesBridgeTest {
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
        ): Boolean =
            record(
                "addCircle:$shapeId:$latitude:$longitude:$radius:" +
                    "%08X:%08X:$strokeWidth".format(fillColor, borderColor),
            )

        override fun addRectangle(
            shapeId: String,
            latitude: Double,
            longitude: Double,
            distance: Double,
            fillColor: Int,
            borderColor: Int,
            strokeWidth: Double,
        ): Boolean =
            record(
                "addRectangle:$shapeId:$latitude:$longitude:$distance:" +
                    "%08X:%08X:$strokeWidth".format(fillColor, borderColor),
            )

        override fun removeShape(shapeId: String): Boolean = record("removeShape:$shapeId")

        override fun removeCircles(): Boolean = record("removeCircles")

        override fun removeRectangles(): Boolean = record("removeRectangles")

        override fun clearShapes(): Boolean = record("clearShapes")

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
        PigeonNativeShapesBridge(session, sessionToken = "token-5", generation = 2L)

    private fun style(fill: Long = 0x8E24AAFFL, border: Long? = 0xFF00D2FFL, width: Double = 3.5) =
        NativeShapeStyle(
            fillColorArgb = fill,
            borderColorArgb = border,
            strokeWidth = width,
        )

    @Test
    fun `circle add forwards id, precision, packed colors and width`() {
        val session = RecordingMapSession()
        bridge(session).addCircle(
            wireSession(),
            shapeId = "circle-1",
            latitude = 47.376912345,
            longitude = 8.541712345,
            radius = 250.5,
            style = style(),
        )

        assertEquals(
            listOf("addCircle:circle-1:47.376912345:8.541712345:250.5:8E24AAFF:FF00D2FF:3.5"),
            session.calls,
        )
    }

    @Test
    fun `rectangle add forwards distance instead of radius`() {
        val session = RecordingMapSession()
        bridge(session).addRectangle(
            wireSession(),
            shapeId = "rect-1",
            latitude = -33.865143,
            longitude = 151.209900,
            distance = 1200.25,
            style = style(fill = 0x22004488L, border = null, width = 1.0),
        )

        // A missing border color falls back to the fill color, matching the
        // legacy decoder's default (border = filled).
        assertEquals(
            listOf("addRectangle:rect-1:-33.865143:151.2099:1200.25:22004488:22004488:1.0"),
            session.calls,
        )
    }

    @Test
    fun `replace re-issues the add for the same id`() {
        val session = RecordingMapSession()
        val shapes = bridge(session)
        shapes.addCircle(
            wireSession(), "circle-1", 47.0, 8.0, 100.0,
            style(fill = 0xFF000000L, border = 0xFF000000L),
        )
        shapes.addCircle(
            wireSession(), "circle-1", 47.1, 8.1, 200.0,
            style(fill = 0xFF111111L, border = 0xFF111111L),
        )

        // Both adds reach the session; the typed plane swaps the shape in
        // place (legacy draw#circle replace semantics).
        assertEquals(2, session.calls.size)
        assertEquals("circle-1", session.calls[1].split(':')[1])
    }

    @Test
    fun `removal by id and kind clears delegate`() {
        val session = RecordingMapSession()
        val shapes = bridge(session)
        shapes.removeShape(wireSession(), "circle-1")
        shapes.removeCircles(wireSession())
        shapes.removeRectangles(wireSession())
        shapes.clearShapes(wireSession())

        assertEquals(
            listOf("removeShape:circle-1", "removeCircles", "removeRectangles", "clearShapes"),
            session.calls,
        )
    }

    @Test
    fun `removal ignores unknown ids like the legacy handlers`() {
        val session = RecordingMapSession().apply { failingOperations += "removeShape" }
        // No exception: removal is a silent no-op, the boolean is ignored.
        bridge(session).removeShape(wireSession(), "missing-id")

        assertEquals(listOf("removeShape:missing-id"), session.calls)
    }

    @Test
    fun `stale session is rejected before any delegation`() {
        val session = RecordingMapSession()
        val stale = NativeCameraSession(sessionToken = "other-token", generation = 9)

        val error = assertThrows(FlutterError::class.java) {
            bridge(session).addCircle(
                stale, "circle-1", 47.0, 8.0, 100.0, style(),
            )
        }
        assertEquals(PigeonNativeShapesBridge.CODE_STALE_SESSION, error.code)
        assertEquals(emptyList<String>(), session.calls)
    }

    @Test
    fun `failing add maps to shapes not ready`() {
        val session = RecordingMapSession().apply { failingOperations += "addCircle" }

        val error = assertThrows(FlutterError::class.java) {
            bridge(session).addCircle(
                wireSession(), "circle-1", 47.0, 8.0, 100.0, style(),
            )
        }
        assertEquals(PigeonNativeShapesBridge.CODE_SHAPES_NOT_READY, error.code)
    }
}

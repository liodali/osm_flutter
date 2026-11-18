package hamza.dali.flutter_osm_plugin.pigeon

import hamza.dali.flutter_osm_plugin.mapscore.MapEventSink
import hamza.dali.flutter_osm_plugin.mapscore.MapSession
import hamza.dali.flutter_osm_plugin.mapscore.models.Anchor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * Delegation contract for the generated roads host (manual drawing,
 * removal by id, clearing): after the token/generation guard passes, every
 * operation reaches the shared typed [MapSession] untouched — ids, flat
 * coordinate precision, packed ARGB colors, widths, borders, dotted flag
 * and zoom-to-route included. Removal of unknown keys stays silent, like
 * the legacy delete#road handler.
 */
class PigeonNativeRoadsBridgeTest {
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
        ): Boolean = record(
            "drawRoad:$roadId:${coordinates.joinToString(",")}:" +
                "%08X:%s:%08X:%s:$zoomInto:$dotted"
                    .format(roadColor, roadWidth, borderColor, borderWidth)
        )

        override fun removeRoad(roadId: String): Boolean = record("removeRoad:$roadId")

        override fun clearRoads(): Boolean = record("clearRoads")

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
        PigeonNativeRoadsBridge(session, sessionToken = "token-5", generation = 2L)

    private fun style(
        road: Long = 0x4CAF50FFL,
        width: Double = 5.0,
        border: Long? = 0xFFFFFFFFL,
        borderWidth: Double? = 2.0,
        dotted: Boolean = false,
    ) = NativeRoadStyle(
        roadColorArgb = road,
        roadWidth = width,
        borderColorArgb = border,
        borderWidth = borderWidth,
        dotted = dotted,
    )

    @Test
    fun `draw forwards id, flat coordinates at full precision, colors and flags`() {
        val session = RecordingMapSession()
        bridge(session).drawRoad(
            wireSession(),
            roadId = "route-1",
            coordinates = doubleArrayOf(47.376912345, 8.541712345, 47.1, 8.2, 47.0, 8.0),
            style = style(dotted = true),
            zoomInto = true,
        )

        assertEquals(
            listOf(
                "drawRoad:route-1:47.376912345,8.541712345,47.1,8.2,47.0,8.0:" +
                    "4CAF50FF:5.0:FFFFFFFF:2.0:true:true",
            ),
            session.calls,
        )
    }

    @Test
    fun `null border keeps the legacy manual defaults`() {
        val session = RecordingMapSession()
        bridge(session).drawRoad(
            wireSession(),
            roadId = "route-1",
            coordinates = doubleArrayOf(47.0, 8.0, 47.1, 8.1),
            style = style(border = null, borderWidth = null),
            zoomInto = false,
        )

        // Null border color → transparent black (0), null width → 0.0,
        // matching the legacy drawRoad#manually decoding defaults.
        assertEquals(
            listOf("drawRoad:route-1:47.0,8.0,47.1,8.1:4CAF50FF:5.0:00000000:0.0:false:false"),
            session.calls,
        )
    }

    @Test
    fun `replacement re-issues draw for the same id`() {
        val session = RecordingMapSession()
        val roads = bridge(session)
        roads.drawRoad(
            wireSession(), "route-1",
            doubleArrayOf(47.0, 8.0, 47.1, 8.1), style(), false,
        )
        roads.drawRoad(
            wireSession(), "route-1",
            doubleArrayOf(47.2, 8.2, 47.3, 8.3),
            style(width = 7.0), false,
        )

        // Replace semantics live in the typed plane (drawRoad removes the
        // old road after validation); the bridge just re-issues the draw.
        assertEquals(2, session.calls.size)
        assertEquals("route-1", session.calls[1].split(':')[1])
    }

    @Test
    fun `removal and clear delegate`() {
        val session = RecordingMapSession()
        val roads = bridge(session)
        roads.removeRoad(wireSession(), "route-1")
        roads.clearRoads(wireSession())

        assertEquals(listOf("removeRoad:route-1", "clearRoads"), session.calls)
    }

    @Test
    fun `removal ignores unknown keys like the legacy handler`() {
        val session = RecordingMapSession().apply { failingOperations += "removeRoad" }
        // No exception: removal is a silent no-op, the boolean is ignored.
        bridge(session).removeRoad(wireSession(), "missing-road")
        assertEquals(listOf("removeRoad:missing-road"), session.calls)
    }

    @Test
    fun `stale session is rejected before any delegation`() {
        val session = RecordingMapSession()
        val stale = NativeCameraSession(sessionToken = "other-token", generation = 9)

        val error = assertThrows(FlutterError::class.java) {
            bridge(session).drawRoad(
                stale, "route-1",
                doubleArrayOf(47.0, 8.0, 47.1, 8.1), style(), false,
            )
        }
        assertEquals(PigeonNativeRoadsBridge.CODE_STALE_SESSION, error.code)
        assertEquals(emptyList<String>(), session.calls)
    }

    @Test
    fun `failing operations map to roads not ready`() {
        val session = RecordingMapSession().apply {
            failingOperations += "drawRoad"
            failingOperations += "clearRoads"
        }
        val roads = bridge(session)

        val drawError = assertThrows(FlutterError::class.java) {
            roads.drawRoad(
                wireSession(), "route-1",
                doubleArrayOf(47.0, 8.0, 47.1, 8.1), style(), false,
            )
        }
        assertEquals(PigeonNativeRoadsBridge.CODE_ROADS_NOT_READY, drawError.code)

        val clearError = assertThrows(FlutterError::class.java) {
            roads.clearRoads(wireSession())
        }
        assertEquals(PigeonNativeRoadsBridge.CODE_ROADS_NOT_READY, clearError.code)
    }
}

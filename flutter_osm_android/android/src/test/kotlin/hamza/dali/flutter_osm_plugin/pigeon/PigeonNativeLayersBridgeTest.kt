package hamza.dali.flutter_osm_plugin.pigeon

import hamza.dali.flutter_osm_plugin.mapscore.MapEventSink
import hamza.dali.flutter_osm_plugin.mapscore.MapSession
import hamza.dali.flutter_osm_plugin.mapscore.models.Anchor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * Delegation contract for the generated layers host (tile sources and
 * overlay visibility): after the token/generation guard passes, every
 * operation reaches the shared typed [MapSession] untouched, with the
 * raster subdomain expansion mirroring the legacy Android decoder.
 */
class PigeonNativeLayersBridgeTest {
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
        ): Boolean = record("setRasterTile:$url:$sourceName:$tileExtension:$minZoom:$maxZoom:$apiKey:$apiValue")

        override fun setVectorTile(
            styleUrl: String,
            sourceName: String,
            minZoom: Int,
            maxZoom: Int,
        ): Boolean = record("setVectorTile:$styleUrl:$sourceName:$minZoom:$maxZoom")

        override fun resetTile(): Boolean = record("resetTile")

        override fun removeCircles(): Boolean = record("removeCircles")

        override fun removeRectangles(): Boolean = record("removeRectangles")

        override fun setOverlaysVisible(visible: Boolean): Boolean = record("setOverlaysVisible:$visible")

        override fun enableUserLocationLayer(): Boolean = record("enableUserLocationLayer")

        override fun requestLocationFix(listener: MapSession.LocationFixListener) = Unit

        override fun startLocationUpdates(listener: MapSession.LocationCommandListener) {
            listener.onComplete(null, null)
        }

        override fun stopLocationUpdates() = Unit


        override fun enableTracking(
            stopFollowInDrag: Boolean,
            disableMarkerRotation: Boolean,
            useDirectionMarker: Boolean,
            anchor: List<Double>,
            listener: MapSession.LocationCommandListener,
        ) {
            calls += "enableTracking"
            listener.onComplete(null, null)
        }

        override fun disableTracking() {
            calls += "disableTracking"
        }

        override fun emitAcknowledgement(requestId: String, operation: String) = Unit

        override fun emitError(requestId: String, operation: String, code: String, message: String?) = Unit

        override fun emitMarkerTap(markerId: String, latitude: Double, longitude: Double) = Unit

        override fun dispose() = Unit
    }

    private fun wireSession() = NativeCameraSession(sessionToken = "token-5", generation = 2)

    private fun bridge(session: MapSession) =
        PigeonNativeLayersBridge(session, sessionToken = "token-5", generation = 2L)

    private fun rasterTile(
        url: String = "https://{s}.tiles.example.org/style/",
        subdomains: List<String> = listOf("a", "b"),
    ) = NativeTileConfiguration(
        urls = listOf(NativeTileServer(url = url, subdomains = subdomains)),
        tileExtension = ".png",
        sourceName = "example-source",
        tileSize = 256L,
        minZoomLevel = 3L,
        maxZoomLevel = 18L,
        apiKey = "access-token",
        apiValue = "secret",
        styleURL = null,
    )

    @Test
    fun `raster tile expands the first subdomain like the legacy decoder`() {
        val session = RecordingMapSession()
        bridge(session).changeTileLayer(wireSession(), rasterTile())

        assertEquals(
            listOf("setRasterTile:https://a.tiles.example.org/style/:example-source:.png:3:18:access-token:secret"),
            session.calls,
        )
    }

    @Test
    fun `raster tile without subdomains keeps the raw template`() {
        val session = RecordingMapSession()
        bridge(session).changeTileLayer(
            wireSession(),
            rasterTile(url = "https://tile.memomaps.de/tilegen/", subdomains = emptyList()),
        )

        assertEquals(
            listOf("setRasterTile:https://tile.memomaps.de/tilegen/:example-source:.png:3:18:access-token:secret"),
            session.calls,
        )
    }

    @Test
    fun `vector tile forwards the style url`() {
        val session = RecordingMapSession()
        bridge(session).changeTileLayer(
            wireSession(),
            rasterTile().copy(styleURL = "https://tiles.openfreemap.org/styles/liberty"),
        )

        assertEquals(
            listOf("setVectorTile:https://tiles.openfreemap.org/styles/liberty:example-source:3:18"),
            session.calls,
        )
    }

    @Test
    fun `null tile resets the default layer`() {
        val session = RecordingMapSession()
        bridge(session).changeTileLayer(wireSession(), null)

        assertEquals(listOf("resetTile"), session.calls)
    }

    @Test
    fun `tile configuration without urls fails with layers not ready`() {
        val session = RecordingMapSession()
        val empty = rasterTile().copy(urls = emptyList())

        val error = assertThrows(FlutterError::class.java) {
            bridge(session).changeTileLayer(wireSession(), empty)
        }
        assertEquals(PigeonNativeLayersBridge.CODE_LAYERS_NOT_READY, error.code)
        assertEquals(emptyList<String>(), session.calls)
    }

    @Test
    fun `overlay visibility forwards the flag`() {
        val session = RecordingMapSession()
        val layers = bridge(session)
        layers.setOverlaysVisible(wireSession(), true)
        layers.setOverlaysVisible(wireSession(), false)

        assertEquals(listOf("setOverlaysVisible:true", "setOverlaysVisible:false"), session.calls)
    }

    @Test
    fun `stale session is rejected before any delegation`() {
        val session = RecordingMapSession()
        val stale = NativeCameraSession(sessionToken = "other-token", generation = 9)

        val error = assertThrows(FlutterError::class.java) {
            bridge(session).changeTileLayer(stale, rasterTile())
        }
        assertEquals(PigeonNativeLayersBridge.CODE_STALE_SESSION, error.code)
        assertEquals(emptyList<String>(), session.calls)
    }

    @Test
    fun `failing operations map to layers not ready`() {
        val session = RecordingMapSession().apply {
            failingOperations += "setRasterTile"
            failingOperations += "resetTile"
            failingOperations += "setOverlaysVisible"
        }
        val layers = bridge(session)

        val rasterError = assertThrows(FlutterError::class.java) {
            layers.changeTileLayer(wireSession(), rasterTile())
        }
        assertEquals(PigeonNativeLayersBridge.CODE_LAYERS_NOT_READY, rasterError.code)

        val resetError = assertThrows(FlutterError::class.java) {
            layers.changeTileLayer(wireSession(), null)
        }
        assertEquals(PigeonNativeLayersBridge.CODE_LAYERS_NOT_READY, resetError.code)

        val overlaysError = assertThrows(FlutterError::class.java) {
            layers.setOverlaysVisible(wireSession(), true)
        }
        assertEquals(PigeonNativeLayersBridge.CODE_LAYERS_NOT_READY, overlaysError.code)
    }
}

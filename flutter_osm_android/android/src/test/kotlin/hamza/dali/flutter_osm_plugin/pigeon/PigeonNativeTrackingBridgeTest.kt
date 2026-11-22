package hamza.dali.flutter_osm_plugin.pigeon

import hamza.dali.flutter_osm_plugin.mapscore.MapEventSink
import hamza.dali.flutter_osm_plugin.mapscore.MapSession
import hamza.dali.flutter_osm_plugin.mapscore.models.Anchor
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Delegation and completion contract for the generated follow-me tracking
 * host: enable is idempotent, carries the typed configuration and
 * surfaces platform denial codes verbatim; disable is idempotent, never
 * prompts and never fails, and must reconcile with the shared location
 * consumers (continuous updates and pending one-shot fixes survive a
 * tracking stop).
 */
class PigeonNativeTrackingBridgeTest {
    private class RecordingMapSession : MapSession {
        override val viewId: Int = 5

        val calls = mutableListOf<String>()
        var enableFailureCode: String? = null
        var enableFailureMessage: String? = null
        var lastAnchor: List<Double>? = null
        var lastStopFollowInDrag: Boolean? = null
        var lastUseDirectionMarker: Boolean? = null
        var lastDisableRotation: Boolean? = null

        override fun startLocationUpdates(listener: MapSession.LocationCommandListener) = Unit

        override fun stopLocationUpdates() = Unit

        override fun enableTracking(
            stopFollowInDrag: Boolean,
            disableMarkerRotation: Boolean,
            useDirectionMarker: Boolean,
            anchor: List<Double>?,
            listener: MapSession.LocationCommandListener,
        ) {
            calls += "enableTracking"
            lastAnchor = anchor
            lastStopFollowInDrag = stopFollowInDrag
            lastUseDirectionMarker = useDirectionMarker
            lastDisableRotation = disableMarkerRotation
            listener.onComplete(enableFailureCode, enableFailureMessage)
        }

        override fun disableTracking() {
            calls += "disableTracking"
        }

        override fun setUserLocationIcons(
            personIcon: ByteArray,
            directionIcon: ByteArray,
            personAnchor: List<Double>?,
            directionAnchor: List<Double>?,
            personLogicalSize: List<Int>?,
            directionLogicalSize: List<Int>?,
        ) = true

        override fun resetUserLocationIcons() = true

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

    private fun config(
        stopFollowInDrag: Boolean = true,
        disableMarkerRotation: Boolean = false,
        useDirectionMarker: Boolean = true,
        anchorX: Double? = 0.5,
        anchorY: Double? = 1.0,
    ) = NativeTrackingConfiguration(
        stopFollowInDrag = stopFollowInDrag,
        disableMarkerRotation = disableMarkerRotation,
        useDirectionMarker = useDirectionMarker,
        anchor = if (anchorX == null || anchorY == null) {
            null
        } else {
            NativeMarkerAnchor(x = anchorX, y = anchorY)
        },
    )

    private fun bridge(session: MapSession) =
        PigeonNativeTrackingBridge(session, sessionToken = "token-5", generation = 2L)

    @Test
    fun `enable delegates the typed configuration and completes once`() = runBlocking {
        val session = RecordingMapSession()
        bridge(session).enableTracking(wireSession(), config())
        assertEquals(listOf("enableTracking"), session.calls)
        assertEquals(listOf(0.5, 1.0), session.lastAnchor)
        assertEquals(true, session.lastStopFollowInDrag)
        assertEquals(false, session.lastDisableRotation)
        assertEquals(true, session.lastUseDirectionMarker)
    }

    @Test
    fun `an omitted anchor keeps the live icon pivot`() = runBlocking {
        // Starting tracking without an explicit override must not re-center
        // anchors the application configured for its own icons.
        val session = RecordingMapSession()
        bridge(session).enableTracking(wireSession(), config(anchorX = null, anchorY = null))
        assertEquals(listOf("enableTracking"), session.calls)
        assertNull(session.lastAnchor)
    }

    @Test
    fun `repeated enable and disable stay idempotent`() = runBlocking {
        val session = RecordingMapSession()
        val tracking = bridge(session)
        tracking.enableTracking(wireSession(), config())
        tracking.enableTracking(wireSession(), config())
        tracking.disableTracking(wireSession())
        tracking.disableTracking(wireSession())
        assertEquals(
            listOf("enableTracking", "enableTracking", "disableTracking", "disableTracking"),
            session.calls,
        )
    }

    @Test
    fun `service-disabled denial carries the session code`() {
        val session = RecordingMapSession().apply {
            enableFailureCode = "location_service_disabled"
            enableFailureMessage = "Location services are disabled."
        }
        val error = runBlocking {
            runCatching { bridge(session).enableTracking(wireSession(), config()) }
                .exceptionOrNull()!!
        }
        assertTrue(error is FlutterError)
        assertEquals("location_service_disabled", (error as FlutterError).code)
    }

    @Test
    fun `stale sessions are rejected before delegation`() {
        val session = RecordingMapSession()
        val stale = NativeCameraSession(sessionToken = "other", generation = 9)
        val error = runBlocking {
            runCatching { bridge(session).enableTracking(stale, config()) }
                .exceptionOrNull()!!
        }
        assertEquals("stale_session", (error as FlutterError).code)
        val stopError = runBlocking {
            runCatching { bridge(session).disableTracking(stale) }
                .exceptionOrNull()!!
        }
        assertEquals("stale_session", (stopError as FlutterError).code)
        assertEquals(emptyList<String>(), session.calls)
    }

    @Test
    fun `disable never surfaces an error and preserves consumers`() = runBlocking {
        val session = RecordingMapSession()
        // The session-level reconciliation (updates + pending fixes) lives
        // in MapscoreMapSession; the bridge contract is delegation without
        // error plumbing.
        bridge(session).disableTracking(wireSession())
        assertEquals(listOf("disableTracking"), session.calls)
    }
}

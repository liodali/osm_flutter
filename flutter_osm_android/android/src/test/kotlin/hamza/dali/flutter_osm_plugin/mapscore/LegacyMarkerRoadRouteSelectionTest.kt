package hamza.dali.flutter_osm_plugin.mapscore

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Attach-time marker and road event route selections on the legacy channel:
 * the payloads are validated, the session selectors decide, and typed error
 * codes reach the Dart client verbatim. The probe, the earlier event route
 * selections and the legacy command set are untouched.
 */
class LegacyMarkerRoadRouteSelectionTest {

    private class NoopMessenger : BinaryMessenger {
        override fun send(channel: String, message: ByteBuffer?) = Unit
        override fun send(
            channel: String,
            message: ByteBuffer?,
            callback: BinaryMessenger.BinaryReply?,
        ) = Unit

        override fun setMessageHandler(
            channel: String,
            handler: BinaryMessenger.BinaryMessageHandler?,
        ) = Unit
    }

    private class RecordingResult : MethodChannel.Result {
        var success: Any? = null
        var errorCode: String? = null
        var notImplemented = false

        override fun success(result: Any?) {
            success = result
        }

        override fun error(code: String, message: String?, details: Any?) {
            errorCode = code
        }

        override fun notImplemented() {
            notImplemented = true
        }
    }

    private fun adapter(
        markerSelector: ((String, Long, String) -> String?)? = null,
        roadSelector: ((String, Long, String) -> String?)? = null,
    ) = LegacyMethodChannelAdapter(
        messenger = NoopMessenger(),
        viewId = 5,
        dispatch = { _, _, result -> result.success(null) },
        typedDispatch = { _, _, result -> result.success(null) },
        bootstrapProvider = { mapOf("revision" to 1) },
        markerRouteSelector = markerSelector,
        roadRouteSelector = roadSelector,
    )

    private fun markerCall(route: String = "pigeon"): MethodCall = MethodCall(
        LegacyMethodChannelAdapter.NATIVE_MARKER_ROUTE_METHOD,
        mapOf(
            "sessionToken" to "token-5",
            "generation" to 0,
            "route" to route,
        ),
    )

    private fun roadCall(route: String = "pigeon"): MethodCall = MethodCall(
        LegacyMethodChannelAdapter.NATIVE_ROAD_ROUTE_METHOD,
        mapOf(
            "sessionToken" to "token-5",
            "generation" to 0,
            "route" to route,
        ),
    )

    @Test
    fun `accepted selections answer true and forward the identity`() {
        var markerSeen: Triple<String, Long, String>? = null
        var roadSeen: Triple<String, Long, String>? = null
        val subject = adapter(
            markerSelector = { token, generation, route ->
                markerSeen = Triple(token, generation, route)
                null
            },
            roadSelector = { token, generation, route ->
                roadSeen = Triple(token, generation, route)
                null
            },
        )
        val markerResult = RecordingResult()
        val roadResult = RecordingResult()
        subject.onMethodCall(markerCall(), markerResult)
        subject.onMethodCall(roadCall(), roadResult)

        assertEquals(true, markerResult.success)
        assertNull(markerResult.errorCode)
        assertEquals(Triple("token-5", 0L, "pigeon"), markerSeen)
        assertEquals(true, roadResult.success)
        assertNull(roadResult.errorCode)
        assertEquals(Triple("token-5", 0L, "pigeon"), roadSeen)
    }

    @Test
    fun `stale session selections surface the typed error codes`() {
        val subject = adapter(
            markerSelector = { _, _, _ -> "stale_session" },
            roadSelector = { _, _, _ -> "stale_session" },
        )
        val markerResult = RecordingResult()
        val roadResult = RecordingResult()
        subject.onMethodCall(markerCall(), markerResult)
        subject.onMethodCall(roadCall(), roadResult)

        assertEquals("stale_session", markerResult.errorCode)
        assertEquals("stale_session", roadResult.errorCode)
    }

    @Test
    fun `unknown route values are rejected`() {
        val subject = adapter(
            markerSelector = { _, _, route ->
                if (route != "pigeon" && route != "legacy") "invalid_route" else null
            },
            roadSelector = { _, _, route ->
                if (route != "pigeon" && route != "legacy") "invalid_route" else null
            },
        )
        val markerResult = RecordingResult()
        val roadResult = RecordingResult()
        subject.onMethodCall(markerCall(route = "carrier-pigeon"), markerResult)
        subject.onMethodCall(roadCall(route = "carrier-pigeon"), roadResult)

        assertEquals("invalid_route", markerResult.errorCode)
        assertEquals("invalid_route", roadResult.errorCode)
    }

    @Test
    fun `malformed payloads are rejected without invoking the selectors`() {
        var markerInvoked = false
        var roadInvoked = false
        val subject = adapter(
            markerSelector = { _, _, _ -> markerInvoked = true; null },
            roadSelector = { _, _, _ -> roadInvoked = true; null },
        )
        val markerResult = RecordingResult()
        val roadResult = RecordingResult()
        subject.onMethodCall(
            MethodCall(
                LegacyMethodChannelAdapter.NATIVE_MARKER_ROUTE_METHOD,
                mapOf("route" to "pigeon"),
            ),
            markerResult,
        )
        subject.onMethodCall(
            MethodCall(
                LegacyMethodChannelAdapter.NATIVE_ROAD_ROUTE_METHOD,
                mapOf("route" to "pigeon"),
            ),
            roadResult,
        )

        assertEquals("invalid_route", markerResult.errorCode)
        assertTrue(!markerInvoked)
        assertEquals("invalid_route", roadResult.errorCode)
        assertTrue(!roadInvoked)
    }

    @Test
    fun `legacy route selections are accepted for symmetry`() {
        var markerRoute: String? = null
        var roadRoute: String? = null
        val subject = adapter(
            markerSelector = { _, _, route -> markerRoute = route; null },
            roadSelector = { _, _, route -> roadRoute = route; null },
        )
        val markerResult = RecordingResult()
        val roadResult = RecordingResult()
        subject.onMethodCall(markerCall(route = "legacy"), markerResult)
        subject.onMethodCall(roadCall(route = "legacy"), roadResult)

        assertEquals(true, markerResult.success)
        assertEquals("legacy", markerRoute)
        assertEquals(true, roadResult.success)
        assertEquals("legacy", roadRoute)
    }

    @Test
    fun `the earlier event route selections remain recognized endpoints`() {
        val subject = adapter()
        for (method in listOf(
            LegacyMethodChannelAdapter.NATIVE_LIFECYCLE_ROUTE_METHOD,
            LegacyMethodChannelAdapter.NATIVE_INTERACTION_ROUTE_METHOD,
        )) {
            val result = RecordingResult()
            subject.onMethodCall(
                MethodCall(
                    method,
                    mapOf(
                        "sessionToken" to "token-5",
                        "generation" to 0,
                        "route" to "pigeon",
                    ),
                ),
                result,
            )
            // The selectors stay unwired in this adapter instance, but their
            // endpoints must remain recognized selections (not notImplemented
            // and not legacy commands).
            assertEquals("invalid_route", result.errorCode)
        }

        val unknown = RecordingResult()
        subject.onMethodCall(MethodCall("no#such#command", null), unknown)
        assertTrue(unknown.notImplemented)
    }
}

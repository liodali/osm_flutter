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
 * Attach-time user-location event route selection on the legacy channel:
 * the payload is validated, the session selector decides, and typed error
 * codes reach the Dart client verbatim. The probe, the earlier event route
 * selections and the legacy command set are untouched.
 */
class LegacyLocationRouteSelectionTest {

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
        locationSelector: ((String, Long, String) -> String?)? = null,
    ) = LegacyMethodChannelAdapter(
        messenger = NoopMessenger(),
        viewId = 5,
        dispatch = { _, _, result -> result.success(null) },
        typedDispatch = { _, _, result -> result.success(null) },
        bootstrapProvider = { mapOf("revision" to 1) },
        locationRouteSelector = locationSelector,
    )

    private fun locationCall(route: String = "pigeon"): MethodCall = MethodCall(
        LegacyMethodChannelAdapter.NATIVE_LOCATION_ROUTE_METHOD,
        mapOf(
            "sessionToken" to "token-5",
            "generation" to 0,
            "route" to route,
        ),
    )

    @Test
    fun `accepted selections answer true and forward the identity`() {
        var seen: Triple<String, Long, String>? = null
        val subject = adapter(
            locationSelector = { token, generation, route ->
                seen = Triple(token, generation, route)
                null
            },
        )
        val result = RecordingResult()
        subject.onMethodCall(locationCall(), result)

        assertEquals(true, result.success)
        assertNull(result.errorCode)
        assertEquals(Triple("token-5", 0L, "pigeon"), seen)
    }

    @Test
    fun `stale session selections surface the typed error code`() {
        val subject = adapter(locationSelector = { _, _, _ -> "stale_session" })
        val result = RecordingResult()
        subject.onMethodCall(locationCall(), result)

        assertEquals("stale_session", result.errorCode)
    }

    @Test
    fun `unknown route values are rejected`() {
        val subject = adapter(
            locationSelector = { _, _, route ->
                if (route != "pigeon" && route != "legacy") "invalid_route" else null
            },
        )
        val result = RecordingResult()
        subject.onMethodCall(locationCall(route = "carrier-pigeon"), result)

        assertEquals("invalid_route", result.errorCode)
    }

    @Test
    fun `malformed payloads are rejected without invoking the selector`() {
        var invoked = false
        val subject = adapter(locationSelector = { _, _, _ -> invoked = true; null })
        val result = RecordingResult()
        subject.onMethodCall(
            MethodCall(
                LegacyMethodChannelAdapter.NATIVE_LOCATION_ROUTE_METHOD,
                mapOf("route" to "pigeon"),
            ),
            result,
        )

        assertEquals("invalid_route", result.errorCode)
        assertTrue(!invoked)
    }

    @Test
    fun `legacy route selections are accepted for symmetry`() {
        var route: String? = null
        val subject = adapter(
            locationSelector = { _, _, selected -> route = selected; null },
        )
        val result = RecordingResult()
        subject.onMethodCall(locationCall(route = "legacy"), result)

        assertEquals(true, result.success)
        assertEquals("legacy", route)
    }

    @Test
    fun `the earlier event route selections remain recognized endpoints`() {
        val subject = adapter()
        for (method in listOf(
            LegacyMethodChannelAdapter.NATIVE_LIFECYCLE_ROUTE_METHOD,
            LegacyMethodChannelAdapter.NATIVE_INTERACTION_ROUTE_METHOD,
            LegacyMethodChannelAdapter.NATIVE_MARKER_ROUTE_METHOD,
            LegacyMethodChannelAdapter.NATIVE_ROAD_ROUTE_METHOD,
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
        subject.onMethodCall(MethodCall("receiveUserLocation", null), unknown)
        assertTrue(unknown.notImplemented)
    }
}

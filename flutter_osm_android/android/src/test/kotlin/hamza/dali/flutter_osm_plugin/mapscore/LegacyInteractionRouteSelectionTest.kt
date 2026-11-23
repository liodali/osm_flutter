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
 * Attach-time interaction event route selection on the legacy channel:
 * the payload is validated, the session selector decides, and typed error
 * codes reach the Dart client verbatim. The probe, the lifecycle selection
 * and the legacy command set are untouched by the new endpoint.
 */
class LegacyInteractionRouteSelectionTest {

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
        selector: ((String, Long, String) -> String?)? = { _, _, _ -> null },
    ) = LegacyMethodChannelAdapter(
        messenger = NoopMessenger(),
        viewId = 5,
        dispatch = { _, _, result -> result.success(null) },
        typedDispatch = { _, _, result -> result.success(null) },
        bootstrapProvider = { mapOf("revision" to 1) },
        interactionRouteSelector = selector,
    )

    private fun selectionCall(route: String = "pigeon"): MethodCall = MethodCall(
        LegacyMethodChannelAdapter.NATIVE_INTERACTION_ROUTE_METHOD,
        mapOf(
            "sessionToken" to "token-5",
            "generation" to 0,
            "route" to route,
        ),
    )

    @Test
    fun `accepted selection answers true and forwards the identity`() {
        var seen: Triple<String, Long, String>? = null
        val subject = adapter { token, generation, route ->
            seen = Triple(token, generation, route)
            null
        }
        val result = RecordingResult()
        subject.onMethodCall(selectionCall(), result)

        assertEquals(true, result.success)
        assertNull(result.errorCode)
        assertEquals(Triple("token-5", 0L, "pigeon"), seen)
    }

    @Test
    fun `stale session selection surfaces the typed error code`() {
        val subject = adapter { _, _, _ -> "stale_session" }
        val result = RecordingResult()
        subject.onMethodCall(selectionCall(), result)

        assertEquals("stale_session", result.errorCode)
        assertNull(result.success)
    }

    @Test
    fun `unknown route values are rejected`() {
        val subject = adapter { _, _, route ->
            if (route != "pigeon" && route != "legacy") "invalid_route" else null
        }
        val result = RecordingResult()
        subject.onMethodCall(selectionCall(route = "carrier-pigeon"), result)

        assertEquals("invalid_route", result.errorCode)
    }

    @Test
    fun `malformed payloads are rejected without invoking the selector`() {
        var invoked = false
        val subject = adapter { _, _, _ -> invoked = true; null }
        val result = RecordingResult()
        subject.onMethodCall(
            MethodCall(
                LegacyMethodChannelAdapter.NATIVE_INTERACTION_ROUTE_METHOD,
                mapOf("route" to "pigeon"),
            ),
            result,
        )

        assertEquals("invalid_route", result.errorCode)
        assertTrue(!invoked)
    }

    @Test
    fun `legacy route selection is accepted for symmetry`() {
        var seenRoute: String? = null
        val subject = adapter { _, _, route -> seenRoute = route; null }
        val result = RecordingResult()
        subject.onMethodCall(selectionCall(route = "legacy"), result)

        assertEquals(true, result.success)
        assertEquals("legacy", seenRoute)
    }

    @Test
    fun `the probe, lifecycle selection and legacy commands are untouched`() {
        val subject = adapter()
        val probe = RecordingResult()
        subject.onMethodCall(MethodCall("map#bootstrap#protocol", null), probe)
        assertEquals(mapOf("revision" to 1), probe.success)

        val lifecycle = RecordingResult()
        subject.onMethodCall(
            MethodCall(
                LegacyMethodChannelAdapter.NATIVE_LIFECYCLE_ROUTE_METHOD,
                mapOf(
                    "sessionToken" to "token-5",
                    "generation" to 0,
                    "route" to "pigeon",
                ),
            ),
            lifecycle,
        )
        // The lifecycle selector stays unwired in this adapter instance, but
        // its endpoint must remain a recognized selection (not notImplemented
        // and not a legacy command).
        assertEquals("invalid_route", lifecycle.errorCode)

        val unknown = RecordingResult()
        subject.onMethodCall(MethodCall("no#such#command", null), unknown)
        assertTrue(unknown.notImplemented)
    }
}

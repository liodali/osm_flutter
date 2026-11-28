package hamza.dali.flutter_osm_plugin.pigeon

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import java.nio.ByteBuffer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Delivery contract for the generated native-to-Dart lifecycle route:
 * every callback travels on the per-view channel with the session
 * identity, two views never share a channel, and emissions after close
 * are dropped (never rerouted through the legacy plane).
 */
class PigeonNativeLifecycleEventsBridgeTest {

    private class RecordingMessenger : BinaryMessenger {
        val sent = mutableListOf<Pair<String, ByteBuffer?>>()

        override fun send(channel: String, message: ByteBuffer?) {
            sent += channel to message
        }

        override fun send(
            channel: String,
            message: ByteBuffer?,
            callback: BinaryMessenger.BinaryReply?,
        ) {
            sent += channel to message
            // Empty success reply, matching the Dart FlutterApi handler.
            // The engine delivers reply buffers positioned at 0; the
            // codec's encodeMessage leaves the position at the end.
            callback?.reply(
                StandardMessageCodec.INSTANCE.encodeMessage(emptyList<Any?>())
                    ?.apply { flip() },
            )
        }

        override fun setMessageHandler(
            channel: String,
            handler: BinaryMessenger.BinaryMessageHandler?,
        ) = Unit
    }

    /** Test replica of the generated private codec: unwraps the session (129). */
    private object SessionCodec : StandardMessageCodec() {
        override fun readValueOfType(type: Byte, buffer: ByteBuffer): Any? =
            if (type == 129.toByte()) readValue(buffer) else super.readValueOfType(type, buffer)
    }

    /** Decodes a captured send buffer (encodeMessage leaves it un-flipped). */
    private fun decodeSent(payload: ByteBuffer?): List<*> =
        SessionCodec.decodeMessage(payload!!.duplicate().apply { flip() }) as List<*>

    private fun bridge(
        messenger: RecordingMessenger,
        viewId: Int,
        token: String = "token-$viewId",
    ) = PigeonNativeLifecycleEventsBridge(
        messenger = messenger,
        viewId = viewId,
        sessionToken = token,
        generation = 0L,
        // Unconfined: emissions run synchronously on the test thread.
        scope = CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `readiness carries the session identity on the per-view channel`() {
        val messenger = RecordingMessenger()
        bridge(messenger, viewId = 5).emitReady(true)

        assertEquals(1, messenger.sent.size)
        val (channel, payload) = messenger.sent.single()
        assertEquals(
            "dev.flutter.pigeon.flutter_osm_interface.NativeMapLifecycleEventsApi.onMapReady.view_5",
            channel,
        )
        val args = decodeSent(payload)
        val session = args[0] as List<*>
        assertEquals("token-5", session[0])
        assertEquals(0L, session[1])
        assertEquals(true, args[1])
    }

    @Test
    fun `restoration carries the session identity on the per-view channel`() {
        val messenger = RecordingMessenger()
        bridge(messenger, viewId = 5).emitRestored()

        val (channel, payload) = messenger.sent.single()
        assertEquals(
            "dev.flutter.pigeon.flutter_osm_interface.NativeMapLifecycleEventsApi.onMapRestored.view_5",
            channel,
        )
        val args = decodeSent(payload)
        val session = args[0] as List<*>
        assertEquals("token-5", session[0])
        assertEquals(0L, session[1])
    }

    @Test
    fun `two views never share a delivery channel`() {
        val messenger = RecordingMessenger()
        bridge(messenger, viewId = 5).emitReady(true)
        bridge(messenger, viewId = 6).emitReady(true)

        assertEquals(2, messenger.sent.size)
        assertTrue(messenger.sent[0].first.endsWith(".view_5"))
        assertTrue(messenger.sent[1].first.endsWith(".view_6"))
        val session5 = decodeSent(messenger.sent[0].second)[0] as List<*>
        val session6 = decodeSent(messenger.sent[1].second)[0] as List<*>
        assertEquals("token-5", session5[0])
        assertEquals("token-6", session6[0])
    }

    @Test
    fun `emissions after close are dropped`() {
        val messenger = RecordingMessenger()
        val subject = bridge(messenger, viewId = 5)
        subject.emitReady(true)
        subject.close()
        subject.emitReady(false)
        subject.emitRestored()

        assertEquals(1, messenger.sent.size)
    }

    @Test
    fun `readiness transitions are forwarded verbatim`() {
        val messenger = RecordingMessenger()
        val subject = bridge(messenger, viewId = 5)
        subject.emitReady(true)
        subject.emitReady(false)
        subject.emitReady(true)

        // Coalescing identical values is the Dart client's contract; the
        // host forwards every transition it is asked to emit.
        assertEquals(3, messenger.sent.size)
        val values = messenger.sent.map { decodeSent(it.second)[1] }
        assertEquals(listOf(true, false, true), values)
    }
}

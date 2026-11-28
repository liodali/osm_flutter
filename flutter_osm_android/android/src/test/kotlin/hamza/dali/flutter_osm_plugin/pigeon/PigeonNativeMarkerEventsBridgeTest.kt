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
 * Delivery contract for the generated native-to-Dart marker interaction
 * route: every callback travels on the per-view channel with the session
 * identity and the raw marker coordinates (full double precision), two
 * views never share a channel, repeated presses are discrete, and
 * emissions after close are dropped (never rerouted through the legacy
 * plane).
 */
class PigeonNativeMarkerEventsBridgeTest {

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
    ) = PigeonNativeMarkerEventsBridge(
        messenger = messenger,
        viewId = viewId,
        sessionToken = token,
        generation = 0L,
        scope = CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `marker single press carries the session identity and raw coordinates`() {
        val messenger = RecordingMessenger()
        bridge(messenger, viewId = 5).emitSinglePress(47.218071429999996, -1.5536219999999902)

        assertEquals(1, messenger.sent.size)
        val (channel, payload) = messenger.sent.single()
        assertEquals(
            "dev.flutter.pigeon.flutter_osm_interface.NativeMapMarkerEventsApi.onMarkerSinglePress.view_5",
            channel,
        )
        val args = decodeSent(payload)
        val session = args[0] as List<*>
        assertEquals("token-5", session[0])
        assertEquals(0L, session[1])
        assertEquals(47.218071429999996, args[1])
        assertEquals(-1.5536219999999902, args[2])
    }

    @Test
    fun `marker long press carries the session identity and raw coordinates`() {
        val messenger = RecordingMessenger()
        bridge(messenger, viewId = 5).emitLongPress(8.000000000000002, -0.9999999999999999)

        val (channel, payload) = messenger.sent.single()
        assertEquals(
            "dev.flutter.pigeon.flutter_osm_interface.NativeMapMarkerEventsApi.onMarkerLongPress.view_5",
            channel,
        )
        val args = decodeSent(payload)
        assertEquals(8.000000000000002, args[1])
        assertEquals(-0.9999999999999999, args[2])
    }

    @Test
    fun `two views never share a delivery channel`() {
        val messenger = RecordingMessenger()
        bridge(messenger, viewId = 5).emitSinglePress(1.0, 2.0)
        bridge(messenger, viewId = 6).emitSinglePress(3.0, 4.0)

        assertEquals(2, messenger.sent.size)
        assertTrue(messenger.sent[0].first.endsWith(".view_5"))
        assertTrue(messenger.sent[1].first.endsWith(".view_6"))
    }

    @Test
    fun `repeated presses are discrete and never coalesced`() {
        val messenger = RecordingMessenger()
        val subject = bridge(messenger, viewId = 5)
        subject.emitSinglePress(47.0, -1.0)
        subject.emitSinglePress(47.0, -1.0)

        assertEquals(2, messenger.sent.size)
    }

    @Test
    fun `emissions after close are dropped, never rerouted`() {
        val messenger = RecordingMessenger()
        val subject = bridge(messenger, viewId = 5)
        subject.close()
        subject.emitSinglePress(47.0, -1.0)
        subject.emitLongPress(47.0, -1.0)

        assertTrue(messenger.sent.isEmpty())
    }
}

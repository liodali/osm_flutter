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
 * Delivery contract for the generated native-to-Dart visible-region route:
 * every change travels on the per-view channel with the session identity
 * and the raw center/bounds/zoom doubles (full precision, the bounds as the
 * generated NativeBounds DTO), two views never share a channel, the bridge
 * owns no rate (every change it is handed is forwarded once — the session
 * coalescer owns the rate), and emissions after close are dropped (never
 * rerouted through the legacy plane).
 */
class PigeonNativeRegionEventsBridgeTest {

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
            if (type == 129.toByte() || type == 133.toByte()) readValue(buffer) else super.readValueOfType(type, buffer)
    }

    /** Decodes a captured send buffer (encodeMessage leaves it un-flipped). */
    private fun decodeSent(payload: ByteBuffer?): List<*> =
        SessionCodec.decodeMessage(payload!!.duplicate().apply { flip() }) as List<*>

    private fun bridge(
        messenger: RecordingMessenger,
        viewId: Int,
        token: String = "token-$viewId",
    ) = PigeonNativeRegionEventsBridge(
        messenger = messenger,
        viewId = viewId,
        sessionToken = token,
        generation = 0L,
        // Unconfined: emissions run synchronously on the test thread.
        scope = CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `a change carries the session identity, raw center and zoom, and the bounds DTO`() {
        val messenger = RecordingMessenger()
        bridge(messenger, viewId = 5).emitRegionChanged(
            centerLatitude = 47.218071429999996,
            centerLongitude = -1.5536219999999902,
            north = 48.00000000000001,
            east = 9.000000000000002,
            south = -0.9999999999999999,
            west = 8.000000000000002,
            zoom = 12.345678901234567,
        )

        assertEquals(1, messenger.sent.size)
        val (channel, payload) = messenger.sent.single()
        assertEquals(
            "dev.flutter.pigeon.flutter_osm_interface.NativeMapRegionEventsApi.onRegionChanged.view_5",
            channel,
        )
        val args = decodeSent(payload)
        val session = args[0] as List<*>
        assertEquals("token-5", session[0])
        assertEquals(0L, session[1])
        // Raw doubles on the wire: the host's full precision survives.
        assertEquals(47.218071429999996, args[1])
        assertEquals(-1.5536219999999902, args[2])
        assertEquals(12.345678901234567, args[4])
        // The bounds DTO decodes in its generated field order
        // (north, south, east, west), not the legacy map's key order.
        val bounds = args[3] as List<*>
        assertEquals(listOf(48.00000000000001, -0.9999999999999999, 9.000000000000002, 8.000000000000002), bounds)
    }

    @Test
    fun `two views never share a delivery channel`() {
        val messenger = RecordingMessenger()
        bridge(messenger, viewId = 5).emitRegionChanged(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0)
        bridge(messenger, viewId = 6).emitRegionChanged(8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0)

        assertEquals(2, messenger.sent.size)
        assertTrue(messenger.sent[0].first.endsWith(".view_5"))
        assertTrue(messenger.sent[1].first.endsWith(".view_6"))
        val session5 = decodeSent(messenger.sent[0].second)[0] as List<*>
        val session6 = decodeSent(messenger.sent[1].second)[0] as List<*>
        assertEquals("token-5", session5[0])
        assertEquals("token-6", session6[0])
    }

    @Test
    fun `the bridge owns no rate, every change it is handed is forwarded once`() {
        val messenger = RecordingMessenger()
        val subject = bridge(messenger, viewId = 5)
        subject.emitRegionChanged(47.0, -1.0, 48.0, 9.0, 46.0, 8.0, 10.0)
        subject.emitRegionChanged(47.0, -1.0, 48.0, 9.0, 46.0, 8.0, 10.0)
        subject.emitRegionChanged(47.1, -1.1, 48.1, 9.1, 46.1, 8.1, 10.5)

        assertEquals(3, messenger.sent.size)
    }

    @Test
    fun `the trailing coalesced change is delivered, not swallowed`() {
        val messenger = RecordingMessenger()
        val subject = bridge(messenger, viewId = 5)
        // What the coalescer flushes for a burst: first change, then newest.
        subject.emitRegionChanged(47.0, -1.0, 48.0, 9.0, 46.0, 8.0, 10.0)
        subject.emitRegionChanged(47.9, -1.9, 48.9, 9.9, 46.9, 8.9, 10.9)

        assertEquals(2, messenger.sent.size)
        val trailing = decodeSent(messenger.sent[1].second)
        assertEquals(47.9, trailing[1])
        assertEquals(10.9, trailing[4])
    }

    @Test
    fun `emissions after close are dropped, never rerouted`() {
        val messenger = RecordingMessenger()
        val subject = bridge(messenger, viewId = 5)
        subject.close()
        subject.emitRegionChanged(47.0, -1.0, 48.0, 9.0, 46.0, 8.0, 10.0)

        assertTrue(messenger.sent.isEmpty())
    }
}

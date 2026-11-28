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
 * Delivery contract for the generated native-to-Dart road tap route: the
 * callback travels on the per-view channel with the session identity and
 * the legacy `receiveRoad` payload field for field (key, distance,
 * duration, optional polyline and instructions), two views never share a
 * channel, repeated taps are discrete, and emissions after close are
 * dropped (never rerouted through the legacy plane).
 */
class PigeonNativeRoadEventsBridgeTest {

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

    /**
     * Test replica of the generated private codec: unwraps the session
     * (129) and the tapped-road payloads (143/144) as their raw lists.
     */
    private object SessionCodec : StandardMessageCodec() {
        override fun readValueOfType(type: Byte, buffer: ByteBuffer): Any? = when (type) {
            129.toByte(), 143.toByte(), 144.toByte() -> readValue(buffer)
            else -> super.readValueOfType(type, buffer)
        }
    }

    private fun decodeSent(payload: ByteBuffer?): List<*> =
        SessionCodec.decodeMessage(payload!!.duplicate().apply { flip() }) as List<*>

    private fun bridge(
        messenger: RecordingMessenger,
        viewId: Int,
        token: String = "token-$viewId",
    ) = PigeonNativeRoadEventsBridge(
        messenger = messenger,
        viewId = viewId,
        sessionToken = token,
        generation = 0L,
        scope = CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `road tap carries the session identity and the full legacy payload`() {
        val messenger = RecordingMessenger()
        bridge(messenger, viewId = 5).emitRoadTap(
            NativeTappedRoad(
                key = "road-42",
                distance = 12.5,
                duration = 8.25,
                routePoints = null,
                instructions = null,
            ),
        )

        assertEquals(1, messenger.sent.size)
        val (channel, payload) = messenger.sent.single()
        assertEquals(
            "dev.flutter.pigeon.flutter_osm_interface.NativeMapRoadEventsApi.onRoadTap.view_5",
            channel,
        )
        val args = decodeSent(payload)
        val session = args[0] as List<*>
        assertEquals("token-5", session[0])
        assertEquals(0L, session[1])
        // The payload list mirrors the legacy receiveRoad fields.
        val road = args[1] as List<*>
        assertEquals("road-42", road[0])
        assertEquals(12.5, road[1])
        assertEquals(8.25, road[2])
        assertEquals(null, road[3])
        assertEquals(null, road[4])
    }

    @Test
    fun `encoded polyline and instructions cross the wire unchanged`() {
        val messenger = RecordingMessenger()
        bridge(messenger, viewId = 5).emitRoadTap(
            NativeTappedRoad(
                key = "road-7",
                distance = null,
                duration = null,
                routePoints = "_p~iF~ps|U_ulLnnqC",
                instructions = listOf(
                    NativeRoadInstruction(
                        instruction = "Turn left",
                        latitude = 47.218071429999996,
                        longitude = -1.5536219999999902,
                    ),
                ),
            ),
        )

        val (_, payload) = messenger.sent.single()
        val road = decodeSent(payload)[1] as List<*>
        assertEquals("_p~iF~ps|U_ulLnnqC", road[3])
        val instructions = road[4] as List<*>
        val instruction = instructions.single() as List<*>
        assertEquals("Turn left", instruction[0])
        assertEquals(47.218071429999996, instruction[1])
        assertEquals(-1.5536219999999902, instruction[2])
    }

    @Test
    fun `two views never share a delivery channel`() {
        val messenger = RecordingMessenger()
        val road = NativeTappedRoad(key = "k", distance = 1.0, duration = 2.0, routePoints = null, instructions = null)
        bridge(messenger, viewId = 5).emitRoadTap(road)
        bridge(messenger, viewId = 6).emitRoadTap(road)

        assertEquals(2, messenger.sent.size)
        assertTrue(messenger.sent[0].first.endsWith(".view_5"))
        assertTrue(messenger.sent[1].first.endsWith(".view_6"))
    }

    @Test
    fun `repeated taps are discrete and emissions after close are dropped`() {
        val messenger = RecordingMessenger()
        val subject = bridge(messenger, viewId = 5)
        val road = NativeTappedRoad(key = "k", distance = 1.0, duration = 2.0, routePoints = null, instructions = null)
        subject.emitRoadTap(road)
        subject.emitRoadTap(road)
        assertEquals(2, messenger.sent.size)

        subject.close()
        subject.emitRoadTap(road)
        assertEquals(2, messenger.sent.size)
    }
}

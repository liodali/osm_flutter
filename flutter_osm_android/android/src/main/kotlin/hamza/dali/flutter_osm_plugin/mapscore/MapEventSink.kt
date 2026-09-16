package hamza.dali.flutter_osm_plugin.mapscore

import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Native-to-Dart event boundary for a map session.
 *
 * The renderer emits semantic events through this interface instead of knowing
 * which transport is currently attached. The first implementation uses the
 * legacy per-view MethodChannel; JNI-backed transports can provide another sink
 * without changing Mapscore callbacks.
 */
interface MapEventSink {
    fun emit(method: String, arguments: Any? = null)
    fun close() {}
}

object NoopMapEventSink : MapEventSink {
    override fun emit(method: String, arguments: Any?) = Unit
}

class MethodChannelMapEventSink(
    private val channel: MethodChannel,
) : MapEventSink {
    private val closed = AtomicBoolean(false)

    override fun emit(method: String, arguments: Any?) {
        if (!closed.get()) {
            channel.invokeMethod(method, arguments)
        }
    }

    override fun close() {
        closed.set(true)
    }
}

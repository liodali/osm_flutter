package hamza.dali.flutter_osm_plugin.mapscore

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Compatibility transport for the existing Android method-channel contract.
 *
 * Command dispatch and event emission share this object, while the map view
 * remains responsible for implementing the legacy command handler. A future
 * JNI transport can be attached to the same map session without changing the
 * renderer's event callbacks.
 */
class LegacyMethodChannelAdapter(
    messenger: BinaryMessenger,
    viewId: Int,
) : MapEventSink {
    private val channel = MethodChannel(messenger, "plugins.dali.hamza/osmview_$viewId")
    private val eventSink = MethodChannelMapEventSink(channel)

    fun setMethodCallHandler(handler: MethodChannel.MethodCallHandler?) {
        channel.setMethodCallHandler(handler)
    }

    override fun emit(method: String, arguments: Any?) {
        eventSink.emit(method, arguments)
    }

    override fun close() {
        eventSink.close()
        channel.setMethodCallHandler(null)
    }
}

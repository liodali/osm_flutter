package hamza.dali.flutter_osm_plugin.pigeon

import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Generated-channel native-to-Dart marker interaction event route (Pigeon
 * channel profile): marker single-press and long-press callbacks.
 *
 * This bridge is the only component that emits generated marker interaction
 * events. Every callback carries the session token/generation pair so the
 * Dart client can drop stale sessions after view replacement or disposal,
 * and the marker position crosses the wire as raw doubles — the host's full
 * precision reaches the public streams without a map round-trip.
 *
 * Delivery is fire-and-forget on the main thread; a missing Dart handler
 * (detached engine) is logged, never retried through the legacy plane —
 * exactly one delivery route is active per attachment. Emissions after
 * [close] are dropped. Marker interactions are discrete: every occurrence
 * is forwarded once and repeats are never coalesced.
 */
internal class PigeonNativeMarkerEventsBridge(
    messenger: BinaryMessenger,
    viewId: Int,
    private val sessionToken: String,
    private val generation: Long,
    private val scope: CoroutineScope =
        CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
) {
    private val api = NativeMapMarkerEventsApi(
        messenger,
        PigeonNativeCameraBridge.viewChannelSuffix(viewId),
    )
    private val closed = AtomicBoolean(false)

    /** Marker single press at the geographic coordinate, full precision. */
    fun emitSinglePress(latitude: Double, longitude: Double) = emit(
        "marker single press",
    ) {
        api.onMarkerSinglePress(NativeCameraSession(sessionToken, generation), latitude, longitude)
    }

    /** Marker long press at the geographic coordinate, full precision. */
    fun emitLongPress(latitude: Double, longitude: Double) = emit(
        "marker long press",
    ) {
        api.onMarkerLongPress(NativeCameraSession(sessionToken, generation), latitude, longitude)
    }

    private fun emit(kind: String, send: suspend () -> Unit) {
        if (closed.get()) return
        scope.launch {
            if (closed.get()) return@launch
            try {
                send()
            } catch (error: Throwable) {
                // Best-effort delivery: a detached Dart side never replays
                // through the legacy plane.
                Log.w("osm", "marker interaction $kind delivery failed: ${error.message}")
            }
        }
    }

    /** Stops emissions; late callbacks are dropped, never rerouted. */
    fun close() {
        if (closed.compareAndSet(false, true)) {
            scope.cancel()
        }
    }
}

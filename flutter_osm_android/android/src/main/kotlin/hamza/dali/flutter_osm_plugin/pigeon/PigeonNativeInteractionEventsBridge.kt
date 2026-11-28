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
 * Generated-channel native-to-Dart map-interaction event route (Pigeon
 * channel profile): single-press and long-press callbacks.
 *
 * This bridge is the only component that emits generated interaction
 * events. Every callback carries the session token/generation pair so the
 * Dart client can drop stale sessions after view replacement or disposal,
 * and the coordinates cross the wire as raw doubles — the host's full
 * precision reaches the public streams without a map round-trip.
 *
 * Delivery is fire-and-forget on the main thread: the host does not wait
 * for the Dart reply, and a missing Dart handler (detached engine) is
 * logged, never retried through the legacy plane — exactly one delivery
 * route is active per attachment. Emissions after [close] are dropped.
 * Interactions are discrete: every occurrence is forwarded once and
 * repeats are never coalesced.
 */
internal class PigeonNativeInteractionEventsBridge(
    messenger: BinaryMessenger,
    viewId: Int,
    private val sessionToken: String,
    private val generation: Long,
    private val scope: CoroutineScope =
        CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
) {
    private val api = NativeMapInteractionEventsApi(
        messenger,
        PigeonNativeCameraBridge.viewChannelSuffix(viewId),
    )
    private val closed = AtomicBoolean(false)

    /** Single press at the geographic coordinate, with full precision. */
    fun emitSinglePress(latitude: Double, longitude: Double) = emit(
        "single press",
    ) {
        api.onSinglePress(NativeCameraSession(sessionToken, generation), latitude, longitude)
    }

    /** Long press at the geographic coordinate, with full precision. */
    fun emitLongPress(latitude: Double, longitude: Double) = emit(
        "long press",
    ) {
        api.onLongPress(NativeCameraSession(sessionToken, generation), latitude, longitude)
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
                Log.w("osm", "interaction $kind delivery failed: ${error.message}")
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

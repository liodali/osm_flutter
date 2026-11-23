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
 * Generated-channel native-to-Dart user-location event route (Pigeon
 * channel profile): continuous location fixes with heading.
 *
 * This bridge is the only component that emits generated user-location
 * events. Every callback carries the session token/generation pair so the
 * Dart client can drop stale sessions after view replacement or disposal,
 * and the fix crosses the wire as raw doubles (position in degrees, heading
 * in degrees clockwise from true north) — the host's full precision reaches
 * the public stream without a map round-trip, exactly like the legacy
 * `receiveUserLocation` payload.
 *
 * Delivery is fire-and-forget on the main thread; a missing Dart handler
 * (detached engine) is logged, never retried through the legacy plane —
 * exactly one delivery route is active per attachment. Emissions after
 * [close] are dropped.
 *
 * The bridge owns no rate: the session coalesces fixes through its
 * `MapEventCoalescer` (`receiveUserLocation` interval) before they reach
 * this bridge, so the generated route inherits the legacy plane's platform
 * rate and newest-wins coalescing unchanged.
 */
internal class PigeonNativeLocationEventsBridge(
    messenger: BinaryMessenger,
    viewId: Int,
    private val sessionToken: String,
    private val generation: Long,
    private val scope: CoroutineScope =
        CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
) {
    private val api = NativeMapLocationEventsApi(
        messenger,
        PigeonNativeCameraBridge.viewChannelSuffix(viewId),
    )
    private val closed = AtomicBoolean(false)

    /** One coalesced user-location fix, with full precision. */
    fun emitLocationChanged(latitude: Double, longitude: Double, heading: Double) = emit(
        "location fix",
    ) {
        api.onLocationChanged(
            NativeCameraSession(sessionToken, generation),
            latitude,
            longitude,
            heading,
        )
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
                Log.w("osm", "user-location $kind delivery failed: ${error.message}")
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

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
 * Generated-channel native-to-Dart road tap event route (Pigeon channel
 * profile).
 *
 * This bridge is the only component that emits generated road tap events.
 * Every callback carries the session token/generation pair so the Dart
 * client can drop stale sessions after view replacement or disposal, and
 * the tapped road's payload mirrors the legacy `receiveRoad` message
 * field for field (key, optional distance/duration, optional encoded
 * polyline, optional instructions).
 *
 * Delivery is fire-and-forget on the main thread; a missing Dart handler
 * (detached engine) is logged, never retried through the legacy plane —
 * exactly one delivery route is active per attachment. Emissions after
 * [close] are dropped. Road taps are discrete: every occurrence is
 * forwarded once and repeats are never coalesced.
 */
internal class PigeonNativeRoadEventsBridge(
    messenger: BinaryMessenger,
    viewId: Int,
    private val sessionToken: String,
    private val generation: Long,
    private val scope: CoroutineScope =
        CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
) {
    private val api = NativeMapRoadEventsApi(
        messenger,
        PigeonNativeCameraBridge.viewChannelSuffix(viewId),
    )
    private val closed = AtomicBoolean(false)

    /** Road tap with the legacy payload, unchanged field for field. */
    fun emitRoadTap(road: NativeTappedRoad) {
        if (closed.get()) return
        val session = NativeCameraSession(sessionToken, generation)
        scope.launch {
            if (closed.get()) return@launch
            try {
                api.onRoadTap(session, road)
            } catch (error: Throwable) {
                // Best-effort delivery: a detached Dart side never replays
                // through the legacy plane.
                Log.w("osm", "road tap delivery failed: ${error.message}")
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

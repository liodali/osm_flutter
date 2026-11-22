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
 * Generated-channel native-to-Dart lifecycle event route (Pigeon channel
 * profile): map readiness and restoration callbacks.
 *
 * This bridge is the only component that emits generated lifecycle events.
 * Every callback carries the session token/generation pair so the Dart
 * client can drop stale sessions after view replacement or disposal.
 *
 * Delivery is fire-and-forget on the main thread: the host does not wait
 * for the Dart reply, and a missing Dart handler (detached engine) is
 * logged, never retried through the legacy plane — exactly one delivery
 * route is active per attachment. Emissions after [close] are dropped.
 */
internal class PigeonNativeLifecycleEventsBridge(
    messenger: BinaryMessenger,
    viewId: Int,
    private val sessionToken: String,
    private val generation: Long,
    private val scope: CoroutineScope =
        CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
) {
    private val api = NativeMapLifecycleEventsApi(
        messenger,
        PigeonNativeCameraBridge.viewChannelSuffix(viewId),
    )
    private val closed = AtomicBoolean(false)

    /** Readiness transition for this session (once per initialization outcome). */
    fun emitReady(isReady: Boolean) {
        if (closed.get()) return
        val session = NativeCameraSession(sessionToken, generation)
        scope.launch {
            if (closed.get()) return@launch
            try {
                api.onMapReady(session, isReady)
            } catch (error: Throwable) {
                // Best-effort delivery: a detached Dart side never replays
                // through the legacy plane.
                Log.w("osm", "lifecycle readiness delivery failed: ${error.message}")
            }
        }
    }

    /// The session restored its saved map state (activity recreation).
    fun emitRestored() {
        if (closed.get()) return
        val session = NativeCameraSession(sessionToken, generation)
        scope.launch {
            if (closed.get()) return@launch
            try {
                api.onMapRestored(session)
            } catch (error: Throwable) {
                Log.w("osm", "lifecycle restoration delivery failed: ${error.message}")
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

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
 * Generated-channel native-to-Dart visible-region event route (Pigeon
 * channel profile): center, bounding box and zoom of the visible region.
 *
 * This bridge is the only component that emits generated region events.
 * Every callback carries the session token/generation pair so the Dart
 * client can drop stale sessions after view replacement or disposal, and
 * the region crosses the wire as raw doubles (center and bounds in degrees,
 * zoom in the camera family's `getZoom` units) — the host's full precision
 * reaches the public stream without a map round-trip.
 *
 * Delivery is fire-and-forget on the main thread; a missing Dart handler
 * (detached engine) is logged, never retried through the legacy plane —
 * exactly one delivery route is active per attachment. Emissions after
 * [close] are dropped.
 *
 * The bridge owns no rate: the session coalesces changes through its
 * `MapEventCoalescer` (`receiveRegionIsChanging` interval) before they
 * reach this bridge, so the generated route inherits the legacy plane's
 * platform rate and newest-wins coalescing unchanged.
 */
internal class PigeonNativeRegionEventsBridge(
    messenger: BinaryMessenger,
    viewId: Int,
    private val sessionToken: String,
    private val generation: Long,
    private val scope: CoroutineScope =
        CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
) {
    private val api = NativeMapRegionEventsApi(
        messenger,
        PigeonNativeCameraBridge.viewChannelSuffix(viewId),
    )
    private val closed = AtomicBoolean(false)

    /** One coalesced visible-region change, with full precision. */
    fun emitRegionChanged(
        centerLatitude: Double,
        centerLongitude: Double,
        north: Double,
        east: Double,
        south: Double,
        west: Double,
        zoom: Double,
    ) = emit("region change") {
        api.onRegionChanged(
            NativeCameraSession(sessionToken, generation),
            centerLatitude,
            centerLongitude,
            NativeBounds(north = north, south = south, east = east, west = west),
            zoom,
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
                Log.w("osm", "visible-region $kind delivery failed: ${error.message}")
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

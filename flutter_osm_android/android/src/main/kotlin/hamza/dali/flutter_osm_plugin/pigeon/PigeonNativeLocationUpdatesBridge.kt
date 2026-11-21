package hamza.dali.flutter_osm_plugin.pigeon

import io.flutter.plugin.common.BinaryMessenger
import hamza.dali.flutter_osm_plugin.mapscore.MapSession
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Generated-channel host for the continuous-updates family (Pigeon
 * channel profile): start/stop location updates.
 *
 * This bridge is the only component that decodes generated updates calls.
 * It validates the per-map session token/generation pair, then delegates
 * to the shared typed [MapSession]. Start completes exactly once
 * (idempotent; `permission_denied` or `location_service_disabled` on
 * platform-reported denial); stop is idempotent, never prompts, never
 * fails, and preserves pending one-shot fixes and tracking. Location
 * events keep flowing on the existing event channel.
 */
internal class PigeonNativeLocationUpdatesBridge(
    private val session: MapSession,
    private val sessionToken: String,
    private val generation: Long,
) : NativeMapLocationUpdatesApi {

    override suspend fun startLocationUpdates(session: NativeCameraSession) {
        validateSession(session)
        suspendCancellableCoroutine { continuation ->
            var resumed = false
            this.session.startLocationUpdates { failureCode, failureMessage ->
                // Exactly-once guard: late callbacks stay no-ops.
                if (resumed) return@startLocationUpdates
                resumed = true
                if (failureCode == null) {
                    continuation.resume(Unit)
                } else {
                    continuation.resumeWithException(
                        FlutterError(failureCode, failureMessage ?: "location updates failed", null)
                    )
                }
            }
        }
    }

    override suspend fun stopLocationUpdates(session: NativeCameraSession) {
        validateSession(session)
        // Idempotent, never prompts, never fails: plain delegation.
        this.session.stopLocationUpdates()
    }

    private fun validateSession(s: NativeCameraSession) {
        if (s.sessionToken != sessionToken || s.generation != generation) {
            throw FlutterError(CODE_STALE_SESSION, "session does not match this map view", null)
        }
    }

    /** Registers this bridge for one map view, alongside legacy endpoints. */
    fun register(messenger: BinaryMessenger, viewId: Int) {
        NativeMapLocationUpdatesApi.setUp(
            messenger, this,
            messageChannelSuffix = PigeonNativeCameraBridge.viewChannelSuffix(viewId))
    }

    /** Removes this bridge's handlers without touching legacy endpoints. */
    fun unregister(messenger: BinaryMessenger, viewId: Int) {
        NativeMapLocationUpdatesApi.setUp(
            messenger, null,
            messageChannelSuffix = PigeonNativeCameraBridge.viewChannelSuffix(viewId))
    }

    companion object {
        /** Typed error codes carried to the Dart facade verbatim. */
        const val CODE_STALE_SESSION = "stale_session"
    }
}

package hamza.dali.flutter_osm_plugin.pigeon

import io.flutter.plugin.common.BinaryMessenger
import hamza.dali.flutter_osm_plugin.mapscore.MapSession
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Generated-channel host for the follow-me tracking family (Pigeon
 * channel profile): enable/disable tracking.
 *
 * This bridge is the only component that decodes generated tracking
 * calls. It validates the per-map session token/generation pair, then
 * delegates to the shared typed [MapSession]. Enable completes exactly
 * once (idempotent; `location_service_disabled` when the platform
 * reports the provider off). Disable is idempotent, never prompts,
 * never fails, and preserves pending one-shot fixes and continuous
 * updates — both consumers share the location subscription and
 * reconcile through the ownership checks. Location events keep flowing
 * on the existing event channel.
 */
internal class PigeonNativeTrackingBridge(
    private val session: MapSession,
    private val sessionToken: String,
    private val generation: Long,
) : NativeMapTrackingApi {

    override suspend fun enableTracking(
        session: NativeCameraSession,
        configuration: NativeTrackingConfiguration,
    ) {
        validateSession(session)
        suspendCancellableCoroutine { continuation ->
            var resumed = false
            this.session.enableTracking(
                stopFollowInDrag = configuration.stopFollowInDrag,
                disableMarkerRotation = configuration.disableMarkerRotation,
                useDirectionMarker = configuration.useDirectionMarker,
                anchor = listOf(configuration.anchor.x, configuration.anchor.y),
            ) { failureCode, failureMessage ->
                // Exactly-once guard: late callbacks stay no-ops.
                if (resumed) return@enableTracking
                resumed = true
                if (failureCode == null) {
                    continuation.resume(Unit)
                } else {
                    continuation.resumeWithException(
                        FlutterError(failureCode, failureMessage ?: "tracking failed", null)
                    )
                }
            }
        }
    }

    override suspend fun disableTracking(session: NativeCameraSession) {
        validateSession(session)
        // Idempotent, never prompts, never fails: plain delegation.
        this.session.disableTracking()
    }

    private fun validateSession(s: NativeCameraSession) {
        if (s.sessionToken != sessionToken || s.generation != generation) {
            throw FlutterError(CODE_STALE_SESSION, "session does not match this map view", null)
        }
    }

    /** Registers this bridge for one map view, alongside legacy endpoints. */
    fun register(messenger: BinaryMessenger, viewId: Int) {
        NativeMapTrackingApi.setUp(
            messenger, this,
            messageChannelSuffix = PigeonNativeCameraBridge.viewChannelSuffix(viewId))
    }

    /** Removes this bridge's handlers without touching legacy endpoints. */
    fun unregister(messenger: BinaryMessenger, viewId: Int) {
        NativeMapTrackingApi.setUp(
            messenger, null,
            messageChannelSuffix = PigeonNativeCameraBridge.viewChannelSuffix(viewId))
    }

    companion object {
        /** Typed error codes carried to the Dart facade verbatim. */
        const val CODE_STALE_SESSION = "stale_session"
    }
}

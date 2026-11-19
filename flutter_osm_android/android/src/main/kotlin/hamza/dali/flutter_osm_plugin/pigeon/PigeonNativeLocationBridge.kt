package hamza.dali.flutter_osm_plugin.pigeon

import io.flutter.plugin.common.BinaryMessenger
import hamza.dali.flutter_osm_plugin.mapscore.MapSession
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Generated-channel host for the location family (Pigeon channel profile):
 * the my-location layer toggle and single-shot fixes.
 *
 * This bridge is the only component that decodes generated location calls.
 * It validates the per-map session token/generation pair, then delegates
 * to the shared typed [MapSession] so legacy and generated endpoints reach
 * one owner — the same pending slots, so a legacy and a generated request
 * can never run in parallel by accident. Completion is exactly once per
 * the schema contract (the session guarantees the listener fires once;
 * the resumed flag additionally ignores any late callback). Permission
 * ownership stays with the host application.
 */
internal class PigeonNativeLocationBridge(
    private val session: MapSession,
    private val sessionToken: String,
    private val generation: Long,
) : NativeMapLocationApi {

    override suspend fun showMyLocation(session: NativeCameraSession) {
        validateSession(session)
        if (!this.session.enableUserLocationLayer()) {
            throw FlutterError(
                CODE_ACTIVITY_UNAVAILABLE,
                "A foreground Activity is required to open location settings.",
                null,
            )
        }
    }

    override suspend fun getCurrentLocation(session: NativeCameraSession): NativeLocationFix {
        validateSession(session)
        return suspendCancellableCoroutine { continuation ->
            var resumed = false
            this.session.requestLocationFix { outcome ->
                // Exactly-once guard: the session never repeats an outcome,
                // but a late callback must stay a no-op regardless.
                if (resumed) return@requestLocationFix
                resumed = true
                when (outcome) {
                    is MapSession.LocationFixOutcome.Fixed -> continuation.resume(
                        NativeLocationFix(
                            latitude = outcome.latitude,
                            longitude = outcome.longitude,
                        )
                    )
                    is MapSession.LocationFixOutcome.Failed -> continuation.resumeWithException(
                        FlutterError(
                            outcome.code,
                            outcome.message ?: "location request failed",
                            null,
                        )
                    )
                }
            }
        }
    }

    private fun validateSession(s: NativeCameraSession) {
        if (s.sessionToken != sessionToken || s.generation != generation) {
            throw FlutterError(CODE_STALE_SESSION, "session does not match this map view", null)
        }
    }

    /** Registers this bridge for one map view, alongside legacy endpoints. */
    fun register(messenger: BinaryMessenger, viewId: Int) {
        NativeMapLocationApi.setUp(
            messenger, this,
            messageChannelSuffix = PigeonNativeCameraBridge.viewChannelSuffix(viewId))
    }

    /** Removes this bridge's handlers without touching legacy endpoints. */
    fun unregister(messenger: BinaryMessenger, viewId: Int) {
        NativeMapLocationApi.setUp(
            messenger, null,
            messageChannelSuffix = PigeonNativeCameraBridge.viewChannelSuffix(viewId))
    }

    companion object {
        /** Typed error codes carried to the Dart facade verbatim. */
        const val CODE_STALE_SESSION = "stale_session"
        const val CODE_ACTIVITY_UNAVAILABLE = "activity_unavailable"
    }
}

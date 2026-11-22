package hamza.dali.flutter_osm_plugin.pigeon

import io.flutter.plugin.common.BinaryMessenger
import hamza.dali.flutter_osm_plugin.mapscore.MapSession

/**
 * Generated-channel host for the user-location icon family (Pigeon channel
 * profile): person and direction icon replacement.
 *
 * This bridge is the only component that decodes generated icon calls. It
 * validates the per-map session token/generation pair, decodes the
 * Dart-prepared PNG bytes, then delegates to the shared typed [MapSession].
 *
 * The call only swaps the layer icons: follow-me tracking, continuous
 * updates and pending one-shot fixes keep running untouched, and no
 * permission flow is triggered. A null icon pair restores the platform
 * default icons and the default center anchor.
 */
internal class PigeonNativeUserLocationIconsBridge(
    private val session: MapSession,
    private val sessionToken: String,
    private val generation: Long,
) : NativeMapUserLocationIconsApi {

    override fun setUserLocationIcons(
        session: NativeCameraSession,
        icons: NativeUserLocationIcons?,
    ) {
        validateSession(session)
        if (icons == null) {
            // Reset route: platform defaults, default center anchor.
            // A session that cannot accept icons yet stays a silent no-op,
            // like the legacy route which reported failures as success
            // values instead of surfacing an error during map init.
            this.session.resetUserLocationIcons()
            return
        }
        this.session.setUserLocationIcons(
            personIcon = icons.person.iconBytes,
            directionIcon = icons.direction.iconBytes,
            personAnchor = icons.person.anchor?.let { listOf(it.x, it.y) },
            directionAnchor = icons.direction.anchor?.let { listOf(it.x, it.y) },
            // Pre-scale sizes: the host re-renders at the display density so
            // a high-resolution capture keeps its intended display size.
            personLogicalSize = icons.person.logicalSize.toLogicalSize(),
            directionLogicalSize = icons.direction.logicalSize.toLogicalSize(),
        )
    }

    /** Wire size to the logical `[width, height]` list hosts render from. */
    private fun NativeMarkerSize?.toLogicalSize(): List<Int>? =
        this?.let { listOf(it.width.toInt(), it.height.toInt()) }

    private fun validateSession(s: NativeCameraSession) {
        if (s.sessionToken != sessionToken || s.generation != generation) {
            throw FlutterError(CODE_STALE_SESSION, "session does not match this map view", null)
        }
    }

    /** Registers this bridge for one map view, alongside legacy endpoints. */
    fun register(messenger: BinaryMessenger, viewId: Int) {
        NativeMapUserLocationIconsApi.setUp(
            messenger, this,
            messageChannelSuffix = PigeonNativeCameraBridge.viewChannelSuffix(viewId))
    }

    /** Removes this bridge's handlers without touching legacy endpoints. */
    fun unregister(messenger: BinaryMessenger, viewId: Int) {
        NativeMapUserLocationIconsApi.setUp(
            messenger, null,
            messageChannelSuffix = PigeonNativeCameraBridge.viewChannelSuffix(viewId))
    }

    companion object {
        /** Typed error codes carried to the Dart facade verbatim. */
        const val CODE_STALE_SESSION = "stale_session"
    }
}

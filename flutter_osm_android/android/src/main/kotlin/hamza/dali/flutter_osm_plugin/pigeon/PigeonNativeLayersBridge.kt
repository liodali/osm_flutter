package hamza.dali.flutter_osm_plugin.pigeon

import io.flutter.plugin.common.BinaryMessenger
import hamza.dali.flutter_osm_plugin.mapscore.MapSession

/**
 * Generated-channel host for the layers family (Pigeon channel profile):
 * tile-source selection and overlay visibility.
 *
 * This bridge is the only component that decodes generated layer calls. It
 * validates the per-map session token/generation pair, then delegates to the
 * shared typed [MapSession] so legacy and generated endpoints reach one
 * owner. Registration lives alongside the legacy endpoints; it never
 * replaces them.
 */
internal class PigeonNativeLayersBridge(
    private val session: MapSession,
    private val sessionToken: String,
    private val generation: Long,
) : NativeMapLayersApi {

    override fun changeTileLayer(
        session: NativeCameraSession,
        tile: NativeTileConfiguration?,
    ) {
        validateSession(session)
        if (tile == null) {
            requireLayers(this.session.resetTile())
            return
        }
        if (tile.styleURL != null) {
            // Vector style: hosts derive the vector flag from the style URL,
            // matching the legacy `isVector` encoding.
            requireLayers(
                this.session.setVectorTile(
                    styleUrl = tile.styleURL,
                    sourceName = tile.sourceName,
                    minZoom = tile.minZoomLevel.toInt(),
                    maxZoom = tile.maxZoomLevel.toInt(),
                )
            )
            return
        }
        // Raster path: expand the subdomain placeholder the way the legacy
        // Android decoder does (every `{s}` becomes the first subdomain);
        // urls without the placeholder pass through unchanged.
        val template = tile.urls.firstOrNull()?.url
            ?: throw FlutterError(CODE_LAYERS_NOT_READY, "tile configuration has no urls", null)
        val subdomains = tile.urls.firstOrNull()?.subdomains.orEmpty()
        val url = if (subdomains.isNotEmpty()) template.replace("{s}", subdomains.first()) else template
        requireLayers(
            this.session.setRasterTile(
                url = url,
                sourceName = tile.sourceName,
                tileExtension = tile.tileExtension,
                minZoom = tile.minZoomLevel.toInt(),
                maxZoom = tile.maxZoomLevel.toInt(),
                apiKey = tile.apiKey,
                apiValue = tile.apiValue,
            )
        )
    }

    override fun setOverlaysVisible(session: NativeCameraSession, visible: Boolean) {
        validateSession(session)
        requireLayers(this.session.setOverlaysVisible(visible))
    }

    private fun requireLayers(applied: Boolean) {
        if (!applied) {
            throw FlutterError(CODE_LAYERS_NOT_READY, "layers are not ready for this operation", null)
        }
    }

    private fun validateSession(s: NativeCameraSession) {
        if (s.sessionToken != sessionToken || s.generation != generation) {
            throw FlutterError(CODE_STALE_SESSION, "session does not match this map view", null)
        }
    }

    /** Registers this bridge for one map view, alongside legacy endpoints. */
    fun register(messenger: BinaryMessenger, viewId: Int) {
        NativeMapLayersApi.setUp(messenger, this, messageChannelSuffix = PigeonNativeCameraBridge.viewChannelSuffix(viewId))
    }

    /** Removes this bridge's handlers without touching legacy endpoints. */
    fun unregister(messenger: BinaryMessenger, viewId: Int) {
        NativeMapLayersApi.setUp(messenger, null, messageChannelSuffix = PigeonNativeCameraBridge.viewChannelSuffix(viewId))
    }

    companion object {
        /** Typed error codes carried to the Dart facade verbatim. */
        const val CODE_STALE_SESSION = "stale_session"
        const val CODE_LAYERS_NOT_READY = "layers_not_ready"
    }
}

package hamza.dali.flutter_osm_plugin.pigeon

import io.flutter.plugin.common.BinaryMessenger
import hamza.dali.flutter_osm_plugin.mapscore.MapSession

/**
 * Generated-channel host for the roads family (Pigeon channel profile):
 * manual road drawing, removal by id and clearing.
 *
 * This bridge is the only component that decodes generated road calls. It
 * validates the per-map session token/generation pair, then delegates to
 * the shared typed [MapSession] so legacy and generated endpoints reach one
 * owner. Registration lives alongside the legacy endpoints; it never
 * replaces them. Route fetching/calculation stays asynchronous in Dart —
 * only an already-computed polyline crosses this channel.
 */
internal class PigeonNativeRoadsBridge(
    private val session: MapSession,
    private val sessionToken: String,
    private val generation: Long,
) : NativeMapRoadsApi {

    override fun drawRoad(
        session: NativeCameraSession,
        roadId: String,
        coordinates: DoubleArray,
        style: NativeRoadStyle,
        zoomInto: Boolean,
    ) {
        validateSession(session)
        requireRoads(
            this.session.drawRoad(
                roadId = roadId,
                coordinates = coordinates,
                roadColor = style.roadColorArgb.toInt(),
                roadWidth = style.roadWidth,
                // A null border color keeps the legacy manual-drawing
                // default (transparent black); a null border width draws
                // the road without a border.
                borderColor = (style.borderColorArgb ?: 0L).toInt(),
                borderWidth = style.borderWidth ?: 0.0,
                zoomInto = zoomInto,
                dotted = style.dotted,
            )
        )
    }

    override fun removeRoad(session: NativeCameraSession, roadId: String) {
        validateSession(session)
        // Removal is a silent no-op for unknown keys, mirroring the legacy
        // delete#road handler; the boolean outcome is intentionally ignored.
        this.session.removeRoad(roadId)
    }

    override fun clearRoads(session: NativeCameraSession) {
        validateSession(session)
        requireRoads(this.session.clearRoads())
    }

    private fun requireRoads(applied: Boolean) {
        if (!applied) {
            throw FlutterError(CODE_ROADS_NOT_READY, "roads are not ready for this operation", null)
        }
    }

    private fun validateSession(s: NativeCameraSession) {
        if (s.sessionToken != sessionToken || s.generation != generation) {
            throw FlutterError(CODE_STALE_SESSION, "session does not match this map view", null)
        }
    }

    /** Registers this bridge for one map view, alongside legacy endpoints. */
    fun register(messenger: BinaryMessenger, viewId: Int) {
        NativeMapRoadsApi.setUp(
            messenger, this,
            messageChannelSuffix = PigeonNativeCameraBridge.viewChannelSuffix(viewId))
    }

    /** Removes this bridge's handlers without touching legacy endpoints. */
    fun unregister(messenger: BinaryMessenger, viewId: Int) {
        NativeMapRoadsApi.setUp(
            messenger, null,
            messageChannelSuffix = PigeonNativeCameraBridge.viewChannelSuffix(viewId))
    }

    companion object {
        /** Typed error codes carried to the Dart facade verbatim. */
        const val CODE_STALE_SESSION = "stale_session"
        const val CODE_ROADS_NOT_READY = "roads_not_ready"
    }
}

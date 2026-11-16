package hamza.dali.flutter_osm_plugin.pigeon

import io.flutter.plugin.common.BinaryMessenger
import hamza.dali.flutter_osm_plugin.mapscore.MapSession
import hamza.dali.flutter_osm_plugin.mapscore.models.Anchor

/**
 * Generated-channel host for the markers family (Pigeon channel profile).
 *
 * Mirrors the typed Android marker contract: stable ids, degrees, and icon
 * bytes prepared in Dart. Validates the per-map session token/generation,
 * then delegates to the shared typed [MapSession] so legacy and generated
 * marker endpoints reach one owner.
 */
internal class PigeonNativeMarkersBridge(
    private val session: MapSession,
    private val sessionToken: String,
    private val generation: Long,
) : NativeMapMarkersApi {

    override fun addMarker(
        session: NativeCameraSession,
        markerId: String,
        latitude: Double,
        longitude: Double,
        iconBytes: ByteArray?,
        angleDegrees: Double,
        anchor: NativeMarkerAnchor?,
    ) {
        validateSession(session)
        requireState(
            this.session.addMarker(
                markerId = markerId,
                latitude = latitude,
                longitude = longitude,
                icon = iconBytes,
                angleDegrees = angleDegrees,
                anchor = anchor?.let { Anchor(it.x.toFloat(), it.y.toFloat()) },
            )
        )
    }

    override fun addMarkers(
        session: NativeCameraSession,
        markerIds: List<String>,
        coordinates: DoubleArray,
    ) {
        validateSession(session)
        requireState(
            this.session.addMarkers(
                markerIds.toTypedArray(),
                coordinates,
            )
        )
    }

    override fun updateMarkerIcon(
        session: NativeCameraSession,
        markerId: String,
        iconBytes: ByteArray,
    ) {
        validateSession(session)
        requireState(this.session.updateMarkerIcon(markerId, iconBytes))
    }

    override fun moveMarker(
        session: NativeCameraSession,
        markerId: String,
        latitude: Double,
        longitude: Double,
    ) {
        validateSession(session)
        requireState(this.session.moveMarker(markerId, latitude, longitude))
    }

    override fun rotateMarker(
        session: NativeCameraSession,
        markerId: String,
        angleDegrees: Double,
    ) {
        validateSession(session)
        requireState(this.session.rotateMarker(markerId, angleDegrees))
    }

    override fun setMarkerAnchor(
        session: NativeCameraSession,
        markerId: String,
        anchor: NativeMarkerAnchor,
    ) {
        validateSession(session)
        requireState(
            this.session.setMarkerAnchor(
                markerId,
                Anchor(anchor.x.toFloat(), anchor.y.toFloat()),
            )
        )
    }

    override fun setStaticPositions(
        session: NativeCameraSession,
        groupId: String,
        coordinates: DoubleArray,
        iconBytes: ByteArray?,
    ) {
        validateSession(session)
        requireState(this.session.setStaticPositions(groupId, coordinates, iconBytes))
    }

    override fun removeStaticPositions(session: NativeCameraSession, groupId: String) {
        validateSession(session)
        requireState(this.session.removeStaticPositions(groupId))
    }

    override fun removeMarker(session: NativeCameraSession, markerId: String) {
        validateSession(session)
        requireState(this.session.removeMarker(markerId))
    }

    override fun removeMarkers(session: NativeCameraSession, markerIds: List<String>) {
        validateSession(session)
        requireState(this.session.removeMarkers(markerIds.toTypedArray()))
    }

    private fun validateSession(s: NativeCameraSession) {
        if (s.sessionToken != sessionToken || s.generation != generation) {
            throw FlutterError(
                PigeonNativeCameraBridge.CODE_STALE_SESSION,
                "session does not match this map view",
                null,
            )
        }
    }

    private fun requireState(applied: Boolean) {
        if (!applied) {
            throw FlutterError(
                PigeonNativeCameraBridge.CODE_MARKERS_NOT_READY,
                "markers are not ready for this operation",
                null,
            )
        }
    }

    fun register(messenger: BinaryMessenger, viewId: Int) {
        NativeMapMarkersApi.setUp(messenger, this, messageChannelSuffix = PigeonNativeCameraBridge.viewChannelSuffix(viewId))
    }

    /** Removes this bridge's handlers without touching legacy endpoints. */
    fun unregister(messenger: BinaryMessenger, viewId: Int) {
        NativeMapMarkersApi.setUp(messenger, null, messageChannelSuffix = PigeonNativeCameraBridge.viewChannelSuffix(viewId))
    }
}

package hamza.dali.flutter_osm_plugin.pigeon

import io.flutter.plugin.common.BinaryMessenger
import hamza.dali.flutter_osm_plugin.mapscore.MapSession

/**
 * Generated-channel host for the camera family (Pigeon channel profile).
 *
 * This bridge is the only component that decodes generated camera calls. It
 * validates the per-map session token/generation pair, then delegates to the
 * shared typed [MapSession] so legacy and generated endpoints reach one
 * owner. Registration lives alongside the legacy endpoints; it never
 * replaces them.
 */
internal class PigeonNativeCameraBridge(
    private val session: MapSession,
    private val sessionToken: String,
    private val generation: Long,
) : NativeMapCameraApi {

    override fun getZoom(session: NativeCameraSession): Double {
        validateSession(session)
        return this.session.getZoom()
            ?: throw FlutterError(CODE_CAMERA_NOT_READY, "camera zoom is not available yet", null)
    }

    override fun setZoom(
        session: NativeCameraSession,
        zoom: Double,
        animated: Boolean,
    ) {
        validateSession(session)
        requireState(this.session.setZoom(zoomLevel = zoom, animated = animated))
    }
    override fun moveTo(
        session: NativeCameraSession,
        latitude: Double,
        longitude: Double,
        animated: Boolean,
    ) {
        validateSession(session)
        requireState(this.session.moveTo(latitude, longitude, animated))
    }

    override fun setRotation(
        session: NativeCameraSession,
        angle: Double,
        animated: Boolean,
    ) {
        validateSession(session)
        requireState(this.session.setRotation(angle, animated))
    }

    override fun getCameraPosition(session: NativeCameraSession): NativeCameraPosition {
        validateSession(session)
        val snapshot = this.session.getCameraPositionSnapshot()
            ?: throw FlutterError(CODE_CAMERA_NOT_READY, "camera is not ready for a snapshot", null)
        return NativeCameraPosition(
            latitude = snapshot[0],
            longitude = snapshot[1],
            zoom = snapshot[2],
            rotation = snapshot[3],
        )
    }

    private fun validateSession(s: NativeCameraSession) {
        if (s.sessionToken != sessionToken || s.generation != generation) {
            throw FlutterError(CODE_STALE_SESSION, "session does not match this map view", null)
        }
    }

    private fun requireState(applied: Boolean) {
        if (!applied) {
            throw FlutterError(CODE_CAMERA_NOT_READY, "camera is not ready for this operation", null)
        }
    }

    /** Registers this bridge for one map view, alongside legacy endpoints. */
    fun register(messenger: BinaryMessenger, viewId: Int) {
        NativeMapCameraApi.setUp(messenger, this, messageChannelSuffix = viewChannelSuffix(viewId))
    }

    /** Removes this bridge's handlers without touching legacy endpoints. */
    fun unregister(messenger: BinaryMessenger, viewId: Int) {
        NativeMapCameraApi.setUp(messenger, null, messageChannelSuffix = viewChannelSuffix(viewId))
    }

    companion object {
        /** Typed error codes carried to the Dart facade verbatim. */
        const val CODE_STALE_SESSION = "stale_session"
        const val CODE_CAMERA_NOT_READY = "camera_not_ready"

        /** Protocol revision answered by the read-only bootstrap probe. */
        const val NATIVE_PROTOCOL_REVISION = 1

        /** Schema identifier answered by the bootstrap probe. */
        const val NATIVE_CAMERA_SCHEMA_ID = "flutter_osm.native.camera.v1"

        /** Capability families advertised by the Android host. */
        const val CAPABILITY_CAMERA = "camera"
        const val CAPABILITY_MARKERS = "markers"

        /** Typed error code for the markers family. */
        const val CODE_MARKERS_NOT_READY = "markers_not_ready"

        fun viewChannelSuffix(viewId: Int): String = "view_$viewId"

        /**
         * Payload of the read-only `map#bootstrap#protocol` legacy-channel
         * probe. Must stay in sync with the Dart bootstrap contract in
         * flutter_osm_interface (`native_camera_bootstrap.dart`).
         */
        fun bootstrapPayload(
            sessionToken: String,
            generation: Long,
        ): Map<String, Any?> = mapOf(
            "revision" to NATIVE_PROTOCOL_REVISION,
            "schemaId" to NATIVE_CAMERA_SCHEMA_ID,
            "capabilities" to listOf(CAPABILITY_CAMERA, CAPABILITY_MARKERS),
            "sessionToken" to sessionToken,
            "generation" to generation,
        )
    }
}

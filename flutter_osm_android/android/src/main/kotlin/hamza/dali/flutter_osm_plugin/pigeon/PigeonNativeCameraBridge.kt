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

    override fun getBounds(session: NativeCameraSession): NativeBounds {
        validateSession(session)
        val bounds = this.session.getBoundsSnapshot()
            ?: throw FlutterError(CODE_CAMERA_NOT_READY, "camera bounds are not available yet", null)
        return NativeBounds(
            north = bounds[0],
            south = bounds[1],
            east = bounds[2],
            west = bounds[3],
        )
    }

    override fun zoomToBoundingBox(
        session: NativeCameraSession,
        bounds: NativeBounds,
        paddingInPixel: Long,
    ) {
        validateSession(session)
        requireCamera(
            this.session.zoomToBoundingBox(
                north = bounds.north,
                south = bounds.south,
                east = bounds.east,
                west = bounds.west,
                paddingInPixel = paddingInPixel.toInt(),
            )
        )
    }

    override fun setBoundsLimit(session: NativeCameraSession, bounds: NativeBounds) {
        validateSession(session)
        requireCamera(
            this.session.setBoundsLimit(
                north = bounds.north,
                east = bounds.east,
                south = bounds.south,
                west = bounds.west,
            )
        )
    }

    override fun removeBoundsLimit(session: NativeCameraSession) {
        validateSession(session)
        requireCamera(this.session.removeBoundsLimit())
    }

    override fun configureZoom(
        session: NativeCameraSession,
        configuration: NativeZoomConfiguration,
    ) {
        validateSession(session)
        requireCamera(
            this.session.configureZoom(
                initZoom = configuration.initZoom,
                minZoomLevel = configuration.minZoomLevel,
                maxZoomLevel = configuration.maxZoomLevel,
                stepZoom = configuration.stepZoom,
            )
        )
    }

    private fun requireCamera(applied: Boolean) {
        if (!applied) {
            throw FlutterError(CODE_CAMERA_NOT_READY, "camera is not ready for this operation", null)
        }
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

        /// Expanded camera surface: bounds queries, zoom-to-bounds, camera
        /// limits/reset and zoom configuration.
        const val CAPABILITY_CAMERA_CONFIG = "camera.config"

        /// Layers surface: tile-source selection and overlay visibility.
        const val CAPABILITY_LAYERS = "layers"

        /// Shapes surface: circles and rectangles.
        const val CAPABILITY_SHAPES = "shapes"

        /// Roads surface: manual drawing, removal, clearing.
        const val CAPABILITY_ROADS = "roads"

        /// Location surface: my-location layer, single-shot fixes.
        const val CAPABILITY_LOCATION = "location"

        /// Continuous-updates surface: start/stop location updates.
        const val CAPABILITY_LOCATION_UPDATES = "location.updates"

        /** Follow-me tracking: enable/disable through the generated route. */
        const val CAPABILITY_TRACKING = "location.tracking"

        /** User-location icons: person/direction replacement. */
        const val CAPABILITY_LOCATION_ICONS = "location.icons"

        /** Tracking accepts omitted anchors (keep the configured pivots). */
        const val CAPABILITY_TRACKING_OPTIONAL_ANCHOR = "location.tracking.anchor"

        /// Native-to-Dart lifecycle callbacks: readiness and restoration.
        /// Advertised only because `PigeonNativeLifecycleEventsBridge` and
        /// the `map#events#lifecycle#route` selection are implemented.
        const val CAPABILITY_LIFECYCLE_EVENTS = "events.lifecycle"

        /// Native-to-Dart interaction callbacks: single and long presses.
        /// Advertised only because `PigeonNativeInteractionEventsBridge`
        /// and the `map#events#interaction#route` selection are implemented.
        const val CAPABILITY_INTERACTION_EVENTS = "events.interaction"

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
            "capabilities" to listOf(
                CAPABILITY_CAMERA,
                CAPABILITY_MARKERS,
                CAPABILITY_CAMERA_CONFIG,
                CAPABILITY_LAYERS,
                CAPABILITY_SHAPES,
                CAPABILITY_ROADS,
                CAPABILITY_LOCATION,
                CAPABILITY_LOCATION_UPDATES,
                CAPABILITY_TRACKING,
                CAPABILITY_LOCATION_ICONS,
                CAPABILITY_TRACKING_OPTIONAL_ANCHOR,
                CAPABILITY_LIFECYCLE_EVENTS,
                CAPABILITY_INTERACTION_EVENTS,
            ),
            "sessionToken" to sessionToken,
            "generation" to generation,
        )
    }
}

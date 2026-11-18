package hamza.dali.flutter_osm_plugin.pigeon

import io.flutter.plugin.common.BinaryMessenger
import hamza.dali.flutter_osm_plugin.mapscore.MapSession

/**
 * Generated-channel host for the shapes family (Pigeon channel profile):
 * circles and rectangles (add/replace, removal by id, kind clears, full
 * clear).
 *
 * This bridge is the only component that decodes generated shape calls. It
 * validates the per-map session token/generation pair, then delegates to
 * the shared typed [MapSession] so legacy and generated endpoints reach one
 * owner. Registration lives alongside the legacy endpoints; it never
 * replaces them.
 */
internal class PigeonNativeShapesBridge(
    private val session: MapSession,
    private val sessionToken: String,
    private val generation: Long,
) : NativeMapShapesApi {

    override fun addCircle(
        session: NativeCameraSession,
        shapeId: String,
        latitude: Double,
        longitude: Double,
        radius: Double,
        style: NativeShapeStyle,
    ) {
        validateSession(session)
        requireShapes(
            this.session.addCircle(
                shapeId = shapeId,
                latitude = latitude,
                longitude = longitude,
                radius = radius,
                fillColor = style.fillColorArgb.toInt(),
                borderColor = (style.borderColorArgb ?: style.fillColorArgb).toInt(),
                strokeWidth = style.strokeWidth,
            )
        )
    }

    override fun addRectangle(
        session: NativeCameraSession,
        shapeId: String,
        latitude: Double,
        longitude: Double,
        distance: Double,
        style: NativeShapeStyle,
    ) {
        validateSession(session)
        requireShapes(
            this.session.addRectangle(
                shapeId = shapeId,
                latitude = latitude,
                longitude = longitude,
                distance = distance,
                fillColor = style.fillColorArgb.toInt(),
                borderColor = (style.borderColorArgb ?: style.fillColorArgb).toInt(),
                strokeWidth = style.strokeWidth,
            )
        )
    }

    override fun removeShape(session: NativeCameraSession, shapeId: String) {
        validateSession(session)
        // Removal is a silent no-op for unknown ids, mirroring the legacy
        // remove#circle / remove#rect handlers; the boolean outcome is
        // intentionally ignored.
        this.session.removeShape(shapeId)
    }

    override fun removeCircles(session: NativeCameraSession) {
        validateSession(session)
        this.session.removeCircles()
    }

    override fun removeRectangles(session: NativeCameraSession) {
        validateSession(session)
        this.session.removeRectangles()
    }

    override fun clearShapes(session: NativeCameraSession) {
        validateSession(session)
        this.session.clearShapes()
    }

    private fun requireShapes(applied: Boolean) {
        if (!applied) {
            throw FlutterError(CODE_SHAPES_NOT_READY, "shapes are not ready for this operation", null)
        }
    }

    private fun validateSession(s: NativeCameraSession) {
        if (s.sessionToken != sessionToken || s.generation != generation) {
            throw FlutterError(CODE_STALE_SESSION, "session does not match this map view", null)
        }
    }

    /** Registers this bridge for one map view, alongside legacy endpoints. */
    fun register(messenger: BinaryMessenger, viewId: Int) {
        NativeMapShapesApi.setUp(
            messenger, this,
            messageChannelSuffix = PigeonNativeCameraBridge.viewChannelSuffix(viewId))
    }

    /** Removes this bridge's handlers without touching legacy endpoints. */
    fun unregister(messenger: BinaryMessenger, viewId: Int) {
        NativeMapShapesApi.setUp(
            messenger, null,
            messageChannelSuffix = PigeonNativeCameraBridge.viewChannelSuffix(viewId))
    }

    companion object {
        /** Typed error codes carried to the Dart facade verbatim. */
        const val CODE_STALE_SESSION = "stale_session"
        const val CODE_SHAPES_NOT_READY = "shapes_not_ready"
    }
}

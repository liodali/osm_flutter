package hamza.dali.flutter_osm_plugin.mapscore

import android.app.Activity
import hamza.dali.flutter_osm_plugin.mapscore.models.Anchor
import io.flutter.plugin.common.PluginRegistry

/** Typed command and lifecycle boundary shared by Android transports. */
interface MapSession : PluginRegistry.ActivityResultListener {
    val viewId: Int

    fun setActivity(activity: Activity?)

    fun setEventSink(sink: MapEventSink)

    fun initialize(latitude: Double, longitude: Double): Boolean

    fun emitReady(isReady: Boolean)

    fun setZoom(
        zoomLevel: Double? = null,
        stepZoom: Double? = null,
        animated: Boolean = true,
    ): Boolean

    fun getZoom(): Double?

    /** Thread-safe camera snapshot for non-main-thread JNI queries. */
    fun getZoomSnapshot(): Double?

    /**
     * Absolute camera snapshot `[lat, lon, osmZoom, rotationDegrees]`, or
     * null when the engine is not ready. Used by the generated camera route.
     */
    fun getCameraPositionSnapshot(): DoubleArray?

    fun moveTo(latitude: Double, longitude: Double, animate: Boolean): Boolean

    fun setRotation(angle: Double, animate: Boolean): Boolean

    /** Visible-region bounds `[north, south, east, west]`, or null when the
     *  engine cannot provide its visible rect yet. */
    fun getBoundsSnapshot(): DoubleArray?

    /** Zooms/animates the viewport to fit the degree bounding box. */
    fun zoomToBoundingBox(
        north: Double,
        south: Double,
        east: Double,
        west: Double,
        paddingInPixel: Int,
    ): Boolean

    /** Restricts the camera to the degree bounding box area. */
    fun setBoundsLimit(
        north: Double,
        east: Double,
        south: Double,
        west: Double,
    ): Boolean

    /** Removes the camera area limit, restoring the world view. */
    fun removeBoundsLimit(): Boolean

    /** Applies the zoom configuration (OSM zoom levels). */
    fun configureZoom(
        initZoom: Double,
        minZoomLevel: Double,
        maxZoomLevel: Double,
        stepZoom: Double,
    ): Boolean

    fun addMarker(
        markerId: String,
        latitude: Double,
        longitude: Double,
        icon: ByteArray? = null,
        angleDegrees: Double = 0.0,
        anchor: Anchor? = null,
    ): Boolean

    fun addMarkers(markerIds: Array<String>, coordinates: DoubleArray): Boolean

    fun updateMarkerIcon(markerId: String, icon: ByteArray): Boolean

    /** Moves one marker without recreating it; fails when the id is unknown. */
    fun moveMarker(markerId: String, latitude: Double, longitude: Double): Boolean

    /** Replaces one marker's icon rotation; [angleDegrees] clockwise. */
    fun rotateMarker(markerId: String, angleDegrees: Double): Boolean

    /** Replaces one marker's icon anchor. */
    fun setMarkerAnchor(markerId: String, anchor: Anchor): Boolean

    fun removeMarker(markerId: String): Boolean

    fun removeMarkers(markerIds: Array<String>): Boolean

    /** Draws (or replaces) one circle; colors are packed ARGB ints. */
    fun addCircle(
        shapeId: String,
        latitude: Double,
        longitude: Double,
        radius: Double,
        fillColor: Int,
        borderColor: Int,
        strokeWidth: Double,
    ): Boolean

    /** Draws (or replaces) one rectangle; colors are packed ARGB ints. */
    fun addRectangle(
        shapeId: String,
        latitude: Double,
        longitude: Double,
        distance: Double,
        fillColor: Int,
        borderColor: Int,
        strokeWidth: Double,
    ): Boolean

    /** Removes one shape by id; false when the id is unknown. */
    fun removeShape(shapeId: String): Boolean

    /** Removes every circle, mirroring the keyless legacy removal. */
    fun removeCircles(): Boolean

    /** Removes every rectangle, mirroring the keyless legacy removal. */
    fun removeRectangles(): Boolean

    fun clearShapes(): Boolean

    fun setStaticPositions(
        groupId: String,
        coordinates: DoubleArray,
        icon: ByteArray? = null,
    ): Boolean

    fun removeStaticPositions(groupId: String): Boolean

    fun drawRoad(
        roadId: String,
        coordinates: DoubleArray,
        roadColor: Int,
        roadWidth: Double,
        borderColor: Int,
        borderWidth: Double,
        zoomInto: Boolean,
        dotted: Boolean,
    ): Boolean

    fun removeRoad(roadId: String): Boolean

    fun clearRoads(): Boolean

    fun setRasterTile(
        url: String,
        sourceName: String,
        tileExtension: String,
        minZoom: Int,
        maxZoom: Int,
        apiKey: String?,
        apiValue: String?,
    ): Boolean

    fun setVectorTile(
        styleUrl: String,
        sourceName: String,
        minZoom: Int,
        maxZoom: Int,
    ): Boolean

    fun resetTile(): Boolean

    fun setOverlaysVisible(visible: Boolean): Boolean

    /**
     * Outcome of one pending location request. Every request completes
     * exactly once — [Fixed] on fix, [Failed] on permission denial,
     * timeout, settings denial, activity detachment or disposal.
     */
    sealed interface LocationFixOutcome {
        data class Fixed(val latitude: Double, val longitude: Double) : LocationFixOutcome
        data class Failed(val code: String, val message: String?) : LocationFixOutcome
    }

    fun interface LocationFixListener {
        fun onOutcome(outcome: LocationFixOutcome)
    }

    /**
     * Enables the my-location layer, opening the location-settings round
     * trip when the provider is off. Completes immediately once the flow
     * is initiated; returns false only when no foreground Activity exists
     * to open settings.
     */
    fun enableUserLocationLayer(): Boolean

    /**
     * Single-shot current position. The listener completes exactly once;
     * an already-pending request fails the new one with
     * `location_request_in_progress`.
     */
    fun requestLocationFix(listener: LocationFixListener)

    /**
     * Outcome callback for location commands that can only fail. A null
     * failure code means success; the callback fires exactly once.
     */
    fun interface LocationCommandListener {
        fun onComplete(failureCode: String?, failureMessage: String?)
    }

    /**
     * Starts continuous user-location updates without follow control.
     * Idempotent; completes exactly once with `location_service_disabled`
     * when the platform reports the provider off (permission ownership
     * stays with the host application).
     */
    fun startLocationUpdates(listener: LocationCommandListener)

    /**
     * Ends the continuous-updates consumer. Idempotent, never prompts,
     * never fails; pending one-shot fixes and tracking keep running.
     */
    fun stopLocationUpdates()

    /**
     * Starts follow-me tracking with the given configuration.
     * Idempotent; completes exactly once with `location_service_disabled`
     * when the platform reports the provider off (permission ownership
     * stays with the host application).
     */
    fun enableTracking(
        stopFollowInDrag: Boolean,
        disableMarkerRotation: Boolean,
        useDirectionMarker: Boolean,
        anchor: List<Double>,
        listener: LocationCommandListener,
    )

    /**
     * Ends follow-me tracking. Idempotent, never prompts, never fails.
     * Continuous updates and pending one-shot fixes keep running: both
     * consumers share the location subscription and reconcile through the
     * ownership checks.
     */
    fun disableTracking()


    fun emitAcknowledgement(requestId: String, operation: String)

    fun emitError(requestId: String, operation: String, code: String, message: String?)

    fun emitMarkerTap(markerId: String, latitude: Double, longitude: Double)

    fun dispose()
}

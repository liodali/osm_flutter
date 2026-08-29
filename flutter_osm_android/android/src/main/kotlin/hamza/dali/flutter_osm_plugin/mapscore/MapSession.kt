package hamza.dali.flutter_osm_plugin.mapscore

import android.app.Activity
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

    fun moveTo(latitude: Double, longitude: Double, animate: Boolean): Boolean

    fun setRotation(angle: Double, animate: Boolean): Boolean

    fun addMarker(
        markerId: String,
        latitude: Double,
        longitude: Double,
        icon: ByteArray? = null,
    ): Boolean

    fun addMarkers(markerIds: Array<String>, coordinates: DoubleArray): Boolean

    fun updateMarkerIcon(markerId: String, icon: ByteArray): Boolean

    fun removeMarker(markerId: String): Boolean

    fun removeMarkers(markerIds: Array<String>): Boolean

    fun addCircle(
        shapeId: String,
        latitude: Double,
        longitude: Double,
        radius: Double,
        fillColor: Int,
        borderColor: Int,
        strokeWidth: Double,
    ): Boolean

    fun addRectangle(
        shapeId: String,
        latitude: Double,
        longitude: Double,
        distance: Double,
        fillColor: Int,
        borderColor: Int,
        strokeWidth: Double,
    ): Boolean

    fun removeShape(shapeId: String): Boolean

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

    fun emitAcknowledgement(requestId: String, operation: String)

    fun emitError(requestId: String, operation: String, code: String, message: String?)

    fun emitMarkerTap(markerId: String, latitude: Double, longitude: Double)

    fun dispose()
}

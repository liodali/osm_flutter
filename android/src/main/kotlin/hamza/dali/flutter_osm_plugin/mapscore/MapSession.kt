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

    fun setZoom(zoomLevel: Double? = null, stepZoom: Double? = null): Boolean

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

    fun removeMarker(markerId: String): Boolean

    fun emitAcknowledgement(requestId: String, operation: String)

    fun emitError(requestId: String, operation: String, code: String, message: String?)

    fun emitMarkerTap(markerId: String, latitude: Double, longitude: Double)

    fun dispose()
}

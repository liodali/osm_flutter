package hamza.dali.flutter_osm_plugin.mapscore

import android.app.Activity
import io.flutter.plugin.common.PluginRegistry

/** Typed command and lifecycle boundary shared by Android transports. */
interface MapSession : PluginRegistry.ActivityResultListener {
    val viewId: Int

    fun setActivity(activity: Activity?)

    fun setEventSink(sink: MapEventSink)

    fun setZoom(zoomLevel: Double? = null, stepZoom: Double? = null)

    fun getZoom(): Double?

    fun moveTo(latitude: Double, longitude: Double, animate: Boolean)

    fun addMarker(
        markerId: String,
        latitude: Double,
        longitude: Double,
        icon: ByteArray? = null,
    ): Boolean

    fun removeMarker(markerId: String): Boolean

    fun dispose()
}

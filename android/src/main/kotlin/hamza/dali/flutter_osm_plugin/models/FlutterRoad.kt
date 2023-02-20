package hamza.dali.flutter_osm_plugin.models

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Paint
import hamza.dali.flutter_osm_plugin.utilities.Constants
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.FolderOverlay
import org.osmdroid.views.overlay.Polyline

open class FlutterRoad(
        val idRoad: String,
        val roadDuration: Double,
        val roadDistance: Double,
) : FolderOverlay() {
    var road: Polyline? = null
        set(value) {
            if (value != null) {
                field = value
                items.add(value)
                field?.setOnClickListener { _, _, geoPointClicked ->
                    onRoadClickListener?.onClick(this,geoPointClicked)
                    true
                }
            }
        }
    var onRoadClickListener: OnRoadClickListener? = null



    interface OnRoadClickListener {
        fun onClick(road: FlutterRoad,geoPointClicked:GeoPoint)
    }
}
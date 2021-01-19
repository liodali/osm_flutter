package hamza.dali.flutter_osm_plugin

import android.app.Application
import android.graphics.Bitmap
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Overlay
import org.osmdroid.views.overlay.Polyline

open class FlutterRoad(
        val application: Application,
        private val mapView: MapView,
) : Overlay() {

    lateinit var start: FlutterRoadMarker//? = null
    lateinit var end: FlutterRoadMarker//? = null
    var road: Polyline? = null
        set(value) {
            if (value != null) {
                initStartEndPoints(value.points.first(), value.points.last())
                field = value
            }
        }
    var markersIcons: HashMap<String, Bitmap> = HashMap()
        set(value) {
            if (value.isNotEmpty()) field = value
        }

    private fun initStartEndPoints(s: GeoPoint, e: GeoPoint) {
        start = FlutterRoadMarker(application, mapView, s).apply {
            this.mapIconsBitmaps = markersIcons
            this.iconPosition(Constants.PositionMarker.START)
        }

        end = FlutterRoadMarker(application, mapView, e).apply {
            this.mapIconsBitmaps = markersIcons
            this.iconPosition(Constants.PositionMarker.END)
        }


    }


}
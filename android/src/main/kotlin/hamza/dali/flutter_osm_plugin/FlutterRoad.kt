package hamza.dali.flutter_osm_plugin

import android.app.Application
import android.graphics.Bitmap
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Overlay
import org.osmdroid.views.overlay.Polyline

open class FlutterRoad(val application: Application, val mapView: MapView) : Overlay() {

    private lateinit var start: FlutterRoadMarker
    private lateinit var end: FlutterRoadMarker
    var road: Polyline? = null
        set(value) {
            if (value != null) {
                if (markersIcons.isNotEmpty())
                    initStartEndPoints(value.points.first(), value.points.last())
                this.mapView.overlays.add(value)
                field = value
            }
        }
    var markersIcons: HashMap<String, Bitmap> = HashMap()
        set(value) {
            if (value.isNotEmpty()) field = value
        }

    private fun initStartEndPoints(s: GeoPoint, e: GeoPoint) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
            mapView.overlays.removeIf {
                (it is Marker) && (it.position == s || it.position == e)
            }
        } else {
            mapView.overlays.removeAll {
                (it is FlutterMaker) && (it.position == s || it.position == e)
            }
        }
        start = FlutterRoadMarker(application, mapView, s)
        start.mapIconsBitmaps = markersIcons
        start.iconPosition(Constants.PositionMarker.START)
        end = FlutterRoadMarker(application, mapView, e)
        end.mapIconsBitmaps = markersIcons
        start.iconPosition(Constants.PositionMarker.END)

        this.mapView.overlays.add(start)
        this.mapView.overlays.add(end)
    }


}
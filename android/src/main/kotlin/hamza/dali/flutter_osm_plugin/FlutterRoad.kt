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
        private val interestPoint: List<GeoPoint> = emptyList(),
) : Overlay() {

    lateinit var start: FlutterRoadMarker//? = null
    lateinit var end: FlutterRoadMarker//? = null
    var middlePoints: MutableList<FlutterRoadMarker> = emptyList<FlutterRoadMarker>().toMutableList()
    var road: Polyline? = null
        set(value) {
            if (value != null) {
                initStartEndPoints(value.actualPoints.first(), value.actualPoints.last(), interestPoint)
                field = value
            }
        }
    var markersIcons: HashMap<String, Bitmap> = HashMap()
        set(value) {
            if (value.isNotEmpty()) field = value
        }

    private fun initStartEndPoints(
            startRoad: GeoPoint,
            destinationRoad: GeoPoint,
            interestPoint: List<GeoPoint> = emptyList()
    ) {
        start = FlutterRoadMarker(application, mapView, startRoad).apply {
            this.mapIconsBitmaps = markersIcons
            this.iconPosition(Constants.PositionMarker.START)
        }

        end = FlutterRoadMarker(application, mapView, destinationRoad).apply {
            this.mapIconsBitmaps = markersIcons
            this.iconPosition(Constants.PositionMarker.END)
        }
        interestPoint.forEach { geoPoint ->
            middlePoints.add(
                    FlutterRoadMarker(application, mapView, geoPoint).apply {
                        this.mapIconsBitmaps = markersIcons
                        this.iconPosition(Constants.PositionMarker.MIDDLE)
                        this.visibilityInfoWindow(false)
                    }
            )
        }


    }


}
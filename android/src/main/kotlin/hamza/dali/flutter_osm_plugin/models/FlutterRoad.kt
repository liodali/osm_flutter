package hamza.dali.flutter_osm_plugin.models

import android.content.Context
import android.graphics.Bitmap
import hamza.dali.flutter_osm_plugin.utilities.Constants
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.FolderOverlay
import org.osmdroid.views.overlay.Polyline

open class FlutterRoad(
    private val context: Context,
    private val mapView: MapView,
    private val interestPoint: List<GeoPoint> = emptyList(),
    private val showInterestPoints: Boolean = false,
) : FolderOverlay() {

    lateinit var start: FlutterRoadMarker//? = null
    lateinit var end: FlutterRoadMarker//? = null
    var middlePoints: MutableList<FlutterRoadMarker> =
        emptyList<FlutterRoadMarker>().toMutableList()
    var road: Polyline? = null
        set(value) {
            if (value != null) {
                field = value
                items.add(value)

                if (showInterestPoints) {
                    initStartEndPoints(
                        value.actualPoints.first(),
                        value.actualPoints.last(),
                        interestPoint
                    )
                }
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
        val listInterest = interestPoint.toMutableList()
        start = FlutterRoadMarker(context, mapView, startRoad).apply {
            this.mapIconsBitmaps = markersIcons
            this.iconPosition(Constants.PositionMarker.START)
            this.visibilityInfoWindow(false)

        }

        end = FlutterRoadMarker(context, mapView, destinationRoad).apply {
            this.mapIconsBitmaps = markersIcons
            this.iconPosition(Constants.PositionMarker.END)
            this.visibilityInfoWindow(false)
        }


        if(interestPoint.isNotEmpty()){
            if (interestPoint.first() == startRoad) {
                listInterest.removeFirst()
            }

            if (interestPoint.last() == destinationRoad) {
                listInterest.removeLast()
            }
            listInterest.forEach { geoPoint ->
                middlePoints.add(
                    FlutterRoadMarker(context, mapView, geoPoint).apply {
                        this.mapIconsBitmaps = markersIcons
                        this.iconPosition(Constants.PositionMarker.MIDDLE)
                        this.visibilityInfoWindow(false)
                    }
                )
            }
            items.addAll(middlePoints.toList())

        }
        items.add(start)
        items.add(end)
    }


}
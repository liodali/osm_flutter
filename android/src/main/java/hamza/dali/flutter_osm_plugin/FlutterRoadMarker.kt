package hamza.dali.flutter_osm_plugin

import android.app.Application
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView

class FlutterRoadMarker(application: Application, mapView: MapView, point: GeoPoint) :
        FlutterMaker(application, mapView, point) {
     var mapIconsBitmaps: HashMap<String, Bitmap> = HashMap()
        get() = this.mapIconsBitmaps
         set(hashMap) {
           if(hashMap.isNotEmpty()) field = hashMap
        }

    fun iconPosition(positionMarker: Constants.PositionMarker) {
        icon = try {
            when (positionMarker) {
                Constants.PositionMarker.START -> {
                    BitmapDrawable(application.resources, mapIconsBitmaps.get(Constants.STARTPOSITIONROAD))
                }
                Constants.PositionMarker.MIDDLE -> {
                    BitmapDrawable(application.resources, mapIconsBitmaps.get(Constants.MIDDLEPOSITIONROAD))
                }
                Constants.PositionMarker.END -> {
                    BitmapDrawable(application.resources, mapIconsBitmaps.get(Constants.ENDPOSITIONROAD))
                }

            }
        } catch (e: Exception) {
            getDefaultIconDrawable(null, null)
        }

    }
}
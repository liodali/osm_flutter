package hamza.dali.flutter_osm_plugin

import android.app.Application
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import android.util.Log
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView

class FlutterRoadMarker(application: Application, mapView: MapView, point: GeoPoint) :
        FlutterMaker(application, mapView, point) {
    var mapIconsBitmaps: HashMap<String, Bitmap> = HashMap()
        set(hashMap) {
            if (hashMap.isNotEmpty()) field = hashMap
        }

    fun iconPosition(positionMarker: Constants.PositionMarker) {
        icon = try {
            when (positionMarker) {
                Constants.PositionMarker.START -> {
                    if (mapIconsBitmaps.containsKey(Constants.STARTPOSITIONROAD))
                        BitmapDrawable(application.resources, mapIconsBitmaps[Constants.STARTPOSITIONROAD])
                    else
                        getDefaultIconDrawable(null, null)

                }
                Constants.PositionMarker.MIDDLE -> {
                    if (mapIconsBitmaps.containsKey(Constants.MIDDLEPOSITIONROAD))
                        BitmapDrawable(application.resources, mapIconsBitmaps[Constants.MIDDLEPOSITIONROAD])
                    else
                        getDefaultIconDrawable(null, null)

                }
                Constants.PositionMarker.END -> {
                    if (mapIconsBitmaps.containsKey(Constants.ENDPOSITIONROAD))
                        BitmapDrawable(application.resources, mapIconsBitmaps[Constants.ENDPOSITIONROAD])
                    else
                        getDefaultIconDrawable(null, null)

                }

            }
        } catch (e: Exception) {
            Log.e("error icon", e.message)
            getDefaultIconDrawable(null, null)
        }

    }
}
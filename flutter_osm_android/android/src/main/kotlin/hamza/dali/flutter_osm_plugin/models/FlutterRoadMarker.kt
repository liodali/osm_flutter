package hamza.dali.flutter_osm_plugin.models

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import hamza.dali.flutter_osm_plugin.utilities.Constants
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
class FlutterRoadMarker(context: Context, mapView: MapView, point: GeoPoint) :
        FlutterMarker(context, mapView, point) {
    var mapIconsBitmaps: HashMap<String, Bitmap> = HashMap()
        set(hashMap) {
            if (hashMap.isNotEmpty()) field = hashMap
        }

    fun iconPosition(positionMarker: Constants.PositionMarker) {
        val iconBitmap:Bitmap? = try {
            when (positionMarker) {
                Constants.PositionMarker.START -> {
                    if (mapIconsBitmaps.containsKey(Constants.STARTPOSITIONROAD))
                        mapIconsBitmaps[Constants.STARTPOSITIONROAD]
                    else
                       null
                }
                Constants.PositionMarker.MIDDLE -> {
                    if (mapIconsBitmaps.containsKey(Constants.MIDDLEPOSITIONROAD))
                        mapIconsBitmaps[Constants.MIDDLEPOSITIONROAD]
                    else
                        null
                }
                Constants.PositionMarker.END -> {
                    if (mapIconsBitmaps.containsKey(Constants.ENDPOSITIONROAD))
                        mapIconsBitmaps[Constants.ENDPOSITIONROAD]
                    else
                       null
                }
            }
        } catch (e: Exception) {
            Log.e("error icon", e.message.toString())
            null
        }
        setIconMaker(null,iconBitmap)

    }
}
package hamza.dali.flutter_osm_plugin.overlays

import android.graphics.Bitmap
import android.graphics.Canvas
import android.location.Location
import hamza.dali.flutter_osm_plugin.VoidCallback
import hamza.dali.flutter_osm_plugin.utilities.toHashMap
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.Projection
import org.osmdroid.views.overlay.mylocation.GpsMyLocationProvider
import org.osmdroid.views.overlay.mylocation.IMyLocationProvider
import org.osmdroid.views.overlay.mylocation.MyLocationNewOverlay

class CustomLocationManager(mapView: MapView) : MyLocationNewOverlay(mapView) {
    private var provider: GpsMyLocationProvider? = GpsMyLocationProvider(mapView.context)

    init {
        setEnableAutoStop(true)
        mMyLocationProvider = provider
    }

    fun onStart(isFollow: Boolean) {
        enableMyLocation()
        if (isFollow) {
            enableFollowLocation()
        }
    }

    private fun disableFollowAndLocation() {
        disableFollowLocation()
        disableMyLocation()
    }

    fun onStopLocation() {
        disableFollowAndLocation()
        mMyLocationProvider.stopLocationProvider()
    }
   fun onDestroy(){
       mMyLocationProvider.destroy()
   }
    override fun draw(c: Canvas?, pProjection: Projection?) {
        mDrawAccuracyEnabled = false
        super.draw(c, pProjection)
    }

     fun currentUserPosition(
        result: MethodChannel.Result,
        afterGetLocation: VoidCallback? = null,
        scope: CoroutineScope,

    ) {
        if (!isMyLocationEnabled) {
            enableMyLocation()
        }
        runOnFirstFix {
            scope.launch(Dispatchers.Main) {
                lastFix?.let { location ->
                    val point = GeoPoint(
                        location.latitude,
                        location.longitude,
                    )
                    if (!isFollowLocationEnabled){
                        disableMyLocation()
                    }

                    result.success(point.toHashMap())
                    if (afterGetLocation != null) {
                        afterGetLocation()
                    }
                } ?: result.error("400", "we cannot get the current position!", "")
            }

        }
    }


    override fun onLocationChanged(location: Location?, source: IMyLocationProvider?) {
        super.onLocationChanged(location, source)

    }

     fun followLocation(onChangedLocation : (gp:GeoPoint )-> Unit) {
        this.enableFollowLocation()
        runOnFirstFix {
            val location = this.lastFix
            val geoPMap = GeoPoint(location)
            onChangedLocation(geoPMap)
        }
    }

    fun setMarkerIcon(personIcon: Bitmap?, directionIcon: Bitmap?) {
        when {
            personIcon != null && directionIcon != null -> {
                setDirectionArrow(
                    personIcon,
                    directionIcon
                )
                val mScale = mMapView!!.context.resources.displayMetrics.density

                setPersonHotspot(
                    mScale * (personIcon.width / 4f) + 0.5f,
                    mScale * (personIcon.width / 3f) + 0.5f,
                )
            }
            personIcon != null -> {
                setPersonIcon(personIcon)
            }
        }
    }
}
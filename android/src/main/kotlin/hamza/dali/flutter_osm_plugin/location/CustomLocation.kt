package hamza.dali.flutter_osm_plugin.location

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Point
import android.graphics.PointF
import android.location.Location
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.MotionEvent
import androidx.core.content.res.ResourcesCompat
import androidx.core.graphics.drawable.toBitmap
import hamza.dali.flutter_osm_plugin.R
import hamza.dali.flutter_osm_plugin.models.VoidCallback
import hamza.dali.flutter_osm_plugin.utilities.toGeoPoint
import hamza.dali.flutter_osm_plugin.utilities.toHashMap
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers.Main
import kotlinx.coroutines.launch
import org.maplibre.android.location.LocationComponentOptions
import org.maplibre.android.location.engine.LocationEngineCallback
import org.maplibre.android.location.engine.LocationEngineRequest
import org.maplibre.android.location.engine.LocationEngineResult
import org.maplibre.android.location.modes.CameraMode
import org.maplibre.android.maps.MapLibreMap
import org.osmdroid.api.IGeoPoint
import org.osmdroid.api.IMapView
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.Projection
import org.osmdroid.views.overlay.Overlay
import org.osmdroid.views.overlay.Overlay.Snappable
import org.osmdroid.views.overlay.mylocation.GpsMyLocationProvider
import org.osmdroid.views.overlay.mylocation.IMyLocationConsumer
import org.osmdroid.views.overlay.mylocation.IMyLocationProvider
import java.lang.Exception
import java.util.LinkedList
import kotlin.lazy

typealias OnChangedLocation = (userLocation: GeoPoint, heading: Double) -> Unit

interface CustomLocationManager : IMyLocationConsumer {
    val context: Context
    val provider: GpsMyLocationProvider
    var currentLocation: Location?
    var mGeoPoint: GeoPoint?
    var mIsFollowing: Boolean
    var controlMapFromOutSide: Boolean
    var enableAutoStop: Boolean
    var mIsLocationEnabled: Boolean
    fun setMarkerIcon(personIcon: Bitmap?, directionIcon: Bitmap?)
    fun startLocationUpdating()
    fun stopLocationUpdating()
    fun enableMyLocation()
    fun onStopLocation()
    fun toggleFollow(enableStop: Boolean)
    fun disableFollowLocation()
    fun sendLocation()
}





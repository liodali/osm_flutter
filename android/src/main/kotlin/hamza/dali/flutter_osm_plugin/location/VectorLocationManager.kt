package hamza.dali.flutter_osm_plugin.location

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.location.Location
import android.util.Log
import androidx.core.content.res.ResourcesCompat
import androidx.core.graphics.drawable.toDrawable
import hamza.dali.flutter_osm_plugin.R
import hamza.dali.flutter_osm_plugin.utilities.toGeoPoint
import hamza.dali.flutter_osm_plugin.utilities.toHashMap
import io.flutter.plugin.common.MethodChannel
import org.maplibre.android.location.LocationComponentActivationOptions
import org.maplibre.android.location.LocationComponentOptions
import org.maplibre.android.location.engine.AndroidLocationEngineImpl
import org.maplibre.android.location.engine.LocationEngineCallback
import org.maplibre.android.location.engine.LocationEngineProxy
import org.maplibre.android.location.engine.LocationEngineRequest
import org.maplibre.android.location.engine.LocationEngineResult
import org.maplibre.android.location.modes.CameraMode
import org.maplibre.android.location.modes.RenderMode
import org.maplibre.android.maps.MapLibreMap
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.overlay.mylocation.GpsMyLocationProvider
import org.osmdroid.views.overlay.mylocation.IMyLocationProvider
import java.lang.Exception

class OSMVectorLocationManager(
    override val context: Context,
    private val mapView: MapLibreMap,
    private val methodChannel: MethodChannel,
    private val methodName: String,
) : CustomLocationManager {
    private val listenerLocation = object : LocationEngineCallback<LocationEngineResult> {
        override fun onSuccess(result: LocationEngineResult?) {
            setLocation(result?.lastLocation)
            sendLocation()
        }

        override fun onFailure(e: Exception) {
            Log.e("listenerLocation", e.stackTraceToString())
        }

    }
    override val provider: GpsMyLocationProvider by lazy {
        GpsMyLocationProvider(context)
    }
    val locationProxy by lazy {
        val andEnginImpl = AndroidLocationEngineImpl(context)
        andEnginImpl.createListener(listenerLocation)
        LocationEngineProxy(andEnginImpl)
    }
//    init {
//        mapView.locationComponent.isLocationComponentEnabled = false
//    }

    override var currentLocation: Location? = null

    override var mGeoPoint: GeoPoint? = null
    override var mIsFollowing: Boolean = false
    override var controlMapFromOutSide: Boolean = false
    override var enableAutoStop: Boolean = false
    override var mIsLocationEnabled: Boolean = false

    fun onStart() {
        mapView.locationComponent.onStart()
        if (mIsFollowing) {
            enableFollowLocation()
        }
    }

    fun onStop() {
        if (mIsFollowing) {
            disableFollowLocation()
        }
        mapView.locationComponent.onStop()
    }

    fun onDestroy() {
        disableFollowLocation()
        mapView.locationComponent.onDestroy()
    }

    override fun setMarkerIcon(
        personIcon: Bitmap?, directionIcon: Bitmap?
    ) {
        mapView.style?.removeImage("personIcon")
        mapView.style?.removeImage("directionIcon")
        mapView.style?.addImage(
            "personIcon", personIcon?.toDrawable(context.resources) ?: ResourcesCompat.getDrawable(
                context.resources, R.drawable.ic_location_on_red_24dp, context.theme
            )!!
        )
        mapView.style?.addImage(
            "directionIcon",
            directionIcon?.toDrawable(context.resources) ?: ResourcesCompat.getDrawable(
                context.resources, R.drawable.baseline_navigation_24, context.theme
            )!!
        )


    }


    override fun startLocationUpdating() {
        enableMyLocation()
        controlMapFromOutSide = true
    }

    override fun stopLocationUpdating() {
        controlMapFromOutSide = false
        onStopLocation()
    }

    override fun enableMyLocation() {
        mIsLocationEnabled = provider.startLocationProvider(this)

        // set initial location when enabled
        if (mIsLocationEnabled) {
            provider.lastKnownLocation?.let { location ->
                setLocation(location)
            }
        }
    }

    override fun onStopLocation() {
        provider.stopLocationProvider()
    }

    override fun toggleFollow(enableStop: Boolean) {
        if (enableStop == false) {
            resetCameraToFollow()
        }
        enableAutoStop = enableStop
        enableFollowLocation()
    }


    override fun disableFollowLocation() {
        mIsFollowing = false
        mapView.locationComponent.cameraMode = CameraMode.NONE
        mapView.locationComponent.isLocationComponentEnabled = false
        mapView.locationComponent.locationEngine = null
        mapView.locationComponent.cancelZoomWhileTrackingAnimation()
        mapView.cancelTransitions()
        mapView.locationComponent.activateLocationComponent(
            LocationComponentActivationOptions
                .builder(context, mapView.style!!)
                .useDefaultLocationEngine(false)
                .locationComponentOptions(
                    LocationComponentOptions.builder(context).build()
                )
                .build()
        )
        mapView.resetNorth()
        mapView.triggerRepaint()
    }

    fun resetCameraToFollow() {
        mapView.locationComponent.cameraMode = CameraMode.TRACKING
        mapView.locationComponent.forceLocationUpdate(currentLocation)
    }

    fun stopCamera() {
        mapView.locationComponent.cameraMode = CameraMode.NONE
    }

    private fun enableFollowLocation() {
        mapView.resetNorth()
        mIsFollowing = true

        mapView.locationComponent.locationEngine = locationProxy
        mapView.locationComponent.activateLocationComponent(
            LocationComponentActivationOptions
                .builder(context, mapView.style!!)
                .useDefaultLocationEngine(true)
                .locationEngineRequest(
                    LocationEngineRequest.Builder(1250)
                        .setFastestInterval(1250)
                        .setPriority(LocationEngineRequest.PRIORITY_HIGH_ACCURACY)
                        .build()
                )
                .locationComponentOptions(
                    LocationComponentOptions.builder(context)
                        .elevation(0f)
                        .bearingName("directionIcon")
                        .backgroundName("personIcon")
                        .foregroundName("personIcon").build()
                )
                .build()
        )
        mapView.locationComponent.isLocationComponentEnabled = mIsFollowing
        mapView.locationComponent.cameraMode = CameraMode.TRACKING
        mapView.locationComponent.renderMode = RenderMode.NORMAL

        // set initial location when enabled
        if (mIsLocationEnabled && provider.lastKnownLocation != null) {
            val location: Location = provider.lastKnownLocation
            setLocation(location)
        }

    }

    override fun sendLocation(
    ) {
        currentLocation?.let { location ->
            methodChannel.invokeMethod(methodName, location.toGeoPoint().toHashMap().apply {
                put("heading", location.bearing.toDouble())
            })
        }
    }

    override fun onLocationChanged(
        location: Location?, source: IMyLocationProvider?
    ) {
        if (location != null) {
            setLocation(location)
            sendLocation()
        }

    }

    private fun setLocation(location: Location?) {
        if (location != null) {
            currentLocation = location
            mGeoPoint = location.toGeoPoint()
        }

    }

    fun currentUserPosition(
        onUserLocationReady: (GeoPoint?) -> Unit,
        onUserLocationFailed: () -> Unit
    ) {
        mapView.locationComponent.activateLocationComponent(
            LocationComponentActivationOptions
                .builder(context, mapView.style!!)
                .useDefaultLocationEngine(true)
                .build()
        )
        mapView.locationComponent.isLocationComponentEnabled = true
        mapView.locationComponent.cameraMode = CameraMode.NONE
        mapView.locationComponent.locationEngine?.getLastLocation(object :
            LocationEngineCallback<LocationEngineResult> {
            override fun onSuccess(p0: LocationEngineResult?) {
                mapView.locationComponent.isLocationComponentEnabled = false
                onUserLocationReady(p0?.lastLocation?.toGeoPoint())
            }

            override fun onFailure(e: Exception) {
                Log.e("getLastLocation failed", e.stackTraceToString())
                onUserLocationFailed()
            }

        })
    }
}
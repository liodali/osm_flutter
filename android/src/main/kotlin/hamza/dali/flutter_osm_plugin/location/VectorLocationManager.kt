package hamza.dali.flutter_osm_plugin.location

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.location.Location
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.res.ResourcesCompat
import androidx.core.graphics.drawable.toDrawable
import hamza.dali.flutter_osm_plugin.R
import hamza.dali.flutter_osm_plugin.map.MarkerConfiguration
import hamza.dali.flutter_osm_plugin.models.toLngLat
import hamza.dali.flutter_osm_plugin.utilities.toGeoPoint
import hamza.dali.flutter_osm_plugin.utilities.toHashMap
import io.flutter.plugin.common.MethodChannel
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdate
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.location.LocationComponentActivationOptions
import org.maplibre.android.location.LocationComponentOptions
import org.maplibre.android.location.engine.LocationEngineCallback
import org.maplibre.android.location.engine.LocationEngineResult
import org.maplibre.android.location.modes.CameraMode
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.plugins.annotation.Symbol
import org.maplibre.android.plugins.annotation.SymbolManager
import org.maplibre.android.plugins.annotation.SymbolOptions
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.overlay.mylocation.GpsMyLocationProvider
import org.osmdroid.views.overlay.mylocation.IMyLocationProvider
import java.lang.Exception

class OSMVectorLocationManager(
    override val context: Context,
    private val mapLibre: MapLibreMap,
    private val locationMarkerManager: SymbolManager,
    private val methodChannel: MethodChannel,
    private val methodName: String,
) : CustomLocationManager {

    private var locationMarker: Symbol? = null
    private var personIconSymbolOption: SymbolOptions? = null
    private var directionIconSymbolOption: Pair<Bitmap, Float>? = null
    override val provider: GpsMyLocationProvider by lazy {
       val gps = GpsMyLocationProvider(context)
        gps.locationUpdateMinTime = 2000L
        gps.locationUpdateMinDistance = 10f
        gps
    }


    override var currentLocation: Location? = null

    override var mGeoPoint: GeoPoint? = null
    override var enableAutoStop: Boolean = false
    override var useDirectionMarker: Boolean = true
    private var locationMode: LocationMode = LocationMode.NONE
    private var locationModeCache: LocationMode? = null
    override var mIsLocationEnabled: Boolean = false
    fun onStart() {
        if (locationModeCache != null && locationModeCache!!.isFollowing()) {
            mIsLocationEnabled = provider.startLocationProvider(this)
            enableFollowLocation()
            locationModeCache = null
        }
    }

    fun onStop() {
        locationModeCache = locationMode
        if (isFollowing()) {
            disableFollowLocation()
        }
        provider.stopLocationProvider()
    }

    fun onDestroy() {
        disableFollowLocation()
        locationModeCache = null
        mapLibre.locationComponent.onDestroy()
    }

     fun setMarkerIcon(
        personIcon: MarkerConfiguration?, directionIcon: Pair<Bitmap, Float>?
    ) {
        mapLibre.style?.removeImage("personIcon")
        mapLibre.style?.removeImage("directionIcon")
        mapLibre.style?.addImage(
            "personIcon", personIcon?.markerIcon?.toDrawable(context.resources) ?: ResourcesCompat.getDrawable(
                context.resources, R.drawable.ic_location_on_red_24dp, context.theme
            )!!
        )
        mapLibre.style?.addImage(
            "directionIcon",
            directionIcon?.first?.toDrawable(context.resources) ?: ResourcesCompat.getDrawable(
                context.resources, R.drawable.baseline_navigation_24, context.theme
            )!!
        )
         personIconSymbolOption = SymbolOptions().withIconImage("personIcon")
             .withIconSize(personIcon?.factorSize?.toFloat() ?:1f)

         directionIconSymbolOption = directionIcon


    }


    override fun startLocationUpdating() {
        enableMyLocation()
        locationMode = LocationMode.LocationOnly
    }

    override fun stopLocationUpdating() {
        locationMode = LocationMode.NONE
        onStopLocation()
    }

    override fun enableMyLocation() {
        if(!mIsLocationEnabled){
            mIsLocationEnabled = provider.startLocationProvider(this)

            // set initial location when enabled
            if (mIsLocationEnabled) {
                provider.lastKnownLocation?.let { location ->
                    setLocation(location)
                }
            }
        }

    }

    override fun onStopLocation() {
        provider.stopLocationProvider()
    }

    override fun toggleFollow() {
        if (!enableAutoStop ) {
            resetCameraToFollow()
            enableAutoStop = !enableAutoStop
            locationMode = LocationMode.GPSBearing
        }

        if(!isFollowing() && !mIsLocationEnabled) {
            enableFollowLocation()
        }
    }


    override fun disableFollowLocation() {
        provider.stopLocationProvider()
        locationMode = LocationMode.NONE
        locationMarkerManager.deleteAll()
        locationMarker = null
        mIsLocationEnabled = false

        mapLibre.resetNorth()
    }

    fun resetCameraToFollow() {
        if(currentLocation != null){
            locationMarker?.latLng = currentLocation!!.toGeoPoint().toLngLat()
            animateCamera()
        }

    }
    private fun animateCamera(){
        mapLibre.animateCamera(object:CameraUpdate {
            override fun getCameraPosition(maplibreMap: MapLibreMap): CameraPosition? {
                return CameraPosition.Builder().target(locationMarker?.latLng)
                    .zoom(maplibreMap.cameraPosition.zoom)
                    .build()
            }
        })
    }
    fun stopCamera() {
        locationModeNone()
    }

    private fun enableFollowLocation() {
        if(!mIsLocationEnabled){
            mIsLocationEnabled = provider.startLocationProvider(this)
        }

        setFollowing()
        // set initial location when enabled
        if (mIsLocationEnabled && provider.lastKnownLocation != null) {
            val location: Location = provider.lastKnownLocation
            setLocation(location)
            mapLibre.resetNorth()
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
            if (isFollowing()) {
                if(locationMarker == null){
                    createMarker(location.toGeoPoint().toLngLat())
                }
                locationMarker?.latLng = location.toGeoPoint().toLngLat()
                if(location.hasBearing() && location.bearing != 0f){
                    locationMarker?.iconRotate = location.bearing
                    locationMarker?.iconImage = "directionIcon"
                    locationMarker?.iconSize = directionIconSymbolOption?.second ?:1f
                }else if( locationMarker?.iconImage != "personIcon") {
                    locationMarker?.iconImage = "personIcon"
                    locationMarker?.iconRotate = 0f
                    locationMarker?.iconSize = personIconSymbolOption?.iconSize ?:1f
                }
                animateCamera()
            }
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
        mapLibre.locationComponent.onStart()
        mapLibre.locationComponent.activateLocationComponent(
            LocationComponentActivationOptions
                .builder(context, mapLibre.style!!)
                .useDefaultLocationEngine(true)
                .build()
        )
        checkPermission()
        mapLibre.locationComponent.isLocationComponentEnabled = true
        mapLibre.locationComponent.cameraMode = CameraMode.NONE
        mapLibre.locationComponent.locationEngine?.getLastLocation(object :
            LocationEngineCallback<LocationEngineResult> {
            override fun onSuccess(p0: LocationEngineResult?) {
                checkPermission()
                mapLibre.locationComponent.isLocationComponentEnabled = false
                mapLibre.locationComponent.onStop()
                onUserLocationReady(p0?.lastLocation?.toGeoPoint())
            }

            override fun onFailure(e: Exception) {
                Log.e("getLastLocation failed", e.stackTraceToString())
                onUserLocationFailed()
            }

        })
    }
   override  fun configurationFollow(enableStop: Boolean?,useDirectionIcon: Boolean? ) {
        if(enableStop!= null){
            this.enableAutoStop = enableStop
        }
        if(useDirectionIcon!= null){
            this.useDirectionMarker = useDirectionIcon
        }
    }
    private fun createMarker(latLng: LatLng){
        locationMarker = locationMarkerManager.create(personIconSymbolOption?.withLatLng(latLng))

    }
    private fun checkPermission() {
        if (ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED && ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
    }
    private fun locationModeNone(){
        locationMode = LocationMode.NONE
    }
    private fun setFollowing() {
        locationMode = when {
            useDirectionMarker -> LocationMode.GPSBearing
            else -> LocationMode.GPSOnly
        }

    }
     fun isFollowing() = locationMode == LocationMode.GPSBearing || locationMode == LocationMode.GPSOnly

}
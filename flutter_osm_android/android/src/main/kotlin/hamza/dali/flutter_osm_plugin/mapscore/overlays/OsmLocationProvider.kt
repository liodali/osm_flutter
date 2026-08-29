package hamza.dali.flutter_osm_plugin.mapscore.overlays

import android.annotation.SuppressLint
import android.content.Context
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle

/**
 * Standalone GPS/network location provider, independent of any map engine.
 *
 * Replaces osmdroid's [org.osmdroid.views.overlay.mylocation.GpsMyLocationProvider].
 * It only acquires locations and forwards them via [onLocation]; rendering is handled
 * separately by [MapsCoreLocationMarker].
 */
class OsmLocationProvider(context: Context) {
    private val locationManager =
        context.getSystemService(Context.LOCATION_SERVICE) as LocationManager

    var onLocation: ((Location) -> Unit)? = null

    var locationUpdateMinTime: Long = 15000L
    var locationUpdateMinDistance: Float = 1.5f

    private val listener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            onLocation?.invoke(location)
        }

        @Deprecated("legacy")
        override fun onProviderEnabled(provider: String) {}

        @Deprecated("legacy")
        override fun onProviderDisabled(provider: String) {}

        @Suppress("DEPRECATION")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
    }

    @SuppressLint("MissingPermission")
    fun start() {
        if (locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            locationManager.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                locationUpdateMinTime,
                locationUpdateMinDistance,
                listener,
            )
        }
        if (locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
            locationManager.requestLocationUpdates(
                LocationManager.NETWORK_PROVIDER,
                locationUpdateMinTime,
                locationUpdateMinDistance,
                listener,
            )
        }
    }

    @SuppressLint("MissingPermission")
    fun lastKnownLocation(): Location? {
        val providers = locationManager.getProviders(true)
        for (provider in providers) {
            @Suppress("DEPRECATION")
            val loc = locationManager.getLastKnownLocation(provider) ?: continue
            return loc
        }
        return null
    }

    fun stop() {
        locationManager.removeUpdates(listener)
    }
}

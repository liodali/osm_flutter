package hamza.dali.flutter_osm_plugin.mapscore.overlays

import android.content.Context
import android.graphics.Bitmap
import android.location.Location
import android.os.Handler
import android.os.Looper
import androidx.core.content.res.ResourcesCompat
import androidx.core.graphics.drawable.toBitmap
import androidx.core.graphics.scale
import hamza.dali.flutter_osm_plugin.R
import hamza.dali.flutter_osm_plugin.mapscore.utilities.latLonToCoord
import hamza.dali.flutter_osm_plugin.mapscore.utilities.rotate
import hamza.dali.flutter_osm_plugin.mapscore.utilities.toTextureHolder
import io.flutter.plugin.common.MethodChannel
import io.openmobilemaps.mapscore.map.view.MapView
import io.openmobilemaps.mapscore.shared.graphics.common.Vec2F
import io.openmobilemaps.mapscore.shared.graphics.shader.BlendMode
import io.openmobilemaps.mapscore.shared.map.layers.icon.IconFactory
import io.openmobilemaps.mapscore.shared.map.layers.icon.IconInfoInterface
import io.openmobilemaps.mapscore.shared.map.layers.icon.IconLayerInterface
import io.openmobilemaps.mapscore.shared.map.layers.icon.IconType
import java.util.LinkedList

typealias OnChangedLocationMapscore = (lat: Double, lon: Double, heading: Double) -> Unit

/**
 * mapscore counterpart of [hamza.dali.flutter_osm_plugin.overlays.CustomLocationManager].
 *
 * Location acquisition ([OsmLocationProvider]) is decoupled from rendering, which is done
 * through a dedicated [IconLayerInterface]. The camera follow logic is implemented in pure
 * Kotlin on top of the mapscore camera API.
 */
class CustomLocationManager(
    private val context: Context,
    private val mapView: MapView,
    private val iconLayer: IconLayerInterface,
) {
    private val provider = OsmLocationProvider(context)
    private val handler = Handler(Looper.getMainLooper())
    private val subscription = ResumableLocationSubscription(
        startUpdates = provider::start,
        stopUpdates = provider::stop,
    )

    var disableRotateDirection = false
    var useDirectionMarker = false
    var mIsFollowing = false
        private set
    val mIsLocationEnabled: Boolean
        get() = subscription.isRequested

    var mGeoPointLat: Double = 0.0
        private set
    var mGeoPointLon: Double = 0.0
        private set

    private var currentLocation: Location? = null
    private var onChangedLocationCallback: OnChangedLocationMapscore? = null
    private val runOnFirstFixQueue = LinkedList<Runnable>()
    private var pendingPositionResult: MethodChannel.Result? = null
    private var stopAfterPositionResult = false
    private val positionTimeout = Runnable {
        cancelPendingPositionRequest(
            code = "location_timeout",
            message = "Timed out waiting for a foreground location fix.",
        )
    }

    private var personBitmap: Bitmap? = null
    private var directionBitmap: Bitmap? = null
    private var personIcon: IconInfoInterface? = null
    private var directionIcon: IconInfoInterface? = null
    private var showingDirection = false
    private var iconAnchor = Vec2F(0.5f, 0.5f)
    private var directionRotation: Float? = null

    private var controlMapFromOutSide = false
    private var enabled = false

    init {
        provider.onLocation = { loc -> onLocationChanged(loc) }
        personBitmap = ResourcesCompat.getDrawable(
            context.resources, R.drawable.ic_location_on_red_24dp, context.theme
        )?.toBitmap()?.scale(56, 56)
        directionBitmap = ResourcesCompat.getDrawable(
            context.resources, R.drawable.baseline_navigation_24, context.theme
        )?.toBitmap()?.scale(56, 56)
    }

    fun enableMyLocation() {
        subscription.start()
        provider.lastKnownLocation()?.let { onLocationChanged(it) }
    }

    fun toggleFollow(enableStop: Boolean) {
        mIsFollowing = true
        if (!mIsLocationEnabled) enableMyLocation()
        if (currentLocation != null) updateMarker(currentLocation!!, true)
    }

    fun onStopLocation() {
        mIsFollowing = false
        cancelPendingPositionRequest(
            code = "location_request_cancelled",
            message = "Location acquisition was stopped.",
        )
        subscription.stop()
        clearMarkerIcons()
    }

    fun startLocationUpdating() {
        controlMapFromOutSide = true
        clearMarkerIcons()
        enableMyLocation()
    }

    fun stopLocationUpdating() {
        controlMapFromOutSide = false
        onStopLocation()
    }

    fun setMarkerIcon(personIconBmp: Bitmap?, directionIconBmp: Bitmap?) {
        if (personIconBmp != null && !personIconBmp.isRecycled) {
            personBitmap = personIconBmp
            personIcon?.let { iconLayer.remove(it) }
            personIcon = null
        }
        if (directionIconBmp != null && !directionIconBmp.isRecycled) {
            directionBitmap = directionIconBmp
            directionIcon?.let { iconLayer.remove(it) }
            directionIcon = null
            showingDirection = false
            directionRotation = null
        }
        currentLocation?.let { updateMarker(it, mIsFollowing) }
    }

    fun setAnchor(anchor: List<Double>) {
        if (anchor.size < 2) return
        iconAnchor = Vec2F(
            anchor.first().toFloat().coerceIn(0f, 1f),
            anchor.last().toFloat().coerceIn(0f, 1f),
        )
        clearMarkerIcons()
        currentLocation?.takeUnless { controlMapFromOutSide }
            ?.let { updateMarker(it, mIsFollowing) }
    }

    fun onChangedLocation(cb: OnChangedLocationMapscore) {
        onChangedLocationCallback = cb
    }

    fun runOnFirstFix(runnable: Runnable?): Boolean {
        return if (currentLocation != null) {
            runnable?.let { Thread(it).start() }
            true
        } else {
            runnable?.let { runOnFirstFixQueue.addLast(it) }
            false
        }
    }

    fun currentUserPosition(result: MethodChannel.Result) {
        val request = {
            if (pendingPositionResult != null) {
                result.error(
                    "location_request_in_progress",
                    "Another location request is already pending for this map.",
                    null,
                )
            } else {
                val location = currentLocation
                if (location != null) {
                    result.success(location.toPositionMap())
                } else {
                    stopAfterPositionResult = !mIsLocationEnabled
                    pendingPositionResult = result
                    handler.postDelayed(positionTimeout, LOCATION_FIX_TIMEOUT_MILLIS)
                    try {
                        if (!mIsLocationEnabled) enableMyLocation()
                    } catch (error: Exception) {
                        cancelPendingPositionRequest(
                            code = "location_start_failed",
                            message = error.message ?: "Unable to start location updates.",
                        )
                    }
                }
            }
        }
        if (Looper.myLooper() == Looper.getMainLooper()) request() else handler.post(request)
    }

    fun cancelPendingPositionRequest(code: String, message: String) {
        val cancel = {
            val result = pendingPositionResult
            if (result != null) {
                pendingPositionResult = null
                handler.removeCallbacks(positionTimeout)
                result.error(code, message, null)
                if (stopAfterPositionResult) subscription.stop()
                stopAfterPositionResult = false
            }
        }
        if (Looper.myLooper() == Looper.getMainLooper()) cancel() else handler.post(cancel)
    }

    fun onResume() {
        subscription.onResume()
    }

    fun onPause() {
        cancelPendingPositionRequest(
            code = "location_request_paused",
            message = "The host Activity paused before a location fix arrived.",
        )
        subscription.onPause()
    }

    fun onDestroy() {
        cancelPendingPositionRequest(
            code = "location_request_cancelled",
            message = "The map session was disposed before a location fix arrived.",
        )
        subscription.close()
        runOnFirstFixQueue.clear()
        onChangedLocationCallback = null
        handler.removeCallbacksAndMessages(null)
        clearMarkerIcons()
    }

    private fun onLocationChanged(loc: Location) {
        currentLocation = loc
        mGeoPointLat = loc.latitude
        mGeoPointLon = loc.longitude
        onChangedLocationCallback?.invoke(loc.latitude, loc.longitude, loc.bearing.toDouble())

        val apply = Runnable {
            completePendingPositionRequest(loc)
            if (!controlMapFromOutSide) {
                updateMarker(loc, mIsFollowing)
            }
            if (runOnFirstFixQueue.isNotEmpty()) {
                val runnables = ArrayList(runOnFirstFixQueue)
                runOnFirstFixQueue.clear()
                runnables.forEach { Thread(it).start() }
            }
        }
        if (Looper.myLooper() == Looper.getMainLooper()) {
            apply.run()
        } else {
            handler.post(apply)
        }
    }

    private fun completePendingPositionRequest(location: Location) {
        val result = pendingPositionResult ?: return
        pendingPositionResult = null
        handler.removeCallbacks(positionTimeout)
        result.success(location.toPositionMap())
        if (stopAfterPositionResult) subscription.stop()
        stopAfterPositionResult = false
    }

    private fun Location.toPositionMap(): HashMap<String, Double> =
        hashMapOf("lat" to latitude, "lon" to longitude)

    private fun updateMarker(loc: Location, follow: Boolean) {
        val coordinate = latLonToCoord(loc.latitude, loc.longitude)
        val hasBearing = loc.hasBearing() || useDirectionMarker
        if (hasBearing && directionBitmap != null) {
            personIcon?.let { iconLayer.remove(it) }
            personIcon = null
            val rotation = if (disableRotateDirection) 0f else loc.bearing
            if (directionIcon == null || directionRotation != rotation) {
                directionIcon?.let { iconLayer.remove(it) }
                directionIcon = createAndAddIcon(
                    "osm_user_direction",
                    directionBitmap,
                    coordinate,
                    rotation,
                )
                directionRotation = rotation
                showingDirection = directionIcon != null
            } else {
                directionIcon?.setCoordinate(coordinate)
            }
        } else {
            if (showingDirection) {
                directionIcon?.let { iconLayer.remove(it) }
                directionIcon = null
                showingDirection = false
                directionRotation = null
            }
            if (personIcon == null) {
                personIcon = createAndAddIcon("osm_user_person", personBitmap, coordinate)
            } else {
                personIcon?.setCoordinate(coordinate)
            }
        }
        iconLayer.invalidate()
        mapView.requestRender()

        if (follow) {
            try {
                mapView.getCamera().moveToCenterPosition(coordinate, true)
            } catch (e: IllegalStateException) {
                // map not ready yet; ignore
            }
        }
    }

    private fun clearMarkerIcons() {
        personIcon?.let { iconLayer.remove(it) }
        directionIcon?.let { iconLayer.remove(it) }
        personIcon = null
        directionIcon = null
        showingDirection = false
        directionRotation = null
        iconLayer.invalidate()
        mapView.requestRender()
    }

    private fun createAndAddIcon(
        identifier: String,
        bitmap: Bitmap?,
        coord: io.openmobilemaps.mapscore.shared.map.coordinates.Coord,
        rotation: Float = 0f,
    ): IconInfoInterface? {
        if (bitmap == null || bitmap.isRecycled) return null
        val source = if (rotation == 0f) bitmap else bitmap.rotate(rotation)
        val (holder, size) = source.toTextureHolder()
        val icon = IconFactory.createIconWithAnchor(
            identifier = identifier,
            coordinate = coord,
            texture = holder,
            iconSize = size,
            scaleType = IconType.INVARIANT,
            blendMode = BlendMode.NORMAL,
            iconAnchor = iconAnchor,
        )
        iconLayer.add(icon)
        return icon
    }

    @Suppress("unused")
    fun setEnabled(e: Boolean) {
        enabled = e
    }

    private companion object {
        const val LOCATION_FIX_TIMEOUT_MILLIS = 15_000L
    }
}

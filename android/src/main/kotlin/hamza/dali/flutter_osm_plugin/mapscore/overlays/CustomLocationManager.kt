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
import hamza.dali.flutter_osm_plugin.mapscore.utilities.latLonToRender
import io.flutter.plugin.common.MethodChannel
import io.openmobilemaps.mapscore.graphics.BitmapTextureHolder
import io.openmobilemaps.mapscore.map.view.MapView
import io.openmobilemaps.mapscore.shared.graphics.common.Vec2F
import io.openmobilemaps.mapscore.shared.graphics.shader.BlendMode
import io.openmobilemaps.mapscore.shared.map.layers.icon.IconFactory
import io.openmobilemaps.mapscore.shared.map.layers.icon.IconInfoInterface
import io.openmobilemaps.mapscore.shared.map.layers.icon.IconLayerInterface
import io.openmobilemaps.mapscore.shared.map.layers.icon.IconType
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
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
    private val helper = mapView.getCoordinateConversionHelper()
    private val provider = OsmLocationProvider(context)
    private val handler = Handler(Looper.getMainLooper())

    var disableRotateDirection = false
    var useDirectionMarker = false
    var mIsFollowing = false
        private set
    var mIsLocationEnabled = false
        private set

    var mGeoPointLat: Double = 0.0
        private set
    var mGeoPointLon: Double = 0.0
        private set

    private var currentLocation: Location? = null
    private var onChangedLocationCallback: OnChangedLocationMapscore? = null
    private val runOnFirstFixQueue = LinkedList<Runnable>()

    private var personBitmap: Bitmap? = null
    private var directionBitmap: Bitmap? = null
    private var personIcon: IconInfoInterface? = null
    private var directionIcon: IconInfoInterface? = null
    private var showingDirection = false

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
        provider.start()
        mIsLocationEnabled = true
        provider.lastKnownLocation()?.let { onLocationChanged(it) }
    }

    fun toggleFollow(enableStop: Boolean) {
        mIsFollowing = true
        if (!mIsLocationEnabled) enableMyLocation()
        if (currentLocation != null) updateMarker(currentLocation!!, true)
    }

    fun onStopLocation() {
        mIsFollowing = false
        mIsLocationEnabled = false
        provider.stop()
        handler.removeCallbacksAndMessages(null)
    }

    fun startLocationUpdating() {
        controlMapFromOutSide = true
        enableMyLocation()
    }

    fun stopLocationUpdating() {
        controlMapFromOutSide = false
        onStopLocation()
    }

    fun setMarkerIcon(personIcon: Bitmap?, directionIcon: Bitmap?) {
        if (personIcon != null) personBitmap = personIcon
        if (directionIcon != null) directionBitmap = directionIcon
        currentLocation?.let { updateMarker(it, mIsFollowing) }
    }

    fun setAnchor(anchor: List<Double>) {
        // anchors for the user marker are kept centered (0.5, 0.5); stored for parity.
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

    fun currentUserPosition(result: MethodChannel.Result, scope: CoroutineScope) {
        if (!mIsLocationEnabled) enableMyLocation()
        runOnFirstFix(Runnable {
            val loc = currentLocation
            if (loc != null) {
                scope.launch(Dispatchers.Main) {
                    val map = HashMap<String, Double>()
                    map["lat"] = loc.latitude
                    map["lon"] = loc.longitude
                    result.success(map)
                }
                mIsLocationEnabled = false
                provider.stop()
            } else {
                scope.launch(Dispatchers.Main) {
                    result.error("400", "we cannot get the current position!", "")
                }
            }
        })
    }

    fun onResume() {
        if (mIsLocationEnabled) provider.start()
    }

    fun onPause() {
        provider.stop()
    }

    fun onDestroy() {
        provider.stop()
        handler.removeCallbacksAndMessages(null)
    }

    private fun onLocationChanged(loc: Location) {
        currentLocation = loc
        mGeoPointLat = loc.latitude
        mGeoPointLon = loc.longitude
        onChangedLocationCallback?.invoke(loc.latitude, loc.longitude, loc.bearing.toDouble())

        if (!controlMapFromOutSide) {
            updateMarker(loc, mIsFollowing)
        }
        // run queued first-fix callbacks
        if (runOnFirstFixQueue.isNotEmpty()) {
            val runnables = ArrayList(runOnFirstFixQueue)
            runOnFirstFixQueue.clear()
            runnables.forEach { Thread(it).start() }
        }
    }

    private fun updateMarker(loc: Location, follow: Boolean) {
        val render = latLonToRender(helper, loc.latitude, loc.longitude)
        val hasBearing = loc.hasBearing() || useDirectionMarker
        if (hasBearing && directionBitmap != null) {
            ensureIcon(personIcon, personBitmap, "osm_user_person", render)
            if (!showingDirection) {
                directionIcon?.let { iconLayer.remove(it) }
                directionIcon = createIcon("osm_user_direction", directionBitmap!!, render)
                iconLayer.add(directionIcon!!)
                showingDirection = true
            }
            personIcon?.setCoordinate(render)
            directionIcon?.setCoordinate(render)
        } else {
            if (showingDirection) {
                directionIcon?.let { iconLayer.remove(it) }
                directionIcon = null
                showingDirection = false
            }
            ensureIcon(personIcon, personBitmap, "osm_user_person", render)
            personIcon?.setCoordinate(render)
        }
        iconLayer.invalidate()

        if (follow) {
            try {
                mapView.getCamera().moveToCenterPosition(render, true)
            } catch (e: IllegalStateException) {
                // map not ready yet; ignore
            }
        }
    }

    private fun ensureIcon(
        current: IconInfoInterface?,
        bitmap: Bitmap?,
        identifier: String,
        coord: io.openmobilemaps.mapscore.shared.map.coordinates.Coord,
    ): IconInfoInterface? {
        if (current != null) return current
        if (bitmap == null) return null
        val holder = BitmapTextureHolder(bitmap)
        val size = Vec2F(bitmap.width.toFloat(), bitmap.height.toFloat())
        val icon = IconFactory.createIconWithAnchor(
            identifier = identifier,
            coordinate = coord,
            texture = holder,
            iconSize = size,
            scaleType = IconType.INVARIANT,
            blendMode = BlendMode.NORMAL,
            iconAnchor = Vec2F(0.5f, 0.5f),
        )
        iconLayer.add(icon)
        return icon
    }

    private fun createIcon(
        identifier: String,
        bitmap: Bitmap,
        coord: io.openmobilemaps.mapscore.shared.map.coordinates.Coord,
    ): IconInfoInterface {
        val holder = BitmapTextureHolder(bitmap)
        val size = Vec2F(bitmap.width.toFloat(), bitmap.height.toFloat())
        return IconFactory.createIconWithAnchor(
            identifier = identifier,
            coordinate = coord,
            texture = holder,
            iconSize = size,
            scaleType = IconType.INVARIANT,
            blendMode = BlendMode.NORMAL,
            iconAnchor = Vec2F(0.5f, 0.5f),
        )
    }

    @Suppress("unused")
    fun setEnabled(e: Boolean) {
        enabled = e
    }
}

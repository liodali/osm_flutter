package hamza.dali.flutter_osm_plugin.overlays

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Point
import android.location.Location
import android.util.Log
import hamza.dali.flutter_osm_plugin.VoidCallback
import hamza.dali.flutter_osm_plugin.utilities.toHashMap
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.osmdroid.api.IMapView
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.Projection
import org.osmdroid.views.overlay.mylocation.GpsMyLocationProvider
import org.osmdroid.views.overlay.mylocation.IMyLocationProvider
import org.osmdroid.views.overlay.mylocation.MyLocationNewOverlay

typealias OnChangedLocation = (gp: GeoPoint) -> Unit

class CustomLocationManager(mapView: MapView) : MyLocationNewOverlay(mapView) {
    private var provider: GpsMyLocationProvider? = GpsMyLocationProvider(mapView.context)
    var disableRotateDirection = false
    private var mDrawPixel: Point = Point()
    private var customIcons = false
    private var onChangedLocation: OnChangedLocation? = null

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
        this.onChangedLocation = null
        disableFollowAndLocation()
        mMyLocationProvider.stopLocationProvider()
    }

    fun onDestroy() {
        mMyLocationProvider.destroy()
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
                    if (!isFollowLocationEnabled) {
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
        if (isFollowLocationEnabled && location != null) {
            val geoPMap = GeoPoint(this.lastFix)
            if (onChangedLocation != null) {
                this.onChangedLocation!!(geoPMap)
            }
        }
    }

    fun toggleFollow(enableStop: Boolean) {
        enableAutoStop = enableStop
        when (enableStop) {
            true -> disableFollowLocation()
            else -> enableFollowLocation()
        }
    }

    fun followLocation(onChangedLocation: (gp: GeoPoint) -> Unit) {
        this.enableFollowLocation()
        runOnFirstFix {
            val location = this.lastFix
            val geoPMap = GeoPoint(location)
            onChangedLocation(geoPMap)
        }
    }

    fun onChangedLocation(onChangedLocation: OnChangedLocation) {
        this.onChangedLocation = onChangedLocation
        runOnFirstFix {
            val location = this.lastFix
            val geoPMap = GeoPoint(location)
            onChangedLocation(geoPMap)
        }
    }

    override fun draw(canvas: Canvas, pProjection: Projection) {
        mDrawAccuracyEnabled = false
        if (customIcons) {
            setPersonAnchor(0.5f, 0.5f)
        }
        when {
            disableRotateDirection && customIcons -> {
                if (lastFix != null && isMyLocationEnabled) {
                    drawOnlyPerson(canvas, pProjection, lastFix)
                }
            }

            else -> super.draw(canvas, pProjection)
        }

    }

    override fun onSnapToItem(x: Int, y: Int, snapPoint: Point?, mapView: IMapView?): Boolean {
        return false
    }

    fun setMarkerIcon(personIcon: Bitmap?, directionIcon: Bitmap?) {

        when {
            personIcon != null && directionIcon != null -> {
                customIcons = true
                mPersonBitmap = personIcon
                mDirectionArrowBitmap = directionIcon

                setDirectionAnchor(.5f, .5f)

//                mPersonHotspot.set(
//                    mScale * (personIcon.width / 4f) + 0.5f,
//                    mScale * (personIcon.width / 3f) + 0.5f,
//                )
            }

            personIcon != null -> {
                customIcons = true
                setPersonIcon(personIcon)
                setPersonAnchor(
                    .5f,
                    .1f
                )
            }
        }
    }

    private fun drawOnlyPerson(canvas: Canvas, pProjection: Projection, lastFix: Location) {
        //val mGeoPoint = lastFix.toGeoPoint()
        pProjection.toPixels(super.getMyLocation(), mDrawPixel)
        canvas.save()
        // Unrotate the icon if the maps are rotated so the little man stays upright
        // Unrotate the icon if the maps are rotated so the little man stays upright
        canvas.rotate(
            -mMapView.mapOrientation, mDrawPixel.x.toFloat(),
            mDrawPixel.y.toFloat()
        )
        // Draw the bitmap
        // Draw the bitmap
        Log.d(
            "personBitmap location",
            "${super.getMyLocation()}"
        )
        Log.d(
            "personBitmap",
            "${mDrawPixel.x},${mDrawPixel.y},${mPersonHotspot.x},${mPersonHotspot.y}"
        )
        Log.d(
            "personBitmap point",
            "${mDrawPixel.x - mPersonHotspot.x},${mDrawPixel.y - mPersonHotspot.y}"
        )
        canvas.drawBitmap(
            mPersonBitmap, mDrawPixel.x.toFloat() - mPersonHotspot.x,
            mDrawPixel.y.toFloat() - mPersonHotspot.y, mPaint
        )
        canvas.restore()
    }
}
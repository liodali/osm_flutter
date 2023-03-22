package hamza.dali.flutter_osm_plugin.overlays

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Point
import android.location.Location
import hamza.dali.flutter_osm_plugin.VoidCallback
import hamza.dali.flutter_osm_plugin.utilities.toGeoPoint
import hamza.dali.flutter_osm_plugin.utilities.toHashMap
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.osmdroid.util.GeoPoint
import org.osmdroid.util.TileSystem
import org.osmdroid.views.MapView
import org.osmdroid.views.Projection
import org.osmdroid.views.overlay.mylocation.GpsMyLocationProvider
import org.osmdroid.views.overlay.mylocation.IMyLocationProvider
import org.osmdroid.views.overlay.mylocation.MyLocationNewOverlay

class CustomLocationManager(mapView: MapView) : MyLocationNewOverlay(mapView) {
    private var provider: GpsMyLocationProvider? = GpsMyLocationProvider(mapView.context)
    var disableRotateDirection = false
    private var mDrawPixel: Point = Point()

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
    }

    fun followLocation(onChangedLocation: (gp: GeoPoint) -> Unit) {
        this.enableFollowLocation()
        runOnFirstFix {
            val location = this.lastFix
            val geoPMap = GeoPoint(location)
            onChangedLocation(geoPMap)
        }
    }

    override fun draw(canvas: Canvas, pProjection: Projection) {
        mDrawAccuracyEnabled = false
        when {
            disableRotateDirection -> {
                if (lastFix != null && isMyLocationEnabled) {
                    drawOnlyPerson(canvas, pProjection, lastFix)
                }
            }
            else -> super.draw(canvas, pProjection)
        }

    }

    fun setMarkerIcon(personIcon: Bitmap?, directionIcon: Bitmap?) {
        when {
            personIcon != null && directionIcon != null -> {
                mPersonBitmap = personIcon
                mDirectionArrowBitmap = directionIcon
                setDirectionAnchor(.5f, .5f)
                val mScale = mMapView!!.context.resources.displayMetrics.density

//                mPersonHotspot.set(
//                    mScale * (personIcon.width / 4f) + 0.5f,
//                    mScale * (personIcon.width / 3f) + 0.5f,
//                )
            }
            personIcon != null -> {
                setPersonIcon(personIcon)
            }
        }
    }

    private fun drawOnlyPerson(canvas: Canvas, pProjection: Projection, lastFix: Location) {
        val mGeoPoint = lastFix.toGeoPoint()
        pProjection.toPixels(mGeoPoint, mDrawPixel)

        if (mDrawAccuracyEnabled) {
            val radius: Float = (lastFix.accuracy
                    / TileSystem.GroundResolution(
                lastFix.latitude,
                pProjection.zoomLevel
            ).toFloat())
            mCirclePaint.alpha = 50
            mCirclePaint.style = Paint.Style.FILL
            canvas.drawCircle(
                mDrawPixel.x.toFloat(),
                mDrawPixel.y.toFloat(),
                radius,
                mCirclePaint
            )
            mCirclePaint.alpha = 150
            mCirclePaint.style = Paint.Style.STROKE
            canvas.drawCircle(
                mDrawPixel.x.toFloat(),
                mDrawPixel.y.toFloat(),
                radius,
                mCirclePaint
            )
        }
        canvas.save()
        // Unrotate the icon if the maps are rotated so the little man stays upright
        // Unrotate the icon if the maps are rotated so the little man stays upright
        canvas.rotate(
            -mMapView.mapOrientation, mDrawPixel.x.toFloat(),
            mDrawPixel.y.toFloat()
        )
        // Draw the bitmap
        // Draw the bitmap
        canvas.drawBitmap(
            mPersonBitmap, mDrawPixel.x - mPersonHotspot.x,
            mDrawPixel.y - mPersonHotspot.y, mPaint
        )
        canvas.restore()
    }
}
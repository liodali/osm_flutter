package hamza.dali.flutter_osm_plugin.overlays

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Point
import android.location.Location
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.MotionEvent
import hamza.dali.flutter_osm_plugin.VoidCallback
import hamza.dali.flutter_osm_plugin.utilities.toHashMap
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers.Main
import kotlinx.coroutines.launch
import org.osmdroid.api.IMapView
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.Projection
import org.osmdroid.views.overlay.mylocation.GpsMyLocationProvider
import org.osmdroid.views.overlay.mylocation.IMyLocationProvider
import org.osmdroid.views.overlay.mylocation.MyLocationNewOverlay
import java.util.LinkedList

typealias OnChangedLocation = (gp: GeoPoint) -> Unit

class CustomLocationManager(mapView: MapView) : MyLocationNewOverlay(mapView) {
    private var provider: GpsMyLocationProvider? = GpsMyLocationProvider(mapView.context)
    var disableRotateDirection = false
    private var mDrawPixel: Point = Point()
    private var customIcons = false
    private var onChangedLocation: OnChangedLocation? = null
    private var skipDraw = false
    private val mRunOnFirstFix = LinkedList<Runnable>()
    var currentLocation: Location? = null
        private set(value) {
            field = value
        }
    private var mHandlerToken = Object()
    private var handler = Handler(Looper.getMainLooper())

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
        skipDraw = true
        if (!isMyLocationEnabled) {
            enableMyLocation()
        }
        runOnFirstFix {
            currentLocation?.let { location ->
                val point = GeoPoint(
                    location.latitude,
                    location.longitude,
                )
                scope.launch(Main) {
                    result.success(point.toHashMap())
                }
                if (!isFollowLocationEnabled) {
                    disableMyLocation()
                }
                skipDraw = false
                if (afterGetLocation != null) {
                    afterGetLocation()
                }
            } ?: result.error("400", "we cannot get the current position!", "")


        }
    }


    override fun onLocationChanged(location: Location?, source: IMyLocationProvider?) {
        //super.onLocationChanged(location, source)
        val geoPMap = GeoPoint(location)
        if (isFollowLocationEnabled && location != null) {
            if (mIsFollowing && !enableAutoStop) {
                mMapView.controller.animateTo(geoPMap)
                enableAutoStop = true
                Log.d("osm user location", "enable auto animate to")
            }
        }
        if (onChangedLocation != null) {
            this.onChangedLocation!!(geoPMap)
        }
        currentLocation = location
        // These location updates can come in from different threads
        handler.postAtTime(object : Runnable {
            override fun run() {
                for (runnable in mRunOnFirstFix) {
                    val t = Thread(runnable)
                    t.name = this.javaClass.name + "#onLocationChanged"
                    t.start()
                }
                mRunOnFirstFix.clear()
            }
        }, mHandlerToken, 0)
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

    override fun onTouchEvent(event: MotionEvent?, mapView: MapView?): Boolean {
        val isSingleFingerDrag =
            event!!.action == MotionEvent.ACTION_MOVE && event.pointerCount == 1
        if (enableAutoStop && isSingleFingerDrag) {
            mapView?.controller?.stopAnimation(false)
            mapView?.animation?.cancel()
            disableFollowLocation()
            enableAutoStop = false
            mIsFollowing = false
            mapView?.controller?.setCenter(mapView.mapCenter)
            Log.d("osm user location", "stop animate to")
        }
        return false
    }

    override fun draw(canvas: Canvas, pProjection: Projection) {
        mDrawAccuracyEnabled = false
        if (!skipDraw) {
            if (customIcons) {
                setPersonAnchor(0.5f, 0.5f)
                setDirectionAnchor(0.5f, 0.5f)
            }
            when {
                disableRotateDirection && customIcons -> {
                    if (lastFix != null && isMyLocationEnabled) {
                        drawPerson(canvas, pProjection, lastFix)
                    }
                }

                else -> {
                    if (lastFix != null) {
                        when (lastFix.hasBearing()) {
                            true -> drawDirection(canvas, pProjection, lastFix)
                            else -> drawPerson(canvas, pProjection, lastFix)
                        }
                    }
                }
            }
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

    private fun drawPerson(canvas: Canvas, pProjection: Projection, lastFix: Location) {
        //val mGeoPoint = lastFix.toGeoPoint()
        pProjection.toPixels(super.getMyLocation(), mDrawPixel)
        canvas.save()
        // Unrotate the icon if the maps are rotated so the little man stays upright
        // Unrotate the icon if the maps are rotated so the little man stays upright
        canvas.rotate(
            -mMapView.mapOrientation, mDrawPixel.x.toFloat(),
            mDrawPixel.y.toFloat()
        )

        canvas.drawBitmap(
            mPersonBitmap, mDrawPixel.x.toFloat() - mPersonHotspot.x,
            mDrawPixel.y.toFloat() - mPersonHotspot.y, mPaint
        )
        canvas.restore()
    }

    private fun drawDirection(canvas: Canvas, pProjection: Projection, lastFix: Location) {
        //val mGeoPoint = lastFix.toGeoPoint()
        pProjection.toPixels(super.getMyLocation(), mDrawPixel)
        canvas.save()
        var mapRotation = lastFix.bearing
        if (mapRotation >= 360.0f) mapRotation -= 360f
        canvas.rotate(mapRotation, mDrawPixel.x.toFloat(), mDrawPixel.y.toFloat())


        canvas.drawBitmap(
            mDirectionArrowBitmap, mDrawPixel.x.toFloat() - mDirectionArrowCenterX,
            mDrawPixel.y.toFloat() - mDirectionArrowCenterY, mPaint
        )
        canvas.restore()
    }

    fun setAnchor(anchor: List<Double>) {
        setPersonAnchor(anchor.first().toFloat(), anchor.last().toFloat())
        setDirectionAnchor(anchor.first().toFloat(), anchor.last().toFloat())
    }

    override fun onDetach(mapView: MapView?) {
        handler.removeCallbacksAndMessages(mHandlerToken)
    }

    override fun runOnFirstFix(runnable: Runnable?): Boolean {
        return if (mMyLocationProvider != null && currentLocation != null) {
            val t = Thread(runnable)
            t.name = this.javaClass.name + "#runOnFirstFix"
            t.start()
            true
        } else {
            mRunOnFirstFix.addLast(runnable)
            false
        }
    }
}
package hamza.dali.flutter_osm_plugin.overlays

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
import hamza.dali.flutter_osm_plugin.VoidCallback
import hamza.dali.flutter_osm_plugin.utilities.toGeoPoint
import hamza.dali.flutter_osm_plugin.utilities.toHashMap
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers.Main
import kotlinx.coroutines.launch
import org.osmdroid.api.IMapView
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.Projection
import org.osmdroid.views.overlay.Overlay
import org.osmdroid.views.overlay.Overlay.Snappable
import org.osmdroid.views.overlay.mylocation.GpsMyLocationProvider
import org.osmdroid.views.overlay.mylocation.IMyLocationConsumer
import org.osmdroid.views.overlay.mylocation.IMyLocationProvider
import java.util.LinkedList

typealias OnChangedLocation = (userLocation: GeoPoint,heading:Double) -> Unit

class CustomLocationManager(private val mapView: MapView) : Overlay(), IMyLocationConsumer,
    Snappable {
    private val provider: GpsMyLocationProvider  by lazy {
        GpsMyLocationProvider(mapView.context)
    }

    private var mDrawPixel: Point = Point()
    private var onChangedLocationCallback: OnChangedLocation? = null
    private val mRunOnFirstFix = LinkedList<Runnable>()

    private val mPaint: Paint = Paint()

    private var mPersonBitmap: Bitmap? = null
    private var mDirectionArrowBitmap: Bitmap? = null
    private val mPersonHotspot: PointF = PointF()

    private var mDirectionArrowCenterX = 0f
    private var mDirectionArrowCenterY = 0f
    var disableRotateDirection = false
    private var enableAutoStop = true
    var mIsFollowing = false
        private set

    var mIsLocationEnabled = false
        private set
    var useDirectionMarker = false
    private var currentLocation: Location? = null

    private val mHandler: Handler = Handler(Looper.getMainLooper())
    var mGeoPoint: GeoPoint = GeoPoint(0.0, 0.0)
        private set
    private var mHandlerToken = Object()

    private var controlMapFromOutSide = false

    init {
        mPaint.isFilterBitmap = true
        mPersonBitmap = ResourcesCompat.getDrawable(
            mapView.context.resources,
            R.drawable.ic_location_on_red_24dp,
            mapView.context.theme
        )?.toBitmap()
        mDirectionArrowBitmap = ResourcesCompat.getDrawable(
            mapView.context.resources,
            R.drawable.baseline_navigation_24,
            mapView.context.theme
        )?.toBitmap()

        provider.locationUpdateMinTime = 15000L
        provider.locationUpdateMinDistance = 1.5f
    }
    private fun setLocation(location: Location) {
        currentLocation = location
        mGeoPoint = location.toGeoPoint()
        if (mIsFollowing) {
            mapView.controller.animateTo(mGeoPoint)
        } else {
            mapView.postInvalidate()
        }
    }

    fun enableMyLocation() {

        val isSuccess = provider.startLocationProvider(this)

        // set initial location when enabled
        if (isSuccess) {

                provider.lastKnownLocation?.let {location->
                    setLocation(location)
                }

        }

        // Update the screen to see changes take effect
        mapView.postInvalidate()
        mIsLocationEnabled = isSuccess
    }

    private fun enableFollowLocation() {
        mIsFollowing = true
        // set initial location when enabled
        if (mIsLocationEnabled) {
            val location: Location = provider.lastKnownLocation
           setLocation(location)


        }
        mapView.postInvalidate()

    }
    fun startLocationUpdating(){
        enableMyLocation()
        controlMapFromOutSide = true
    }
    fun stopLocationUpdating(){
        controlMapFromOutSide = false
        onStopLocation()
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
        //this.onChangedLocationCallback = null
        disableFollowAndLocation()
        provider.stopLocationProvider()
        mHandler.removeCallbacksAndMessages(mHandlerToken)
    }

    private fun disableMyLocation() {
        mIsLocationEnabled = false
        stopLocationProvider()
        mapView.postInvalidate()

    }

    private fun stopLocationProvider() {
        provider.stopLocationProvider()

    }

    override fun onResume() {
        super.onResume()
        if (mIsLocationEnabled)  enableMyLocation()
        if (mIsFollowing) enableFollowLocation()

    }

    override fun onPause() {
        stopLocationProvider()
        super.onPause()
    }

    fun onDestroy() {
        provider.destroy()
    }


    fun currentUserPosition(
        result: MethodChannel.Result,
        afterGetLocation: VoidCallback? = null,
        scope: CoroutineScope,

        ) {
        if (!mIsLocationEnabled) {
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
                disableMyLocation()

                if (afterGetLocation != null) {
                    afterGetLocation()
                }
            } ?: result.error("400", "we cannot get the current position!", "")
        }
    }


    override fun onLocationChanged(location: Location?, source: IMyLocationProvider?) {
        // super.onLocationChanged(location, source)

        currentLocation = location
        mGeoPoint = GeoPoint(location)
        /*if (mIsFollowing && location != null && !enableAutoStop) {

            mapView.controller.animateTo(mGeoPoint)
            enableAutoStop = true
            Log.d("osm user location", "enable auto animate to")

        }
        //mapView.postInvalidate()*/
        if (onChangedLocationCallback != null) {
            onChangedLocationCallback!!(mGeoPoint,currentLocation!!.bearing.toDouble())
        }

        if (location != null) {
            mHandler.postAtTime(object : Runnable {
                override fun run() {
                    /*
                     * if we call startLocationUpdating,we will not control map from here
                     *
                     */
                    if(!controlMapFromOutSide){
                        setLocation(location)
                    }
                    for (runnable in mRunOnFirstFix) {
                        val t = Thread(runnable)
                        t.setName(this.javaClass.getName() + "#onLocationChanged")
                        t.start()
                    }
                    mRunOnFirstFix.clear()
                }
            }, mHandlerToken, 0)
        }
    }

    fun toggleFollow(enableStop: Boolean,) {
        enableAutoStop = enableStop
        enableFollowLocation()
    }

    fun followLocation(onChangedLocation: (gp: GeoPoint) -> Unit) {
        this.enableFollowLocation()
        runOnFirstFix {
            val location = this.currentLocation!!
            val geoPMap = GeoPoint(location)
            onChangedLocation(geoPMap)
        }
    }

    fun disableFollowLocation() {
        if (mapView.controller != null) mapView.controller.stopAnimation(false)
        mIsFollowing = false
    }

    fun onChangedLocation(onChangedLocation: OnChangedLocation) {
        this.onChangedLocationCallback = onChangedLocation
        /*val location = this.currentLocation!!
        val geoPMap = GeoPoint(location)
        onChangedLocationCallback!!(geoPMap,location.bearing.toDouble())*/
    }

    override fun onTouchEvent(event: MotionEvent?, mapView: MapView?): Boolean {
        val isSingleFingerDrag =
            event!!.action == MotionEvent.ACTION_MOVE && event.pointerCount == 1
        if (enableAutoStop && isSingleFingerDrag) {
            mapView?.controller?.stopAnimation(false)
            mapView?.animation?.cancel()
            disableFollowLocation()
            enableAutoStop = false
            //mapView?.controller?.setCenter(mapView.mapCenter)
            Log.d("osm user location", "stop animate to")
        }
        return false
    }


    override fun draw(canvas: Canvas, pProjection: Projection) {
        if (currentLocation != null && mIsLocationEnabled && !controlMapFromOutSide) {
            pProjection.toPixels(mGeoPoint, mDrawPixel)
            when (currentLocation!!.hasBearing() || this.useDirectionMarker) {
                true -> {
                    val mapRotation = when {
                        !disableRotateDirection -> currentLocation!!.bearing
                        else -> 0f
                    }
                    drawDirection(canvas, mapRotation)
                }

                else -> drawPerson(canvas)
            }
        }

    }


    fun setMarkerIcon(personIcon: Bitmap?, directionIcon: Bitmap?) {

        when {
            personIcon != null && directionIcon != null -> {
                mPersonBitmap = personIcon
                mDirectionArrowBitmap = directionIcon
                setDirectionAnchor(.5f, .5f)
                setPersonAnchor(
                    .5f,
                    .1f
                )
            }

            personIcon != null -> {
                mPersonBitmap = personIcon
                setPersonAnchor(
                    .5f,
                    .1f
                )
            }
        }
    }

    private fun drawPerson(canvas: Canvas) {

        canvas.save()
        canvas.rotate(
            -mapView.mapOrientation, mDrawPixel.x.toFloat(),
            mDrawPixel.y.toFloat()
        )

        canvas.drawBitmap(
            mPersonBitmap!!, mDrawPixel.x.toFloat() - mPersonHotspot.x,
            mDrawPixel.y.toFloat() - mPersonHotspot.y, mPaint
        )
        canvas.restore()
    }

    private fun drawDirection(canvas: Canvas, mapRotation: Float) {

        var rotation = mapRotation
        if (rotation >= 360.0f) {
            rotation -= 360f
        }
        canvas.save()
        canvas.rotate(rotation, mDrawPixel.x.toFloat(), mDrawPixel.y.toFloat())


        canvas.drawBitmap(
            mDirectionArrowBitmap!!, mDrawPixel.x.toFloat() - mDirectionArrowCenterX,
            mDrawPixel.y.toFloat() - mDirectionArrowCenterY, mPaint
        )
        canvas.restore()
    }

    fun setAnchor(anchor: List<Double>) {
        setPersonAnchor(anchor.first().toFloat(), anchor.last().toFloat())
        setDirectionAnchor(anchor.first().toFloat(), anchor.last().toFloat())
    }

    override fun onDetach(mapView: MapView?) {
        mHandler.removeCallbacksAndMessages(mHandlerToken)
    }


    private fun setPersonAnchor(pHorizontal: Float, pVertical: Float) {
        mPersonHotspot.set(
            mPersonBitmap!!.getWidth() * pHorizontal,
            mPersonBitmap!!.getHeight() * pVertical
        )
    }

    /**
     * Anchors for the direction icon
     * Expected values between 0 and 1, 0 being top/left, .5 center and 1 bottom/right
     * @since 6.2.0
     */
    private fun setDirectionAnchor(pHorizontal: Float, pVertical: Float) {
        mDirectionArrowCenterX = mDirectionArrowBitmap!!.getWidth() * pHorizontal
        mDirectionArrowCenterY = mDirectionArrowBitmap!!.getHeight() * pVertical
    }

    fun runOnFirstFix(runnable: Runnable?): Boolean {
        return if (currentLocation != null) {
            val t = Thread(runnable)
            t.setName(this.javaClass.getName() + "#runOnFirstFix")
            t.start()
            true
        } else {
            mRunOnFirstFix.addLast(runnable)
            false
        }
    }


    override fun onSnapToItem(x: Int, y: Int, snapPoint: Point?, mapView: IMapView?): Boolean {
        return false
    }
}
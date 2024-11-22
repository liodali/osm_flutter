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
import org.osmdroid.api.IGeoPoint
import org.osmdroid.api.IMapView
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.Projection
import org.osmdroid.views.overlay.Overlay
import org.osmdroid.views.overlay.Overlay.Snappable
import org.osmdroid.views.overlay.mylocation.GpsMyLocationProvider
import org.osmdroid.views.overlay.mylocation.IMyLocationProvider
import java.util.LinkedList

abstract class CustomOSMLocationManager(
    override val context: Context,

) : Overlay(), Snappable, CustomLocationManager {

    abstract val onMove: (IGeoPoint) -> Unit
    abstract val onUpdate: () -> Unit
    override val provider: GpsMyLocationProvider by lazy {
        GpsMyLocationProvider(context)
    }
}
class OSMLocationManager(
    private val mapView: MapView,
    private val methodChannel: MethodChannel,
    private val methodName: String
) : CustomOSMLocationManager(mapView.context) {

    override val onMove: (IGeoPoint) -> Unit
        get() = { geoPoint ->
            mapView.controller.animateTo(geoPoint)
        }
    override val onUpdate: () -> Unit
        get() = {
            mapView.postInvalidate()
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
    override var enableAutoStop = true

    override var mIsFollowing: Boolean = false


    override var mIsLocationEnabled: Boolean = false
    var useDirectionMarker = false
    override var currentLocation: Location? = null

    override var mGeoPoint: GeoPoint? = GeoPoint(0.0, 0.0)

    private val mHandler: Handler = Handler(Looper.getMainLooper())


    private var mHandlerToken = Object()

    override var controlMapFromOutSide = false

    init {
        mPaint.isFilterBitmap = true
        mPersonBitmap = ResourcesCompat.getDrawable(
            context.resources, R.drawable.ic_location_on_red_24dp, context.theme
        )?.toBitmap()
        mDirectionArrowBitmap = ResourcesCompat.getDrawable(
            context.resources, R.drawable.baseline_navigation_24, context.theme
        )?.toBitmap()

        provider.locationUpdateMinTime = 15000L
        provider.locationUpdateMinDistance = 1.5f
    }

    private fun setLocation(location: Location) {
        currentLocation = location
        mGeoPoint = location.toGeoPoint()
        if (mIsFollowing) {
            onMove(mGeoPoint!!)
        } else {
            onUpdate()
        }
    }

    override fun enableMyLocation() {

        mIsLocationEnabled = provider.startLocationProvider(this)
        // set initial location when enabled
        if (mIsLocationEnabled) {
            provider.lastKnownLocation?.let { location ->
                setLocation(location)
            }
        }
        // Update the screen to see changes take effect
        onUpdate()
    }

    private fun enableFollowLocation() {
        mIsFollowing = true
        // set initial location when enabled
        if (mIsLocationEnabled && provider.lastKnownLocation != null) {
            val location: Location = provider.lastKnownLocation
            setLocation(location)
        }
        onUpdate()

    }

    override fun startLocationUpdating() {
        enableMyLocation()
        controlMapFromOutSide = true
    }

    override fun stopLocationUpdating() {
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

    override fun onStopLocation() {
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
        if (mIsLocationEnabled) enableMyLocation()
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

        if (onChangedLocationCallback != null) {
            onChangedLocationCallback!!(mGeoPoint!!, currentLocation!!.bearing.toDouble())
        }

        if (location != null) {
            mHandler.postAtTime(object : Runnable {
                override fun run() {/*
                     * if we call startLocationUpdating,we will not control map from here
                     *
                     */
                    if (!controlMapFromOutSide) {
                        setLocation(location)
                    }
                    sendLocation()
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

    override fun toggleFollow(enableStop: Boolean) {
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

    override fun disableFollowLocation() {
        if (mapView.controller != null) mapView.controller.stopAnimation(false)
        mIsFollowing = false
    }


    override fun sendLocation() {
        currentLocation?.let { location ->
            methodChannel.invokeMethod(methodName, location.toGeoPoint().toHashMap().apply {
                put("heading", location.bearing.toDouble())
            })
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

    override fun setMarkerIcon(personIcon: Bitmap?, directionIcon: Bitmap?) {

        when {
            personIcon != null && directionIcon != null -> {
                mPersonBitmap = personIcon
                mDirectionArrowBitmap = directionIcon
                setDirectionAnchor(.5f, .5f)
                setPersonAnchor(
                    .5f, .1f
                )
            }

            personIcon != null -> {
                mPersonBitmap = personIcon
                setPersonAnchor(
                    .5f, .1f
                )
            }
        }
    }

    private fun drawPerson(canvas: Canvas) {

        canvas.save()
        canvas.rotate(
            -mapView.mapOrientation, mDrawPixel.x.toFloat(), mDrawPixel.y.toFloat()
        )

        canvas.drawBitmap(
            mPersonBitmap!!,
            mDrawPixel.x.toFloat() - mPersonHotspot.x,
            mDrawPixel.y.toFloat() - mPersonHotspot.y,
            mPaint
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
            mDirectionArrowBitmap!!,
            mDrawPixel.x.toFloat() - mDirectionArrowCenterX,
            mDrawPixel.y.toFloat() - mDirectionArrowCenterY,
            mPaint
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
            mPersonBitmap!!.getWidth() * pHorizontal, mPersonBitmap!!.getHeight() * pVertical
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
            if (runnable != null) {
                mRunOnFirstFix.addLast(runnable)
            }
            false
        }
    }


    override fun onSnapToItem(x: Int, y: Int, snapPoint: Point?, mapView: IMapView?): Boolean {
        return false
    }
}
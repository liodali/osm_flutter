package hamza.dali.flutter_osm_plugin

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.SharedPreferences
import android.graphics.*
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.FrameLayout
import android.widget.LinearLayout
import androidx.core.content.ContextCompat
import androidx.core.content.res.ResourcesCompat
import androidx.core.graphics.BlendModeColorFilterCompat
import androidx.core.graphics.BlendModeCompat
import androidx.core.graphics.drawable.toBitmap
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.coroutineScope
import androidx.preference.PreferenceManager
import com.squareup.picasso.Callback
import com.squareup.picasso.Picasso
import com.squareup.picasso.Target
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.CREATED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.DESTROYED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.PAUSED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.STARTED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.STOPPED
import hamza.dali.flutter_osm_plugin.utilities.FlutterPickerViewOverlay
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding.OnSaveInstanceStateListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.platform.PlatformView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers.Default
import kotlinx.coroutines.Dispatchers.Main
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.osmdroid.bonuspack.routing.OSRMRoadManager
import org.osmdroid.bonuspack.routing.RoadManager
import org.osmdroid.bonuspack.utils.PolylineEncoder
import org.osmdroid.config.Configuration
import org.osmdroid.events.MapEventsReceiver
import org.osmdroid.events.MapListener
import org.osmdroid.events.ScrollEvent
import org.osmdroid.events.ZoomEvent
import org.osmdroid.tileprovider.MapTileProviderBasic
import org.osmdroid.tileprovider.tilesource.TileSourceFactory.MAPNIK
import org.osmdroid.tileprovider.util.SimpleInvalidationHandler
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.CustomZoomButtonsController
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.*
import org.osmdroid.views.overlay.mylocation.GpsMyLocationProvider
import org.osmdroid.views.overlay.mylocation.MyLocationNewOverlay
import kotlin.collections.component1
import kotlin.collections.component2
import kotlin.collections.set


fun GeoPoint.toHashMap(): HashMap<String, Double> {
    return HashMap<String, Double>().apply {
        this[Constants.latLabel] = latitude
        this[Constants.lonLabel] = longitude
    }

}

fun GeoPoint.eq(other: GeoPoint): Boolean {
    return this.latitude == other.latitude && this.longitude == other.longitude
}

fun HashMap<String, Double>.toGeoPoint(): GeoPoint {
    if (this.keys.contains("lat") && this.keys.contains("lon")) {
        return GeoPoint(this["lat"]!!, this["lon"]!!)
    }
    throw IllegalArgumentException("cannot map this hashMap to GeoPoint")

}

fun FlutterOsmView.configZoomMap(call: MethodCall, result: MethodChannel.Result) {
    val args = call.arguments as HashMap<String, Any>
    this.map?.minZoomLevel = (args["minZoomLevel"] as Double)
    this.map?.maxZoomLevel = (args["maxZoomLevel"] as Double)
    stepZoom = args["stepZoom"] as Double
    initZoom = args["initZoom"] as Double


    result.success(200)
}

fun FlutterOsmView.getZoom(result: MethodChannel.Result) {
    try {
        result.success(this.map!!.zoomLevelDouble)
    } catch (e: Exception) {
        result.error("404", e.stackTraceToString(), null)
    }

}

class FlutterOsmView(
        private val context: Context?,
        private val binaryMessenger: BinaryMessenger,
        private val id: Int,//viewId
        private var application: Application?,
        private var activity: Activity?,
        lifecycle: Lifecycle?,

        ) :
        DefaultLifecycleObserver,
        OnSaveInstanceStateListener,
        PlatformView,
        MethodCallHandler {

    internal var map: MapView? = null
    private var locationNewOverlay: MyLocationNewOverlay? = null
    private var customMarkerIcon: Bitmap? = null
    private var customPersonMarkerIcon: Bitmap? = null
    private var customArrowMarkerIcon: Bitmap? = null
    private var customPickerMarkerIcon: Bitmap? = null
    private var staticMarkerIcon: HashMap<String, Bitmap> = HashMap()
    private val customRoadMarkerIcon = HashMap<String, Bitmap>()
    private val staticPoints: HashMap<String, MutableList<GeoPoint>> = HashMap()
    private var homeMarker: FlutterMarker? = null
    private val folderStaticPosition: FolderOverlay by lazy {
        FolderOverlay()
    }
    private val folderShape: FolderOverlay by lazy {
        FolderOverlay().apply {
            name = Constants.shapesNames
        }
    }
    private val folderCircles: FolderOverlay by lazy {
        FolderOverlay().apply {
            name = Constants.circlesNames
        }
    }
    private val folderRect: FolderOverlay by lazy {
        FolderOverlay().apply {
            name = Constants.regionNames
        }
    }
    private val folderRoad: FolderOverlay by lazy {
        FolderOverlay().apply {
            this.name = Constants.roadName
        }
    }

    private var flutterRoad: FlutterRoad? = null
    private var job: Job? = null
    private var jobFlow: Job? = null
    private var scope: CoroutineScope? = null


    private lateinit var methodChannel: MethodChannel


    private val provider: GpsMyLocationProvider by lazy {
        GpsMyLocationProvider(application)
    }

    private var mapEventsOverlay: MapEventsOverlay? = null


    private var roadManager: OSRMRoadManager? = null
    private var roadColor: Int? = null
    internal var stepZoom = Constants.stepZoom
    internal var initZoom = 10.0
    private var isTracking = false
    private var isEnabled = false
    private var visibilityInfoWindow = false

    private val boundingWorldBox: BoundingBox by lazy {
        BoundingBox(85.0, 180.0, -85.0, -180.0)
    }

    private val staticOverlayListener by lazy {
        MapEventsOverlay(object : MapEventsReceiver {
            override fun singleTapConfirmedHelper(p: GeoPoint?): Boolean {

                methodChannel.invokeMethod("receiveSinglePress", p!!.toHashMap())

                return true
            }

            override fun longPressHelper(p: GeoPoint?): Boolean {

                methodChannel.invokeMethod("receiveLongPress", p!!.toHashMap())

                return true

            }

        })
    }


    private var mainLinearLayout: FrameLayout = FrameLayout(context!!).apply {
        this.layoutParams =
                MapView.LayoutParams(FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
    }
    private var markerSelectionPicker: FlutterPickerViewOverlay? = null

    init {
        lifecycle?.addObserver(this)

    }


    private fun initMap() {


        map = MapView(context).also {
            it.layoutParams = MapView.LayoutParams(
                    LinearLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT)
            )
            it.isTilesScaledToDpi = true
            it.setMultiTouchControls(true)
            it.setTileSource(MAPNIK)
            it.isVerticalMapRepetitionEnabled = false
            it.isHorizontalMapRepetitionEnabled = false
            it.setScrollableAreaLimitDouble(boundingWorldBox)
            it.setScrollableAreaLimitLatitude(
                    MapView.getTileSystem().maxLatitude,
                    MapView.getTileSystem().minLatitude,
                    0
            );
            it.zoomController.setVisibility(CustomZoomButtonsController.Visibility.NEVER)
            //
            it.minZoomLevel = 2.0
            it.controller.setZoom(2.0)
            it.controller.setCenter(GeoPoint(0.0, 0.0))
        }

        map?.addMapListener(object : MapListener {
            override fun onScroll(event: ScrollEvent?): Boolean {
                return true
            }

            override fun onZoom(event: ZoomEvent?): Boolean {
                if (event!!.zoomLevel < Constants.zoomStaticPosition) {
                    val rect = Rect()
                    map?.getDrawingRect(rect)
                    map?.overlays?.remove(folderStaticPosition)
                } else if (markerSelectionPicker == null) {
                    if (map != null && !map!!.overlays.contains(folderStaticPosition)) {
                        map!!.overlays.add(folderStaticPosition)
                    }
                }
                return true
            }
        })
        map?.overlays?.add(0, staticOverlayListener)


//        map!!.addOnFirstLayoutListener { v, left, top, right, bottom ->
//        methodChannel.invokeMethod("map#init", true)
//        }
        mainLinearLayout.addView(map)


    }


    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {

                "use#visiblityInfoWindow" -> {
                    visibilityInfoWindow = call.arguments as Boolean
                    result.success(null)
                }
                "config#Zoom" -> {
                    configZoomMap(call = call, result = result)
                }
                "Zoom" -> {
                    setZoom(call, result)
                }
                "get#Zoom" -> {
                    getZoom(result)
                }
                "change#stepZoom" -> {
                    stepZoom = call.arguments as Double
                    result.success(null)
                }
                "currentLocation" -> {
                    enableMyLocation(result)
                }

                "showZoomController" -> {
                    val isZoomControllerVisible = call.arguments as Boolean
                    val visibility = if (isZoomControllerVisible) {
                        CustomZoomButtonsController.Visibility.SHOW_AND_FADEOUT
                    } else
                        CustomZoomButtonsController.Visibility.NEVER
                    map?.zoomController?.setVisibility(visibility)
                    result.success(null)
                }

                "initMap" -> {
                    initPosition(call, result)
                }
                "limitArea" -> {
                    limitCameraArea(call, result)
                }
                "remove#limitArea" -> {
                    removeLimitCameraArea(call, result)

                }
                "changePosition" -> {
                    changePosition(call, result)
                }
                "trackMe" -> {
                    trackUserLocation(call, result)
                }
                "deactivateTrackMe" -> {
                    deactivateTrackMe(call, result)
                }
                "user#position" -> {
                    if (locationNewOverlay == null) {
                        locationNewOverlay = MyLocationNewOverlay(provider, map)
                    }
                    locationNewOverlay?.let {
                        if (!it.isMyLocationEnabled) {
                            it.enableMyLocation()
                        }
                        currentUserPosition(call, result)
                    } ?: result.error("400", "Opps!error locationOverlay is NULL", "")
                }

                "user#pickPosition" -> {
                    pickPosition(call, result)
                }
                "goto#position" -> {
                    goToSpecificPosition(call, result)
                }
                "user#removeMarkerPosition" -> {
                    removePosition(call, result)
                }
                "user#removeroad" -> {
                    if (folderRoad.items.isNotEmpty()) {
                        folderRoad.items.clear()
                        map?.invalidate()
                    }
                    result.success(null)

                }
                "road" -> {
                    drawRoad(call, result)
                }
                "marker#icon" -> {
                    changeIcon(call, result)
                }
                "road#color" -> {
                    setRoadColor(call, result)
                }
                "drawRoad#manually" -> {
                    drawRoadManually(call, result)
                }
                "road#markers" -> {
                    setRoadMaker(call, result)
                }
                "staticPosition" -> {
                    staticPosition(call, result)
                }
                "staticPosition#IconMarker" -> {
                    staticPositionIconMaker(call, result)
                }
                "draw#circle" -> {
                    drawCircle(call, result)
                }
                "remove#circle" -> {
                    removeCircle(call, result)
                }
                "draw#rect" -> {
                    drawRect(call, result)
                }
                "remove#rect" -> {
                    removeRect(call, result)
                }
                "clear#shapes" -> {
                    folderCircles.items.clear()
                    folderRect.items.clear()
                    map?.invalidate()
                    result.success(null)

                }
                "advancedPicker#marker#icon" -> {
                    setCustomAdvancedPickerMarker(
                            call = call,
                            result = result,
                    )
                }
                "advanced#selection" -> {
                    startAdvancedSelection(call)
                    result.success(null)
                }
                "get#position#advanced#selection" -> {
                    confirmAdvancedSelection(result)
                }
                "confirm#advanced#selection" -> {
                    confirmAdvancedSelection(result, isFinished = true)
                }

                "cancel#advanced#selection" -> {
                    cancelAdvancedSelection()
                    result.success(null)
                }
                "map#orientation" -> {
                    mapOrientation(call, result)
                }
                "user#locationMarkers" -> {
                    changeLocationMarkers(call, result)
                }
                "add#Marker" -> {
                    addMarkerManually(call, result)
                }
                else -> {
                    result.notImplemented()
                }
            }

        } catch (e: Exception) {
            Log.e(e.cause.toString(), e.stackTraceToString())
            result.error("404", e.message, e.stackTraceToString())
        }
    }

    private fun setZoom(methodCall: MethodCall, result: MethodChannel.Result) {
        val args = methodCall.arguments as HashMap<String, Any>
        when (args.containsKey("stepZoom")) {
            true -> {
                var zoomInput = args["stepZoom"] as Double
                if (zoomInput == 0.0) {
                    zoomInput = stepZoom
                } else if (zoomInput == -1.0) {
                    zoomInput = -stepZoom
                }
                val zoom = map!!.zoomLevelDouble + zoomInput
                map!!.controller.setZoom(zoom)
            }
            false -> {
                if (args.containsKey("zoomLevel")) {
                    val level = args["zoomLevel"] as Double
                    map!!.controller.setZoom(level)
                }

            }
        }

        result.success(null)
    }

    private fun initPosition(methodCall: MethodCall, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val args = methodCall.arguments!! as HashMap<String, Double>
        val geoPoint = GeoPoint(args["lat"]!!, args["lon"]!!)
        val zoom = initZoom
        //homeMarker = addMarker(geoPoint, zoom, null)

        when (map!!.mapCenter.latitude == 0.0 && map!!.mapCenter.longitude == 0.0) {
            true -> map!!.controller.animateTo(geoPoint, zoom, 500)
            false -> map!!.controller.setCenter(geoPoint)

        }


        methodChannel.invokeMethod("map#init", true)
        result.success(null)
    }

    private fun changePosition(methodCall: MethodCall, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val args = methodCall.arguments!! as HashMap<String, Double>
        if (homeMarker != null) {
            map!!.overlays.remove(homeMarker)
        }
        //map!!.overlays.clear()
        val geoPoint = GeoPoint(args["lat"]!!, args["lon"]!!)
        val zoom = when (map!!.zoomLevelDouble) {
            0.0 -> initZoom
            else -> map!!.zoomLevelDouble
        }
        homeMarker = addMarker(geoPoint, zoom, null)

        result.success(null)
    }

    private fun addMarker(
            geoPoint: GeoPoint,
            zoom: Double,
            color: Int? = null,
            dynamicMarkerBitmap: Drawable? = null,
            imageURL: String? = null,
            animateTo: Boolean = true,
    ): FlutterMarker {
        map!!.controller.setZoom(zoom)
        if (animateTo)
            map!!.controller.animateTo(geoPoint)
        val marker: FlutterMarker = createMarker(geoPoint, color) as FlutterMarker
        when {
            dynamicMarkerBitmap != null -> {
                marker.icon = dynamicMarkerBitmap
                map!!.overlays.add(marker)

            }
            imageURL != null && imageURL.isNotEmpty() -> {
                Picasso.get()
                        .load(imageURL)
                        .fetch(object : Callback {
                            override fun onSuccess() {
                                Picasso.get()
                                        .load(imageURL)
                                        .into(object : Target {
                                            override fun onBitmapLoaded(
                                                    bitmapMarker: Bitmap?,
                                                    from: Picasso.LoadedFrom?
                                            ) {

                                                marker.icon =
                                                        BitmapDrawable(activity!!.resources, bitmapMarker)
                                                map!!.overlays.add(marker)

                                            }

                                            override fun onBitmapFailed(
                                                    e: java.lang.Exception?,
                                                    errorDrawable: Drawable?
                                            ) {
                                                marker.icon = ContextCompat.getDrawable(
                                                        context!!,
                                                        R.drawable.ic_location_on_red_24dp
                                                )
                                                map!!.overlays.add(marker)

                                            }

                                            override fun onPrepareLoad(placeHolderDrawable: Drawable?) {
                                                // marker.icon = ContextCompat.getDrawable(context!!, R.drawable.ic_location_on_red_24dp)
                                            }

                                        })
                            }

                            override fun onError(e: java.lang.Exception?) {
                                TODO("Not yet implemented")
                            }

                        })


            }
            else -> map!!.overlays.add(marker)

        }

        return marker
    }

    private fun createMarker(geoPoint: GeoPoint, color: Int?, icon: Bitmap? = null): Marker {
        val marker = FlutterMarker(application!!, map!!, geoPoint)
        marker.visibilityInfoWindow(visibilityInfoWindow)
//        marker.longPress = object : LongClickHandler {
//            override fun invoke(marker: Marker): Boolean {
//                map!!.overlays.remove(marker)
//                map!!.invalidate()
//                return true
//            }
//        }
        val iconDrawable: Drawable = getDefaultIconDrawable(color, icon = icon)
        //marker.setPosition(geoPoint);
        marker.icon = iconDrawable
        //marker.setInfoWindow(new FlutterInfoWindow(creatWindowInfoView(),map!!,geoPoint));
        marker.position = geoPoint
        return marker
    }

    private fun getDefaultIconDrawable(color: Int?, icon: Bitmap? = null): Drawable {
        val iconDrawable: Drawable
        if (icon != null) {
            iconDrawable = BitmapDrawable(activity!!.resources, icon)
            if (color != null) iconDrawable.setColorFilter(
                    BlendModeColorFilterCompat.createBlendModeColorFilterCompat(
                            color,
                            BlendModeCompat.SRC_OVER
                    )
            )
        } else if (customMarkerIcon != null) {
            iconDrawable = BitmapDrawable(activity!!.resources, customMarkerIcon)
            if (color != null) iconDrawable.setColorFilter(
                    BlendModeColorFilterCompat.createBlendModeColorFilterCompat(
                            color,
                            BlendModeCompat.SRC_OVER
                    )
            )
        } else {
            iconDrawable =
                    ContextCompat.getDrawable(activity!!, R.drawable.ic_location_on_red_24dp)!!
        }
        return iconDrawable
    }

    private fun enableMyLocation(result: MethodChannel.Result) {

        if (markerSelectionPicker != null) {
            mainLinearLayout.removeView(markerSelectionPicker)
            map!!.overlays.add(folderShape)
            map!!.overlays.add(folderRoad)
            map!!.overlays.add(folderStaticPosition)
            markerSelectionPicker = null
        }

        if (locationNewOverlay == null) {
            locationNewOverlay = MyLocationNewOverlay(provider, map)
        }
        //locationNewOverlay!!.setPersonIcon()
        when (customPersonMarkerIcon != null) {
            true -> {
                when (customArrowMarkerIcon != null) {
                    true -> locationNewOverlay!!.setDirectionArrow(
                            customPersonMarkerIcon,
                            customArrowMarkerIcon
                    )
                    false -> locationNewOverlay!!.setPersonIcon(customPersonMarkerIcon)
                }

            }
            false -> {
                val defaultPerson = ContextCompat
                        .getDrawable(
                                application!!,
                                R.drawable.ic_location_on_red_24dp
                        )!!.toBitmap()
                when (customArrowMarkerIcon != null) {
                    true -> {
                        locationNewOverlay!!.setDirectionArrow(
                                defaultPerson,
                                customArrowMarkerIcon
                        )
                        locationNewOverlay!!.setPersonHotspot(0f, 0f)

                    }
                    false -> locationNewOverlay!!.setPersonIcon(defaultPerson)
                }
                val mScale = map!!.context.resources.displayMetrics.density

                locationNewOverlay!!.setPersonHotspot(
                        mScale * (defaultPerson.width / 4f) + 0.5f,
                        mScale * (defaultPerson.width / 3f) + 0.5f,
                )

            }
        }
        if (customPersonMarkerIcon != null) {
            val mScale = map!!.context.resources.displayMetrics.density

            locationNewOverlay!!.setPersonHotspot(
                    mScale * (customPersonMarkerIcon!!.width / 4f) + 0.5f,
                    mScale * (customPersonMarkerIcon!!.width / 3f) + 0.5f,
            )

        }
        locationNewOverlay?.let { location ->
            if (!location.isMyLocationEnabled) {
                isEnabled = true
                location.enableMyLocation()
            }
            location.runOnFirstFix {
                scope!!.launch(Main) {
                    val currentPosition = GeoPoint(location.lastFix)
                    map!!.controller.animateTo(currentPosition)
                }
            }
        }
        if (!map!!.overlays.contains(locationNewOverlay)) {
            map!!.overlays.add(locationNewOverlay)
        }
        result.success(isEnabled)
    }

    private fun onChangedLocation(locationOverlay: MyLocationNewOverlay) {
        //
        provider.startLocationProvider { location, source ->
            locationOverlay.onLocationChanged(location, source)
            val geoPMap = GeoPoint(location).toHashMap()
            methodChannel.invokeMethod("receiveUserLocation", geoPMap)

            //eventLocationSink?.success(geoPMap)
        }
    }


    private fun addMarkerManually(call: MethodCall, result: MethodChannel.Result) {
        var args = call.arguments as HashMap<String, Any>
        var bitmap = customMarkerIcon
        if (args.containsKey("icon")) {
            bitmap = getBitmap(args["icon"] as ByteArray)
        }
        val point = (args["point"] as HashMap<String, Double>).toGeoPoint()


        val marker = addMarker(
                point,
                dynamicMarkerBitmap = getDefaultIconDrawable(null, icon = bitmap),
                zoom = map!!.zoomLevelDouble,
                animateTo = false
        )

        map!!.overlays.add(marker)
        result.success(null)

    }

    private fun changeLocationMarkers(call: MethodCall, result: MethodChannel.Result) {
        val args: HashMap<String, Any> = call.arguments as HashMap<String, Any>
        try {
            customPersonMarkerIcon = getBitmap((args["personIcon"] as ByteArray))
            customArrowMarkerIcon = getBitmap((args["arrowDirectionIcon"] as ByteArray))
            result.success(null)
        } catch (e: Exception) {
            e.printStackTrace()
            result.success(e.message)

        }
    }

    private fun removeLimitCameraArea(call: MethodCall, result: MethodChannel.Result) {
        map!!.setScrollableAreaLimitDouble(boundingWorldBox)
        result.success(200)
    }

    private fun limitCameraArea(call: MethodCall, result: MethodChannel.Result) {
        val list = call.arguments as List<Double>
        map!!.setScrollableAreaLimitDouble(
                BoundingBox(
                        list[0], list[1], list[2], list[3]
                )
        )
        result.success(200)
    }

    private fun mapOrientation(call: MethodCall, result: MethodChannel.Result) {
        //map!!.mapOrientation = (call.arguments as Double?)?.toFloat() ?: 0f
        map!!.controller.animateTo(
                map!!.mapCenter,
                map!!.zoomLevelDouble,
                null,
                (call.arguments as Double?)?.toFloat() ?: 0f
        )
        map!!.invalidate()
        result.success(null)
    }


    private fun drawRoadManually(call: MethodCall, result: MethodChannel.Result) {
        val args: HashMap<String, Any> = call.arguments as HashMap<String, Any>

        val encodedWayPoints = (args["road"] as String)
        val colorRoad = (args["roadColor"] as List<Int>)
        val color = Color.rgb(colorRoad.first(), colorRoad.last(), colorRoad[1])
        val widthRoad = (args["roadWidth"] as Double)

        if (!map!!.overlays.contains(folderRoad)) {
            map!!.overlays.add(folderRoad)
        } else {
            folderRoad.items.clear()
        }

        val route = PolylineEncoder.decode(encodedWayPoints, 10, false)
        val polyLine = Polyline(map!!)
        polyLine.setPoints(route)
        polyLine.outlinePaint.color = color
        polyLine.outlinePaint.strokeWidth = widthRoad.toFloat()

        folderRoad.items.add(polyLine)


        /*
            flutterRoad = FlutterRoad(application!!, map!!)

            flutterRoad?.let {
                it.markersIcons = customRoadMarkerIcon
                polyLine.outlinePaint.strokeWidth = 5.0f
                it.road = polyLine
                // if (it.start != null)
//                folderRoad.items.add(it.start.apply {
//                    this.visibilityInfoWindow(visibilityInfoWindow)
//                })
//                //  if (it.end != null)
//                folderRoad.items.add(it.end.apply {
//                    this.visibilityInfoWindow(visibilityInfoWindow)
//                })
            }*/

        map!!.invalidate()
        result.success(null)
    }

    private fun trackUserLocation(call: MethodCall, result: MethodChannel.Result) {
        try {
            locationNewOverlay?.let { locationOverlay ->
                when {
                    !locationOverlay.isFollowLocationEnabled -> {
                        isTracking = true
                        locationOverlay.enableFollowLocation()
                        onChangedLocation(locationOverlay)
                        result.success(true)
                    }
                    else -> result.success(null)

                }


            }
        } catch (e: Exception) {
            result.error("400", e.stackTraceToString(), "")
        }
    }

    private fun goToSpecificPosition(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments!! as HashMap<String, *>
        val geoPoint = GeoPoint(args["lat"]!! as Double, args["lon"]!! as Double)
        //map!!.controller.zoomTo(defaultZoom)
        map!!.controller.animateTo(geoPoint)
        result.success(null)
    }


    private fun drawRect(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments!! as HashMap<String, *>
        val geoPoint = GeoPoint(args["lat"]!! as Double, args["lon"]!! as Double)
        val key = args["key"] as String
        val colors = args["color"] as List<Double>
        val distance = (args["distance"] as Double)
        val stokeWidth = (args["stokeWidth"] as Double).toFloat()
        val color = Color.rgb(colors[0].toInt(), colors[1].toInt(), colors[2].toInt())

        val region: List<GeoPoint> =
                Polygon.pointsAsRect(geoPoint, distance, distance).toList() as List<GeoPoint>
        val p = Polygon(map!!)
        p.id = key
        p.points = region
        p.fillPaint.color = color
        p.fillPaint.style = Paint.Style.FILL
        p.fillPaint.alpha = 50
        p.outlinePaint.strokeWidth = stokeWidth
        p.outlinePaint.color = color
        p.setOnClickListener { polygon, _, _ ->
            polygon.closeInfoWindow()
            false
        }

        folderRect.items.removeAll {
            it is Polygon && it.id == key
        }
        folderRect.items.add(p)
        if (!map!!.overlays.contains(folderShape)) {
            map!!.overlays.add(folderShape)
            if (!folderShape.items.contains(folderRect)) {
                folderShape.add(folderRect)
            }
        }
        map!!.invalidate()
        result.success(null)
    }

    private fun removeRect(call: MethodCall, result: MethodChannel.Result) {
        val id = call.arguments as String?
        if (id != null)
            folderRect.items.removeAll {
                (it as Polygon).id == id
            }
        else {
            folderRect.items.clear()
        }
        map!!.invalidate()
        result.success(null)
    }

    private fun confirmAdvancedSelection(
            result: MethodChannel.Result,
            isFinished: Boolean = false
    ) {
        if (markerSelectionPicker != null) {
            //markerSelectionPicker!!.callOnClick()
            mainLinearLayout.removeView(markerSelectionPicker)
            val position = map!!.mapCenter as GeoPoint
            if (isFinished) {
                addMarker(position, map!!.zoomLevelDouble, null)
                markerSelectionPicker = null
                map!!.overlays.add(folderShape)
                map!!.overlays.add(folderRoad)
                map!!.overlays.add(folderStaticPosition)
                if (isTracking) {
                    isTracking = false
                    isEnabled = false
                }
            }
            result.success(position.toHashMap())
        }

    }

    private fun cancelAdvancedSelection() {
        if (markerSelectionPicker != null) {
            mainLinearLayout.removeView(markerSelectionPicker)
            if (isTracking) {
                try {
                    locationNewOverlay?.let { locationOverlay ->
                        if (!locationOverlay.isFollowLocationEnabled) {
                            isTracking = true
                            locationOverlay.enableFollowLocation()
                            onChangedLocation(locationOverlay)
                        }
                    }
                } catch (e: Exception) {
                }
            }
            map!!.overlays.add(folderShape)
            map!!.overlays.add(folderRoad)
            map!!.overlays.add(folderStaticPosition)
            markerSelectionPicker = null
        }
    }

    private fun startAdvancedSelection(call: MethodCall) {
        map!!.overlays.clear()
        if (isTracking) {
            try {
                locationNewOverlay?.let { locationOverlay ->
                    if (locationOverlay.isFollowLocationEnabled) {
                        locationOverlay.disableFollowLocation()
                        locationOverlay.disableMyLocation()
                        provider.stopLocationProvider()
                    }
                }
            } catch (e: Exception) {
            }
        }
        map!!.invalidate()
        if (markerSelectionPicker != null) {
            mainLinearLayout.removeView(markerSelectionPicker)
        }
        val point = Point()
        map!!.projection.toPixels(map!!.mapCenter, point)
        val bitmap: Bitmap = customPickerMarkerIcon
                ?: ResourcesCompat.getDrawable(
                        context!!.resources,
                        R.drawable.ic_location_on_red_24dp,
                        null
                )!!.toBitmap(
                        64,
                        64
                ) //BitmapFactory.decodeResource(, R.drawable.ic_location_on_red_24dp)?:customMarkerIcon

        markerSelectionPicker = FlutterPickerViewOverlay(
                bitmap, context!!, point, customPickerMarkerIcon != null
        )
        val params = FrameLayout.LayoutParams(
                WRAP_CONTENT,
                WRAP_CONTENT, Gravity.CENTER
        )
        markerSelectionPicker!!.layoutParams = params
        mainLinearLayout.addView(markerSelectionPicker)

    }

    private fun deactivateTrackMe(call: MethodCall, result: MethodChannel.Result) {
        isTracking = false
        isEnabled = false
        try {
            locationNewOverlay?.let { locationOverlay ->
                when {
                    locationOverlay.isFollowLocationEnabled -> {
                        locationOverlay.disableFollowLocation()
                        locationOverlay.disableMyLocation()
                        provider.stopLocationProvider()
                    }
                    else -> result.success(null)

                }

            }
        } catch (e: Exception) {
            result.error("400", e.stackTraceToString(), "")
        }
        result.success(false)
    }

    private fun removeCircle(call: MethodCall, result: MethodChannel.Result) {
        val id = call.arguments as String?
        if (id != null)
            folderCircles.items.removeAll {
                (it as Polygon).id == id
            }
        else {
            folderCircles.items.clear()
        }
        map!!.invalidate()
        result.success(null)
    }

    private fun drawCircle(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments!! as HashMap<String, *>
        val geoPoint = GeoPoint(args["lat"]!! as Double, args["lon"]!! as Double)
        val key = args["key"] as String
        val colors = args["color"] as List<Double>
        val radius = (args["radius"] as Double)
        val stokeWidth = (args["stokeWidth"] as Double).toFloat()
        val color = Color.rgb(colors[0].toInt(), colors[2].toInt(), colors[1].toInt())

        val circle: List<GeoPoint> = Polygon.pointsAsCircle(geoPoint, radius)
        val p = Polygon(map!!)
        p.id = key
        p.points = circle
        p.fillPaint.color = color
        p.fillPaint.style = Paint.Style.FILL
        p.fillPaint.alpha = 50
        p.outlinePaint.strokeWidth = stokeWidth
        p.outlinePaint.color = color
        p.setOnClickListener { polygon, _, _ ->
            polygon.closeInfoWindow()
            false
        }

        folderCircles.items.removeAll {
            it is Polygon && it.id == key
        }
        folderCircles.items.add(p)
        if (!map!!.overlays.contains(folderShape)) {
            map!!.overlays.add(folderShape)
            if (!folderShape.items.contains(folderCircles)) {
                folderShape.add(folderCircles)
            }
        }
        map!!.invalidate()
        result.success(null)
    }

    private fun drawRoad(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments!! as HashMap<String, Any>

        val showPoiMarker = args["showMarker"] as Boolean
        val meanUrl = when (args["roadType"] as String) {
            "car" -> OSRMRoadManager.MEAN_BY_CAR
            "bike" -> OSRMRoadManager.MEAN_BY_BIKE
            "foot" -> OSRMRoadManager.MEAN_BY_FOOT
            else -> OSRMRoadManager.MEAN_BY_CAR
        }
        val listPointsArgs = args["wayPoints"] as List<HashMap<String, Double>>

        val listInterestPoints: List<GeoPoint> = when (args.containsKey("middlePoints")) {
            true -> args["middlePoints"] as List<HashMap<String, Double>>
            false -> emptyList()
        }.map { g ->
            GeoPoint(g["lat"]!!, g["lon"]!!)
        }.toList()

        val colorRoad: Int? = when (args.containsKey("roadColor")) {
            true -> {
                val colors = (args["roadColor"] as List<Int>)
                Color.rgb(colors.first(), colors.last(), colors[1])
            }
            else -> roadColor
        }
        val roadWidth: Float = when (args.containsKey("roadWidth")) {
            true -> (args["roadWidth"] as Double).toFloat()
            else -> 5f
        }
        flutterRoad?.let {
            map!!.overlays.remove(it.road!!)
        }
        if (!map!!.overlays.contains(folderRoad)) {
            map!!.overlays.add(folderRoad)
        } else {
            folderRoad.items.clear()
        }
        map!!.invalidate()

        if (roadManager == null)
            roadManager = OSRMRoadManager(application!!, "json/application")
        roadManager?.let { manager ->
            manager.setMean(meanUrl)

            job = scope?.launch(Default) {
                val wayPoints = listPointsArgs.map {
                    GeoPoint(it["lat"]!!, it["lon"]!!)
                }.toList()
                withContext(Main) {
                    map!!.overlays.removeAll {
                        (it is FlutterMarker && wayPoints.contains(it.position)) ||
                                (it is FlutterMarker && listInterestPoints.contains(it.position))
                    }
                }
                val roadPoints = ArrayList(wayPoints)
                if (listInterestPoints.isNotEmpty()) {
                    roadPoints.addAll(1, listInterestPoints)
                }
                val road = manager.getRoad(roadPoints)
                withContext(Main) {
                    if (road.mRouteHigh.size > 2) {
                        val polyLine = RoadManager.buildRoadOverlay(road)
                        polyLine?.setOnClickListener { _, _, eventPos ->
                            methodChannel.invokeMethod("receiveSinglePress", eventPos?.toHashMap())
                            true
                        }
                        /// set polyline color
                        polyLine.outlinePaint.color = colorRoad ?: Color.GREEN


                        flutterRoad = FlutterRoad(
                                application!!,
                                map!!,
                                interestPoint = if (showPoiMarker) listInterestPoints else emptyList()
                        )

                        flutterRoad?.let { roadF ->
                            roadF.markersIcons = customRoadMarkerIcon
                            polyLine.outlinePaint.strokeWidth = roadWidth

                            roadF.road = polyLine
                            if (showPoiMarker) {
                                // if (it.start != null)
                                folderRoad.items.add(roadF.start.apply {
                                    this.visibilityInfoWindow(visibilityInfoWindow)
                                })
                                //  if (it.end != null)
                                folderRoad.items.add(roadF.end.apply {
                                    this.visibilityInfoWindow(visibilityInfoWindow)
                                })
                                folderRoad.items.addAll(roadF.middlePoints)
                            }

                            folderRoad.items.add(roadF.road!!)
                        }
                        map!!.invalidate()
                    }
                    result.success(HashMap<String, Double>().apply {
                        this["duration"] = road.mDuration
                        this["distance"] = road.mLength
                    })
                }

            }
        }
    }

    private fun staticPositionIconMaker(call: MethodCall, result: MethodChannel.Result) {
        val hashMap: HashMap<String, Any> = call.arguments as HashMap<String, Any>

        try {
            val bitmap = getBitmap((hashMap["bitmap"] as ByteArray))
            staticMarkerIcon[(hashMap["id"] as String)] = bitmap
            result.success(null)
        } catch (e: java.lang.Exception) {
            Log.e("id", hashMap["id"].toString())
            Log.e("err static point marker", e.stackTraceToString())
            result.error("400", "error to getBitmap static Position", "")
            staticMarkerIcon = HashMap()
        }
    }

    private fun staticPosition(call: MethodCall, result: MethodChannel.Result) {
        val map = call.arguments as HashMap<String, Any>
        val id = map["id"] as String?
        val points = map["point"] as MutableList<HashMap<String, Double>>?
        val geoPoints: MutableList<GeoPoint> = emptyList<GeoPoint>().toMutableList()
        val angleGeoPoints: MutableList<Double> = emptyList<Double>().toMutableList()
        for (hashMap in points!!) {
            geoPoints.add(GeoPoint(hashMap["lat"]!!, hashMap["lon"]!!))
            if (hashMap.containsKey("angle"))
                angleGeoPoints.add(hashMap["angle"]!!)
        }
        if (staticPoints.containsKey(id)) {
            Log.e(id, "" + points.size)
            staticPoints[id]?.clear()
            staticPoints[id]?.addAll(geoPoints)
            if (folderStaticPosition.items.isNotEmpty())
                folderStaticPosition.remove(folderStaticPosition.items.first {
                    (it as FolderOverlay).name?.equals(id) == true
                })
        } else {
            staticPoints[id!!] = geoPoints
        }
        showStaticPosition(id!!, angleGeoPoints.toList())
        result.success(null)
    }

    private fun setRoadMaker(call: MethodCall, result: MethodChannel.Result) {
        try {
            val hashMap = call.arguments!! as HashMap<String, ByteArray>
            hashMap.forEach { (key, bytes) ->
                customRoadMarkerIcon[key] = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            }
            result.success(null)
        } catch (e: Exception) {
            Log.d("err", e.stackTraceToString())
            result.error("400", "Opss!Erreur", e.stackTraceToString())
        }
    }

    private fun setRoadColor(call: MethodCall, result: MethodChannel.Result) {
        val argb = call.arguments!! as List<Int>
        roadColor = Color.rgb(argb[0], argb[1], argb[2])
        result.success(null)
    }

    private fun changeIcon(call: MethodCall, result: MethodChannel.Result) {
        try {
            customMarkerIcon = getBitmap(call.arguments as ByteArray)
            //customMarkerIcon.recycle();
            result.success(null)
        } catch (e: Exception) {
            Log.d("err", e.stackTraceToString())
            customMarkerIcon = null
            result.error("500", "Cannot make markerIcon custom", "")
        }
    }

    private fun setCustomAdvancedPickerMarker(call: MethodCall, result: MethodChannel.Result) {
        try {
            customPickerMarkerIcon = getBitmap(call.arguments as ByteArray)
            //customMarkerIcon.recycle();
            result.success(null)
        } catch (e: Exception) {
            Log.d("err", e.stackTraceToString())
            customMarkerIcon = null
            result.error("500", "Cannot make markerIcon custom", "")
        }
    }

    private fun pickPosition(call: MethodCall, result: MethodChannel.Result) {
        //val usingCamera=call.arguments as Boolean

        val args = call.arguments as Map<String, Any>
        val marker: Drawable? = if (args.containsKey("icon")) {
            val bitmap = getBitmap(args["icon"] as ByteArray)
            BitmapDrawable(activity!!.resources, bitmap)
        } else null
        val imageURL: String? = if (args.containsKey("imageURL")) {
            args["imageURL"] as String
        } else null

        if (mapEventsOverlay == null) {
            if (map!!.overlays.first() is MapEventsOverlay)
                map!!.overlays.removeFirst()
            mapEventsOverlay = MapEventsOverlay(object : MapEventsReceiver {
                override fun singleTapConfirmedHelper(p: GeoPoint?): Boolean {

                    addMarker(
                            p!!, map!!.zoomLevelDouble,
                            null,
                            marker,
                            imageURL,
                    )
                    result.success(p.toHashMap())
                    if (mapEventsOverlay != null) {
                        mapEventsOverlay = null
                        map!!.overlays.removeFirst()
                        map!!.overlays.add(0, staticOverlayListener)
                    }
                    return true
                }

                override fun longPressHelper(p: GeoPoint?): Boolean {
                    return true
                }

            })
            if (mapEventsOverlay != null)
                map!!.overlays.add(0, mapEventsOverlay)
        }

    }

    private fun removePosition(call: MethodCall, result: MethodChannel.Result) {
        val geoMap = call.arguments as HashMap<String, Double>
        deleteMarker(geoMap.toGeoPoint())
        result.success(null)
    }

    private fun deleteMarker(geoPoint: GeoPoint) {
        val geoMarkers = map!!.overlays.filterIsInstance<FlutterMarker>().filter { marker ->
            marker.position.eq(geoPoint)
        }
        if (geoMarkers.isNotEmpty()) {
            map!!.overlays.removeAll(geoMarkers)
            map!!.invalidate()
        }

    }

    private fun currentUserPosition(call: MethodCall, result: MethodChannel.Result) {
        locationNewOverlay?.let { locationOverlay ->
            locationOverlay.runOnFirstFix {
                scope!!.launch(Main) {
                    locationOverlay.lastFix?.let { location ->
                        val point = GeoPoint(
                                location.latitude,
                                location.longitude,
                        )
                        locationOverlay.disableMyLocation()
                        result.success(point.toHashMap())
                    } ?: result.error("400", "we cannot get the current position!", "")
                }
            }

        } ?: result.error("400", "we cannot get the current position!", "")
    }

    private fun showStaticPosition(idStaticPosition: String, angles: List<Double> = emptyList()) {

        /* folderStaticPosition.items.retainAll {
             (it as FolderOverlay).name?.equals(idStaticPosition) == true
         }*/


        val overlay = FolderOverlay().apply {
            name = idStaticPosition
        }
        staticPoints[idStaticPosition]?.forEachIndexed { index, geoPoint ->
            val marker = FlutterMarker(application!!, map!!)
            marker.position = geoPoint

            marker.defaultInfoWindow()
            marker.visibilityInfoWindow(visibilityInfoWindow)
            marker.onClickListener = Marker.OnMarkerClickListener { marker, _ ->
                val hashMap = HashMap<String, Double>()
                hashMap["lon"] = marker!!.position.longitude
                hashMap["lat"] = marker.position.latitude
                methodChannel.invokeMethod("receiveGeoPoint", hashMap)
                true
            }
            if (staticMarkerIcon.isNotEmpty() && staticMarkerIcon.containsKey(idStaticPosition)) {
                marker.setIconMaker(
                        null,
                        staticMarkerIcon[idStaticPosition],
                        angle = when (angles.isNotEmpty()) {
                            true -> angles[index]
                            else -> 0.0
                        }
                )
            } else {
                marker.setIconMaker(null, null)
            }
            overlay.add(marker)
        }
        folderStaticPosition.add(overlay)
        if (map!!.zoomLevelDouble > 10.0) {
            if (map!!.overlays.contains(folderStaticPosition)) {
                map!!.overlays.remove(folderStaticPosition)
                map!!.overlays.add(folderStaticPosition)
                map!!.invalidate()
            }
        }

    }


    private fun getBitmap(bytes: ByteArray): Bitmap {
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    }


    override fun getView(): View {
        return mainLinearLayout
    }

    override fun dispose() {
        staticMarkerIcon.clear()
        staticPoints.clear()
        customMarkerIcon = null
        customRoadMarkerIcon.clear()
        mainLinearLayout.removeAllViews()
        map!!.onDetach()
        map = null
    }

    override fun onFlutterViewAttached(flutterView: View) {
        //   map!!.onAttachedToWindow()
        if (map != null) {
            val prefs: SharedPreferences = PreferenceManager.getDefaultSharedPreferences(context)
            Configuration.getInstance()
                    .load(context, PreferenceManager.getDefaultSharedPreferences(context))
//            initMap()
//            map?.forceLayout()
        }

    }


    override fun onFlutterViewDetached() {
        map!!.onDetach()
//        mainLinearLayout.removeAllViews()
//        map!!.onDetach()
//        map = null
    }


    override fun onSaveInstanceState(bundle: Bundle) {
        bundle.putString("center", "${map!!.mapCenter.latitude},${map!!.mapCenter.longitude}")
        bundle.putString("zoom", map!!.zoomLevelDouble.toString())
    }

    override fun onRestoreInstanceState(bundle: Bundle?) {
        Log.d("osm data", bundle?.getString("center") ?: "")
    }

    override fun onCreate(owner: LifecycleOwner) {
        FlutterOsmPlugin.state.set(CREATED)
        methodChannel = MethodChannel(binaryMessenger, "plugins.dali.hamza/osmview_${id}")
        methodChannel.setMethodCallHandler(this)
        //eventChannel = EventChannel(binaryMessenger, "plugins.dali.hamza/osmview_stream_${id}")
        //eventChannel.setStreamHandler(this)
        methodChannel.invokeMethod("map#init", true)

        scope = owner.lifecycle.coroutineScope
        folderStaticPosition.name = Constants.nameFolderStatic

        initMap()
        // map!!.forceLayout()

    }

    override fun onStart(owner: LifecycleOwner) {
        FlutterOsmPlugin.state.set(STARTED)
        Log.e("osm", "osm flutter plugin start")
    }


    override fun onResume(owner: LifecycleOwner) {
        FlutterOsmPlugin.state.set(FlutterOsmPlugin.RESUMED)
        Log.e("osm", "osm flutter plugin resume")
        if (map == null) {
            initMap()
        }
        map?.onResume()
        val tileProvider =
                MapTileProviderBasic(context!!.applicationContext, MAPNIK)
        val mTileRequestCompleteHandler = SimpleInvalidationHandler(map)
        tileProvider.setTileRequestCompleteHandler(mTileRequestCompleteHandler)
        map!!.tileProvider = tileProvider
        reStartFollowLocation()


    }

    override fun onPause(owner: LifecycleOwner) {
        FlutterOsmPlugin.state.set(PAUSED)
        stopFollowLocation()
        val prefs: SharedPreferences = PreferenceManager.getDefaultSharedPreferences(context);
        Configuration.getInstance().save(context, prefs);
        map?.onPause()
        Log.e("osm", "osm flutter plugin pause")

    }

    override fun onStop(owner: LifecycleOwner) {
        FlutterOsmPlugin.state.set(STOPPED)
        job?.let {
            if (it.isActive) {
                it.cancel()
            }
        }
        jobFlow?.let {
            if (it.isActive) {
                it.cancel()
            }
        }
        jobFlow = null
        job = null

    }


    override fun onDestroy(owner: LifecycleOwner) {
        mainLinearLayout.removeAllViews()
        //map!!.onDetach()
        methodChannel.setMethodCallHandler(null)
        //configuration!!.osmdroidTileCache.delete()
        //configuration = null
        //eventChannel.setStreamHandler(null)
        map = null
        FlutterOsmPlugin.state.set(DESTROYED)

    }

    private fun reStartFollowLocation() {
        if (isEnabled || isTracking) {

            if (locationNewOverlay == null) {
                locationNewOverlay = MyLocationNewOverlay(provider, map)
            }

            locationNewOverlay?.also { myLocation ->
                if (isEnabled) {
                    myLocation.enableMyLocation()
                }
                if (isTracking) {
                    myLocation.enableFollowLocation()
                    onChangedLocation(myLocation)
                }

            }


        }
    }

    private fun stopFollowLocation() {
        if (isTracking || isEnabled) {
            locationNewOverlay?.also { myLocation ->

                if (myLocation.isFollowLocationEnabled) {
                    myLocation.disableFollowLocation()
                }
                if (myLocation.isMyLocationEnabled) {
                    myLocation.disableMyLocation()
                    //provider.stopLocationProvider()
                }
                provider.stopLocationProvider()
            }
            locationNewOverlay = null
        }
    }
}
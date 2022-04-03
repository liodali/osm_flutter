package hamza.dali.flutter_osm_plugin

import android.app.Activity
import android.content.*
import android.graphics.*
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.location.LocationManager
import android.location.LocationManager.GPS_PROVIDER
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
import androidx.lifecycle.*
import androidx.preference.PreferenceManager
import com.squareup.picasso.Callback
import com.squareup.picasso.Picasso
import com.squareup.picasso.Target
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.CREATED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.DESTROYED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.PAUSED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.STARTED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.STOPPED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.mapSnapShots
import hamza.dali.flutter_osm_plugin.models.FlutterMarker
import hamza.dali.flutter_osm_plugin.models.FlutterRoad
import hamza.dali.flutter_osm_plugin.models.RoadConfig
import hamza.dali.flutter_osm_plugin.utilities.*
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding.OnSaveInstanceStateListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.platform.PlatformView
import kotlinx.coroutines.*
import kotlinx.coroutines.Dispatchers.Default
import kotlinx.coroutines.Dispatchers.IO
import kotlinx.coroutines.Dispatchers.Main
import org.osmdroid.bonuspack.routing.OSRMRoadManager
import org.osmdroid.bonuspack.routing.RoadManager
import org.osmdroid.bonuspack.utils.PolylineEncoder
import org.osmdroid.config.Configuration
import org.osmdroid.events.MapEventsReceiver
import org.osmdroid.events.MapListener
import org.osmdroid.events.ScrollEvent
import org.osmdroid.events.ZoomEvent
import org.osmdroid.tileprovider.tilesource.TileSourceFactory.MAPNIK
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.CustomZoomButtonsController
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.*
import org.osmdroid.views.overlay.mylocation.GpsMyLocationProvider
import org.osmdroid.views.overlay.mylocation.MyLocationNewOverlay
import java.io.ByteArrayOutputStream
import kotlin.collections.component1
import kotlin.collections.component2
import kotlin.collections.set


typealias VoidCallback = () -> Unit

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
    private val context: Context,
    private val binaryMessenger: BinaryMessenger,
    private val id: Int,//viewId
    private val providerLifecycle: ProviderLifecycle,
    private val keyArgMapSnapShot: String
) :
    LifecycleObserver,
    OnSaveInstanceStateListener,
    PlatformView,
    MethodCallHandler,
    PluginRegistry.ActivityResultListener {


    internal var map: MapView? = null
    private var keyMapSnapshot: String = keyArgMapSnapShot
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
    private val folderMarkers: FolderOverlay by lazy {
        FolderOverlay().apply {
            this.name = Constants.markerNameOverlay
        }
    }

    private var flutterRoad: FlutterRoad? = null
    private var job: Job? = null
    var activity: Activity? = null
    private var scope: CoroutineScope? = null
    private var sendUserLocationToDart: Boolean = false
    private var skipCheckLocation: Boolean = false
    private var resultFlutter: MethodChannel.Result? = null
    private lateinit var methodChannel: MethodChannel


    private val gpsServiceManager: LocationManager by lazy {
        context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    }
    private val checkGPSServiceBroadcast: BroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {

            if (gpsServiceManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                if (sendUserLocationToDart) {
                    locationNewOverlay?.let {
                        if (!it.isMyLocationEnabled) {
                            it.enableMyLocation()
                        }
                        currentUserPosition(resultFlutter!!)
                        sendUserLocationToDart = false
                        resultFlutter = null
                    }
                    sendUserLocationToDart = false
                    resultFlutter = null
                }
            }
        }

    }

    private var provider: GpsMyLocationProvider? = GpsMyLocationProvider(context)

    private var mapEventsOverlay: MapEventsOverlay? = null


    private var roadManager: OSRMRoadManager? = null
    private var roadColor: Int? = null
    internal var stepZoom = Constants.stepZoom
    internal var initZoom = 10.0
    private var isTracking = false
    private var isEnabled = false
    private var visibilityInfoWindow = false

    companion object {
        val boundingWorldBox: BoundingBox =
            BoundingBox(
                85.0,
                180.0,
                -85.0,
                -180.0,
            )
        internal val getUserLocationReqCode = 200
        internal val currentUserLocationReqCode = 201

    }


    fun mapSnapShot(): MapSnapShot {
        if (keyMapSnapshot.isEmpty()) {
            return MapSnapShot()
        }
        if (!mapSnapShots.containsKey(keyMapSnapshot)) {
            mapSnapShots[keyMapSnapshot] = MapSnapShot()
        }
        return mapSnapShots[keyMapSnapshot]!!
    }

    private fun removeCurrentCache() {
        mapSnapShots.remove(keyMapSnapshot)
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


    private val mapListener by lazy {
        object : MapListener {
            override fun onScroll(event: ScrollEvent?): Boolean {
                if (!isTracking && !isEnabled) {
                    val hashMap = HashMap<String, Any?>()
                    hashMap["bounding"] = map?.boundingBox?.toHashMap()
                    hashMap["center"] = (map?.mapCenter as GeoPoint).toHashMap()
                    methodChannel.invokeMethod("receiveRegionIsChanging", hashMap)
                }

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
        }
    }


    private var mainLinearLayout: FrameLayout = FrameLayout(context).apply {
        this.layoutParams =
            FrameLayout.LayoutParams(FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
    }
    private var markerSelectionPicker: FlutterPickerViewOverlay? = null

    init {
        providerLifecycle.getLifecyle()?.addObserver(this)

    }

    private fun initMap() {


        map = MapView(context)

        map!!.layoutParams = MapView.LayoutParams(
            LinearLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT)
        )
        map!!.isTilesScaledToDpi = true
        map!!.setMultiTouchControls(true)
        map!!.setTileSource(MAPNIK)
        map!!.isVerticalMapRepetitionEnabled = false
        map!!.isHorizontalMapRepetitionEnabled = false
        map!!.setScrollableAreaLimitDouble(mapSnapShot().boundingWorld())
        map!!.setScrollableAreaLimitLatitude(
            MapView.getTileSystem().maxLatitude,
            MapView.getTileSystem().minLatitude,
            0
        )
        map!!.zoomController.setVisibility(CustomZoomButtonsController.Visibility.NEVER)
        //
        map!!.minZoomLevel = 2.0
        when (mapSnapShots.containsKey(keyMapSnapshot)) {
            true -> {
                map!!.controller.setCenter(mapSnapShot().centerGeoPoint())
                map!!.controller.setZoom(mapSnapShot().zoomLevel(2.0))
            }
            else -> {
                map!!.controller.setCenter(GeoPoint(0.0, 0.0))
                map!!.controller.setZoom(2.0)
            }
        }

        map!!.addMapListener(mapListener)
        map!!.overlayManager.add(0, staticOverlayListener)
        map!!.overlayManager.add(folderMarkers)

        mainLinearLayout.addView(map)
    }


    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {

                "map#setCache" -> {
                    setCacheMap()
                    result.success(null)
                }
                "map#clearCache#view" -> {
                    mapSnapShot().reset(all = true)
                    result.success(null)
                }
                "map#saveCache#view" -> {
                    saveCacheMap()
                    result.success(null)
                }
                "removeCache" -> {
                    removeCurrentCache()
                    result.success(null)
                }
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
                "zoomToRegion" -> {
                    zoomingMapToBoundingBox(call, result)
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
                "currentLocation" -> {
                    when (gpsServiceManager.isProviderEnabled(GPS_PROVIDER)) {
                        true -> enableUserLocation()
                        else -> {
                            openSettingLocation(requestCode = currentUserLocationReqCode)
                        }
                    }
                    result.success(isEnabled)
                }
                "initMap" -> {
                    initPosition(call, result)
                }
                "limitArea" -> {
                    limitCameraArea(call, result)
                }
                "remove#limitArea" -> {
                    removeLimitCameraArea(result)

                }
                "changePosition" -> {
                    changePosition(call, result)
                }
                "trackMe" -> {
                    trackUserLocation(result)
                }
                "deactivateTrackMe" -> {
                    deactivateTrackMe(result)
                }
                "map#center" -> {
                    result.success((map?.mapCenter as GeoPoint).toHashMap())
                }
                "map#bounds" -> {
                    getMapBounds(result = result)
                }
                "user#position" -> {
                    if (locationNewOverlay == null) {
                        initLocationAndProvider()
                    }
                    when (gpsServiceManager.isProviderEnabled(GPS_PROVIDER)) {
                        true -> {
                            getUserLocation(result)
                        }
                        false -> {
                            resultFlutter = result
                            openSettingLocation(requestCode = getUserLocationReqCode)

                        }
                    }
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
                        mapSnapShot().clearCachedRoad()
                        folderRoad.items.clear()
                        map?.invalidate()
                    }
                    result.success(null)

                }
                "road" -> {
                    drawRoad(call, result)
                }
                "draw#multi#road" -> {
                    drawMultiRoad(call, result)
                }
                "clear#roads" -> {
                    clearAllRoad(result)
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
                    startAdvancedSelection()
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
                "update#Marker" -> {
                    updateMarker(call, result)
                }
                "get#geopoints" -> {
                    getGeoPoints(result)
                }
                else -> {
                    result.notImplemented()
                }
            }

        } catch (e: Exception) {
            Log.e(e.cause.toString(), "error osm plugin ${e.stackTraceToString()}")
            result.error("404", e.message, e.stackTraceToString())
        }
    }

    private fun getGeoPoints(result: MethodChannel.Result) {
       val list = folderMarkers.items.filterIsInstance(Marker::class.java)
        val geoPoints  = emptyList<HashMap<String,Double>>().toMutableList()
        geoPoints.addAll(
            list.map {
                it.position.toHashMap()
            }.toList()
        )
        result.success(geoPoints.toList())

    }

    private fun getUserLocation(result: MethodChannel.Result, callback: VoidCallback? = null) {
        locationNewOverlay?.let {
            if (!it.isMyLocationEnabled) {
                it.enableMyLocation()
            }
            currentUserPosition(result, afterGetLocation = callback)
        } ?: result.error("400", "Opps!error locationOverlay is NULL", "")
    }

    private fun zoomingMapToBoundingBox(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as Map<String, Any>
        val box = BoundingBox.fromGeoPoints(
            arrayOf(
                GeoPoint(
                    args["north"]!! as Double,
                    args["east"]!! as Double,
                ),
                GeoPoint(
                    args["south"]!! as Double,
                    args["west"]!! as Double,
                ),
            ).toMutableList()
        )

        map?.zoomToBoundingBox(
            box, true, args["padding"]!! as Int
        )
        result.success(null)
    }

    private fun getMapBounds(result: MethodChannel.Result) {
        val bounds = map?.boundingBox ?: boundingWorldBox
        result.success(bounds.toHashMap())
    }


    private fun setCacheMap() {
        val mapSnapShot = mapSnapShot()
        // set last location and zoom level and orientation 
        if (mapSnapShot.centerGeoPoint() != null &&
            !mapSnapShot.centerGeoPoint()!!.eq(GeoPoint(0.0, 0.0))
        ) {
            if (mapSnapShot.mapOrientation() != 0f) {
                map!!.mapOrientation = mapSnapShot.mapOrientation()
            }
            map!!.controller.setCenter(mapSnapShot.centerGeoPoint())
            map!!.controller.setZoom(mapSnapShot.zoomLevel(initZoom))
        }
        /**
         * show  cached markers
         */
        scope?.launch {
            mapSnapShot.markers().forEach { (point, bytes) ->
                val icon = bytes?.let { getBitmap(bytes = it) }
                val drawable = getDefaultIconDrawable(icon = icon, color = null)
                withContext(Main) {
                    addMarker(
                        point,
                        dynamicMarkerBitmap = drawable,
                        animateTo = false,
                        zoom = mapSnapShot.zoomLevel(initZoom)
                    )
                }
            }
        }
        // set geo marker drawable 
        if (mapSnapShot.staticGeoPointsIcons().isNotEmpty()) {
            scope?.launch {
                mapSnapShot.staticGeoPointsIcons().forEach { (key, icon) ->
                    staticMarkerIcon[key] = getBitmap(icon)
                }
            }
        }
        // set static geo marker position in the map
        if (mapSnapShot.staticGeoPoints().isNotEmpty()) {
            resetLastGeoPointPosition(mapSnapShot)
        }
        mapSnapShot.lastCachedRoad()?.let { lastRoad ->
            if (lastRoad.roadPoints.isNotEmpty()) {
                if (!map!!.overlayManager.contains(folderRoad)) {
                    map!!.overlayManager.add(folderRoad)
                }
                val polyLine = Polyline(map!!)
                polyLine.setPoints(lastRoad.roadPoints)
                flutterRoad = createRoad(
                    polyLine = polyLine,
                    colorRoad = lastRoad.roadColor,
                    roadWidth = lastRoad.roadWith,
                    listInterestPoints = lastRoad.listInterestPoints,
                    showPoiMarker = lastRoad.showIcons,
                )

                map!!.invalidate()
            }

        }
        mapSnapShot.cachedRoads().forEach { road ->
            if (road.roadPoints.isNotEmpty()) {
                if (!map!!.overlayManager.contains(folderRoad)) {
                    map!!.overlayManager.add(folderRoad)
                }
                val polyLine = Polyline(map!!)
                polyLine.setPoints(road.roadPoints)
                //customRoadMarkerIcon.p
                flutterRoad = createRoad(
                    polyLine = polyLine,
                    colorRoad = road.roadColor,
                    roadWidth = road.roadWith,
                    listInterestPoints = road.listInterestPoints,
                    showPoiMarker = road.showIcons,
                )
            }
        }
        map!!.invalidate()
        resetAdvPickerOrTrackLocation(mapSnapShot)
        clearCacheMap()
        methodChannel.invokeMethod("map#restored", null)
    }


    private fun saveCacheMap() {
        mapSnapShot().cache(
            geoPoint = map!!.mapCenter as GeoPoint,
            zoom = map!!.zoomLevelDouble,
            customPickerMarkerIcon = getBytesFromBitmap(customPickerMarkerIcon),
            customRoadMarkerIcon = HashMap(
                customRoadMarkerIcon.mapValues { m ->
                    getBytesFromBitmap(m.value)!!
                }
            )
        )
    }

    private fun clearCacheMap() {
        mapSnapShot().reset()
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
        map!!.controller.setZoom(mapSnapShot().zoomLevel(zoom))
        map!!.controller.setCenter(mapSnapShot().centerGeoPoint() ?: geoPoint)
        methodChannel.invokeMethod("map#init", true)
        scope?.launch {
            mapSnapShot().cacheLocation(geoPoint, zoom)
        }
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
        marker.onClickListener = Marker.OnMarkerClickListener { marker, _ ->
            val hashMap = HashMap<String, Double>()
            hashMap["lon"] = marker!!.position.longitude
            hashMap["lat"] = marker.position.latitude
            methodChannel.invokeMethod("receiveGeoPoint", hashMap)
            true
        }
        when {
            dynamicMarkerBitmap != null -> {
                marker.icon = dynamicMarkerBitmap
                folderMarkers.items.add(marker)

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
                                            BitmapDrawable(context.resources, bitmapMarker)
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
                            Log.e("error image", e?.stackTraceToString() ?: "")
                        }

                    })


            }
            else -> folderMarkers.items.add(marker)

        }

        map?.invalidate()
        return marker
    }

    private fun createMarker(geoPoint: GeoPoint, color: Int?, icon: Bitmap? = null): Marker {
        val marker = FlutterMarker(context, map!!, geoPoint, scope)
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
            iconDrawable = BitmapDrawable(context.resources, icon)
            if (color != null) iconDrawable.setColorFilter(
                BlendModeColorFilterCompat.createBlendModeColorFilterCompat(
                    color,
                    BlendModeCompat.SRC_OVER
                )
            )
        } else if (customMarkerIcon != null) {
            iconDrawable = BitmapDrawable(context.resources, customMarkerIcon)
            if (color != null) iconDrawable.setColorFilter(
                BlendModeColorFilterCompat.createBlendModeColorFilterCompat(
                    color,
                    BlendModeCompat.SRC_OVER
                )
            )
        } else {
            iconDrawable =
                ContextCompat.getDrawable(context, R.drawable.ic_location_on_red_24dp)!!
        }
        return iconDrawable
    }

    private fun enableUserLocation() {

        if (markerSelectionPicker != null) {
            mainLinearLayout.removeView(markerSelectionPicker)
            if (!map!!.overlays.contains(folderShape))
                map!!.overlays.add(folderShape)
            if (!map!!.overlays.contains(folderRoad))
                map!!.overlays.add(folderRoad)
            if (!map!!.overlays.contains(folderStaticPosition))
                map!!.overlays.add(folderStaticPosition)
            markerSelectionPicker = null
        }

        if (locationNewOverlay == null) {
            initLocationAndProvider()
        }
        //locationNewOverlay!!.setPersonIcon()
        setMarkerTracking()
        locationNewOverlay?.let { location ->
            if (!location.isMyLocationEnabled) {
                isEnabled = true
                location.enableMyLocation()
            }
            mapSnapShot().setEnableMyLocation(isEnabled)
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

    }

    private fun setMarkerTracking() {
        when (customPersonMarkerIcon != null) {
            true -> {
                when (customArrowMarkerIcon != null) {
                    true -> {
                        locationNewOverlay!!.setDirectionArrow(
                            customPersonMarkerIcon,
                            customArrowMarkerIcon
                        )
                        val mScale = map!!.context.resources.displayMetrics.density

                        locationNewOverlay!!.setPersonHotspot(
                            mScale * (customPersonMarkerIcon!!.width / 4f) + 0.5f,
                            mScale * (customPersonMarkerIcon!!.width / 3f) + 0.5f,
                        )
                    }
                    false -> locationNewOverlay!!.setPersonIcon(customPersonMarkerIcon)
                }

            }
        }
    }

    private fun onChangedLocation() {
        //
        locationNewOverlay?.let { locationOverlay ->
            locationOverlay.runOnFirstFix {
                val location = locationOverlay.lastFix
                val geoPMap = GeoPoint(location).toHashMap()
                scope?.launch {
                    withContext(Main) {
                        methodChannel.invokeMethod("receiveUserLocation", geoPMap)
                    }
                }
            }
        }

    }


    private fun addMarkerManually(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as HashMap<*, *>
        val point = (args["point"] as HashMap<String, Double>).toGeoPoint()

        var bitmap = customMarkerIcon
        if (args.containsKey("icon")) {
            bitmap = getBitmap(args["icon"] as ByteArray)
            scope?.launch {
                mapSnapShot().overlaySnapShotMarker(
                    point = point,
                    icon = args["icon"] as ByteArray
                )
            }
        }


        addMarker(
            point,
            dynamicMarkerBitmap = getDefaultIconDrawable(null, icon = bitmap),
            zoom = map!!.zoomLevelDouble,
            animateTo = false
        )


        result.success(null)

    }

    private fun updateMarker(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as HashMap<*, *>
        val point = (args["point"] as HashMap<String, Double>).toGeoPoint()
        var bitmap = customMarkerIcon
        if (args.containsKey("icon")) {
            bitmap = getBitmap(args["icon"] as ByteArray)
            scope?.launch {
                mapSnapShot().overlaySnapShotMarker(
                    point = point,
                    icon = args["icon"] as ByteArray
                )
            }
        }
        val marker: FlutterMarker? = folderMarkers.items.filterIsInstance<FlutterMarker>()
            .firstOrNull { marker ->
                marker.position.eq(point)
            }
        when (marker != null) {
            true -> {
                marker.icon = getDefaultIconDrawable(null, icon = bitmap)
                val index = folderMarkers.items.indexOf(marker)
                folderMarkers.items[index] = marker
                map!!.invalidate()
                result.success(200)
            }
            false -> result.error(
                "404",
                "GeoPoint not found",
                "you trying to modify icon of marker not exist",
            )
        }

    }


    private fun changeLocationMarkers(call: MethodCall, result: MethodChannel.Result) {
        val args: HashMap<String, Any> = call.arguments as HashMap<String, Any>
        try {
            val personIcon = (args["personIcon"] as ByteArray)
            val arrowIcon = (args["arrowDirectionIcon"] as ByteArray)
            customPersonMarkerIcon = getBitmap(personIcon)
            customArrowMarkerIcon = getBitmap(arrowIcon)
            mapSnapShot().setUserTrackMarker(
                personMarker = personIcon,
                arrowMarker = arrowIcon
            )
            result.success(null)
        } catch (e: Exception) {
            e.printStackTrace()
            result.success(e.message)

        }
    }

    private fun removeLimitCameraArea(result: MethodChannel.Result) {
        map!!.setScrollableAreaLimitDouble(boundingWorldBox)
        mapSnapShot().setBoundingWorld(boundingWorldBox)
        result.success(200)
    }

    private fun limitCameraArea(call: MethodCall, result: MethodChannel.Result) {
        val list = call.arguments as List<Double>
        val box = BoundingBox(
            list[0], list[1], list[2], list[3]
        )
        map!!.setScrollableAreaLimitDouble(box)
        mapSnapShot().setBoundingWorld(
            box = box
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
        mapSnapShot().saveMapOrientation(map!!.mapOrientation)
        map!!.invalidate()
        result.success(null)
    }



    private fun trackUserLocation(result: MethodChannel.Result) {
        try {
            if (homeMarker != null) {
                folderMarkers.items.remove(homeMarker)
                map?.invalidate()
            }
            locationNewOverlay?.let { locationOverlay ->
                when {
                    !locationOverlay.isFollowLocationEnabled -> {
                        isTracking = true
                        locationOverlay.enableFollowLocation()
                        onChangedLocation()
                        mapSnapShot().setTrackLocation(isTracking)
                        mapSnapShot().setEnableMyLocation(isEnabled)
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
                homeMarker = addMarker(position, map!!.zoomLevelDouble, null)
                markerSelectionPicker = null
                map!!.overlays.add(folderShape)
                map!!.overlays.add(folderRoad)
                map!!.overlays.add(folderStaticPosition)
                map!!.overlays.add(folderMarkers)
                map?.overlays?.add(0, staticOverlayListener)
                map?.invalidate()
                mapSnapShot().setAdvancedPicker(false)

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
                    if (isEnabled) {
                        enableUserLocation()
                    }
                    locationNewOverlay?.let { locationOverlay ->
                        if (!locationOverlay.isFollowLocationEnabled) {
                            isTracking = true
                            locationOverlay.enableFollowLocation()
                            onChangedLocation()
                        }
                    }
                } catch (e: Exception) {
                }
            }
            map!!.overlays.add(folderShape)
            map!!.overlays.add(folderRoad)
            map!!.overlays.add(folderStaticPosition)
            map!!.overlays.add(folderMarkers)
            map?.overlays?.add(0, staticOverlayListener)
            markerSelectionPicker = null
            mapSnapShot().setAdvancedPicker(false)

        }
    }

    private fun startAdvancedSelection() {
        map!!.overlays.clear()
        if (isTracking) {
            try {
                locationNewOverlay?.let { locationOverlay ->
                    if (locationOverlay.isFollowLocationEnabled) {
                        locationOverlay.disableFollowLocation()
                        locationOverlay.disableMyLocation()
                        provider?.stopLocationProvider()
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
                context.resources,
                R.drawable.ic_location_on_red_24dp,
                null
            )!!.toBitmap(
                64,
                64
            ) //BitmapFactory.decodeResource(, R.drawable.ic_location_on_red_24dp)?:customMarkerIcon

        markerSelectionPicker = FlutterPickerViewOverlay(
            bitmap, context, point, customPickerMarkerIcon != null
        )
        val params = FrameLayout.LayoutParams(
            WRAP_CONTENT,
            WRAP_CONTENT, Gravity.CENTER
        )
        markerSelectionPicker!!.layoutParams = params
        mainLinearLayout.addView(markerSelectionPicker)
        mapSnapShot().setAdvancedPicker(
            isActive = true
        )

    }

    private fun deactivateTrackMe(result: MethodChannel.Result) {
        isTracking = false
        isEnabled = false
        mapSnapShot().setTrackLocation(isTracking)
        mapSnapShot().setEnableMyLocation(isEnabled)
        try {
            locationNewOverlay?.disableFollowLocation()
            locationNewOverlay?.disableMyLocation()
            provider?.stopLocationProvider()
            result.success(true)
        } catch (e: Exception) {
            result.error("400", e.stackTraceToString(), "")
        }
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

    private fun clearAllRoad(result: MethodChannel.Result) {
        folderRoad.items.clear()

        map!!.invalidate()
        result.success(200)
    }

    private fun drawMultiRoad(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments!! as List<HashMap<String, Any>>
        val listConfigRoad = emptyList<RoadConfig>().toMutableList()

        for (arg in args) {
            val waypoints = (arg["wayPoints"] as List<HashMap<String, Double>>).map { map ->
                GeoPoint(map["lat"]!!, map["lon"]!!)
            }.toList()
            listConfigRoad.add(
                RoadConfig(
                    meanUrl = when (arg["roadType"] as String) {
                        "car" -> OSRMRoadManager.MEAN_BY_CAR
                        "bike" -> OSRMRoadManager.MEAN_BY_BIKE
                        "foot" -> OSRMRoadManager.MEAN_BY_FOOT
                        else -> OSRMRoadManager.MEAN_BY_CAR
                    },
                    colorRoad = when (arg.containsKey("roadColor")) {
                        true -> {
                            val colors = (arg["roadColor"] as List<Int>)
                            Color.rgb(colors.first(), colors.last(), colors[1])
                        }
                        else -> roadColor
                    },
                    roadWidth = when (arg.containsKey("roadWidth")) {
                        true -> (arg["roadWidth"] as Double).toFloat()
                        else -> 5f
                    },
                    wayPoints = waypoints,
                    interestPoints = when (arg.containsKey("middlePoints")) {
                        true -> arg["middlePoints"] as List<HashMap<String, Double>>
                        false -> emptyList()
                    }.map { g ->
                        GeoPoint(g["lat"]!!, g["lon"]!!)
                    }.toList()
                )
            )
        }


        //val showPoiMarker = args["showMarker"] as Boolean

        flutterRoad?.road?.let {
            map!!.overlays.remove(it)
        }
        checkRoadFolderAboveUserOverlay()
        folderRoad.items.clear()
        val cachedRoads = map!!.overlays.filterIsInstance<Polyline>().toSet()
        if (cachedRoads.isNotEmpty()) {
            map!!.overlays.removeAll(cachedRoads)
        }
        map!!.invalidate()

        val resultRoads = emptyList<HashMap<String, Any>>().toMutableList();
        job = scope?.launch(Default) {
            withContext(IO) {
                for (config in listConfigRoad) {
                    if (roadManager == null)
                        roadManager = OSRMRoadManager(context, "json/application")
                    roadManager?.let { manager ->
                        manager.setMean(config.meanUrl)
                        var routePointsEncoded = ""
                        withContext(Main) {
                            folderMarkers.items.removeAll {
                                (it is FlutterMarker && config.wayPoints.contains(it.position)) ||
                                        (it is FlutterMarker && config.interestPoints.contains(it.position))
                            }
                            mapSnapShot().removeMarkersFromSnapShot(config.wayPoints)
                        }
                        val roadPoints = ArrayList(config.wayPoints)
                        if (config.interestPoints.isNotEmpty()) {
                            roadPoints.addAll(1, config.interestPoints)
                        }
                        val road = manager.getRoad(roadPoints)
                        withContext(Main) {
                            if (road.mRouteHigh.size > 2) {
                                routePointsEncoded = PolylineEncoder.encode(road.mRouteHigh, 10)
                                val polyLine = RoadManager.buildRoadOverlay(road)
                                createRoad(
                                    polyLine = polyLine,
                                    colorRoad = config.colorRoad,
                                    roadWidth = config.roadWidth,
                                    showPoiMarker = false,
                                    listInterestPoints = config.interestPoints,
                                )

                                mapSnapShot().cacheListRoad(
                                    RoadSnapShot(
                                        roadPoints = road.mRouteHigh,
                                        roadColor = config.colorRoad,
                                        roadWith = config.roadWidth,
                                        listInterestPoints = config.interestPoints,
                                        showIcons = false
                                    )
                                )
                                resultRoads.add(HashMap<String, Any>().apply {
                                    this["duration"] = road.mDuration
                                    this["distance"] = road.mLength
                                    this["routePoints"] = routePointsEncoded
                                })
                            }
                        }
                        delay(100)

                    }
                }

            }
            withContext(Main) {
                map!!.invalidate()
                result.success(resultRoads.toList())
            }
        }

    }

    private fun checkRoadFolderAboveUserOverlay() {
        if (!map!!.overlays.contains(folderRoad)) {
            locationNewOverlay?.let { locationOverlay ->
                val indexOf = map!!.overlays.indexOf(locationOverlay)
                when (indexOf != -1) {
                    true -> map!!.overlays.add(indexOf - 1, folderRoad)
                    false -> map!!.overlays.add(folderRoad)
                }
            } ?: map!!.overlays.add(folderRoad)
        }
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
        val zoomToRegion = args["zoomIntoRegion"] as Boolean
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
        flutterRoad?.road?.let {
            map!!.overlays.remove(it)
        }

        checkRoadFolderAboveUserOverlay()
        folderRoad.items.clear()


        map!!.invalidate()

        if (roadManager == null)
            roadManager = OSRMRoadManager(context, "json/application")
        roadManager?.let { manager ->
            manager.setMean(meanUrl)
            var routePointsEncoded = ""
            job = scope?.launch(Default) {
                val wayPoints = listPointsArgs.map {
                    GeoPoint(it["lat"]!!, it["lon"]!!)
                }.toList()
                withContext(Main) {
                    folderMarkers.items.removeAll {
                        (it is FlutterMarker && wayPoints.contains(it.position)) ||
                                (it is FlutterMarker && listInterestPoints.contains(it.position))
                    }
                    mapSnapShot().removeMarkersFromSnapShot(wayPoints)
                }
                val roadPoints = ArrayList(wayPoints)
                if (listInterestPoints.isNotEmpty()) {
                    roadPoints.addAll(1, listInterestPoints)
                }
                val road = manager.getRoad(roadPoints)
                withContext(Main) {
                    if (road.mRouteHigh.size > 2) {
                        routePointsEncoded = PolylineEncoder.encode(road.mRouteHigh, 10)
                        val polyLine = RoadManager.buildRoadOverlay(road)
                        flutterRoad = createRoad(
                            polyLine = polyLine,
                            colorRoad = colorRoad,
                            roadWidth = roadWidth,
                            showPoiMarker = showPoiMarker,
                            listInterestPoints = listInterestPoints,
                        )
                        mapSnapShot().cacheRoad(
                            RoadSnapShot(
                                roadPoints = road.mRouteHigh,
                                roadColor = colorRoad,
                                roadWith = roadWidth,
                                listInterestPoints = listInterestPoints,
                                showIcons = showPoiMarker
                            )
                        )
                        if (zoomToRegion) {
                            map!!.zoomToBoundingBox(
                                BoundingBox.fromGeoPoints(road.mRouteHigh),
                                true,
                                64,
                            )
                        }

                        map!!.invalidate()
                    }
                    result.success(HashMap<String, Any>().apply {
                        this["duration"] = road.mDuration
                        this["distance"] = road.mLength
                        this["routePoints"] = routePointsEncoded
                    })
                }

            }
        }
    }

    private fun drawRoadManually(call: MethodCall, result: MethodChannel.Result) {
        val args: HashMap<String, Any> = call.arguments as HashMap<String, Any>

        val encodedWayPoints = (args["road"] as String)
        val colorRoad = (args["roadColor"] as List<Int>)
        val color = Color.rgb(colorRoad.first(), colorRoad.last(), colorRoad[1])
        val widthRoad = (args["roadWidth"] as Double)
        val zoomToRegion = args["zoomInto"] as Boolean
        val clearPreviousRoad = args["clearPreviousRoad"] as Boolean
        val interestPointsEncoded = args["interestPoints"] as String?
        val iconInterestPoints = args["iconInterestPoints"] as ByteArray?
        checkRoadFolderAboveUserOverlay()
        if (clearPreviousRoad) {
            folderRoad.items.clear()
        }
        var bitmapIconInterestPoints: Bitmap? = null
        if (iconInterestPoints != null) {
            bitmapIconInterestPoints = getBitmap(bytes = iconInterestPoints!!)
        }


        val route = PolylineEncoder.decode(encodedWayPoints, 10, false)
        val listInterestPoints = when (interestPointsEncoded != null) {
            true -> PolylineEncoder.decode(interestPointsEncoded, 10, false)
            false -> emptyList<GeoPoint>()
        }

        val polyLine = Polyline(map!!)
        polyLine.setPoints(route)
        polyLine.outlinePaint.color = color
        polyLine.outlinePaint.strokeWidth = widthRoad.toFloat()
        createRoad(
            polyLine = polyLine,
            colorRoad = color,
            roadWidth = widthRoad.toFloat(),
            showPoiMarker = listInterestPoints.isNotEmpty(),
            listInterestPoints = listInterestPoints,
            bitmapIcon = bitmapIconInterestPoints
        )

        mapSnapShot().cacheRoad(
            RoadSnapShot(
                roadPoints = route,
                roadColor = color,
                roadWith = widthRoad.toFloat(),
                showIcons = false,
            )
        )
        if (zoomToRegion) {
            map!!.zoomToBoundingBox(
                BoundingBox.fromGeoPoints(polyLine.actualPoints),
                true,
                64,
            )
        }
        map!!.invalidate()
        result.success(null)
    }

    private fun createRoad(
        polyLine: Polyline,
        colorRoad: Int?,
        showPoiMarker: Boolean,
        listInterestPoints: List<GeoPoint>,
        roadWidth: Float,
        bitmapIcon: Bitmap? = null,
    ): FlutterRoad {
        polyLine.setOnClickListener { _, _, eventPos ->
            methodChannel.invokeMethod("receiveSinglePress", eventPos?.toHashMap())
            true
        }
        /// set polyline color
        polyLine.outlinePaint.color = colorRoad ?: Color.GREEN

        val iconsRoads = customRoadMarkerIcon
        when {
            (iconsRoads.isEmpty() && bitmapIcon != null) -> {
                iconsRoads[Constants.STARTPOSITIONROAD] = bitmapIcon
                iconsRoads[Constants.MIDDLEPOSITIONROAD] = bitmapIcon
                iconsRoads[Constants.ENDPOSITIONROAD] = bitmapIcon
            }
            iconsRoads.isNotEmpty() && bitmapIcon != null -> {
                iconsRoads[Constants.MIDDLEPOSITIONROAD] = bitmapIcon
                if (!iconsRoads.containsKey(Constants.STARTPOSITIONROAD)) {
                    iconsRoads[Constants.STARTPOSITIONROAD] = bitmapIcon
                }
                if (!iconsRoads.containsKey(Constants.ENDPOSITIONROAD)) {
                    iconsRoads[Constants.ENDPOSITIONROAD] = bitmapIcon
                }
            }
        }
        val flutterRoad = FlutterRoad(
            context,
            map!!,
            interestPoint = if (showPoiMarker) listInterestPoints else emptyList(),
            showInterestPoints = showPoiMarker
        )

        flutterRoad.let { roadF ->
            if (showPoiMarker) {
                roadF.markersIcons = iconsRoads
            }
            polyLine.outlinePaint.strokeWidth = roadWidth

            roadF.road = polyLine
            /*if (showPoiMarker) {
                // if (it.start != null)
                folderRoad.items.add(roadF.start.apply {
                    this.visibilityInfoWindow(visibilityInfoWindow)
                })
                //  if (it.end != null)
                folderRoad.items.add(roadF.end.apply {
                    this.visibilityInfoWindow(visibilityInfoWindow)
                })
                folderRoad.items.addAll(roadF.middlePoints)
            }*/

            folderRoad.items.add(roadF)
        }

        return flutterRoad
    }

    private fun staticPositionIconMaker(call: MethodCall, result: MethodChannel.Result) {
        val hashMap: HashMap<String, Any> = call.arguments as HashMap<String, Any>

        try {
            val key = (hashMap["id"] as String)
            val bytes = (hashMap["bitmap"] as ByteArray)
            val bitmap = getBitmap(bytes)
            val refresh = hashMap["refresh"] as Boolean
            staticMarkerIcon[key] = bitmap
            mapSnapShot().addToIconsStaticGeoPoints(key, bytes)
            scope?.launch {
                if (staticPoints.containsKey(key) && refresh) {
                    showStaticPosition(
                        key,
                        mapSnapShot().staticGeoPoints()[key]!!.second
                    )
                }
            }
            result.success(null)
        } catch (e: java.lang.Exception) {
            Log.e("id", hashMap["id"].toString())
            Log.e("err static point marker", e.stackTraceToString())
            result.error("400", "error to getBitmap static Position", "")
            staticMarkerIcon = HashMap()
        }
    }

    private fun staticPosition(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as HashMap<String, Any>
        val id = args["id"] as String?
        val points = args["point"] as MutableList<HashMap<String, Double>>?
        val geoPoints: MutableList<GeoPoint> = emptyList<GeoPoint>().toMutableList()
        val angleGeoPoints: MutableList<Double> = emptyList<Double>().toMutableList()
        for (hashMap in points!!) {
            geoPoints.add(GeoPoint(hashMap["lat"]!!, hashMap["lon"]!!))
            when (hashMap.containsKey("angle")) {
                true -> angleGeoPoints.add(hashMap["angle"] ?: 0.0)
                else -> angleGeoPoints.add(0.0)
            }
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
        scope?.launch {
            mapSnapShot().addToStaticGeoPoints(
                id,
                Pair(
                    geoPoints.toList(),
                    angleGeoPoints.toList(),
                )
            )
        }
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
            BitmapDrawable(context.resources, bitmap)
        } else null
        val imageURL: String? = if (args.containsKey("imageURL")) {
            args["imageURL"] as String
        } else null

        if (mapEventsOverlay == null) {
            if (map!!.overlays.first() is MapEventsOverlay)
                map!!.overlays.removeFirst()
            mapEventsOverlay = MapEventsOverlay(object : MapEventsReceiver {
                override fun singleTapConfirmedHelper(p: GeoPoint?): Boolean {

                    val pMarker = addMarker(
                        p!!, map!!.zoomLevelDouble,
                        null,
                        marker,
                        imageURL,
                    )
                    scope?.launch {
                        mapSnapShot().overlaySnapShotMarker(
                            point = p,
                            icon = getBytesFromBitmap(pMarker.icon.toBitmap())!!
                        )
                    }
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
        val geoMarkers = folderMarkers.items.filterIsInstance<FlutterMarker>().filter { marker ->
            marker.position.eq(geoPoint)
        }
        if (geoMarkers.isNotEmpty()) {
            folderMarkers.items.removeAll(geoMarkers)
            scope?.launch {
                mapSnapShot().removeMarkersFromSnapShot(
                    removedPoints = geoMarkers.map {
                        it.position
                    }
                )
            }
            map!!.overlays.remove(folderMarkers)
            map!!.overlays.add(folderMarkers)
            map!!.invalidate()
        }

    }

    private fun currentUserPosition(
        result: MethodChannel.Result,
        afterGetLocation: VoidCallback? = null
    ) {
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
                        if (afterGetLocation != null) {
                            afterGetLocation()
                        }
                    } ?: result.error("400", "we cannot get the current position!", "")
                }
            }

        } ?: result.error("400", "we cannot get the current position!", "")
    }

    private fun showStaticPosition(idStaticPosition: String, angles: List<Double> = emptyList()) {

        var overlay: FolderOverlay? = folderStaticPosition.items.firstOrNull {
            (it as FolderOverlay).name?.equals(idStaticPosition) == true
        } as FolderOverlay?

        overlay?.let {
            it.items.clear()
        }
        if (overlay != null) {
            folderStaticPosition.remove(overlay)
        }
        if (overlay == null) {
            overlay = FolderOverlay().apply {
                name = idStaticPosition
            }
        }

        staticPoints[idStaticPosition]?.forEachIndexed { index, geoPoint ->
            val marker = FlutterMarker(context, map!!, scope)
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
        if (map!!.zoomLevelDouble > 10.0 && !mapSnapShot().advancedPicker()) {
            if (map!!.overlays.contains(folderStaticPosition)) {
                map!!.overlays.remove(folderStaticPosition)
            }
            if (!map!!.overlays.contains(folderStaticPosition)) {
                map!!.overlays.add(folderStaticPosition)

            }
            map!!.invalidate()
        }

    }


    private fun getBitmap(bytes: ByteArray): Bitmap {
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    }

    private fun getBytesFromBitmap(bitmap: Bitmap?): ByteArray? {
        if (bitmap == null) {
            return null
        }
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
        return stream.toByteArray()
    }


    override fun getView(): View {
        return mainLinearLayout
    }

    override fun dispose() {
        job?.let {
            if (it.isActive) {
                it.cancel()
            }
        }
        mainLinearLayout.removeAllViews()
        //clearCacheMap()
        //map!!.onDetach()
        // map = null
    }

    override fun onFlutterViewAttached(flutterView: View) {
        //   map!!.onAttachedToWindow()
        if (map == null) {
            val prefs: SharedPreferences = PreferenceManager.getDefaultSharedPreferences(context)
            Configuration.getInstance()
                .load(context, PreferenceManager.getDefaultSharedPreferences(context))
//            map?.forceLayout()
        }

    }


    override fun onFlutterViewDetached() {
        map!!.onDetach()
        staticMarkerIcon.clear()
        staticPoints.clear()
        customMarkerIcon = null
        customRoadMarkerIcon.clear()
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

    @OnLifecycleEvent(Lifecycle.Event.ON_CREATE)
    fun onCreate(owner: LifecycleOwner) {
        FlutterOsmPlugin.state.set(CREATED)
        methodChannel = MethodChannel(binaryMessenger, "plugins.dali.hamza/osmview_${id}")
        methodChannel.setMethodCallHandler(this)
        //eventChannel = EventChannel(binaryMessenger, "plugins.dali.hamza/osmview_stream_${id}")
        //eventChannel.setStreamHandler(this)
        //methodChannel.invokeMethod("map#init", true)


        scope = owner.lifecycle.coroutineScope
        folderStaticPosition.name = Constants.nameFolderStatic
        Configuration.getInstance().load(
            context,
            PreferenceManager.getDefaultSharedPreferences(context)
        )
        initMap()
        // map!!.forceLayout()
        Log.e("osm", "osm flutter plugin create")

    }


    @OnLifecycleEvent(Lifecycle.Event.ON_START)
    fun onStart(owner: LifecycleOwner) {
        FlutterOsmPlugin.state.set(STARTED)
        Log.e("osm", "osm flutter plugin start")
        context.applicationContext.registerReceiver(
            checkGPSServiceBroadcast,
            IntentFilter(LocationManager.PROVIDERS_CHANGED_ACTION)
        );

    }


    @OnLifecycleEvent(Lifecycle.Event.ON_RESUME)
    fun onResume(owner: LifecycleOwner) {
        FlutterOsmPlugin.state.set(FlutterOsmPlugin.RESUMED)
        Log.e("osm", "osm flutter plugin resume")
        if (map == null) {
            initMap()
        }
        map?.onResume()
        if (!skipCheckLocation) {
            //reStartFollowLocation()
        }


    }

    @OnLifecycleEvent(Lifecycle.Event.ON_PAUSE)
    fun onPause(owner: LifecycleOwner) {
        FlutterOsmPlugin.state.set(PAUSED)
        locationNewOverlay?.onPause()
        map?.onPause()
        skipCheckLocation = false
        Log.e("osm", "osm flutter plugin pause")

    }

    @OnLifecycleEvent(Lifecycle.Event.ON_STOP)
    fun onStop(owner: LifecycleOwner) {
        FlutterOsmPlugin.state.set(STOPPED)
        Log.e("osm", "osm flutter plugin stopped")
        context.applicationContext.unregisterReceiver(checkGPSServiceBroadcast)
        locationNewOverlay = null
        provider = null
        job?.let {
            if (it.isActive) {
                it.cancel()
            }
        }

        job = null
    }

    @OnLifecycleEvent(Lifecycle.Event.ON_DESTROY)
    fun onDestroy(owner: LifecycleOwner) {
        mainLinearLayout.removeAllViews()

        removeCurrentCache()

        //map!!.onDetach()
        methodChannel.setMethodCallHandler(null)
        //configuration!!.osmdroidTileCache.delete()
        //configuration = null
        //eventChannel.setStreamHandler(null)
        map = null
        FlutterOsmPlugin.state.set(DESTROYED)

    }


    private fun reStartFollowLocation() {
        initLocationAndProvider()
        locationNewOverlay?.let { myLocation ->
            if (myLocation.isMyLocationEnabled) {
                myLocation.disableMyLocation()
            }
            if (myLocation.isFollowLocationEnabled) {
                myLocation.disableFollowLocation()
            }
            if (isEnabled) {
                myLocation.enableMyLocation()
            }
            if (isTracking) {
                myLocation.enableFollowLocation()
                onChangedLocation()

            }
        }


    }


    private fun resetAdvPickerOrTrackLocation(mapSnapShot: MapSnapShot) {
        when (mapSnapShot.advancedPicker()) {
            true -> startAdvancedSelection()
            false -> {
                isTracking = mapSnapShot.trackMyLocation()
                isEnabled = mapSnapShot.getEnableMyLocation()
                when (isEnabled || isTracking) {
                    true -> {
                        mapSnapShot.getPersonUserTrackMarker()?.let { bytes ->
                            customPersonMarkerIcon = getBitmap(bytes)

                        }
                        mapSnapShot.getArrowDirectionTrackMarker()?.let { bytes ->
                            customArrowMarkerIcon = getBitmap(bytes)

                        }
                        if (isEnabled) {
                            enableUserLocation()
                        }
                        if (isTracking) {
                            locationNewOverlay?.let { locationOverlay ->
                                when {
                                    !locationOverlay.isFollowLocationEnabled -> {
                                        locationOverlay.enableFollowLocation()
                                        onChangedLocation()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private fun resetLastGeoPointPosition(mapSnapShot: MapSnapShot) {
        scope?.launch {
            withContext(Default) {
                mapSnapShot.staticGeoPointsIcons().forEach { (key, icon) ->
                    staticMarkerIcon[key] = getBitmap(icon)
                }
            }
            mapSnapShot.staticGeoPoints().forEach { staticPoint ->
                staticPoints[staticPoint.key] = staticPoint.value.first.toMutableList()
                withContext(Main) {
                    showStaticPosition(
                        staticPoint.key,
                        staticPoint.value.second.toList()
                    )
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            getUserLocationReqCode -> {
                skipCheckLocation = true
                if (gpsServiceManager.isProviderEnabled(GPS_PROVIDER)) {
                    if (resultFlutter != null) {
                        initLocationAndProvider()
                        getUserLocation(resultFlutter!!) {
                            resultFlutter = null
                        }
                    }

                }
            }
            currentUserLocationReqCode -> {
                skipCheckLocation = true
                if (gpsServiceManager.isProviderEnabled(GPS_PROVIDER)) {
                    enableUserLocation()
                }
            }
        }
        return true
    }

    private fun initLocationAndProvider() {
        if (provider == null) {
            provider = GpsMyLocationProvider(context)
        }
        if (locationNewOverlay == null) {
            locationNewOverlay = MyLocationNewOverlay(provider, map)
        }
    }


}


package hamza.dali.flutter_osm_plugin

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Paint
import android.location.LocationManager
import android.location.LocationManager.GPS_PROVIDER
import android.location.LocationManager.NETWORK_PROVIDER
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.widget.FrameLayout
import android.widget.LinearLayout
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.coroutineScope
import androidx.preference.PreferenceManager
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.CREATED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.DESTROYED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.PAUSED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.STARTED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.STOPPED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.mapSnapShots
import hamza.dali.flutter_osm_plugin.models.Anchor
import hamza.dali.flutter_osm_plugin.models.CustomTile
import hamza.dali.flutter_osm_plugin.models.FlutterGeoPoint
import hamza.dali.flutter_osm_plugin.models.FlutterMarker
import hamza.dali.flutter_osm_plugin.models.FlutterRoad
import hamza.dali.flutter_osm_plugin.models.RoadConfig
import hamza.dali.flutter_osm_plugin.models.RoadGeoPointInstruction
import hamza.dali.flutter_osm_plugin.models.toRoadConfig
import hamza.dali.flutter_osm_plugin.models.toRoadInstruction
import hamza.dali.flutter_osm_plugin.models.toRoadOption
import hamza.dali.flutter_osm_plugin.overlays.CustomLocationManager
import hamza.dali.flutter_osm_plugin.utilities.Constants
import hamza.dali.flutter_osm_plugin.utilities.MapSnapShot
import hamza.dali.flutter_osm_plugin.utilities.RoadSnapShot
import hamza.dali.flutter_osm_plugin.utilities.eq
import hamza.dali.flutter_osm_plugin.utilities.openSettingLocation
import hamza.dali.flutter_osm_plugin.utilities.resetTileSource
import hamza.dali.flutter_osm_plugin.utilities.setCustomTile
import hamza.dali.flutter_osm_plugin.utilities.setStyle
import hamza.dali.flutter_osm_plugin.utilities.toBitmap
import hamza.dali.flutter_osm_plugin.utilities.toByteArray
import hamza.dali.flutter_osm_plugin.utilities.toGeoPoint
import hamza.dali.flutter_osm_plugin.utilities.toHashMap
import hamza.dali.flutter_osm_plugin.utilities.toMap
import hamza.dali.flutter_osm_plugin.utilities.toRGB
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding.OnSaveInstanceStateListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.platform.PlatformView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers.Default
import kotlinx.coroutines.Dispatchers.IO
import kotlinx.coroutines.Dispatchers.Main
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
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
import org.osmdroid.tileprovider.tilesource.OnlineTileSourceBase
import org.osmdroid.tileprovider.tilesource.TileSourceFactory.MAPNIK
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.CustomZoomButtonsController
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.FolderOverlay
import org.osmdroid.views.overlay.MapEventsOverlay
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polygon
import org.osmdroid.views.overlay.Polyline
import org.osmdroid.views.overlay.gestures.RotationGestureOverlay
import kotlin.collections.component1
import kotlin.collections.component2
import kotlin.collections.set


typealias VoidCallback = () -> Unit

enum class Shape {
    rect,
    circle
}

fun FlutterOsmView.configZoomMap(call: MethodCall, result: MethodChannel.Result) {
    val args = call.arguments as HashMap<*, *>
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

@Suppress("UNCHECKED_CAST")
class FlutterOsmView(
    private val context: Context,
    private val binaryMessenger: BinaryMessenger,
    private val id: Int,//viewId
    private val providerLifecycle: ProviderLifecycle,
    private val keyArgMapSnapShot: String,
    private val customTile: CustomTile?,
    private val isEnabledRotationGesture: Boolean = false
) : OnSaveInstanceStateListener, PlatformView, MethodCallHandler,
    PluginRegistry.ActivityResultListener, DefaultLifecycleObserver {


    internal var map: MapView? = null
    private var keyMapSnapshot: String = keyArgMapSnapShot
    private lateinit var locationNewOverlay: CustomLocationManager
    private var customMarkerIcon: Bitmap? = null
    private var customPersonMarkerIcon: Bitmap? = null
    private var customArrowMarkerIcon: Bitmap? = null
    private var staticMarkerIcon: HashMap<String, Bitmap> = HashMap()
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
    private var scope: CoroutineScope? = null
    private var skipCheckLocation: Boolean = false
    private var resultFlutter: MethodChannel.Result? = null
    private lateinit var methodChannel: MethodChannel
    private val mRotationGestureOverlay: RotationGestureOverlay by lazy {
        RotationGestureOverlay(map!!).apply {
            this.isEnabled = isEnabledRotationGesture
        }
    }
    private lateinit var activity: Activity

    private val gpsServiceManager: LocationManager by lazy {
        context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    }


    private var roadManager: OSRMRoadManager? = null
    internal var stepZoom = Constants.stepZoom
    internal var initZoom = 10.0
    private var isTracking = false
    private var isEnabled = false
    private var visibilityInfoWindow = false

    companion object {
        val boundingWorldBox: BoundingBox = BoundingBox(
            85.0,
            180.0,
            -85.0,
            -180.0,
        )
        internal const val getUserLocationReqCode = 200
        internal const val currentUserLocationReqCode = 201

    }

    fun setActivity(activity: Activity) {
        this.activity = activity
    }

    private fun mapSnapShot(): MapSnapShot {
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
                val hashMap = HashMap<String, Any?>()
                hashMap["bounding"] = map?.boundingBox?.toHashMap()
                hashMap["center"] = (map?.mapCenter as GeoPoint).toHashMap()
                methodChannel.invokeMethod("receiveRegionIsChanging", hashMap)

                return true
            }

            override fun onZoom(event: ZoomEvent?): Boolean {
                val hashMap = HashMap<String, Any?>()
                hashMap["bounding"] = map?.boundingBox?.toHashMap()
                hashMap["center"] = (map?.mapCenter as GeoPoint).toHashMap()
                methodChannel.invokeMethod("receiveRegionIsChanging", hashMap)
                return true
            }
        }
    }


    private var mainLinearLayout: FrameLayout = FrameLayout(context).apply {
        this.layoutParams =
            FrameLayout.LayoutParams(FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
    }

    init {
        providerLifecycle.getOSMLifecycle()?.addObserver(this)

    }

    private fun initMap() {


        map = MapView(context)

        map!!.layoutParams = MapView.LayoutParams(
            LinearLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT)
        )
        map!!.isTilesScaledToDpi = true
        map!!.setMultiTouchControls(true)
        when {
            customTile != null -> {
                map!!.setCustomTile(
                    name = customTile.sourceName,
                    minZoomLvl = customTile.minZoomLevel,
                    maxZoomLvl = customTile.maxZoomLevel,
                    tileSize = customTile.tileSize,
                    tileExtensionFile = customTile.tileFileExtension,
                    baseURLs = customTile.urls.toTypedArray(),
                    api = customTile.api,
                )
            }

            else -> map!!.setTileSource(MAPNIK)
        }

        map!!.isVerticalMapRepetitionEnabled = false
        map!!.isHorizontalMapRepetitionEnabled = false
        map!!.setScrollableAreaLimitDouble(mapSnapShot().boundingWorld())
        map!!.setScrollableAreaLimitLatitude(
            MapView.getTileSystem().maxLatitude, MapView.getTileSystem().minLatitude, 0
        )
        map!!.zoomController.setVisibility(CustomZoomButtonsController.Visibility.NEVER)
        //
        map!!.minZoomLevel = 2.0
        when (mapSnapShots.containsKey(keyMapSnapshot)) {
            true -> {
                map!!.setExpectedCenter(mapSnapShot().centerGeoPoint())
                map!!.controller.setZoom(mapSnapShot().zoomLevel(2.0))
            }

            else -> {
                map!!.setExpectedCenter(GeoPoint(0.0, 0.0))
                map!!.controller.setZoom(2.0)
            }
        }

        map!!.addMapListener(mapListener)
        map!!.overlayManager.add(0, staticOverlayListener)
        map!!.overlayManager.add(folderMarkers)
        map!!.overlayManager.add(mRotationGestureOverlay)
        mainLinearLayout.addView(map)
        /// init LocationManager
        locationNewOverlay = CustomLocationManager(map!!)

        locationNewOverlay.onChangedLocation { userLocation,heading ->
            scope?.launch {
                withContext(Main) {
                    methodChannel.invokeMethod(
                        "receiveUserLocation", userLocation.toHashMap().apply {
                            put("heading",heading)
                        }
                    )
                }
            }
        }
    }


    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "change#tile" -> {
                    val args = call.arguments as HashMap<String, Any>?
                    when (!args.isNullOrEmpty()) {
                        true -> {
                            val tile = CustomTile.fromMap(args)
                            if (!tile.urls.contains((map!!.tileProvider.tileSource as OnlineTileSourceBase).baseUrl)) {
                                changeLayerTile(tile = tile)
                            }
                        }

                        false -> {
                            if (map!!.tileProvider != MAPNIK) {
                                map!!.resetTileSource()
                            }
                        }
                    }
                }

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
                    } else CustomZoomButtonsController.Visibility.NEVER
                    map?.zoomController?.setVisibility(visibility)
                    result.success(null)
                }

                "currentLocation" -> {
                    when (gpsServiceManager.isProviderEnabled(GPS_PROVIDER) || gpsServiceManager.isProviderEnabled(
                        NETWORK_PROVIDER
                    )) {
                        true -> enableUserLocation()
                        else -> {
                            openSettingLocation(
                                requestCode = currentUserLocationReqCode, activity = activity
                            )
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
                    val args = call.arguments as List<*>
                    val enableStopFollow = args.first() as Boolean
                    val disableRotation = args[1] as Boolean
                    val useDirectionMarker = args[2] as Boolean
                    val anchor = args.last() as List<Double>
                    locationNewOverlay.setAnchor(anchor)
                    trackUserLocation(enableStopFollow,useDirectionMarker, disableRotation, result)
                }

                "deactivateTrackMe" -> {
                    deactivateTrackMe(result)
                }
                "startLocationUpdating" -> {
                    locationNewOverlay.startLocationUpdating()
                    result.success(null)
                }
                "stopLocationUpdating" -> {
                    locationNewOverlay.stopLocationUpdating()
                    result.success(null)
                }
                "map#center" -> {
                    result.success((map?.mapCenter as GeoPoint).toHashMap())
                }

                "map#bounds" -> {
                    getMapBounds(result = result)
                }

                "user#position" -> {
                    when (gpsServiceManager.isProviderEnabled(GPS_PROVIDER)
                            || gpsServiceManager.isProviderEnabled(
                        NETWORK_PROVIDER
                    )) {
                        true ->
                            getUserLocation(result)

                        false -> {
                            resultFlutter = result
                            openSettingLocation(
                                requestCode = getUserLocationReqCode, activity = activity
                            )

                        }
                    }
                }

                /*"user#pickPosition" -> {
                    pickPosition(call, result)
                }*/
                "moveTo#position" -> {
                    moveToSpecificPosition(call, result)
                }

                "user#removeMarkerPosition" -> {
                    removePosition(call, result)
                }

                "delete#road" -> {
                    deleteRoad(call, result)
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

                "drawRoad#manually" -> {
                    drawRoadManually(call, result)
                }

                "staticPosition" -> {
                    staticPosition(call, result)
                }

                "staticPosition#IconMarker" -> {
                    staticPositionIconMaker(call, result)
                }

                "draw#circle" -> {
                    drawShape(call, result, shapeType = Shape.circle)
                }

                "remove#circle" -> {
                    removeCircle(call, result)
                }

                "draw#rect" -> {
                    drawShape(call, result, shapeType = Shape.rect)
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

                "change#Marker" -> {
                    changePositionMarker(call, result)
                }

                "get#geopoints" -> {
                    getGeoPoints(result)
                }

                "delete#markers" -> {
                    deleteMarkers(call, result)
                }

                "toggle#Alllayer" -> {
                    toggleLayer(call, result)
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

    private fun toggleLayer(call: MethodCall, result: MethodChannel.Result) {
        val isEnabled = call.arguments as Boolean
        map!!.overlays.forEach { overlay ->
            overlay.isEnabled = isEnabled
        }
        map!!.invalidate()
        result.success(200)
    }


    private fun changeLayerTile(tile: CustomTile) {
        map?.setCustomTile(
            name = tile.sourceName,
            minZoomLvl = tile.minZoomLevel,
            maxZoomLvl = tile.maxZoomLevel,
            tileSize = tile.tileSize,
            tileExtensionFile = tile.tileFileExtension,
            baseURLs = tile.urls.toTypedArray(),
            api = tile.api,
        )

    }

    private fun getGeoPoints(result: MethodChannel.Result) {
        val list = folderMarkers.items.filterIsInstance(Marker::class.java)
        val geoPoints = emptyList<HashMap<String, Double>>().toMutableList()
        geoPoints.addAll(
            list.map {
                it.position.toHashMap()
            }.toList()
        )
        result.success(geoPoints.toList())

    }

    private fun getUserLocation(result: MethodChannel.Result, callback: VoidCallback? = null) {
        locationNewOverlay.currentUserPosition(
            result, callback, scope!!
        )
    }

    private fun changeLocationMarkers(call: MethodCall, result: MethodChannel.Result) {
        val args: HashMap<String, Any> = call.arguments as HashMap<String, Any>
        try {
            val personIcon = (args["personIcon"] as ByteArray)
            val arrowIcon = (args["arrowDirectionIcon"] as ByteArray)
            customPersonMarkerIcon = personIcon.toBitmap()
            customArrowMarkerIcon = arrowIcon.toBitmap()
            setMarkerTracking()
            mapSnapShot().setUserTrackMarker(
                personMarker = personIcon, arrowMarker = arrowIcon
            )
            result.success(null)
        } catch (e: Exception) {
            e.printStackTrace()
            result.success(e.message)

        }
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
        if (mapSnapShot.centerGeoPoint() != null && !mapSnapShot.centerGeoPoint()!!
                .eq(GeoPoint(0.0, 0.0))
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
            mapSnapShot.markers().forEach { point ->
                val icon = point.icon?.toBitmap()
                //val drawable = getDefaultIconDrawable(icon = icon, color = null)
                withContext(Main) {
                    addMarker(
                        point.geoPoint,
                        dynamicMarkerBitmap = icon,
                        animateTo = false,
                        angle = point.angle,
                        anchor = point.anchor,
                        zoom = mapSnapShot.zoomLevel(initZoom)
                    )
                }
            }
        }
        // set geo marker drawable 
        if (mapSnapShot.staticGeoPointsIcons().isNotEmpty()) {
            scope?.launch {
                mapSnapShot.staticGeoPointsIcons().forEach { (key, icon) ->
                    staticMarkerIcon[key] = icon.toBitmap()
                }
            }
        }
        // set static geo marker position in the map
        if (mapSnapShot.staticGeoPoints().isNotEmpty()) {
            resetLastGeoPointPosition(mapSnapShot)
        }
        mapSnapShot.lastCachedRoad()?.let { lastRoad ->
            if (lastRoad.roadPoints.isNotEmpty()) {
                checkRoadFolderAboveUserOverlay()
                val polyLine = Polyline(map!!)
                polyLine.setPoints(lastRoad.roadPoints)
                polyLine.setStyle(
                    color = lastRoad.roadColor ?: Color.GREEN,
                    width = lastRoad.roadWidth,
                    borderColor = lastRoad.roadBorderColor,
                    borderWidth = lastRoad.roadBorderWidth
                )
                flutterRoad = createRoad(
                    roadID = lastRoad.roadID,
                    polyLine = polyLine,
                    roadDuration = lastRoad.duration,
                    roadDistance = lastRoad.distance
                )

                map!!.invalidate()
            }

        }
        mapSnapShot.cachedRoads().forEach { road ->
            if (road.roadPoints.isNotEmpty()) {
                checkRoadFolderAboveUserOverlay()
                val polyLine = Polyline(map!!)
                polyLine.setPoints(road.roadPoints)

                val borderPolyline = Polyline(map!!)
                borderPolyline.setPoints(road.roadPoints)
                //customRoadMarkerIcon.p
                polyLine.setStyle(
                    borderColor = road.roadBorderColor,
                    borderWidth = road.roadBorderWidth,
                    color = road.roadColor ?: Color.GREEN,
                    width = road.roadWidth,
                )
                flutterRoad = createRoad(
                    polyLine = polyLine,
                    roadID = road.roadID,
                    roadDuration = road.duration,
                    roadDistance = road.distance
                )
            }
        }
        map!!.invalidate()
        clearCacheMap()
        methodChannel.invokeMethod("map#restored", null)
    }


    private fun saveCacheMap() {
        mapSnapShot().cache(
            geoPoint = map!!.mapCenter as GeoPoint,
            zoom = map!!.zoomLevelDouble,
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
        @Suppress("UNCHECKED_CAST") val args = methodCall.arguments!! as HashMap<String, Double>
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
        @Suppress("UNCHECKED_CAST") val args = methodCall.arguments!! as HashMap<String, Double>
        if (homeMarker != null) {
            folderMarkers.remove(homeMarker)
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


    private fun addMarkerManually(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as HashMap<*, *>
        val point = (args["point"] as HashMap<String, Double>).toGeoPoint()

        var bitmap = customMarkerIcon
        if (args.containsKey("icon")) {
            bitmap = (args["icon"] as ByteArray).toBitmap()

        }
        val angle = when ((args["point"] as HashMap<String, Double>).containsKey("angle")) {
            true -> (args["point"] as HashMap<String, Double>)["angle"] as Double
            else -> 0.0
        }
        val anchor = when (args.containsKey("iconAnchor")) {
            true -> Anchor(args["iconAnchor"] as HashMap<String, Any>)
            else -> null
        }
        scope?.launch {
            mapSnapShot().overlaySnapShotMarker(
                point = FlutterGeoPoint(
                    point,
                    icon = bitmap.toByteArray(), //args["icon"] as ByteArray,
                    angle = angle,
                    anchor = anchor,
                )
            )
        }
        addMarker(
            point,
            dynamicMarkerBitmap = bitmap,
            zoom = map!!.zoomLevelDouble,
            animateTo = false,
            angle = angle,
            anchor = anchor,
        )


        result.success(null)

    }

    private fun updateMarker(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as HashMap<*, *>
        val point = (args["point"] as HashMap<String, Double>).toGeoPoint()
        var bitmap = customMarkerIcon
        if (args.containsKey("icon")) {
            bitmap = (args["icon"] as ByteArray).toBitmap()
            scope?.launch {
                val oldFlutterGeoPoint =
                    mapSnapShot().markers().firstOrNull { fGeoPoint -> fGeoPoint.geoPoint == point }
                mapSnapShot().overlaySnapShotMarker(
                    point = oldFlutterGeoPoint!!.copy(
                        geoPoint = point,
                        icon = args["icon"] as ByteArray
                    )
                )
            }
        }
        val marker: FlutterMarker? =
            folderMarkers.items.filterIsInstance<FlutterMarker>().firstOrNull { marker ->
                marker.position.eq(point)
            }
        when (marker != null) {
            true -> {
                marker.setIconMaker(null, bitmap = bitmap)
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


    private fun changePositionMarker(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as HashMap<*, *>
        val oldLocation = (args["old_location"] as HashMap<String, Double>).toGeoPoint()
        val newLocation = (args["new_location"] as HashMap<String, Double>).toGeoPoint()

        val marker: FlutterMarker? =
            folderMarkers.items.filterIsInstance<FlutterMarker>().firstOrNull { marker ->
                marker.position.eq(oldLocation)
            }
        marker?.position = newLocation
        val angle = when (args.containsKey("angle") && args["angle"] != null) {
            true -> {
                val angle = args["angle"] as Double
                when (marker?.angle != angle) {
                    true -> args["angle"] as Double
                    else -> marker?.angle ?: 0.0
                }
            }

            else -> marker?.angle ?: 0.0
        }
        val anchor = when (args.containsKey("iconAnchor")) {
            true ->
                Anchor(args["iconAnchor"] as HashMap<String, Any>)

            else ->
                marker?.getOldAnchor()

        }
        val icon = when (args.containsKey("new_icon")) {
            true -> args["new_icon"] as ByteArray
            else -> mapSnapShot().markers()
                .first { p -> p.geoPoint == oldLocation }.icon as ByteArray
        }.let { byteArray ->
            scope?.launch {
                mapSnapShot().overlaySnapShotMarker(
                    point = FlutterGeoPoint(
                        geoPoint = newLocation,
                        icon = byteArray,
                        angle = angle,
                        anchor = anchor
                    ),
                    oldPoint = oldLocation,
                )
            }
            val bitmap = byteArray.toBitmap()
            bitmap
        }


        folderMarkers.items.remove(marker)
        addMarker(
            newLocation,
            dynamicMarkerBitmap = icon,
            angle = angle,
            animateTo = false,
            imageURL = null,
            anchor = anchor
        )

        map?.invalidate()
        result.success(200)
    }

    private fun addMarker(
        geoPoint: GeoPoint,
        zoom: Double = map!!.zoomLevelDouble,
        color: Int? = null,
        dynamicMarkerBitmap: Bitmap? = null,
        imageURL: String? = null,
        animateTo: Boolean = true,
        angle: Double = 0.0,
        anchor: Anchor? = null,
    ): FlutterMarker {
        map!!.controller.setZoom(zoom)
        if (animateTo) map!!.controller.animateTo(geoPoint)
        val marker = createMarker(
            geoPoint, color, angle = angle
        )
        marker.onClickListener = Marker.OnMarkerClickListener { markerP, _ ->
            val hashMap = HashMap<String, Double>()
            hashMap["lon"] = markerP!!.position.longitude
            hashMap["lat"] = markerP.position.latitude
            methodChannel.invokeMethod("receiveGeoPoint", hashMap)
            true
        }
        /*marker.longPress = { GeoPoint ->
            val hashMap = HashMap<String, Double>()
            hashMap["lon"] = GeoPoint.position.longitude
            hashMap["lat"] = GeoPoint.position.latitude
            methodChannel.invokeMethod("receiveLongPressGeoPoint", hashMap)
            true
        }*/
        when {
            dynamicMarkerBitmap != null -> {
                marker.setIconMaker(null, bitmap = dynamicMarkerBitmap, angle)
            }

            !imageURL.isNullOrEmpty() -> {
                marker.setIconMarkerFromURL(imageURL, angle)
            }

        }


        anchor?.let { markerAnchor ->
            marker.updateAnchor(anchor = markerAnchor)
        }

        folderMarkers.items.add(marker)

        map?.invalidate()
        return marker
    }

    private fun createMarker(
        geoPoint: GeoPoint,
        color: Int?,
        icon: Bitmap? = null,
        angle: Double = 0.0,
    ): FlutterMarker {
        val marker = FlutterMarker(context, map!!, geoPoint, scope)
        marker.visibilityInfoWindow(visibilityInfoWindow)

//        marker.longPress = object : LongClickHandler {
//            override fun invoke(marker: Marker): Boolean {
//                map!!.overlays.remove(marker)
//                map!!.invalidate()
//                return true
//            }
//        }
        marker.setIconMaker(color, bitmap = icon, angle)
        //marker.setPosition(geoPoint);
        return marker
    }

    private fun deleteMarkers(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as List<HashMap<String, Double>>
        val geoPoints = args.map { mapGeoP ->
            mapGeoP.toGeoPoint()
        }
        geoPoints.forEach { geoPoint ->
            deleteMarker(geoPoint)
        }
        result.success(200)
    }

    private fun setMarkerTracking() {
        locationNewOverlay.setMarkerIcon(customPersonMarkerIcon, customArrowMarkerIcon)
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

    private fun enableUserLocation() {


        //locationNewOverlay!!.setPersonIcon()
        /*if (!locationNewOverlay.isMyLocationEnabled) {
            isEnabled = true
            locationNewOverlay.enableMyLocation()
        }
        mapSnapShot().setEnableMyLocation(isEnabled)*/
        if (!map!!.overlays.contains(locationNewOverlay)) {
            map!!.overlays.add(locationNewOverlay)
        }
        locationNewOverlay.enableMyLocation()
        locationNewOverlay.runOnFirstFix {
            scope!!.launch(Main) {
                val currentPosition = locationNewOverlay.mGeoPoint

                map!!.controller.stopAnimation(true)
                map!!.controller.setCenter(currentPosition)
                //map!!.controller.animateTo(currentPosition)
            }

        }


    }

    private fun trackUserLocation(
        enableStopFollow: Boolean = false,
        useDirectionMarker: Boolean = false,
        disableRotation: Boolean = false,
        result: MethodChannel.Result
    ) {
        try {
            if (homeMarker != null) {
                folderMarkers.items.remove(homeMarker)
            }

            map?.invalidate()
            locationNewOverlay.disableRotateDirection = disableRotation
            if (!locationNewOverlay.mIsLocationEnabled) {
                isEnabled = true
                locationNewOverlay.enableMyLocation()
                mapSnapShot().setEnableMyLocation(isEnabled)
            }
            locationNewOverlay.useDirectionMarker = useDirectionMarker
            locationNewOverlay.toggleFollow(enableStopFollow)
            when {
                locationNewOverlay.mIsFollowing -> {
                    isTracking = true

                    mapSnapShot().setTrackLocation(isTracking)
                    mapSnapShot().setEnableMyLocation(isEnabled)
                    result.success(true)
                }

                else -> result.success(null)

            }
        } catch (e: Exception) {
            result.error("400", e.stackTraceToString(), "")
        }
    }

    private fun deactivateTrackMe(result: MethodChannel.Result) {
        isTracking = false
        isEnabled = false
        mapSnapShot().setTrackLocation(isTracking)
        mapSnapShot().setEnableMyLocation(isEnabled)
        try {
            locationNewOverlay.useDirectionMarker = false
            locationNewOverlay.onStopLocation()
            result.success(true)
        } catch (e: Exception) {
            result.error("400", e.stackTraceToString(), "")
        }
    }

    private fun moveToSpecificPosition(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments!! as HashMap<String, *>
        val geoPoint = GeoPoint(args["lat"]!! as Double, args["lon"]!! as Double)
        val animate = args["animate"] as Boolean? ?: false
        //map!!.controller.zoomTo(defaultZoom)
        when(animate){
            true ->map!!.controller.animateTo(geoPoint)
            false -> map!!.controller.setCenter(geoPoint)
        }

        result.success(null)
    }


    private fun drawShape(call: MethodCall, result: MethodChannel.Result, shapeType: Shape) {
        val args = call.arguments!! as HashMap<*, *>
        val geoPoint = GeoPoint(args["lat"]!! as Double, args["lon"]!! as Double)
        val key = args["key"] as String
        val colorRgb = args["color"] as List<*>

        val stokeWidth = (args["strokeWidth"] as Double).toFloat()
        val colorBorder = when (args.contains("colorBorder")) {
            true -> {
                val rgb = args["colorBorder"] as List<*>
                Color.argb(
                    Integer.parseInt(rgb[3].toString()),
                    Integer.parseInt(rgb[0].toString()),
                    Integer.parseInt(rgb[1].toString()),
                    Integer.parseInt(rgb[2].toString()),
                )
            }

            else -> null
        }
        val colorFillPaint = Color.argb(
            Integer.parseInt(colorRgb[3].toString()),
            Integer.parseInt(colorRgb[0].toString()),
            Integer.parseInt(colorRgb[1].toString()),
            Integer.parseInt(colorRgb[2].toString()),
        )

        val shapeGeos: List<GeoPoint> = when (shapeType) {
            Shape.rect -> {
                val distance = (args["distance"] as Double)
                Polygon.pointsAsRect(geoPoint, distance, distance).toList() as List<GeoPoint>
            }

            else -> {
                val radius = (args["radius"] as Double)
                Polygon.pointsAsCircle(geoPoint, radius)
            }
        }

        val p = Polygon(map!!)
        p.id = key
        p.points = shapeGeos
        p.fillPaint.color = colorFillPaint
        p.fillPaint.style = Paint.Style.FILL
        //p.fillPaint.alpha = 50
        p.outlinePaint.strokeWidth = stokeWidth
        p.outlinePaint.color = colorBorder ?: colorFillPaint
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
        if (id != null) folderRect.items.removeAll {
            (it as Polygon).id == id
        }
        else {
            folderRect.items.clear()
        }
        map!!.invalidate()
        result.success(null)
    }


    private fun removeCircle(call: MethodCall, result: MethodChannel.Result) {
        val id = call.arguments as String?
        if (id != null) folderCircles.items.removeAll {
            (it as Polygon).id == id
        }
        else {
            folderCircles.items.clear()
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
                    }, roadOption = arg.toRoadOption(),

                    wayPoints = waypoints, interestPoints = when (arg.containsKey("middlePoints")) {
                        true -> arg["middlePoints"] as List<HashMap<String, Double>>
                        false -> emptyList()
                    }.map { g ->
                        GeoPoint(g["lat"]!!, g["lon"]!!)
                    }.toList(), roadID = arg["key"] as String
                )
            )
        }

        checkRoadFolderAboveUserOverlay()

        map!!.invalidate()

        val resultRoads = emptyList<HashMap<String, Any>>().toMutableList()
        job = scope?.launch(Default) {
            withContext(IO) {
                for (config in listConfigRoad) {
                    if (roadManager == null) roadManager =
                        OSRMRoadManager(context, "json/application")
                    roadManager?.let { manager ->
                        manager.setMean(config.meanUrl)
                        var routePointsEncoded: String
                        // this part to remove marker of interest points
                        withContext(Main) {
                            folderMarkers.items.removeAll {
                                (it is FlutterMarker && config.wayPoints.contains(it.position)) || (it is FlutterMarker && config.interestPoints.contains(
                                    it.position
                                ))
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
                                polyLine.setStyle(
                                    borderColor = config.roadOption.roadBorderColor,
                                    borderWidth = config.roadOption.roadBorderWidth,
                                    color = config.roadOption.roadColor ?: Color.GREEN,
                                    width = config.roadOption.roadWidth,
                                )
                                createRoad(
                                    polyLine = polyLine,
                                    roadID = config.roadID,
                                    roadDuration = road.mDuration,
                                    roadDistance = road.mLength
                                )
                                val instructions = road.mNodes.toRoadInstruction()
                                mapSnapShot().cacheListRoad(
                                    RoadSnapShot(
                                        roadPoints = road.mRouteHigh,
                                        roadColor = config.roadOption.roadColor,
                                        roadWidth = config.roadOption.roadWidth,
                                        roadBorderColor = config.roadOption.roadBorderColor,
                                        roadBorderWidth = config.roadOption.roadBorderWidth,
                                        roadID = config.roadID,
                                        duration = road.mDuration,
                                        distance = road.mLength,
                                        instructions = instructions
                                    )
                                )
                                resultRoads.add(
                                    road.toMap(
                                        config.roadID, routePointsEncoded, instructions
                                    )
                                )
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
            map!!.overlays.add(1, folderRoad)
        }
    }

    private fun deleteRoad(call: MethodCall, result: MethodChannel.Result) {
        val roadKey = call.arguments as String?
        when (roadKey != null) {
            true -> {
                val road = folderRoad.items.map {
                    it as FlutterRoad
                }.first { road ->
                    road.idRoad == roadKey
                }
                if (flutterRoad?.idRoad == roadKey) {
                    mapSnapShot().clearCachedRoad()
                    flutterRoad = null
                }
                folderRoad.items.remove(road)
                map?.invalidate()
                map?.invalidate()

            }

            else -> {
                if (folderRoad.items.isNotEmpty()) {
                    mapSnapShot().clearCachedRoad()
                    folderRoad.items.clear()
                    map?.invalidate()
                    flutterRoad = null
                }
            }
        }

        result.success(null)
    }


    private fun drawRoad(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments!! as HashMap<String, Any>


        val meanUrl = when (args["roadType"] as String) {
            "car" -> OSRMRoadManager.MEAN_BY_CAR
            "bike" -> OSRMRoadManager.MEAN_BY_BIKE
            "foot" -> OSRMRoadManager.MEAN_BY_FOOT
            else -> OSRMRoadManager.MEAN_BY_CAR
        }
        val zoomToRegion = args["zoomIntoRegion"] as Boolean
        val roadConfig = args.toRoadConfig()
        checkRoadFolderAboveUserOverlay()

        var instructions = emptyList<RoadGeoPointInstruction>()
        if (roadManager == null) roadManager = OSRMRoadManager(context, "json/application")
        roadManager?.let { manager ->
            manager.setMean(meanUrl)
            var routePointsEncoded = ""
            job = scope?.launch(Default) {


                val roadPoints = ArrayList(roadConfig.wayPoints)
                if (roadConfig.interestPoints.isNotEmpty()) {
                    roadPoints.addAll(1, roadConfig.interestPoints)
                }
                val road = manager.getRoad(roadPoints)
                withContext(Main) {
                    if (road.mRouteHigh.size > 2) {
                        routePointsEncoded = PolylineEncoder.encode(road.mRouteHigh, 10)
                        val polyLine = Polyline(map!!, false, false).apply {
                            this.setStyle(
                                borderColor = roadConfig.roadOption.roadBorderColor,
                                borderWidth = roadConfig.roadOption.roadBorderWidth,
                                color = roadConfig.roadOption.roadColor ?: Color.GREEN,
                                width = roadConfig.roadOption.roadWidth,
                            )
                            this.setPoints(RoadManager.buildRoadOverlay(road).actualPoints)

                        }
                        flutterRoad = createRoad(
                            polyLine = polyLine,
                            roadID = roadConfig.roadID,
                            roadDuration = road.mDuration,
                            roadDistance = road.mLength

                        )
                        instructions = road.mNodes.toRoadInstruction()
                        mapSnapShot().cacheRoad(
                            RoadSnapShot(
                                roadPoints = road.mRouteHigh,
                                roadColor = roadConfig.roadOption.roadColor ?: Color.GREEN,
                                roadWidth = roadConfig.roadOption.roadWidth,
                                roadBorderWidth = roadConfig.roadOption.roadBorderWidth,
                                roadBorderColor = roadConfig.roadOption.roadBorderColor,
                                roadID = roadConfig.roadID,
                                duration = road.mDuration,
                                distance = road.mLength,
                                instructions = instructions
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
                    result.success(
                        road.toMap(
                            roadConfig.roadID, routePointsEncoded, instructions
                        )
                    )
                }

            }
        }
    }


    private fun drawRoadManually(call: MethodCall, result: MethodChannel.Result) {
        val args: HashMap<String, Any> = call.arguments as HashMap<String, Any>
        val roadId = args["key"] as String
        val encodedWayPoints = (args["road"] as String)
        val roadColor = (args["roadColor"] as List<Int>).toRGB()
        val roadWidth = (args["roadWidth"] as Double).toFloat()
        val roadBorderWidth = (args["roadBorderWidth"] as Double).toFloat()
        val roadBorderColor = (args["roadBorderColor"] as List<Int>).toRGB()
        val zoomToRegion = args["zoomIntoRegion"] as Boolean

        checkRoadFolderAboveUserOverlay()


        val route = PolylineEncoder.decode(encodedWayPoints, 10, false)


        val polyLine = Polyline(map!!)
        polyLine.setPoints(route)
        polyLine.setStyle(
            borderWidth = roadBorderWidth,
            borderColor = roadBorderColor,
            color = roadColor,
            width = roadWidth
        )

        createRoad(
            roadID = roadId,
            polyLine = polyLine,
        )

        mapSnapShot().cacheRoad(
            RoadSnapShot(
                roadID = roadId,
                roadPoints = route,
                roadColor = roadColor,
                roadBorderColor = roadColor,
                roadWidth = roadWidth,
                roadBorderWidth = roadWidth,
                duration = 0.0,
                distance = 0.0,
                instructions = emptyList()
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
        roadID: String,
        polyLine: Polyline,
        roadDuration: Double = 0.0,
        roadDistance: Double = 0.0,

        ): FlutterRoad {


        val flutterRoad = FlutterRoad(
            roadID,
            roadDistance = roadDistance,
            roadDuration = roadDuration,
        )
        flutterRoad.let { roadF ->
            roadF.road = polyLine
            //roadF.road.setOnClickListener { polyline, mapView, eventPos ->  }
            roadF.onRoadClickListener = object : FlutterRoad.OnRoadClickListener {
                override fun onClick(road: FlutterRoad, geoPointClicked: GeoPoint) {
                    val map = HashMap<String, Any>()
                    map["roadPoints"] = road.road?.actualPoints?.map {
                        it.toHashMap()
                    } ?: emptyList<Any>()
                    map["distance"] = road.roadDistance
                    map["duration"] = road.roadDuration
                    map["key"] = road.idRoad
                    methodChannel.invokeMethod("receiveRoad", map)

                }

            }
            folderRoad.items.add(roadF)
        }

        return flutterRoad
    }

    private fun staticPositionIconMaker(call: MethodCall, result: MethodChannel.Result) {
        val hashMap: HashMap<String, Any> = call.arguments as HashMap<String, Any>

        try {
            val key = (hashMap["id"] as String)
            val bytes = (hashMap["bitmap"] as ByteArray)
            val bitmap = bytes.toBitmap()
            val refresh = hashMap["refresh"] as Boolean
            staticMarkerIcon[key] = bitmap
            mapSnapShot().addToIconsStaticGeoPoints(key, bytes)
            scope?.launch {
                if (staticPoints.containsKey(key) && refresh) {
                    showStaticPosition(
                        key, mapSnapShot().staticGeoPoints()[key]!!.second
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
            if (folderStaticPosition.items.isNotEmpty()) folderStaticPosition.remove(
                folderStaticPosition.items.first {
                    (it as FolderOverlay).name?.equals(id) == true
                })
        } else {
            staticPoints[id!!] = geoPoints
        }
        showStaticPosition(id!!, angleGeoPoints.toList())
        scope?.launch {
            mapSnapShot().addToStaticGeoPoints(
                id, Pair(
                    geoPoints.toList(),
                    angleGeoPoints.toList(),
                )
            )
        }
        result.success(null)
    }


    private fun changeIcon(call: MethodCall, result: MethodChannel.Result) {
        try {
            customMarkerIcon = (call.arguments as ByteArray).toBitmap()
            //customMarkerIcon.recycle();
            result.success(null)
        } catch (e: Exception) {
            Log.d("err", e.stackTraceToString())
            customMarkerIcon = null
            result.error("500", "Cannot make markerIcon custom", "")
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
                mapSnapShot().removeMarkersFromSnapShot(removedPoints = geoMarkers.map {
                    it.position
                })
            }
            map!!.overlays.remove(folderMarkers)
            map!!.overlays.add(folderMarkers)
            map!!.invalidate()
        }

    }

    private fun showStaticPosition(idStaticPosition: String, angles: List<Double> = emptyList()) {

        var overlay: FolderOverlay? = folderStaticPosition.items.firstOrNull {
            (it as FolderOverlay).name?.equals(idStaticPosition) == true
        } as FolderOverlay?

        overlay?.items?.clear()
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
            marker.onClickListener = Marker.OnMarkerClickListener { markerP, _ ->
                val hashMap = HashMap<String, Double>()
                hashMap["lon"] = markerP!!.position.longitude
                hashMap["lat"] = markerP.position.latitude
                methodChannel.invokeMethod("receiveGeoPoint", hashMap)
                true
            }
            if (staticMarkerIcon.isNotEmpty() && staticMarkerIcon.containsKey(idStaticPosition)) {
                marker.setIconMaker(
                    null, staticMarkerIcon[idStaticPosition], angle = when (angles.isNotEmpty()) {
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
        if (!mapSnapShot().advancedPicker()) {
            map!!.overlays.remove(folderStaticPosition)
            map!!.overlays.add(folderStaticPosition)
        }
        map!!.invalidate()

    }


    override fun getView(): View {
        return mainLinearLayout
    }

    override fun dispose() {
        locationNewOverlay.disableFollowLocation()
        locationNewOverlay.onPause()
        job?.let {
            if (it.isActive) {
                it.cancel()
            }
        }
        mainLinearLayout.removeAllViews()
        providerLifecycle.getOSMLifecycle()?.removeObserver(this)

        //clearCacheMap()
        //map!!.onDetach()
        // map = null
    }

    override fun onFlutterViewAttached(flutterView: View) {
        //   map!!.onAttachedToWindow()
        if (map == null) {
            val prefs: SharedPreferences = PreferenceManager.getDefaultSharedPreferences(context)
            Configuration.getInstance()
                .load(context, prefs)
//            map?.forceLayout()
        }

    }


    override fun onFlutterViewDetached() {
        //map!!.onDetach()
        staticMarkerIcon.clear()
        staticPoints.clear()
        customMarkerIcon = null
    }


    override fun onSaveInstanceState(bundle: Bundle) {
        bundle.putString("center", "${map!!.mapCenter.latitude},${map!!.mapCenter.longitude}")
        bundle.putString("zoom", map!!.zoomLevelDouble.toString())
    }

    override fun onRestoreInstanceState(bundle: Bundle?) {
        Log.d("osm data", bundle?.getString("center") ?: "")
    }

    override fun onCreate(owner: LifecycleOwner) {
        super.onCreate(owner)
        FlutterOsmPlugin.state.set(CREATED)
        methodChannel = MethodChannel(binaryMessenger, "plugins.dali.hamza/osmview_${id}")
        methodChannel.setMethodCallHandler(this)
        //eventChannel = EventChannel(binaryMessenger, "plugins.dali.hamza/osmview_stream_${id}")
        //eventChannel.setStreamHandler(this)
        //methodChannel.invokeMethod("map#init", true)


        scope = owner.lifecycle.coroutineScope
        folderStaticPosition.name = Constants.nameFolderStatic
        Configuration.getInstance().load(
            context, PreferenceManager.getDefaultSharedPreferences(context)
        )
        initMap()
        // map!!.forceLayout()
        Log.e("osm", "osm flutter plugin create")

    }


    override fun onStart(owner: LifecycleOwner) {
        super.onStart(owner)
        FlutterOsmPlugin.state.set(STARTED)
        Log.e("osm", "osm flutter plugin start")
        activity = FlutterOsmPlugin.pluginBinding!!.activity
        FlutterOsmPlugin.pluginBinding!!.addActivityResultListener(this)
//        context.applicationContext.registerReceiver(
//            checkGPSServiceBroadcast,
//            IntentFilter(LocationManager.PROVIDERS_CHANGED_ACTION)
//        )

    }


    override fun onResume(owner: LifecycleOwner) {
        super.onResume(owner)
        FlutterOsmPlugin.state.set(FlutterOsmPlugin.RESUMED)
        Log.e("osm", "osm flutter plugin resume")
        if (map == null) {
            initMap()
        }
        map?.onResume()
        locationNewOverlay.onResume()
    }

    override fun onPause(owner: LifecycleOwner) {
        super.onPause(owner)
        FlutterOsmPlugin.state.set(PAUSED)
        map?.let {
            locationNewOverlay.disableFollowLocation()
            locationNewOverlay.onPause()
        }
        map?.onPause()
        skipCheckLocation = false
        Log.e("osm", "osm flutter plugin pause")

    }

    override fun onStop(owner: LifecycleOwner) {
        super.onStop(owner)
        FlutterOsmPlugin.state.set(STOPPED)
        Log.e("osm", "osm flutter plugin stopped")
        //context.applicationContext.unregisterReceiver(checkGPSServiceBroadcast)
        job?.let {
            if (it.isActive) {
                it.cancel()
            }
        }

        job = null
    }

    override fun onDestroy(owner: LifecycleOwner) {
        super.onDestroy(owner)
        locationNewOverlay.onDestroy()
        FlutterOsmPlugin.pluginBinding!!.removeActivityResultListener(this)
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


    private fun resetLastGeoPointPosition(mapSnapShot: MapSnapShot) {
        scope?.launch {
            withContext(Default) {
                mapSnapShot.staticGeoPointsIcons().forEach { (key, icon) ->
                    staticMarkerIcon[key] = icon.toBitmap()
                }
            }
            mapSnapShot.staticGeoPoints().forEach { staticPoint ->
                staticPoints[staticPoint.key] = staticPoint.value.first.toMutableList()
                withContext(Main) {
                    showStaticPosition(
                        staticPoint.key, staticPoint.value.second.toList()
                    )
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            getUserLocationReqCode -> {
                skipCheckLocation = true
                if (gpsServiceManager.isProviderEnabled(GPS_PROVIDER) || gpsServiceManager.isProviderEnabled(
                        NETWORK_PROVIDER
                    )
                ) {
                    if (resultFlutter != null) {
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


}


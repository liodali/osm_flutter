package hamza.dali.flutter_osm_plugin

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Color
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
import hamza.dali.flutter_osm_plugin.models.Anchor
import hamza.dali.flutter_osm_plugin.models.CustomTile
import hamza.dali.flutter_osm_plugin.models.FlutterGeoPoint
import hamza.dali.flutter_osm_plugin.models.FlutterMarker
import hamza.dali.flutter_osm_plugin.models.FlutterRoad
import hamza.dali.flutter_osm_plugin.models.OSMShape
import hamza.dali.flutter_osm_plugin.models.RoadConfig
import hamza.dali.flutter_osm_plugin.models.RoadGeoPointInstruction
import hamza.dali.flutter_osm_plugin.models.Shape
import hamza.dali.flutter_osm_plugin.models.toRoadConfig
import hamza.dali.flutter_osm_plugin.models.toRoadInstruction
import hamza.dali.flutter_osm_plugin.models.toRoadOption
import hamza.dali.flutter_osm_plugin.overlays.CustomLocationManager
import hamza.dali.flutter_osm_plugin.utilities.Constants
import hamza.dali.flutter_osm_plugin.utilities.StaticOverlayManager
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
import kotlin.collections.set


typealias VoidCallback = () -> Unit


fun FlutterOsmView.configZoomMap(call: MethodCall, result: MethodChannel.Result) {
    val args = call.arguments as HashMap<*, *>
    this.mapView?.minZoomLevel = (args["minZoomLevel"] as Double)
    this.mapView?.maxZoomLevel = (args["maxZoomLevel"] as Double)
    stepZoom = args["stepZoom"] as Double
    initZoom = args["initZoom"] as Double


    result.success(200)
}

fun FlutterOsmView.getZoom(result: MethodChannel.Result) {
    try {
        result.success(this.mapView!!.zoomLevelDouble)
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
    private val isEnabledRotationGesture: Boolean = false,
    private val isStaticMap: Boolean = false
) : OnSaveInstanceStateListener, PlatformView, MethodCallHandler,
    PluginRegistry.ActivityResultListener, DefaultLifecycleObserver {


    internal var mapView: MapView? = null
    private lateinit var locationNewOverlay: CustomLocationManager
    private var customMarkerIcon: Bitmap? = null
    private var customPersonMarkerIcon: Bitmap? = null
    private var customArrowMarkerIcon: Bitmap? = null
    private var staticMarkerIcon: HashMap<String, Bitmap> = HashMap()
    private val staticPoints: HashMap<String, MutableList<FlutterGeoPoint>> = HashMap()
    private var homeMarker: FlutterMarker? = null
    private val folderStaticPosition: FolderOverlay by lazy {
        FolderOverlay()
    }
    private val folderShape: FolderOverlay by lazy {
        FolderOverlay().apply {
            name = Constants.shapesNames
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
        RotationGestureOverlay(mapView!!).apply {
            this.isEnabled = isEnabledRotationGesture && !isStaticMap
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
    private val markerIconsCache: MutableMap<GeoPoint, ByteArray?> =
        emptyMap<GeoPoint, ByteArray>().toMutableMap()

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
                hashMap["bounding"] = mapView?.boundingBox?.toHashMap()
                hashMap["center"] = (mapView?.mapCenter as GeoPoint?)?.toHashMap()
                methodChannel.invokeMethod("receiveRegionIsChanging", hashMap)

                return !isStaticMap
            }

            override fun onZoom(event: ZoomEvent?): Boolean {
                val hashMap = HashMap<String, Any?>()
                hashMap["bounding"] = mapView?.boundingBox?.toHashMap()
                hashMap["center"] = (mapView?.mapCenter as GeoPoint?)?.toHashMap()
                methodChannel.invokeMethod("receiveRegionIsChanging", hashMap)
                return !isStaticMap
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

    @SuppressLint("ClickableViewAccessibility")
    private fun initMap() {


        mapView = MapView(context)

        mapView?.layoutParams = MapView.LayoutParams(
            LinearLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT)
        )
        mapView?.isTilesScaledToDpi = true
        mapView?.setMultiTouchControls(!isStaticMap)
        when {
            customTile != null -> {
                mapView?.setCustomTile(
                    name = customTile.sourceName,
                    minZoomLvl = customTile.minZoomLevel,
                    maxZoomLvl = customTile.maxZoomLevel,
                    tileSize = customTile.tileSize,
                    tileExtensionFile = customTile.tileFileExtension,
                    baseURLs = customTile.urls.toTypedArray(),
                    api = customTile.api,
                )
            }

            else -> mapView?.setTileSource(MAPNIK)
        }

        mapView?.isVerticalMapRepetitionEnabled = false
        mapView?.isHorizontalMapRepetitionEnabled = false
        mapView?.setScrollableAreaLimitLatitude(
            MapView.getTileSystem().maxLatitude,
            MapView.getTileSystem().minLatitude,
            0
        )
        mapView?.zoomController?.setVisibility(CustomZoomButtonsController.Visibility.NEVER)
        //
        mapView?.minZoomLevel = 2.0

        mapView?.setExpectedCenter(GeoPoint(0.0, 0.0))
        mapView?.controller?.setZoom(2.0)


        mapView?.addMapListener(mapListener)
        if (isStaticMap) {
            mapView?.isFlingEnabled = false
            mapView?.overlayManager = StaticOverlayManager(mapView!!.mapOverlay)
        }



        mapView?.overlayManager?.add(0, staticOverlayListener)
        mapView?.overlayManager?.add(folderMarkers)
        mapView?.overlayManager?.add(mRotationGestureOverlay)
        mainLinearLayout.addView(mapView)
        mainLinearLayout.setOnTouchListener { _, _ -> !isStaticMap }
        /// init LocationManager
        locationNewOverlay = CustomLocationManager(mapView!!)

        locationNewOverlay.onChangedLocation { userLocation, heading ->
            scope?.launch {
                withContext(Main) {
                    methodChannel.invokeMethod(
                        "receiveUserLocation", userLocation.toHashMap().apply {
                            put("heading", heading)
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
                            if (!tile.urls.contains((mapView?.tileProvider?.tileSource as OnlineTileSourceBase).baseUrl)) {
                                changeLayerTile(tile = tile)
                            }
                        }

                        false -> {
                            if (mapView?.tileProvider != MAPNIK) {
                                mapView?.resetTileSource()
                            }
                        }
                    }
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
                    mapView?.zoomController?.setVisibility(visibility)
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
                    trackUserLocation(enableStopFollow, useDirectionMarker, disableRotation, result)
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
                    result.success((mapView?.mapCenter as GeoPoint).toHashMap())
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
                    drawShape(call, result)
                }

                "remove#circle" -> {
                    removeCircle(call, result)
                }

                "draw#rect" -> {
                    drawShape(call, result, )
                }

                "remove#rect" -> {
                    removeRect(call, result)
                }

                "clear#shapes" -> {
                    folderShape.items.clear()
                    mapView?.invalidate()
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
        mapView?.overlays?.forEach { overlay ->
            overlay.isEnabled = isEnabled
        }
        mapView?.invalidate()
        result.success(200)
    }


    private fun changeLayerTile(tile: CustomTile) {
        mapView?.setCustomTile(
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
        val list = folderMarkers.items.filterIsInstance<Marker>()
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

        mapView?.zoomToBoundingBox(
            box, true, args["padding"]!! as Int
        )
        result.success(null)
    }

    private fun getMapBounds(result: MethodChannel.Result) {
        val bounds = mapView?.boundingBox ?: boundingWorldBox
        result.success(bounds.toHashMap())
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
                val zoom = mapView!!.zoomLevelDouble + zoomInput
                mapView?.controller?.setZoom(zoom)
            }

            false -> {
                if (args.containsKey("zoomLevel")) {
                    val level = args["zoomLevel"] as Double
                    mapView?.controller?.setZoom(level)
                }

            }
        }

        result.success(null)
    }

    private fun initPosition(methodCall: MethodCall, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST") val args = methodCall.arguments!! as HashMap<String, Double>
        val geoPoint = GeoPoint(args["lat"]!!, args["lon"]!!)
        val zoom = initZoom
        mapView?.controller?.setZoom(zoom)
        mapView?.controller?.setCenter(geoPoint)
        methodChannel.invokeMethod("map#init", true)

        result.success(null)
    }

    private fun changePosition(methodCall: MethodCall, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST") val args = methodCall.arguments!! as HashMap<String, Double>
        if (homeMarker != null) {
            folderMarkers.remove(homeMarker)
        }
        //map!!.overlays.clear()
        val geoPoint = GeoPoint(args["lat"]!!, args["lon"]!!)
        val zoom = when (mapView?.zoomLevelDouble) {
            0.0 -> initZoom
            else -> mapView!!.zoomLevelDouble
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
        markerIconsCache[point] = bitmap.toByteArray() ?: customMarkerIcon?.toByteArray()
        addMarker(
            point,
            dynamicMarkerBitmap = bitmap,
            zoom = mapView!!.zoomLevelDouble,
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
                    markerIconsCache.asSequence()
                        .firstOrNull { fGeoPoint -> fGeoPoint.key == point }
                markerIconsCache[point] = args["icon"] as ByteArray

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
                mapView?.invalidate()
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
            else -> markerIconsCache.asSequence().first {
                it.key == oldLocation
            }.value
        }.let { byteArray ->
            scope?.launch {
                markerIconsCache[newLocation] = byteArray
                markerIconsCache.remove(oldLocation)
            }
            val bitmap = byteArray?.toBitmap()
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

        mapView?.invalidate()
        result.success(200)
    }

    private fun addMarker(
        geoPoint: GeoPoint,
        zoom: Double = mapView!!.zoomLevelDouble,
        color: Int? = null,
        dynamicMarkerBitmap: Bitmap? = null,
        imageURL: String? = null,
        animateTo: Boolean = true,
        angle: Double = 0.0,
        anchor: Anchor? = null,
    ): FlutterMarker {
        mapView?.controller?.setZoom(zoom)
        if (animateTo) mapView?.controller?.animateTo(geoPoint)
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
        marker.longPress = { gP ->
            val hashMap = HashMap<String, Double>()
            hashMap["lon"] = gP.position.longitude
            hashMap["lat"] = gP.position.latitude
            methodChannel.invokeMethod("receiveGeoPointLongPress", hashMap)
            true
        }
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

        mapView?.invalidate()
        return marker
    }

    private fun createMarker(
        geoPoint: GeoPoint,
        color: Int?,
        icon: Bitmap? = null,
        angle: Double = 0.0,
    ): FlutterMarker {
        val marker = FlutterMarker(context, mapView!!, geoPoint, scope)
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
        mapView?.setScrollableAreaLimitDouble(boundingWorldBox)
        result.success(200)
    }

    private fun limitCameraArea(call: MethodCall, result: MethodChannel.Result) {
        val list = call.arguments as List<Double>
        val box = BoundingBox(
            list[0], list[1], list[2], list[3]
        )
        mapView?.setScrollableAreaLimitDouble(box)

        result.success(200)
    }

    private fun mapOrientation(call: MethodCall, result: MethodChannel.Result) {
        //mapView?.mapOrientation = (call.arguments as Double?)?.toFloat() ?: 0f
        mapView?.controller?.animateTo(
            mapView?.mapCenter,
            mapView?.zoomLevelDouble,
            null,
            (call.arguments as Double?)?.toFloat() ?: 0f
        )

        mapView?.invalidate()
        result.success(null)
    }

    private fun enableUserLocation() {


        //locationNewOverlay!!.setPersonIcon()
        /*if (!locationNewOverlay.isMyLocationEnabled) {
            isEnabled = true
            locationNewOverlay.enableMyLocation()
        }
        mapSnapShot().setEnableMyLocation(isEnabled)*/
        if (mapView != null  && !mapView!!.overlays.contains(locationNewOverlay)) {
            mapView!!.overlays.add(locationNewOverlay)
        }
        locationNewOverlay.enableMyLocation()
        locationNewOverlay.runOnFirstFix {
            scope!!.launch(Main) {
                val currentPosition = locationNewOverlay.mGeoPoint

                mapView?.controller?.stopAnimation(true)
                mapView?.controller?.setCenter(currentPosition)
                //mapView?.controller.animateTo(currentPosition)
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

            mapView?.invalidate()
            locationNewOverlay.disableRotateDirection = disableRotation
            if (!locationNewOverlay.mIsLocationEnabled) {
                isEnabled = true
                locationNewOverlay.enableMyLocation()

            }
            locationNewOverlay.useDirectionMarker = useDirectionMarker
            locationNewOverlay.toggleFollow(enableStopFollow)
            when {
                locationNewOverlay.mIsFollowing -> {
                    isTracking = true
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
        //mapView?.controller.zoomTo(defaultZoom)
        when (animate) {
            true -> mapView?.controller?.animateTo(geoPoint)
            false -> mapView?.controller?.setCenter(geoPoint)
        }

        result.success(null)
    }


    private fun drawShape(call: MethodCall, result: MethodChannel.Result,) {
        val args = call.arguments!! as HashMap<*, *>
        val key = args["key"] as String
        val shape = OSMShape(args, mapView!!)
        folderShape.items.removeAll {
            it is OSMShape && it.id == key
        }
        folderShape.items.add(shape)
        if (mapView != null && !mapView!!.overlays.contains(folderShape)) {
            mapView!!.overlays.add(1,folderShape)
        }
        mapView?.invalidate()
        result.success(null)
    }

    private fun removeRect(call: MethodCall, result: MethodChannel.Result) {
        val id = call.arguments as String?
        when {
            id != null -> folderShape.items.removeAll {
                (it as Polygon).id == id
            }

            else -> folderShape.items.removeAll { shape ->
                shape is OSMShape && shape.shape == Shape.POLYGON
            }
        }
        mapView?.invalidate()
        result.success(null)
    }


    private fun removeCircle(call: MethodCall, result: MethodChannel.Result) {
        val id = call.arguments as String?
        when {
            id != null -> folderShape.items.removeAll {
                (it as Polygon).id == id
            }

            else -> folderShape.items.removeAll { shape ->
               shape is OSMShape && shape.shape == Shape.CIRCLE
            }
        }
        mapView?.invalidate()
        result.success(null)
    }


    private fun clearAllRoad(result: MethodChannel.Result) {
        folderRoad.items.clear()

        mapView?.invalidate()
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

        mapView?.invalidate()

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
                mapView?.invalidate()
                result.success(resultRoads.toList())
            }
        }

    }

    private fun checkRoadFolderAboveUserOverlay() {
        if (mapView!= null && !mapView!!.overlays.contains(folderRoad)) {
            mapView!!.overlays.add(1, folderRoad)
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
                    flutterRoad = null
                }
                folderRoad.items.remove(road)
                mapView?.invalidate()

            }

            else -> {
                if (folderRoad.items.isNotEmpty()) {
                    folderRoad.items.clear()
                    mapView?.invalidate()
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
                        mapView?.let {
                            val polyLine = Polyline(mapView!!, false, false).apply {
                                setStyle(
                                    borderColor = roadConfig.roadOption.roadBorderColor,
                                    borderWidth = roadConfig.roadOption.roadBorderWidth,
                                    color = roadConfig.roadOption.roadColor ?: Color.GREEN,
                                    width = roadConfig.roadOption.roadWidth,
                                    isDottedPolyline = roadConfig.roadOption.isDotted
                                )
                                setPoints(RoadManager.buildRoadOverlay(road).actualPoints)

                            }
                            flutterRoad = createRoad(
                                polyLine = polyLine,
                                roadID = roadConfig.roadID,
                                roadDuration = road.mDuration,
                                roadDistance = road.mLength

                            )
                            instructions = road.mNodes.toRoadInstruction()

                            if (zoomToRegion) {
                                mapView?.zoomToBoundingBox(
                                    BoundingBox.fromGeoPoints(road.mRouteHigh),
                                    true,
                                    64,
                                )
                            }

                            mapView?.invalidate()
                        }


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
        val roadBorderWidth = (args["roadBorderWidth"] as Double? ?: 0).toFloat()
        val roadBorderColor = (args["roadBorderColor"] as List<Int>?)?.toRGB() ?: 0
        val zoomToRegion = args["zoomIntoRegion"] as Boolean

        checkRoadFolderAboveUserOverlay()


        val route = PolylineEncoder.decode(encodedWayPoints, 10, false)

        mapView?.let {
            val polyLine = Polyline(mapView!!)
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


            if (zoomToRegion) {
                mapView?.zoomToBoundingBox(
                    BoundingBox.fromGeoPoints(polyLine.actualPoints),
                    true,
                    64,
                )
            }
            mapView?.invalidate()
            result.success(null)
        }?: result.error("ROAD_DRAWING_FAILED", "Failed to draw road manually", null)

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

            if (staticPoints.containsKey(key) && refresh) {
                showStaticPosition(
                    key,
                )
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
        val geoPoints: MutableList<FlutterGeoPoint> = mutableListOf()
        for (geoPointMap in points!!) {
            val geoPoint = GeoPoint(geoPointMap["lat"]!!, geoPointMap["lon"]!!)
            val angle = when (geoPointMap.containsKey("angle")) {
                true -> geoPointMap["angle"] ?: 0.0
                else -> 0.0
            }
            geoPoints.add(FlutterGeoPoint(geoPoint, angle))
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
        showStaticPosition(id!!)

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
                geoMarkers.forEach {
                    markerIconsCache.remove(it.position)
                }
            }
            mapView?.overlays?.remove(folderMarkers)
            mapView?.overlays?.add(folderMarkers)
            mapView?.invalidate()
        }

    }

    private fun showStaticPosition(idStaticPosition: String) {

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
            val marker = FlutterMarker(context, mapView!!, scope)
            marker.position = geoPoint.geoPoint

            marker.defaultInfoWindow()
            marker.visibilityInfoWindow(visibilityInfoWindow)
            marker.onClickListener = Marker.OnMarkerClickListener { markerP, _ ->
                val hashMap = HashMap<String, Double>()
                hashMap["lon"] = markerP!!.position.longitude
                hashMap["lat"] = markerP.position.latitude
                methodChannel.invokeMethod("receiveGeoPoint", hashMap)
                true
            }
            marker.longPress = { gP ->
                val hashMap = HashMap<String, Double>()
                hashMap["lon"] = gP.position.longitude
                hashMap["lat"] = gP.position.latitude
                methodChannel.invokeMethod("receiveGeoPointLongPress", hashMap)
                true
            }
            if (staticMarkerIcon.isNotEmpty() && staticMarkerIcon.containsKey(idStaticPosition)) {
                marker.setIconMaker(
                    null, staticMarkerIcon[idStaticPosition], angle = geoPoint.angle
                )
            } else {
                marker.setIconMaker(null, null)
            }
            overlay.add(marker)
        }
        folderStaticPosition.add(overlay)
        if ( mapView != null && !mapView!!.overlays.contains(folderStaticPosition)) {
            mapView!!.overlays.add(folderStaticPosition)
        }
        mapView?.invalidate()

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
        //mapView?.onDetach()
        // map = null
    }

    override fun onFlutterViewAttached(flutterView: View) {
        //   mapView?.onAttachedToWindow()
        if (mapView == null) {
            val prefs: SharedPreferences = PreferenceManager.getDefaultSharedPreferences(context)
            Configuration.getInstance()
                .load(context, prefs)
        }

    }


    override fun onFlutterViewDetached() {
        //mapView?.onDetach()
        staticMarkerIcon.clear()
        staticPoints.clear()
        customMarkerIcon = null
    }


    override fun onSaveInstanceState(bundle: Bundle) {
        mapView?.let {
            bundle.putString("center", "${mapView!!.mapCenter.latitude},${mapView!!.mapCenter.longitude}")
            bundle.putString("zoom", mapView!!.zoomLevelDouble.toString())
        }
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
        // mapView?.forceLayout()
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
        if (mapView == null) {
            initMap()
        }
        mapView?.onResume()
        locationNewOverlay.onResume()
    }

    override fun onPause(owner: LifecycleOwner) {
        super.onPause(owner)
        FlutterOsmPlugin.state.set(PAUSED)
        mapView?.let {
            locationNewOverlay.disableFollowLocation()
            locationNewOverlay.onPause()
        }
        mapView?.onPause()
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
        //mapView?.onDetach()
        methodChannel.setMethodCallHandler(null)

        //configuration!!.osmdroidTileCache.delete()
        //configuration = null
        //eventChannel.setStreamHandler(null)
        mapView = null
        FlutterOsmPlugin.state.set(DESTROYED)

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


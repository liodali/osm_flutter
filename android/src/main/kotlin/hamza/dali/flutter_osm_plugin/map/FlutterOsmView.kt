package hamza.dali.flutter_osm_plugin.map

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
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.CREATED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.DESTROYED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.PAUSED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.STARTED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.STOPPED
import hamza.dali.flutter_osm_plugin.ProviderLifecycle
import hamza.dali.flutter_osm_plugin.location.OSMLocationManager
import hamza.dali.flutter_osm_plugin.models.Anchor
import hamza.dali.flutter_osm_plugin.models.CustomTile
import hamza.dali.flutter_osm_plugin.models.FlutterGeoPoint
import hamza.dali.flutter_osm_plugin.models.FlutterMarker
import hamza.dali.flutter_osm_plugin.models.FlutterOSMRoad
import hamza.dali.flutter_osm_plugin.models.FlutterOSMRoadFolder
import hamza.dali.flutter_osm_plugin.models.FlutterRoad
import hamza.dali.flutter_osm_plugin.models.OSMShape
import hamza.dali.flutter_osm_plugin.models.Shape
import hamza.dali.flutter_osm_plugin.models.VoidCallback
import hamza.dali.flutter_osm_plugin.models.toRoadOption
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
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding.OnSaveInstanceStateListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers.Main
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
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
import kotlin.collections.get
import kotlin.collections.set


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
    private val isEnabledRotationGesture: Boolean = false,
    private val isStaticMap: Boolean = false
) : OnSaveInstanceStateListener, MethodCallHandler,
    DefaultLifecycleObserver, OSM {


    internal var map: MapView? = null
    private lateinit var locationNewOverlay: OSMLocationManager
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

    private var flutterRoad: FlutterOSMRoadFolder? = null
    private var job: Job? = null
    private var scope: CoroutineScope? = null
    private var skipCheckLocation: Boolean = false
    private var resultFlutter: MethodChannel.Result? = null
    private lateinit var methodChannel: MethodChannel
    private val mRotationGestureOverlay: RotationGestureOverlay by lazy {
        RotationGestureOverlay(map!!).apply {
            this.isEnabled = isEnabledRotationGesture && !isStaticMap
        }
    }
    private lateinit var activity: Activity

    private val gpsServiceManager: LocationManager by lazy {
        context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    }


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

    override fun setActivity(activity: Activity) {
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
                hashMap["bounding"] = map?.boundingBox?.toHashMap()
                hashMap["center"] = (map?.mapCenter as GeoPoint).toHashMap()
                methodChannel.invokeMethod("receiveRegionIsChanging", hashMap)

                return !isStaticMap
            }

            override fun onZoom(event: ZoomEvent?): Boolean {
                val hashMap = HashMap<String, Any?>()
                hashMap["bounding"] = map?.boundingBox?.toHashMap()
                hashMap["center"] = (map?.mapCenter as GeoPoint).toHashMap()
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


        map = MapView(context)

        map!!.layoutParams = MapView.LayoutParams(
            LinearLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT)
        )
        map!!.isTilesScaledToDpi = true
        map!!.setMultiTouchControls(!isStaticMap)
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
        map!!.setScrollableAreaLimitLatitude(
            MapView.getTileSystem().maxLatitude,
            MapView.getTileSystem().minLatitude,
            0
        )
        map!!.zoomController.setVisibility(CustomZoomButtonsController.Visibility.NEVER)
        //
        map!!.minZoomLevel = 2.0

        map!!.setExpectedCenter(GeoPoint(0.0, 0.0))
        map!!.controller.setZoom(2.0)


        map!!.addMapListener(mapListener)
        if (isStaticMap) {
            map!!.isFlingEnabled = false
            map!!.overlayManager = StaticOverlayManager(map!!.mapOverlay)
        }



        map!!.overlayManager.add(0, staticOverlayListener)
        map!!.overlayManager.add(folderMarkers)
        map!!.overlayManager.add(mRotationGestureOverlay)
        mainLinearLayout.addView(map)
        mainLinearLayout.setOnTouchListener { _, _ -> !isStaticMap }

    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "initMap" -> {
                    initPosition(call, result)
                }

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
                    result.success(map?.mapCenter?.toHashMap())
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
//                    drawMultiRoad(call, result)
                }

                "clear#roads" -> {
                    clearAllRoad(result)
                }

                "marker#icon" -> {
                    changeIcon(call, result)
                }

                "drawRoad#manually" -> {
                    // drawRoadManually(call, result)
                }

                "staticPosition" -> {
                    staticPosition(call, result)
                }

                "staticPosition#IconMarker" -> {
                    staticPositionIconMaker(call, result)
                }


                "draw#shape" -> {
                    drawShape(call, result)
                }

                "remove#shape" -> {
                    removeShape(call, result)
                }

                "clear#shapes" -> {
                    folderShape.items.clear()
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

        map?.zoomToBoundingBox(
            box, true, args["padding"]!! as Int
        )
        result.success(null)
    }

    private fun getMapBounds(result: MethodChannel.Result) {
        val bounds = map?.boundingBox ?: boundingWorldBox
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

    @Suppress("UNCHECKED_CAST")
    private fun initPosition(methodCall: MethodCall, result: MethodChannel.Result) {
        val args = methodCall.arguments!! as HashMap<String, Double>
        val geoPoint = GeoPoint(args["lat"]!!, args["lon"]!!)
        val zoom = initZoom
        map!!.controller.setZoom(zoom)
        map!!.controller.setCenter(geoPoint)
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
        markerIconsCache[point] = bitmap.toByteArray() ?: customMarkerIcon?.toByteArray()
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
        marker.longPress = { GeoPoint ->
            val hashMap = HashMap<String, Double>()
            hashMap["lon"] = GeoPoint.position.longitude
            hashMap["lat"] = GeoPoint.position.latitude
            methodChannel.invokeMethod("receiveLongPressGeoPoint", hashMap)
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
        result.success(200)
    }

    private fun limitCameraArea(call: MethodCall, result: MethodChannel.Result) {
        val list = call.arguments as List<Double>
        val box = BoundingBox(
            list[0], list[1], list[2], list[3]
        )
        map!!.setScrollableAreaLimitDouble(box)

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

            }
            locationNewOverlay.configurationFollow(enableStopFollow, useDirectionMarker)
            locationNewOverlay.toggleFollow()
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
        //map!!.controller.zoomTo(defaultZoom)
        when (animate) {
            true -> map!!.controller.animateTo(geoPoint)
            false -> map!!.controller.setCenter(geoPoint)
        }

        result.success(null)
    }


    private fun drawShape(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments!! as HashMap<*, *>
        val key = args["key"] as String
        val shape = OSMShape(args, map!!)
        folderShape.items.removeAll {
            it is OSMShape && it.id == key
        }
        folderShape.items.add(shape)
        if (!map!!.overlays.contains(folderShape)) {
            map!!.overlays.add(1, folderShape)
        }
        map!!.invalidate()
        result.success(null)
    }

    private fun removeShape(call: MethodCall, result: MethodChannel.Result) {
        val arg = call.arguments
        when {
            arg is String? && arg != null -> folderShape.items.removeAll {
                (it as Polygon).id == arg
            }

            arg is HashMap<*, *> -> {
                clearShapeByType(arg["shape"] as String)
            }
        }
        map!!.invalidate()
        result.success(null)
    }

    private fun clearShapeByType(typeShape: String) {
        when (typeShape) {
            "rect" -> folderShape.items.removeAll { shape ->
                shape is OSMShape && shape.shape == Shape.POLYGON
            }
            "circle" -> folderShape.items.removeAll { shape ->
                shape is OSMShape && shape.shape == Shape.CIRCLE
            }
            else -> return
        }
    }

    private fun clearAllRoad(result: MethodChannel.Result) {
        folderRoad.items.clear()

        map!!.invalidate()
        result.success(200)
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
                    it as FlutterOSMRoad
                }.first { road ->
                    road.idRoad == roadKey
                }
                if (flutterRoad?.idRoad == roadKey) {
                    flutterRoad = null
                }
                folderRoad.items.remove(road)
                map?.invalidate()
                map?.invalidate()

            }

            else -> {
                if (folderRoad.items.isNotEmpty()) {
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


        val roadId = args["key"] as String
        val linesMap = args["segments"] as List<HashMap<*, *>>
        var lines = mutableListOf<Polyline>()
        val zoomToRegion = args["zoomIntoRegion"] as Boolean

        for (arg in linesMap) {
            val encoded = arg["polylineEncoded"] as String
            val roadOption = (arg["option"] as HashMap<*, *>).toRoadOption()
            checkRoadFolderAboveUserOverlay()


            val routePointsEncoded = PolylineEncoder.decode(encoded, 5, false)
            val polyLine = Polyline(map!!, false, false).apply {
                setStyle(
                    borderColor = roadOption.roadBorderColor,
                    borderWidth = roadOption.roadBorderWidth,
                    color = roadOption.roadColor ?: Color.GREEN,
                    width = roadOption.roadWidth,
                    isDottedPolyline = roadOption.isDotted

                )
                setPoints(routePointsEncoded)

            }
            lines.add(polyLine)
        }
        flutterRoad = createRoad(
            polyLines = lines,
            roadID = roadId,
        )
        if (zoomToRegion) {
            map!!.zoomToBoundingBox(
                BoundingBox.fromGeoPoints(lines.map { it.actualPoints }.reduce { a, b -> a + b }
                    .toList()),
                true,
                64,
            )
        }

        map!!.invalidate()

        result.success(
            mapOf(
                "key" to roadId
            )
        )
    }


//    private fun drawRoadManually(call: MethodCall, result: MethodChannel.Result) {
//        val args: HashMap<String, Any> = call.arguments as HashMap<String, Any>
//        val roadId = args["key"] as String
//        val encodedWayPoints = (args["road"] as String)
//        val roadColor = (args["roadColor"] as List<Int>).toRGB()
//        val roadWidth = (args["roadWidth"] as Double).toFloat()
//        val roadBorderWidth = (args["roadBorderWidth"] as Double? ?: 0).toFloat()
//        val roadBorderColor = (args["roadBorderColor"] as List<Int>?)?.toRGB() ?: 0
//        val zoomToRegion = args["zoomIntoRegion"] as Boolean
//
//        checkRoadFolderAboveUserOverlay()
//
//
//        val route = PolylineEncoder.decode(encodedWayPoints, 10, false)
//
//
//        val polyLine = Polyline(map!!)
//        polyLine.setPoints(route)
//        polyLine.setStyle(
//            borderWidth = roadBorderWidth,
//            borderColor = roadBorderColor,
//            color = roadColor,
//            width = roadWidth
//        )
//
//        createRoad(
//            roadID = roadId,
//            polyLine = polyLine,
//        )
//
//
//        if (zoomToRegion) {
//            map!!.zoomToBoundingBox(
//                BoundingBox.fromGeoPoints(polyLine.actualPoints),
//                true,
//                64,
//            )
//        }
//        map!!.invalidate()
//        result.success(null)
//    }

    private fun createRoad(
        roadID: String,
        polyLines: List<Polyline>,

        ): FlutterOSMRoadFolder {


        val flutterRoad = FlutterOSMRoad(
            roadID,
//            roadDistance = roadDistance,
//            roadDuration = roadDuration,
        )
        flutterRoad.let { roadF ->
            for (polyline in polyLines) {
                roadF.addSegment(polyline)
                //roadF.road.setOnClickListener { polyline, mapView, eventPos ->  }
                roadF.onRoadClickListener = object : FlutterRoad.OnRoadClickListener {
                    override fun onClick(idRoad: String, polyineId: String, polyEncoded: String) {
                        val map = HashMap<String, Any?>()
                        map["key"] = idRoad
                        map["segId"] = polyineId
                        methodChannel.invokeMethod("receiveRoad", map)

                    }

                }
            }
            roadF.items.addAll(roadF.roadSegments)
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
            map!!.overlays.remove(folderMarkers)
            map!!.overlays.add(folderMarkers)
            map!!.invalidate()
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
            val marker = FlutterMarker(context, map!!, scope)
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
        if (!map!!.overlays.contains(folderStaticPosition)) {
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
        FlutterOsmPlugin.Companion.state.set(CREATED)
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
        /// init LocationManager
        locationNewOverlay = OSMLocationManager(map!!, methodChannel, "receiveUserLocation")

        // map!!.forceLayout()
        Log.e("osm", "osm flutter plugin create")

    }


    override fun onStart(owner: LifecycleOwner) {
        super.onStart(owner)
        FlutterOsmPlugin.Companion.state.set(STARTED)
        Log.e("osm", "osm flutter plugin start")
        activity = FlutterOsmPlugin.Companion.pluginBinding!!.activity
        FlutterOsmPlugin.Companion.pluginBinding!!.addActivityResultListener(this)
//        context.applicationContext.registerReceiver(
//            checkGPSServiceBroadcast,
//            IntentFilter(LocationManager.PROVIDERS_CHANGED_ACTION)
//        )

    }


    override fun onResume(owner: LifecycleOwner) {
        super.onResume(owner)
        FlutterOsmPlugin.Companion.state.set(FlutterOsmPlugin.Companion.RESUMED)
        Log.e("osm", "osm flutter plugin resume")
        if (map == null) {
            initMap()
        }
        map?.onResume()
        locationNewOverlay.onResume()
    }

    override fun onPause(owner: LifecycleOwner) {
        super.onPause(owner)
        FlutterOsmPlugin.Companion.state.set(PAUSED)
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
        FlutterOsmPlugin.Companion.state.set(STOPPED)
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
        FlutterOsmPlugin.Companion.pluginBinding!!.removeActivityResultListener(this)
        mainLinearLayout.removeAllViews()
        //map!!.onDetach()
        methodChannel.setMethodCallHandler(null)

        //configuration!!.osmdroidTileCache.delete()
        //configuration = null
        //eventChannel.setStreamHandler(null)
        map = null
        FlutterOsmPlugin.Companion.state.set(DESTROYED)

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


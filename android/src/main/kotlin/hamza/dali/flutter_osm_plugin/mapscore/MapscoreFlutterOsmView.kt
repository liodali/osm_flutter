package hamza.dali.flutter_osm_plugin.mapscore

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.location.LocationManager
import android.location.LocationManager.GPS_PROVIDER
import android.location.LocationManager.NETWORK_PROVIDER
import android.os.Bundle
import android.util.Log
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.widget.FrameLayout
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.coroutineScope
import hamza.dali.flutter_osm_plugin.ProviderLifecycle
import hamza.dali.flutter_osm_plugin.models.CustomTile
import hamza.dali.flutter_osm_plugin.mapscore.models.Anchor
import hamza.dali.flutter_osm_plugin.mapscore.models.FlutterMarker
import hamza.dali.flutter_osm_plugin.mapscore.models.FlutterRoad
import hamza.dali.flutter_osm_plugin.mapscore.models.MapscoreColorHelper
import hamza.dali.flutter_osm_plugin.mapscore.models.MapscoreGeoPoint
import hamza.dali.flutter_osm_plugin.mapscore.models.MapscoreShape
import hamza.dali.flutter_osm_plugin.mapscore.models.ShapeType
import hamza.dali.flutter_osm_plugin.mapscore.models.MeanOfTransport
import hamza.dali.flutter_osm_plugin.mapscore.models.RoadGeoPointInstruction
import hamza.dali.flutter_osm_plugin.mapscore.models.RoadOption
import hamza.dali.flutter_osm_plugin.mapscore.models.toMap
import hamza.dali.flutter_osm_plugin.mapscore.models.toRoadConfigMapscore
import hamza.dali.flutter_osm_plugin.mapscore.fontloader.SystemFontLoader
import hamza.dali.flutter_osm_plugin.mapscore.network.OsmRoadManager
import hamza.dali.flutter_osm_plugin.mapscore.overlays.CustomLocationManager
import hamza.dali.flutter_osm_plugin.mapscore.utilities.MapscoreConstants
import hamza.dali.flutter_osm_plugin.mapscore.utilities.decodePolyline
import hamza.dali.flutter_osm_plugin.mapscore.utilities.latLonToCoord
import hamza.dali.flutter_osm_plugin.mapscore.utilities.latLonToRender
import hamza.dali.flutter_osm_plugin.mapscore.utilities.openSettingLocation
import hamza.dali.flutter_osm_plugin.mapscore.utilities.rotate
import hamza.dali.flutter_osm_plugin.mapscore.utilities.screenDensity
import hamza.dali.flutter_osm_plugin.mapscore.utilities.toBitmap
import hamza.dali.flutter_osm_plugin.mapscore.utilities.toByteArray
import hamza.dali.flutter_osm_plugin.mapscore.utilities.toHashMap
import hamza.dali.flutter_osm_plugin.mapscore.utilities.toLatLon
import hamza.dali.flutter_osm_plugin.mapscore.utilities.toRGB
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding.OnSaveInstanceStateListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.platform.PlatformView
import io.openmobilemaps.mapscore.graphics.BitmapTextureHolder
import io.openmobilemaps.mapscore.map.layers.TiledRasterLayer
import io.openmobilemaps.mapscore.map.layers.TiledVectorLayer
import io.openmobilemaps.mapscore.map.view.MapView
import io.openmobilemaps.mapscore.shared.graphics.common.Color
import io.openmobilemaps.mapscore.shared.graphics.common.Vec2F
import io.openmobilemaps.mapscore.shared.graphics.shader.BlendMode
import io.openmobilemaps.mapscore.shared.map.MapConfig
import io.openmobilemaps.mapscore.shared.map.MapInterface
import io.openmobilemaps.mapscore.shared.map.coordinates.CoordinateSystemFactory
import io.openmobilemaps.mapscore.shared.map.coordinates.Coord
import io.openmobilemaps.mapscore.shared.map.coordinates.RectCoord
import io.openmobilemaps.mapscore.shared.map.layers.ColorStateList
import io.openmobilemaps.mapscore.shared.map.layers.SizeType
import io.openmobilemaps.mapscore.shared.map.layers.icon.IconLayerCallbackInterface
import io.openmobilemaps.mapscore.shared.map.layers.icon.IconLayerInterface
import io.openmobilemaps.mapscore.shared.map.layers.line.LineCapType
import io.openmobilemaps.mapscore.shared.map.layers.line.LineFactory
import io.openmobilemaps.mapscore.shared.map.layers.line.LineInfoInterface
import io.openmobilemaps.mapscore.shared.map.layers.line.LineJoinType
import io.openmobilemaps.mapscore.shared.map.layers.line.LineLayerCallbackInterface
import io.openmobilemaps.mapscore.shared.map.layers.line.LineLayerInterface
import io.openmobilemaps.mapscore.shared.map.layers.line.LineStyle
import io.openmobilemaps.mapscore.shared.map.layers.polygon.PolygonLayerInterface
import io.openmobilemaps.mapscore.shared.map.camera.MapCameraListenerInterface
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID
import kotlin.math.PI

typealias VoidCallbackMapscore = () -> Unit

/**
 * mapscore-based replacement for [hamza.dali.flutter_osm_plugin.FlutterOsmView].
 *
 * It preserves the exact same MethodChannel contract so the Dart side is unchanged, but
 * the rendering is performed by openmobilemaps maps-core (OpenGL) instead of osmdroid.
 */
class MapscoreFlutterOsmView(
    private val context: Context,
    private val binaryMessenger: BinaryMessenger,
    private val id: Int,
    private val providerLifecycle: ProviderLifecycle,
    private val keyArgMapSnapShot: String,
    private val customTile: CustomTile?,
    private val isEnabledRotationGesture: Boolean = false,
    private val isStaticMap: Boolean = false,
) : OnSaveInstanceStateListener, PlatformView, MethodCallHandler,
    PluginRegistry.ActivityResultListener, DefaultLifecycleObserver {

    private var mapView: MapView? = null
    private var rasterLayer: TiledRasterLayer? = null
    private var vectorLayer: TiledVectorLayer? = null
    private lateinit var iconLayer: IconLayerInterface
    private lateinit var staticIconLayer: IconLayerInterface
    private lateinit var userIconLayer: IconLayerInterface
    private lateinit var lineLayer: LineLayerInterface
    private lateinit var polygonLayer: PolygonLayerInterface

    private lateinit var locationNewOverlay: CustomLocationManager
    private lateinit var methodChannel: MethodChannel

    private val markers: MutableMap<String, FlutterMarker> = LinkedHashMap()
    private val markerIconsCache: MutableMap<String, ByteArray?> = LinkedHashMap()
    private val roads: MutableMap<String, FlutterRoad> = LinkedHashMap()
    private val shapes: MutableMap<String, MapscoreShape> = LinkedHashMap()
    private val staticPoints: MutableMap<String, MutableList<MapscoreGeoPoint>> = LinkedHashMap()
    private val staticMarkerIcon: MutableMap<String, Bitmap> = LinkedHashMap()
    private val staticIcons: MutableMap<String, MutableList<io.openmobilemaps.mapscore.shared.map.layers.icon.IconInfoInterface>> =
        LinkedHashMap()

    private var customMarkerIcon: Bitmap? = null
    private var customPersonMarkerIcon: Bitmap? = null
    private var customArrowMarkerIcon: Bitmap? = null
    private var homeMarker: FlutterMarker? = null

    private var scope: CoroutineScope? = null
    private var job: Job? = null
    private var resultFlutter: MethodChannel.Result? = null
    private var skipCheckLocation = false
    private var activity: Activity? = null

    internal var stepZoom = MapscoreConstants.stepZoom
    internal var initZoom = 10.0
    private var isTracking = false
    private var isEnabled = false
    private var visibilityInfoWindow = false

    private var roadManager: OsmRoadManager? = null

    private val gpsServiceManager: LocationManager by lazy {
        context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    }

    private val mainLinearLayout: FrameLayout = FrameLayout(context).apply {
        layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
    }

    private val gestureDetector: GestureDetector by lazy {
        GestureDetector(context, object : GestureDetector.SimpleOnGestureListener() {
            override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
                invokeTap(e.x, e.y, longPress = false)
                return true
            }

            override fun onLongPress(e: MotionEvent) {
                invokeTap(e.x, e.y, longPress = true)
            }
        })
    }

    init {
        providerLifecycle.getOSMLifecycle()?.addObserver(this)
    }

    fun setActivity(activity: Activity) {
        this.activity = activity
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun initMap(lifecycle: androidx.lifecycle.Lifecycle) {
        val map = MapView(context).apply {
            layoutParams = FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT)
            setupMap(MapConfig(CoordinateSystemFactory.getEpsg3857System()))
            registerLifecycle(lifecycle)
            setTouchEnabled(!isStaticMap)
        }
        mapView = map

        if (customTile?.isVector == true) {
            vectorLayer = createVectorLayer(customTile)
            vectorLayer?.let { map.addLayer(it) }
        } else {
            rasterLayer = createRasterLayer()
            rasterLayer?.let { map.addLayer(it) }
        }
        map.requestRender()

        polygonLayer = PolygonLayerInterface.create()
        lineLayer = LineLayerInterface.create()
        iconLayer = IconLayerInterface.create()
        staticIconLayer = IconLayerInterface.create()
        userIconLayer = IconLayerInterface.create()

        map.addLayer(polygonLayer.asLayerInterface())
        map.addLayer(lineLayer.asLayerInterface())
        map.addLayer(staticIconLayer.asLayerInterface())
        map.addLayer(iconLayer.asLayerInterface())
        map.addLayer(userIconLayer.asLayerInterface())

        setupMarkerCallbacks(iconLayer)
        setupMarkerCallbacks(staticIconLayer)
        setupRoadCallbacks()
        setupCameraListener()

        try {
            map.getCamera().setMinZoom(MapscoreConstants.osmZoomToMapscore(2.0))
            map.getCamera().setMaxZoom(MapscoreConstants.osmZoomToMapscore(20.0))
            map.getCamera().setRotationEnabled(isEnabledRotationGesture && !isStaticMap)
        } catch (e: Exception) {
            Log.e("osm", "camera setup: ${e.message}")
        }

        map.setOnTouchListener { _, event ->
            if (!isStaticMap) gestureDetector.onTouchEvent(event)
            false
        }

        mainLinearLayout.addView(map)

        locationNewOverlay = CustomLocationManager(context, map, userIconLayer)
        locationNewOverlay.onChangedLocation { lat, lon, heading ->
            scope?.launch(Dispatchers.Main) {
                val map2 = HashMap<String, Any>()
                map2["lat"] = lat
                map2["lon"] = lon
                map2["heading"] = heading
                methodChannel.invokeMethod("receiveUserLocation", map2)
            }
        }
    }

    private fun createRasterLayer(): TiledRasterLayer {
        val tileUrl = if (customTile != null) buildCustomTileUrl(customTile) else DEFAULT_OSM_TILE_URL
        val name = customTile?.sourceName ?: "osm-default"
        val layer = TiledRasterLayer(context, tileUrl, name)
        customTile?.let {
            layer.rasterLayerInterface().setMinZoomLevelIdentifier(it.minZoomLevel)
            layer.rasterLayerInterface().setMaxZoomLevelIdentifier(it.maxZoomLevel)
        }
        return layer
    }

    private fun createVectorLayer(tile: CustomTile): TiledVectorLayer? {
        val styleUrl = tile.styleURL ?: return null
        val layer = TiledVectorLayer(context, styleUrl, fontLoader = SystemFontLoader(context))
        layer.vectorLayerInterface().setMinZoomLevelIdentifier(tile.minZoomLevel)
        layer.vectorLayerInterface().setMaxZoomLevelIdentifier(tile.maxZoomLevel)
        return layer
    }

    private fun buildCustomTileUrl(tile: CustomTile): String {
        val base = tile.urls.firstOrNull() ?: return DEFAULT_OSM_TILE_URL
        var url: String = base
        val ext = if (tile.tileFileExtension.startsWith(".")) tile.tileFileExtension else ".${tile.tileFileExtension}"
        if (!url.contains("{x}") && !url.contains("{z}")) {
            url = url.trimEnd('/') + "/{z}/{x}/{y}" + ext
        }
        tile.api?.let { (k, v) -> url = "$url?$k=$v" }
        return url
    }

    private fun setupMarkerCallbacks(layer: IconLayerInterface) {
        layer.setLayerClickable(true)
        layer.setCallbackHandler(object : IconLayerCallbackInterface() {
            override fun onClickConfirmed(icons: ArrayList<io.openmobilemaps.mapscore.shared.map.layers.icon.IconInfoInterface>): Boolean {
                val helper = mapView?.getCoordinateConversionHelper() ?: return false
                icons.forEach { icon ->
                    val (lat, lon) = icon.getCoordinate().toLatLon(helper)
                    val h = HashMap<String, Double>()
                    h["lat"] = lat
                    h["lon"] = lon
                    val marker = findMarkerByPosition(lat, lon)
                    if (marker != null) {
                        marker.onClickListener?.invoke(marker)
                    }
                    methodChannel.invokeMethod("receiveGeoPoint", h)
                }
                return true
            }

            override fun onLongPress(icons: ArrayList<io.openmobilemaps.mapscore.shared.map.layers.icon.IconInfoInterface>): Boolean {
                val helper = mapView?.getCoordinateConversionHelper() ?: return false
                icons.forEach { icon ->
                    val (lat, lon) = icon.getCoordinate().toLatLon(helper)
                    val h = HashMap<String, Double>()
                    h["lat"] = lat
                    h["lon"] = lon
                    val marker = findMarkerByPosition(lat, lon)
                    if (marker != null) {
                        marker.longPress?.invoke(marker)
                    }
                    methodChannel.invokeMethod("receiveGeoPointLongPress", h)
                }
                return true
            }
        })
    }

    private fun setupRoadCallbacks() {
        lineLayer.setLayerClickable(true)
        lineLayer.setCallbackHandler(object : LineLayerCallbackInterface() {
            override fun onLineClickConfirmed(line: LineInfoInterface) {
                val road = roads.values.firstOrNull { it.matches(line) } ?: return
                val helper = mapView?.getCoordinateConversionHelper() ?: return
                val map = HashMap<String, Any>()
                map["roadPoints"] = road.coordinates.map { it.toHashMap(helper) }
                map["distance"] = road.roadDistance
                map["duration"] = road.roadDuration
                map["key"] = road.idRoad
                methodChannel.invokeMethod("receiveRoad", map)
            }
        })
    }

    private fun setupCameraListener() {
        val camera = mapView?.getCamera() ?: return
        camera.addListener(object : MapCameraListenerInterface() {
            override fun onVisibleBoundsChanged(visibleBounds: RectCoord, zoom: Double) {
                val helper = mapView?.getCoordinateConversionHelper() ?: return
                val h = HashMap<String, Any?>()
                h["bounding"] = visibleBounds.toHashMap(helper)
                val center = mapView?.getCamera()?.getCenterPosition()
                h["center"] = center?.toHashMap(helper)
                scope?.launch(Dispatchers.Main) {
                    methodChannel.invokeMethod("receiveRegionIsChanging", h)
                }
            }

            override fun onRotationChanged(angle: Float) {}

            override fun onMapInteraction() {}

            override fun onCameraChange(
                viewMatrix: ArrayList<Float>,
                projectionMatrix: ArrayList<Float>,
                origin: io.openmobilemaps.mapscore.shared.graphics.common.Vec3D,
                verticalFov: Float,
                horizontalFov: Float,
                width: Float,
                height: Float,
                focusPointAltitude: Float,
                focusPointPosition: Coord,
                zoom: Float,
            ) {
            }
        })
    }

    private fun invokeTap(x: Float, y: Float, longPress: Boolean) {
        val map = mapView ?: return
        try {
            val helper = map.getCoordinateConversionHelper()
            val coord = map.getCamera().coordFromScreenPosition(Vec2F(x, y))
            val (lat, lon) = coord.toLatLon(helper)
            val h = HashMap<String, Double>()
            h["lat"] = lat
            h["lon"] = lon
            methodChannel.invokeMethod(if (longPress) "receiveLongPress" else "receiveSinglePress", h)
        } catch (e: Exception) {
            Log.e("osm", "tap conversion failed: ${e.message}")
        }
    }

    private fun findMarkerByPosition(lat: Double, lon: Double): FlutterMarker? =
        markers.values.firstOrNull { it.lat == lat && it.lon == lon }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "change#tile" -> {
                    val args = call.arguments as? HashMap<String, Any>
                    if (!args.isNullOrEmpty()) {
                        val tile = CustomTile.fromMap(args)
                        swapRasterLayer(tile)
                    } else {
                        swapRasterLayer(null)
                    }
                    result.success(null)
                }

                "use#visiblityInfoWindow" -> {
                    visibilityInfoWindow = call.arguments as Boolean
                    result.success(null)
                }

                "config#Zoom" -> configZoomMap(call, result)
                "Zoom" -> setZoom(call, result)
                "get#Zoom" -> getZoom(result)
                "change#stepZoom" -> {
                    stepZoom = call.arguments as Double
                    result.success(null)
                }

                "zoomToRegion" -> zoomingMapToBoundingBox(call, result)
                "showZoomController" -> {
                    // mapscore has no built-in zoom buttons
                    result.success(null)
                }

                "currentLocation" -> {
                    if (gpsServiceManager.isProviderEnabled(GPS_PROVIDER) || gpsServiceManager.isProviderEnabled(
                            NETWORK_PROVIDER
                        )
                    ) {
                        enableUserLocation()
                    } else {
                        activity?.let { openSettingLocation(MapscoreConstants.currentUserLocationReqCode, it) }
                    }
                    result.success(isEnabled)
                }

                "initMap" -> initPosition(call, result)
                "limitArea" -> limitCameraArea(call, result)
                "remove#limitArea" -> removeLimitCameraArea(result)
                "changePosition" -> changePosition(call, result)
                "trackMe" -> {
                    val args = call.arguments as List<*>
                    val enableStopFollow = args.first() as Boolean
                    val disableRotation = args[1] as Boolean
                    val useDirectionMarker = args[2] as Boolean
                    val anchor = args.last() as List<Double>
                    locationNewOverlay.setAnchor(anchor)
                    trackUserLocation(enableStopFollow, useDirectionMarker, disableRotation, result)
                }

                "deactivateTrackMe" -> deactivateTrackMe(result)
                "startLocationUpdating" -> {
                    locationNewOverlay.startLocationUpdating()
                    result.success(null)
                }

                "stopLocationUpdating" -> {
                    locationNewOverlay.stopLocationUpdating()
                    result.success(null)
                }

                "map#center" -> {
                    val helper = mapView?.getCoordinateConversionHelper()
                    val center = mapView?.getCamera()?.getCenterPosition()
                    result.success(center?.toHashMap(helper!!))
                }

                "map#bounds" -> getMapBounds(result)
                "user#position" -> {
                    if (gpsServiceManager.isProviderEnabled(GPS_PROVIDER) || gpsServiceManager.isProviderEnabled(
                            NETWORK_PROVIDER
                        )
                    ) {
                        getUserLocation(result)
                    } else {
                        resultFlutter = result
                        activity?.let { openSettingLocation(MapscoreConstants.getUserLocationReqCode, it) }
                    }
                }

                "moveTo#position" -> moveToSpecificPosition(call, result)
                "user#removeMarkerPosition" -> {
                    val (lat, lon) = (call.arguments as HashMap<String, Double>).toLatLon()
                    deleteMarker(lat, lon)
                    result.success(null)
                }

                "delete#road" -> deleteRoad(call, result)
                "draw#multi#road" -> drawMultiRoad(call, result)
                "clear#roads" -> {
                    roads.values.forEach { it.remove() }
                    roads.clear()
                    result.success(200)
                }

                "marker#icon" -> changeIcon(call, result)
                "drawRoad#manually" -> drawRoadManually(call, result)
                "staticPosition" -> staticPosition(call, result)
                "staticPosition#IconMarker" -> staticPositionIconMaker(call, result)
                "draw#circle" -> drawShape(call, result)
                "draw#rect" -> drawShape(call, result)
                "remove#circle" -> removeShape(call, result, ShapeType.CIRCLE)
                "remove#rect" -> removeShape(call, result, ShapeType.POLYGON)
                "clear#shapes" -> {
                    shapes.values.forEach { it.remove() }
                    shapes.clear()
                    result.success(null)
                }

                "map#orientation" -> mapOrientation(call, result)
                "user#locationMarkers" -> changeLocationMarkers(call, result)
                "add#Marker" -> addMarkerManually(call, result)
                "update#Marker" -> updateMarker(call, result)
                "change#Marker" -> changePositionMarker(call, result)
                "get#geopoints" -> getGeoPoints(result)
                "delete#markers" -> deleteMarkers(call, result)
                "toggle#Alllayer" -> toggleLayer(call, result)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.e("osm", "error osm plugin ${e.stackTraceToString()}")
            result.error("404", e.message, e.stackTraceToString())
        }
    }

    private fun swapRasterLayer(tile: CustomTile?) {
        val map = mapView ?: return
        rasterLayer?.let { map.removeLayer(it); rasterLayer = null }
        vectorLayer?.let { map.removeLayer(it); vectorLayer = null }

        if (tile?.isVector == true) {
            val layer = createVectorLayer(tile) ?: return
            vectorLayer = layer
            map.insertLayerAt(layer, 0)
        } else {
            val name = tile?.sourceName ?: "osm-default"
            val url = if (tile != null) buildCustomTileUrl(tile) else DEFAULT_OSM_TILE_URL
            val layer = TiledRasterLayer(context, url, name)
            rasterLayer = layer
            map.insertLayerAt(layer, 0)
        }
        map.requestRender()
    }

    private fun configZoomMap(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as HashMap<*, *>
        val camera = mapView?.getCamera()
        val minZoom = (args["minZoomLevel"] as Double)
        val maxZoom = (args["maxZoomLevel"] as Double)
        camera?.setMinZoom(MapscoreConstants.osmZoomToMapscore(minZoom))
        camera?.setMaxZoom(MapscoreConstants.osmZoomToMapscore(maxZoom))
        stepZoom = args["stepZoom"] as Double
        initZoom = args["initZoom"] as Double
        result.success(200)
    }

    private fun getZoom(result: MethodChannel.Result) {
        try {
            val z = mapView?.getCamera()?.getZoom() ?: return result.error("404", "no zoom", null)
            result.success(MapscoreConstants.mapscoreToOsmZoom(z))
        } catch (e: Exception) {
            result.error("404", e.stackTraceToString(), null)
        }
    }

    private fun setZoom(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as HashMap<String, Any>
        val camera = mapView?.getCamera() ?: return result.success(null)
        if (args.containsKey("stepZoom")) {
            var step = args["stepZoom"] as Double
            if (step == 0.0) step = stepZoom
            else if (step == -1.0) step = -stepZoom
            val current = MapscoreConstants.mapscoreToOsmZoom(camera.getZoom())
            camera.setZoom(MapscoreConstants.osmZoomToMapscore(current + step), true)
        } else if (args.containsKey("zoomLevel")) {
            camera.setZoom(MapscoreConstants.osmZoomToMapscore(args["zoomLevel"] as Double), true)
        }
        result.success(null)
    }

    private fun zoomingMapToBoundingBox(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as Map<String, Any>
        // Mapscore's moveToBoundingBox expects WGS84 coordinates and converts internally.
        val topLeft = latLonToCoord(args["north"]!! as Double, args["west"]!! as Double)
        val bottomRight = latLonToCoord(args["south"]!! as Double, args["east"]!! as Double)
        val rect = RectCoord(topLeft, bottomRight)
        val padding = (args["padding"] as? Int ?: 64).toFloat() / 1000f
        mapView?.getCamera()?.moveToBoundingBox(rect, padding.coerceIn(0.0f, 0.5f), true, null, null)
        result.success(null)
    }

    private fun getMapBounds(result: MethodChannel.Result) {
        val helper = mapView?.getCoordinateConversionHelper()
        val rect = mapView?.getCamera()?.getVisibleRect()
        result.success(rect?.toHashMap(helper!!))
    }

    private fun initPosition(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as HashMap<String, Double>
        val camera = mapView?.getCamera() ?: return result.success(null)
        camera.moveToCenterPositionZoom(
            latLonToCoord(args["lat"]!!, args["lon"]!!),
            MapscoreConstants.osmZoomToMapscore(initZoom),
            false
        )
        mapView?.requestRender()
        methodChannel.invokeMethod("map#init", true)
        result.success(null)
    }

    private fun changePosition(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as HashMap<String, Double>
        homeMarker?.let { markers.remove(it.identifier); it.remove() }
        val zoom = mapView?.getCamera()?.getZoom()?.let { MapscoreConstants.mapscoreToOsmZoom(it) } ?: initZoom
        homeMarker = addMarker(args["lat"]!!, args["lon"]!!, zoom = zoom)
        result.success(null)
    }

    private fun limitCameraArea(call: MethodCall, result: MethodChannel.Result) {
        val list = call.arguments as List<Double>
        val helper = mapView?.getCoordinateConversionHelper() ?: return result.success(200)
        // list = [latNorth, lonEast, latSouth, lonWest]
        val topLeft = latLonToRender(helper, list[0], list[3])
        val bottomRight = latLonToRender(helper, list[2], list[1])
        val camera = mapView?.getCamera()
        camera?.setBounds(RectCoord(topLeft, bottomRight))
        camera?.setBoundsRestrictWholeVisibleRect(true)
        result.success(200)
    }

    private fun removeLimitCameraArea(result: MethodChannel.Result) {
        val helper = mapView?.getCoordinateConversionHelper()
        if (helper != null) {
            val topLeft = latLonToRender(helper, 85.0, -180.0)
            val bottomRight = latLonToRender(helper, -85.0, 180.0)
            mapView?.getCamera()?.setBounds(RectCoord(topLeft, bottomRight))
        }
        result.success(200)
    }

    private fun mapOrientation(call: MethodCall, result: MethodChannel.Result) {
        val angle = (call.arguments as Double?)?.toFloat() ?: 0f
        mapView?.getCamera()?.setRotation(angle, true)
        result.success(null)
    }

    private fun moveToSpecificPosition(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as HashMap<String, *>
        val coord = latLonToCoord(args["lat"]!! as Double, args["lon"]!! as Double)
        val animate = args["animate"] as Boolean? ?: false
        mapView?.getCamera()?.moveToCenterPosition(coord, animate)
        result.success(null)
    }

    private fun enableUserLocation() {
        locationNewOverlay.enableMyLocation()
        locationNewOverlay.runOnFirstFix(Runnable {
            scope?.launch(Dispatchers.Main) {
                try {
                    val helper = mapView?.getCoordinateConversionHelper() ?: return@launch
                    val coord = latLonToRender(helper, locationNewOverlay.mGeoPointLat, locationNewOverlay.mGeoPointLon)
                    mapView?.getCamera()?.moveToCenterPosition(coord, false)
                } catch (e: Exception) {
                    Log.e("osm", "enableUserLocation: ${e.message}")
                }
            }
        })
        isEnabled = true
    }

    private fun getUserLocation(result: MethodChannel.Result) {
        locationNewOverlay.currentUserPosition(result, scope!!)
    }

    private fun trackUserLocation(
        enableStopFollow: Boolean,
        useDirectionMarker: Boolean,
        disableRotation: Boolean,
        result: MethodChannel.Result
    ) {
        try {
            homeMarker?.let { markers.remove(it.identifier); it.remove() }
            locationNewOverlay.disableRotateDirection = disableRotation
            locationNewOverlay.useDirectionMarker = useDirectionMarker
            locationNewOverlay.toggleFollow(enableStopFollow)
            isTracking = locationNewOverlay.mIsFollowing
            result.success(if (locationNewOverlay.mIsFollowing) true else null)
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

    private fun changeLocationMarkers(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as HashMap<String, Any>
        try {
            customPersonMarkerIcon = (args["personIcon"] as ByteArray).toBitmap()
            customArrowMarkerIcon = (args["arrowDirectionIcon"] as ByteArray).toBitmap()
            locationNewOverlay.setMarkerIcon(customPersonMarkerIcon, customArrowMarkerIcon)
            result.success(null)
        } catch (e: Exception) {
            e.printStackTrace()
            result.success(e.message)
        }
    }

    private fun addMarker(
        lat: Double,
        lon: Double,
        zoom: Double = initZoom,
        color: Int? = null,
        dynamicMarkerBitmap: Bitmap? = null,
        imageURL: String? = null,
        animateTo: Boolean = true,
        angle: Double = 0.0,
        anchor: Anchor? = null,
    ): FlutterMarker {
        val density = screenDensity(context)
        val marker = FlutterMarker(
            context = context,
            helper = mapView!!.getCoordinateConversionHelper(),
            iconLayer = iconLayer,
            identifier = UUID.randomUUID().toString(),
            density = density,
        )
        marker.setPosition(lat, lon)
        marker.onClickListener = { m ->
            val h = HashMap<String, Double>()
            h["lat"] = m.lat
            h["lon"] = m.lon
            methodChannel.invokeMethod("receiveGeoPoint", h)
            true
        }
        marker.longPress = { m ->
            val h = HashMap<String, Double>()
            h["lat"] = m.lat
            h["lon"] = m.lon
            methodChannel.invokeMethod("receiveGeoPointLongPress", h)
            true
        }
        markers[marker.identifier] = marker
        when {
            dynamicMarkerBitmap != null -> marker.setIconMaker(null, dynamicMarkerBitmap, angle)
            !imageURL.isNullOrEmpty() -> marker.setIconMarkerFromURL(imageURL, angle)
            else -> marker.setIconMaker(color, null, angle)
        }
        anchor?.let { marker.updateAnchor(it) }

        val camera = mapView?.getCamera()
        camera?.setZoom(MapscoreConstants.osmZoomToMapscore(zoom), false)
        if (animateTo) camera?.moveToCenterPosition(latLonToCoord(lat, lon), true)
        return marker
    }

    private fun addMarkerManually(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as HashMap<*, *>
        val (lat, lon) = (args["point"] as HashMap<String, Double>).toLatLon()
        var bitmap = customMarkerIcon
        if (args.containsKey("icon")) bitmap = (args["icon"] as ByteArray).toBitmap()
        val angle =
            if ((args["point"] as HashMap<String, Double>).containsKey("angle")) (args["point"] as HashMap<String, Double>)["angle"] as Double else 0.0
        val anchor = if (args.containsKey("iconAnchor")) Anchor(args["iconAnchor"] as HashMap<String, Any>) else null
        markerIconsCache["$lat,$lon"] = bitmap?.toByteArray() ?: customMarkerIcon?.toByteArray()
        val zoom = mapView?.getCamera()?.getZoom()?.let { MapscoreConstants.mapscoreToOsmZoom(it) } ?: initZoom
        addMarker(
            lat,
            lon,
            zoom = zoom,
            dynamicMarkerBitmap = bitmap,
            animateTo = false,
            angle = angle,
            anchor = anchor
        )
        result.success(null)
    }

    private fun updateMarker(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as HashMap<*, *>
        val (lat, lon) = (args["point"] as HashMap<String, Double>).toLatLon()
        var bitmap = customMarkerIcon
        if (args.containsKey("icon")) {
            bitmap = (args["icon"] as ByteArray).toBitmap()
            markerIconsCache["$lat,$lon"] = args["icon"] as ByteArray
        }
        val marker = findMarkerByPosition(lat, lon)
        if (marker != null) {
            marker.setIconMaker(null, bitmap)
            result.success(200)
        } else {
            result.error("404", "GeoPoint not found", "you trying to modify icon of marker not exist")
        }
    }

    private fun changePositionMarker(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as HashMap<*, *>
        val (oldLat, oldLon) = (args["old_location"] as HashMap<String, Double>).toLatLon()
        val (newLat, newLon) = (args["new_location"] as HashMap<String, Double>).toLatLon()
        val marker = findMarkerByPosition(oldLat, oldLon)
        val angle =
            if (args.containsKey("angle") && args["angle"] != null) args["angle"] as Double else marker?.angle ?: 0.0
        val anchor =
            if (args.containsKey("iconAnchor")) Anchor(args["iconAnchor"] as HashMap<String, Any>) else marker?.getOldAnchor()
        val iconBytes =
            if (args.containsKey("new_icon")) args["new_icon"] as ByteArray else markerIconsCache["$oldLat,$oldLon"]
        markerIconsCache["$newLat,$newLon"] = iconBytes
        markerIconsCache.remove("$oldLat,$oldLon")
        marker?.let { markers.remove(it.identifier); it.remove() }
        addMarker(
            newLat,
            newLon,
            dynamicMarkerBitmap = iconBytes?.toBitmap(),
            angle = angle,
            animateTo = false,
            anchor = anchor
        )
        result.success(200)
    }

    private fun getGeoPoints(result: MethodChannel.Result) {
        val helper = mapView?.getCoordinateConversionHelper()
        val list = markers.values.map { it.iconInfo?.getCoordinate()?.toHashMap(helper!!) ?: HashMap<String, Double>() }
        result.success(list)
    }

    private fun deleteMarkers(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as List<HashMap<String, Double>>
        args.forEach { deleteMarker(it.toLatLon().first, it.toLatLon().second) }
        result.success(200)
    }

    private fun deleteMarker(lat: Double, lon: Double) {
        val toRemove = markers.values.filter { it.lat == lat && it.lon == lon }
        toRemove.forEach { markers.remove(it.identifier); it.remove() }
        markerIconsCache.remove("$lat,$lon")
    }

    private fun toggleLayer(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.arguments as Boolean
        val layers = listOf(
            iconLayer.asLayerInterface(),
            staticIconLayer.asLayerInterface(),
            lineLayer.asLayerInterface(),
            polygonLayer.asLayerInterface(),
            userIconLayer.asLayerInterface(),
        )
        layers.forEach { if (enabled) it.show() else it.hide() }
        result.success(200)
    }

    private fun changeIcon(call: MethodCall, result: MethodChannel.Result) {
        try {
            customMarkerIcon = (call.arguments as ByteArray).toBitmap()
            result.success(null)
        } catch (e: Exception) {
            customMarkerIcon = null
            result.error("500", "Cannot make markerIcon custom", "")
        }
    }

    private fun drawShape(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as HashMap<*, *>
        val key = args["key"] as String
        shapes[key]?.let { it.remove(); shapes.remove(key) }
        val shape = MapscoreShape(args, polygonLayer, mapView!!.getCoordinateConversionHelper())
        shapes[key] = shape
        result.success(null)
    }

    private fun removeShape(call: MethodCall, result: MethodChannel.Result, type: ShapeType) {
        val id = call.arguments as String?
        if (id != null) {
            shapes[id]?.let { it.remove(); shapes.remove(id) }
        } else {
            val keys = shapes.entries.filter { it.value.shape == type }.map { it.key }
            keys.forEach { shapes[it]?.remove(); shapes.remove(it) }
        }
        result.success(null)
    }

    private fun drawMultiRoad(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as List<HashMap<String, Any>>
        if (roadManager == null) roadManager = OsmRoadManager()
        job = scope?.launch(Dispatchers.Default) {
            val results = ArrayList<HashMap<String, Any>>()
            for (arg in args) {
                val config = arg.toRoadConfigMapscore()
                val roadResult = withContext(Dispatchers.IO) {
                    roadManager?.fetchRoad(config.wayPoints, config.interestPoints, config.mean)
                }
                if (roadResult != null && roadResult.coords.size > 2) {
                    withContext(Dispatchers.Main) {
                        drawRoadLines(
                            config.roadID,
                            config.roadOption,
                            roadResult.coords,
                            roadResult.distance,
                            roadResult.duration,
                            false
                        )
                    }
                    results.add(roadResult.toMap(config.roadID))
                }
                delay(100)
            }
            withContext(Dispatchers.Main) {
                result.success(results)
            }
        }
    }

    private fun drawRoadManually(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as HashMap<String, Any>
        val roadId = args["key"] as String
        val encoded = args["road"] as String
        val roadColor = (args["roadColor"] as List<Int>).toRGB()
        val roadWidth = (args["roadWidth"] as Double).toFloat()
        val roadBorderWidth = (args["roadBorderWidth"] as Double? ?: 0).toFloat()
        val roadBorderColor = (args["roadBorderColor"] as List<Int>?)?.toRGB() ?: 0
        val zoomToRegion = args["zoomIntoRegion"] as Boolean
        val isDotted = args["isDotted"] as? Boolean ?: false
        val option = RoadOption(
            roadColor = roadColor,
            roadWidth = roadWidth,
            roadBorderWidth = roadBorderWidth,
            roadBorderColor = roadBorderColor,
            isDotted = isDotted,
        )
        val coords = decodePolyline(encoded, 5)
        drawRoadLines(roadId, option, coords, 0.0, 0.0, zoomToRegion)
        result.success(null)
    }

    private fun drawRoadLines(
        roadId: String,
        option: RoadOption,
        latLonCoords: List<Pair<Double, Double>>,
        distance: Double,
        duration: Double,
        zoomToRegion: Boolean,
    ) {
        val helper = mapView?.getCoordinateConversionHelper() ?: return
        val renderCoords = latLonCoords.map { latLonToRender(helper, it.first, it.second) }
        val color = option.roadColor ?: android.graphics.Color.GREEN
        val border = option.roadBorderColor ?: android.graphics.Color.BLACK

        val renderArrayList = ArrayList(renderCoords)
        val borderLine = if (option.roadBorderWidth > 0) {
            LineFactory.createLine(
                "${roadId}_border",
                renderArrayList,
                lineStyle(border, option.roadBorderWidth + option.roadWidth, option.isDotted)
            )
        } else null
        val mainLine =
            LineFactory.createLine(roadId, renderArrayList, lineStyle(color, option.roadWidth, option.isDotted))

        roads[roadId]?.remove()
        val road = FlutterRoad(roadId, duration, distance, lineLayer)
        road.setRoad(renderCoords, borderLine, mainLine)
        road.onRoadClickListener = object : FlutterRoad.OnRoadClickListener {
            override fun onClick(road: FlutterRoad) {
                val map = HashMap<String, Any>()
                map["roadPoints"] = road.coordinates.map { it.toHashMap(helper) }
                map["distance"] = road.roadDistance
                map["duration"] = road.roadDuration
                map["key"] = road.idRoad
                methodChannel.invokeMethod("receiveRoad", map)
            }
        }
        roads[roadId] = road

        if (zoomToRegion && latLonCoords.size >= 2) {
            val minLat = latLonCoords.minOf { it.first }
            val maxLat = latLonCoords.maxOf { it.first }
            val minLon = latLonCoords.minOf { it.second }
            val maxLon = latLonCoords.maxOf { it.second }
            // Mapscore's moveToBoundingBox expects WGS84 coordinates and converts internally.
            val rect = RectCoord(latLonToCoord(maxLat, minLon), latLonToCoord(minLat, maxLon))
            try {
                mapView?.getCamera()?.moveToBoundingBox(rect, 0.1f, true, null, null)
            } catch (e: Exception) {
                Log.e("osm", "zoomToRegion: ${e.message}")
            }
        }
        mapView?.requestRender()
    }

    private fun lineStyle(color: Int, width: Float, isDotted: Boolean): LineStyle {
        val c = MapscoreColorHelper.intToColor(color)
        val csl = ColorStateList(c, c)
        val transparent = ColorStateList(Color(0f, 0f, 0f, 0f), Color(0f, 0f, 0f, 0f))
        return LineStyle(
            color = csl,
            gapColor = transparent,
            opacity = 1f,
            blur = 0f,
            widthType = SizeType.SCREEN_PIXEL,
            width = width,
            dashArray = if (isDotted) arrayListOf(10f, 20f) else arrayListOf(),
            dashFade = 0f,
            dashAnimationSpeed = 0f,
            lineCap = LineCapType.ROUND,
            lineJoin = LineJoinType.ROUND,
            offset = 0f,
            dotted = isDotted,
            dottedSkew = 0f,
        )
    }

    private fun deleteRoad(call: MethodCall, result: MethodChannel.Result) {
        val roadKey = call.arguments as String?
        if (roadKey != null) {
            roads[roadKey]?.let { it.remove(); roads.remove(roadKey) }
        } else {
            roads.values.forEach { it.remove() }
            roads.clear()
        }
        result.success(null)
    }

    private fun staticPosition(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as HashMap<String, Any>
        val id = args["id"] as String
        val points = args["point"] as MutableList<HashMap<String, Double>>
        val geoPoints = points.map { p ->
            MapscoreGeoPoint(
                lat = p["lat"]!!,
                lon = p["lon"]!!,
                angle = if (p.containsKey("angle")) p["angle"] ?: 0.0 else 0.0,
            )
        }.toMutableList()
        staticPoints[id] = geoPoints
        showStaticPosition(id)
        result.success(null)
    }

    private fun staticPositionIconMaker(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as HashMap<String, Any>
        try {
            val key = args["id"] as String
            val bitmap = (args["bitmap"] as ByteArray).toBitmap()
            val refresh = args["refresh"] as Boolean
            staticMarkerIcon[key] = bitmap
            if (staticPoints.containsKey(key) && refresh) showStaticPosition(key)
            result.success(null)
        } catch (e: Exception) {
            result.error("400", "error to getBitmap static Position", "")
        }
    }

    private fun showStaticPosition(id: String) {
        val helper = mapView?.getCoordinateConversionHelper() ?: return
        val density = screenDensity(context)
        // remove existing static icons for this group
        staticIcons[id]?.forEach { staticIconLayer.remove(it) }
        staticIcons[id] = mutableListOf()
        val points = staticPoints[id] ?: return
        val bitmap = staticMarkerIcon[id]
        points.forEachIndexed { index, geoPoint ->
            val texBmp = bitmap
            val iconInfo = if (texBmp != null) {
                val holder =
                    BitmapTextureHolder(if (geoPoint.angle > 0.0) texBmp.rotate((geoPoint.angle * 180.0 / PI).toFloat()) else texBmp)
                val size = Vec2F(texBmp.width.toFloat(), texBmp.height.toFloat())
                io.openmobilemaps.mapscore.shared.map.layers.icon.IconFactory.createIconWithAnchor(
                    identifier = "static_${id}_$index",
                    coordinate = latLonToRender(helper, geoPoint.lat, geoPoint.lon),
                    texture = holder,
                    iconSize = size,
                    scaleType = io.openmobilemaps.mapscore.shared.map.layers.icon.IconType.INVARIANT,
                    blendMode = BlendMode.NORMAL,
                    iconAnchor = Vec2F(0.5f, 0.5f),
                )
            } else {
                val def = androidx.core.content.ContextCompat.getDrawable(
                    context,
                    hamza.dali.flutter_osm_plugin.R.drawable.ic_location_on_red_24dp
                )!!
                val holder = BitmapTextureHolder(def)
                val size = Vec2F(def.intrinsicWidth.toFloat(), def.intrinsicHeight.toFloat())
                io.openmobilemaps.mapscore.shared.map.layers.icon.IconFactory.createIconWithAnchor(
                    identifier = "static_${id}_$index",
                    coordinate = latLonToRender(helper, geoPoint.lat, geoPoint.lon),
                    texture = holder,
                    iconSize = size,
                    scaleType = io.openmobilemaps.mapscore.shared.map.layers.icon.IconType.INVARIANT,
                    blendMode = BlendMode.NORMAL,
                    iconAnchor = Vec2F(0.5f, 0.5f),
                )
            }
            staticIconLayer.add(iconInfo)
            staticIcons[id]!!.add(iconInfo)
        }
    }

    private fun OsmRoadManager.RoadResult.toMap(key: String): HashMap<String, Any> =
        HashMap<String, Any>().apply {
            this["duration"] = duration
            this["distance"] = distance
            this["routePoints"] = encodedPolyline
            this["key"] = key
            this["instructions"] =
                if (instructions.isNotEmpty()) instructions.toMap() else emptyList<HashMap<String, Any>>()
        }

    override fun getView(): View = mainLinearLayout

    override fun dispose() {
        locationNewOverlay.onDestroy()
        job?.let { if (it.isActive) it.cancel() }
        mainLinearLayout.removeAllViews()
        providerLifecycle.getOSMLifecycle()?.removeObserver(this)
    }

    override fun onFlutterViewAttached(flutterView: View) {}

    override fun onFlutterViewDetached() {
        staticMarkerIcon.clear()
        staticPoints.clear()
        customMarkerIcon = null
    }

    override fun onSaveInstanceState(bundle: Bundle) {
        try {
            val center = mapView?.getCamera()?.getCenterPosition()
            val zoom = mapView?.getCamera()?.getZoom()
            if (center != null && zoom != null) {
                bundle.putString("zoom", MapscoreConstants.mapscoreToOsmZoom(zoom).toString())
            }
        } catch (e: Exception) {
            // map not ready
        }
    }

    override fun onRestoreInstanceState(bundle: Bundle?) {}

    override fun onCreate(owner: LifecycleOwner) {
        super.onCreate(owner)
        methodChannel = MethodChannel(binaryMessenger, "plugins.dali.hamza/osmview_$id")
        methodChannel.setMethodCallHandler(this)
        scope = owner.lifecycle.coroutineScope
        initMap(owner.lifecycle)
        Log.e("osm", "mapscore flutter plugin create")
    }

    override fun onStart(owner: LifecycleOwner) {
        super.onStart(owner)
        activity = hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.pluginBinding?.activity
        hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.pluginBinding?.addActivityResultListener(this)
    }

    override fun onResume(owner: LifecycleOwner) {
        super.onResume(owner)
        locationNewOverlay.onResume()
    }

    override fun onPause(owner: LifecycleOwner) {
        super.onPause(owner)
        locationNewOverlay.onPause()
        skipCheckLocation = false
    }

    override fun onStop(owner: LifecycleOwner) {
        super.onStop(owner)
        job?.let { if (it.isActive) it.cancel() }
        job = null
    }

    override fun onDestroy(owner: LifecycleOwner) {
        super.onDestroy(owner)
        locationNewOverlay.onDestroy()
        hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.pluginBinding?.removeActivityResultListener(this)
        mainLinearLayout.removeAllViews()
        methodChannel.setMethodCallHandler(null)
        mapView = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            MapscoreConstants.getUserLocationReqCode -> {
                skipCheckLocation = true
                if (gpsServiceManager.isProviderEnabled(GPS_PROVIDER) || gpsServiceManager.isProviderEnabled(
                        NETWORK_PROVIDER
                    )
                ) {
                    resultFlutter?.let { getUserLocation(it); resultFlutter = null }
                }
            }

            MapscoreConstants.currentUserLocationReqCode -> {
                skipCheckLocation = true
                if (gpsServiceManager.isProviderEnabled(GPS_PROVIDER)) enableUserLocation()
            }
        }
        return true
    }

    companion object {
        const val DEFAULT_OSM_TILE_URL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
    }
}

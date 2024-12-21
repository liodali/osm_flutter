package hamza.dali.flutter_osm_plugin.map

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.widget.FrameLayout
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import hamza.dali.flutter_osm_plugin.ProviderLifecycle
import hamza.dali.flutter_osm_plugin.location.OSMVectorLocationManager
import hamza.dali.flutter_osm_plugin.models.Anchor
import hamza.dali.flutter_osm_plugin.models.CustomCircleManager
import hamza.dali.flutter_osm_plugin.models.CustomFillManager
import hamza.dali.flutter_osm_plugin.models.CustomLineManager
import hamza.dali.flutter_osm_plugin.models.CustomSymbolManager
import hamza.dali.flutter_osm_plugin.models.FlutterGeoPoint
import hamza.dali.flutter_osm_plugin.models.FlutterMapLibreOSMRoad
import hamza.dali.flutter_osm_plugin.models.FlutterRoad
import hamza.dali.flutter_osm_plugin.models.MapMethodChannelCall
import hamza.dali.flutter_osm_plugin.models.OSMTile
import hamza.dali.flutter_osm_plugin.models.OnClickSymbols
import hamza.dali.flutter_osm_plugin.models.OnMapMove
import hamza.dali.flutter_osm_plugin.models.Shape
import hamza.dali.flutter_osm_plugin.models.VectorOSMTile
import hamza.dali.flutter_osm_plugin.models.toArrayLatLng
import hamza.dali.flutter_osm_plugin.models.toBoundingBox
import hamza.dali.flutter_osm_plugin.models.toBoundsLibre
import hamza.dali.flutter_osm_plugin.models.toGeoPoint
import hamza.dali.flutter_osm_plugin.models.toGeoPoints
import hamza.dali.flutter_osm_plugin.models.toList
import hamza.dali.flutter_osm_plugin.models.toLngLat
import hamza.dali.flutter_osm_plugin.models.toSymbols
import hamza.dali.flutter_osm_plugin.models.where
import hamza.dali.flutter_osm_plugin.utilities.toBitmap
import hamza.dali.flutter_osm_plugin.utilities.toGeoPoint
import hamza.dali.flutter_osm_plugin.utilities.toHashMap
import hamza.dali.flutter_osm_plugin.utilities.toPolyline
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding.OnSaveInstanceStateListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.platform.PlatformView
import org.maplibre.android.MapLibre
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdate
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import org.maplibre.android.maps.Style.OnStyleLoaded
import org.maplibre.android.plugins.annotation.*
import org.maplibre.android.plugins.annotation.Annotation
import org.maplibre.android.utils.ColorUtils
import org.osmdroid.api.IGeoPoint
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import java.util.ArrayList


class FlutterMapLibreView(
    private val context: Context,
    private val binaryMessenger: BinaryMessenger,
    private val idView: Int,//viewId
    private val providerLifecycle: ProviderLifecycle,
    private val keyArgMapSnapShot: String,
    private val customTile: OSMTile?,
    private val isEnabledRotationGesture: Boolean = false,
    private val isStaticMap: Boolean = false,
) : OnSaveInstanceStateListener, PlatformView, MethodCallHandler,
    PluginRegistry.ActivityResultListener, DefaultLifecycleObserver, OSMBase {
    private lateinit var methodChannel: MethodChannel
    private var activity: Activity? = null
    private var mapView: MapView? = null
    private var mapLibre: MapLibreMap? = null
    private var markerManager: CustomSymbolManager? = null
    private var markerStaticManager: CustomSymbolManager? = null
    private var fillShapeManager: CustomFillManager? = null
    private var circleShapeManager: CustomCircleManager? = null
    private var lineManager: CustomLineManager? = null
    private var singleClickMarker: OnClickSymbols? = null
    private var longClickMarker: OnClickSymbols? = null
    private var mapClick: OnClickSymbols? = null
    private var mapMove: OnMapMove? = null
    private var userLocationChanged: OnClickSymbols? = null
    private val idsShapes: MutableList<Triple<Annotation<*>, String, Shape>> =
        emptyList<Triple<Annotation<*>, String, Shape>>().toMutableList()
    private val roads: MutableList<FlutterMapLibreOSMRoad> = mutableListOf<FlutterMapLibreOSMRoad>()
    private var zoomStep = 1.0
    private var initZoom = 3.0
    private var locationManager: OSMVectorLocationManager? = null
    private var mainLinearLayout: FrameLayout = FrameLayout(context).apply {
        this.layoutParams =
            FrameLayout.LayoutParams(FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
    }

    init {
        MapLibre.getInstance(context) // needs to be called before MapView gets created
        mapView = MapView(context)
        mainLinearLayout.addView(mapView)
        providerLifecycle.getOSMLifecycle()?.addObserver(this)
    }

    override fun onSaveInstanceState(bundle: Bundle) {
        TODO("Not yet implemented")
    }

    override fun onRestoreInstanceState(bundle: Bundle?) {
        TODO("Not yet implemented")
    }

    override fun getView(): View? = mainLinearLayout
    override fun onCreate(owner: LifecycleOwner) {
        super.onCreate(owner)

        methodChannel = MethodChannel(binaryMessenger, "plugins.dali.hamza/osmview_$idView")
        methodChannel.setMethodCallHandler(this)
        init(
            OSMInitConfiguration(
                GeoPoint(0.0, 0.0),
                customTile = customTile,
                initZoom = 3.0
            )
        )
        mapView?.onCreate(null)

    }

    override fun onStart(owner: LifecycleOwner) {
        super.onStart(owner)
        locationManager?.onStart()
        mapView?.onStart()
    }

    override fun onResume(owner: LifecycleOwner) {
        super.onResume(owner)
        mapView?.onResume()
    }

    override fun onPause(owner: LifecycleOwner) {
        super.onPause(owner)
        mapView?.onPause()
    }

    override fun onStop(owner: LifecycleOwner) {
        super.onStop(owner)
        locationManager?.onStop()
        mapView?.onStop()
    }

    override fun onDestroy(owner: LifecycleOwner) {
        super.onDestroy(owner)

        locationManager?.onDestroy()
        mapView?.onDestroy()
        mapView = null
        mapLibre = null
        locationManager = null
    }

    override fun dispose() {
        providerLifecycle.getOSMLifecycle()?.removeObserver(this)
        mapView?.onDestroy()
        mapView = null
        mapLibre = null
    }

    override fun onMethodCall(
        call: MethodCall, result: MethodChannel.Result,
    ) {
        when (MapMethodChannelCall.Companion.fromMethodCall(call)) {
            MapMethodChannelCall.Init -> {
                mapView?.getMapAsync {
                    val args = call.arguments!! as HashMap<*, *>
                    val geoPoint = GeoPoint(args["lat"]!! as Double, args["lon"]!! as Double)
                    moveTo(geoPoint, initZoom, true)
                    methodChannel.invokeMethod("map#init", true)
                    result.success(200)
                }
            }

            MapMethodChannelCall.LimitArea -> {
                val list: List<Double> = (call.arguments as List<*>).filterIsInstance<Double>()
                val box = BoundingBox(
                    list[0], list[1], list[2], list[3]
                )
                setBoundingBox(box)
                result.success(200)
            }


            MapMethodChannelCall.AddMarker -> {
                val args = call.arguments as HashMap<*, *>
                val point = (args["point"] as HashMap<String, Double>).toGeoPoint()

                addMarker(point, MarkerConfiguration.fromArgs(args, customMarkerIcon))
                result.success(200)
            }

            MapMethodChannelCall.Bounds -> {
                result.success(bounds().toHashMap())
            }

            MapMethodChannelCall.Center -> {
                result.success(center().toHashMap())
            }

            MapMethodChannelCall.ChangeMarker -> {
                val args = call.arguments as HashMap<*, *>
                val oldLocation = (args["old_location"] as HashMap<String, Double>).toGeoPoint()
                val newLocation = (args["new_location"] as HashMap<String, Double>).toGeoPoint()
                val oldSymbol =
                    markerManager?.annotations?.where { it.latLng.toGeoPoint() == oldLocation }
                val oldIconKey = oldSymbol?.iconImage
                val angle = when (args.containsKey("angle") && args["angle"] != null) {
                    true -> args["angle"] as Double
                    else -> oldSymbol?.iconRotate?.toDouble() ?: 0.0
                }
                val anchor = when (args.containsKey("iconAnchor")) {
                    true ->
                        Anchor(args["iconAnchor"] as HashMap<String, Any>)

                    else ->
                        Anchor(0.5f, 0.5f, "center")
                }
                val icon = when (args.containsKey("new_icon")) {
                    true -> args["new_icon"] as ByteArray
                    else -> null
                }.let { byteArray ->
                    val bitmap = byteArray?.toBitmap()
                    bitmap
                }
                val factorSize = when (args.containsKey("new_factorSize")) {
                    true -> args["new_factorSize"] as Double
                    else -> 48.0
                }
                markerManager?.delete(oldSymbol)
                addMarker(
                    newLocation, MarkerConfiguration(
                        markerIcon = icon ?: when {
                            oldIconKey != null -> mapLibre?.style?.getImage(oldIconKey)
                                ?: customMarkerIcon!!

                            else -> customMarkerIcon!!
                        },
                        markerRotate = angle,
                        markerAnchor = anchor,
                        factorSize = factorSize
                    )
                )
                result.success(200)
            }

            MapMethodChannelCall.ChangeTile -> {
                val args = call.arguments as String
                changeTile(VectorOSMTile(style = args)) {
                    result.success(200)
                }

            }

            MapMethodChannelCall.DrawRoad -> {
                val roadConfig = OSMRoadConfiguration.fromArgs(call.arguments as HashMap<*, *>)
                val id = drawPolyline(roadConfig, true)
                result.success(
                    mapOf(
                        "id" to id
                    )
                )
            }

            MapMethodChannelCall.ClearRoads -> {
                clearAllPolylines()
                result.success(200)
            }


            MapMethodChannelCall.DefaultMarkerIcon -> {
                customMarkerIcon = (call.arguments as ByteArray).toBitmap()
                result.success(200)
            }

            MapMethodChannelCall.DeleteMakers -> {
                val args = call.arguments as List<*>
                val geoPoints = args.filterIsInstance<HashMap<*, *>>().map { mapGeoP ->
                    (mapGeoP as HashMap<String, Double>).toGeoPoint()
                }
                geoPoints.forEach { geoPoint ->
                    removeMarker(geoPoint)
                }
                result.success(200)
            }

            MapMethodChannelCall.DeleteRoad -> {
                val roadKey = call.arguments as String?
                if (roadKey != null) {
                    removePolyline(roadKey)
                }
                result.success(200)
            }

            MapMethodChannelCall.DrawMultiRoad -> {
                result.success(200)
            }

            MapMethodChannelCall.DrawRoadManually -> {
                result.success(200)
            }

            MapMethodChannelCall.DrawShape -> {
                addShape(OSMShapeConfiguration.fromArgs(call.arguments as HashMap<*, *>))
                result.success(200)
            }


            MapMethodChannelCall.RemoveShape -> {
                val args = call.arguments
                when {
                    args is String? && args != null -> {
                        removeShape(args)
                    }

                    args is HashMap<*, *> -> removeShapesByType(args["shape"] as String)
                }
                result.success(200)
            }

            MapMethodChannelCall.ClearShapes -> {
                fillShapeManager?.deleteAll()
                circleShapeManager?.deleteAll()
                mapLibre?.triggerRepaint()
                idsShapes.clear()
                result.success(200)
            }

            MapMethodChannelCall.GetMarkers -> {
                val jsonGeoPs = markers().map {
                    it.toHashMap()
                }
                result.success(jsonGeoPs)
            }

            MapMethodChannelCall.GetZoom -> {
                result.success(zoom())
                result.success(200)
            }

            MapMethodChannelCall.InfoWindowVisibility -> result.success(200)
            MapMethodChannelCall.MapOrientation -> {
                val rotate = call.arguments as Double? ?: 0.0

                val cameraPosition =
                    CameraPosition.Builder().target(mapLibre?.cameraPosition?.target).zoom(zoom())
                        .bearing(rotate)
                        .build()
                mapLibre?.animateCamera(object : CameraUpdate {
                    override fun getCameraPosition(maplibreMap: MapLibreMap): CameraPosition? {
                        return cameraPosition
                    }
                })
                result.success(200)
            }

            MapMethodChannelCall.MoveTo -> {
                val args = call.arguments!! as HashMap<*, *>
                val geoPoint = GeoPoint(args["lat"]!! as Double, args["lon"]!! as Double)
                val animate = args["animate"] as Boolean? == true
                moveTo(geoPoint, null, animate)
                result.success(200)
            }

            MapMethodChannelCall.RemoveLimitArea -> {
                mapLibre?.setLatLngBoundsForCameraTarget(LatLngBounds.world())
                result.success(200)
            }

            MapMethodChannelCall.RemoveMarkerPosition -> {
                val geoMap = call.arguments as HashMap<String, Double>
                removeMarker(geoMap.toGeoPoint())
                result.success(200)
            }

            MapMethodChannelCall.SetStepZoom -> {
                zoomStep = call.arguments as Double
                result.success(200)
            }

            MapMethodChannelCall.SetZoom -> {
                val args = call.arguments as HashMap<*, *>
                when (args.containsKey("stepZoom")) {
                    true -> {
                        var zoomInput = args["stepZoom"] as Double
                        if (zoomInput == 0.0) {
                            zoomInput = zoomStep
                        } else if (zoomInput == -1.0) {
                            zoomInput = -zoomStep
                        }
                        zoomIn(zoomInput.toInt(), true)
                    }

                    false -> {
                        if (args.containsKey("zoomLevel")) {
                            val level = args["zoomLevel"] as Double
                            setZoomLevel(level, true)
                        }

                    }
                }
                result.success(200)
            }

            MapMethodChannelCall.ShowZoomController -> {
                result.success(200)
            }


            MapMethodChannelCall.StaticPosition -> {
                val args = call.arguments as HashMap<*, *>
                val id = args["id"] as String?
                val points = args["point"] as List<HashMap<*, *>>?
                val geoPoints: MutableList<FlutterGeoPoint> = mutableListOf()
                for (geoPointMap in points!!) {
                    val geoPoint =
                        GeoPoint(geoPointMap["lat"]!! as Double, geoPointMap["lon"]!! as Double)
                    val angle = when (geoPointMap.containsKey("angle")) {
                        true -> geoPointMap["angle"] as Double? ?: 0.0
                        else -> 0.0
                    }
                    geoPoints.add(FlutterGeoPoint(geoPoint, angle))
                }

                setStaticMarkers(id ?: "", geoPoints)
                result.success(200)
            }

            MapMethodChannelCall.StaticPositionIconMarker -> {
                val hashMap: HashMap<*, *> = call.arguments as HashMap<*, *>

                try {
                    val key = (hashMap["id"] as String)
                    val size = (hashMap["factorSize"] as Double)
                    val bytes = (hashMap["bitmap"] as ByteArray)
                    setStaticMarkerIcons(key, bytes, size)

                } catch (e: java.lang.Exception) {
                    Log.e("id", hashMap["id"].toString())
                    Log.e("err static point marker", e.stackTraceToString())
                    result.error("400", "error to getBitmap static Position", "")
                    staticMarkerIcon = HashMap()
                }
                result.success(200)
            }


            MapMethodChannelCall.ToggleLayers -> {
                val isEnabled = call.arguments as Boolean
                lineManager?.toggle(isEnabled)
                markerManager?.toggle(isEnabled)
                fillShapeManager?.toggle(isEnabled)
                circleShapeManager?.toggle(isEnabled)
                result.success(200)
            }

            MapMethodChannelCall.LocationMarkers -> {
                val args = call.arguments!! as HashMap<*, *>
                // update user marker and direction marker
                val personIcon = (args["personIcon"] as ByteArray)
                val arrowIcon = (args["arrowDirectionIcon"] as ByteArray)
                val factorPerson = args["personIconFactorSize"] as Double? ?: 1.0
                val factorArrow = args["arrowDirectionIconFactorSize"] as Double? ?: 1.0
                customPersonMarkerIcon = MarkerConfiguration(
                    markerIcon = personIcon.toBitmap(),
                    markerRotate = 0.0,
                    markerAnchor = Anchor(0.5f, 0.5f),
                    factorSize = factorPerson
                )
                locationManager?.setMarkerIcon(
                    customPersonMarkerIcon,
                    Pair(arrowIcon.toBitmap(), factorArrow.toFloat())
                )
                result.success(200)
            }

            MapMethodChannelCall.StartLocationUpdating -> {
                locationManager?.startLocationUpdating()
                result.success(200)
            }

            MapMethodChannelCall.StopLocationUpdating -> {
                locationManager?.stopLocationUpdating()
                result.success(200)
            }

            MapMethodChannelCall.TrackMe -> {
                val args = call.arguments as List<*>
                val enableStopFollow = args.first() as Boolean
                val disableRotation = args[1] as Boolean
                val useDirectionMarker = args[2] as Boolean
                mapView?.getMapAsync { map ->
                    map.uiSettings.isRotateGesturesEnabled = disableRotation
                }
                locationManager?.configurationFollow(enableStopFollow, useDirectionMarker)
                locationManager?.toggleFollow()
                result.success(200)
            }

            MapMethodChannelCall.DeactivateTrackMe -> {

                locationManager?.disableFollowLocation()
                mapView?.getMapAsync { map ->
                    map.uiSettings.isRotateGesturesEnabled = true
                }
                result.success(200)
            }

            MapMethodChannelCall.CurrentLocation -> {
                locationManager?.currentUserPosition({ geoPoint ->
                    if (geoPoint != null) {
                        moveTo(geoPoint, mapLibre?.cameraPosition?.zoom, true)
                    }
                    result.success(200)
                }, {
                    result.error("userLocationFailed", "userLocationFailed", "userLocationFailed")
                })

            }

            MapMethodChannelCall.UpdateMarker -> {
                val args = call.arguments as HashMap<*, *>
                val point = (args["point"] as HashMap<String, Double>).toGeoPoint()
                var bitmap = customMarkerIcon
                if (args.containsKey("icon")) {
                    bitmap = (args["icon"] as ByteArray).toBitmap()
                    mapLibre?.style?.removeImage(point.toString())
                    mapLibre?.style?.addImage(point.toString(), bitmap)
                    markerManager?.updateSource()
                    mapLibre?.triggerRepaint()
                }

                result.success(200)
            }

            MapMethodChannelCall.UserPosition -> {
                result.success(200)
            }

            MapMethodChannelCall.ZoomConfiguration -> {
                val args = call.arguments as HashMap<*, *>

                zoomConfig(
                    OSMZoomConfiguration(
                        minZoom = args["minZoomLevel"] as Double,
                        maxZoom = args["maxZoomLevel"] as Double,
                        zoomStep = args["stepZoom"] as Double,
                        initZoom = args["initZoom"] as Double
                    )
                )
                result.success(200)
            }

            MapMethodChannelCall.ZoomToRegion -> {
                val args = call.arguments as Map<*, *>
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
                moveToBounds(box, 64, true)
                result.success(200)
            }

            else -> result.notImplemented()
        }
    }

    override fun onActivityResult(
        requestCode: Int, resultCode: Int, data: Intent?,
    ): Boolean {
        TODO("Not yet implemented")
    }


    override var customMarkerIcon: Bitmap? = null


    var customPersonMarkerIcon: MarkerConfiguration? = null
    override var staticMarkerIcon: HashMap<String, Bitmap> = HashMap<String, Bitmap>()
    override val staticPoints: HashMap<String, MutableList<FlutterGeoPoint>> =
        HashMap<String, MutableList<FlutterGeoPoint>>()


    override fun init(configuration: OSMInitConfiguration) {

        mapView?.getMapAsync { map ->
            mapLibre = map
            mapLibre!!.setMinZoomPreference(configuration.minZoom)
            mapLibre!!.setMaxZoomPreference(configuration.maxZoom)
            if (configuration.bounds != null) {
                mapLibre!!.setLatLngBoundsForCameraTarget(configuration.bounds.toBoundsLibre())
            }
            val style = when (configuration.customTile) {
                is VectorOSMTile -> Style.Builder().fromUri(configuration.customTile.style)
                else -> Style.Builder().fromUri("https://tiles.openfreemap.org/styles/liberty")
            }
            map.setStyle(style) { styleLoaded ->

                lineManager = CustomLineManager(
                    mapView!!,
                    mapLibre!!,
                    styleLoaded,
                    null,//markerManager?.layerId,
                    null,
                )
                markerManager = CustomSymbolManager(mapView!!, mapLibre!!, styleLoaded)

                markerStaticManager = CustomSymbolManager(
                    mapView!!,
                    mapLibre!!,
                    styleLoaded,
                    null,
                    lineManager?.layerId
                )

                fillShapeManager = CustomFillManager(
                    mapView!!, mapLibre!!, mapLibre!!.style!!,
                    lineManager?.layerId, null,
                )
                circleShapeManager = CustomCircleManager(
                    mapView!!, mapLibre!!, mapLibre!!.style!!,
                    lineManager?.layerId, null,
                )
                locationManager =
                    OSMVectorLocationManager(
                        context,
                        mapLibre!!,
                        SymbolManager(
                            mapView!!,
                            mapLibre!!,
                            styleLoaded,
                            null,
                            markerManager?.layerId
                        ),
                        methodChannel,
                        "receiveUserLocation"
                    )
            }

            map.cameraPosition = CameraPosition.Builder().target(configuration.point.toLngLat())
                .zoom(configuration.initZoom).build()
            map.addOnMapClickListener { lng ->
                mapClick?.invoke(lng.toGeoPoint())
                methodChannel.invokeMethod("receiveSinglePress", lng.toGeoPoint().toHashMap())
                false
            }
            map.addOnMapLongClickListener { lng ->
                mapClick?.invoke(lng.toGeoPoint())
                methodChannel.invokeMethod("receiveLongPress", lng.toGeoPoint().toHashMap())
                true
            }
            map.addOnCameraMoveListener {
                if (map.cameraPosition.target != null) {
                    val bounds = map.projection.visibleRegion.latLngBounds.toBoundingBox()
                    mapMove?.invoke(bounds, map.cameraPosition.target!!.toGeoPoint())
                }
                val hashMap = HashMap<String, Any?>()
                hashMap["bounding"] = bounds().toHashMap()
                hashMap["center"] = center().toHashMap()
                methodChannel.invokeMethod("receiveRegionIsChanging", hashMap)

            }
            map.addOnCameraMoveStartedListener { reason ->
                if (reason == MapLibreMap.OnCameraMoveStartedListener.REASON_API_GESTURE) {
                    if (locationManager != null && locationManager!!.isFollowing() && locationManager!!.enableAutoStop) {
                        locationManager?.stopCamera()
                        map.cancelTransitions()
                    }
                }
            }

        }

    }

    override fun changeTile(tile: OSMTile, onDone: () -> Unit) {
        mapLibre?.setStyle((tile as VectorOSMTile).style, object : OnStyleLoaded {
            override fun onStyleLoaded(p0: Style) {
                onDone()
            }

        })
    }

    override fun zoomConfig(zoomConfig: OSMZoomConfiguration) {
        zoomStep = zoomConfig.zoomStep
        mapLibre?.setMinZoomPreference(zoomConfig.minZoom)
        mapLibre?.setMaxZoomPreference(zoomConfig.maxZoom)
        initZoom = zoomConfig.initZoom
    }

    override fun setBoundingBox(bounds: BoundingBox) {
        mapLibre?.setLatLngBoundsForCameraTarget(bounds.toBoundsLibre())
    }

    override fun moveTo(point: IGeoPoint, zoom: Double?, animate: Boolean) {
        mapView?.getMapAsync { map ->
            val cameraPosition =
                CameraPosition.Builder().target(point.toLngLat())
                    .zoom(zoom ?: map.cameraPosition.zoom)
                    .build()
            when (animate) {
                true -> map.animateCamera(object : CameraUpdate {
                    override fun getCameraPosition(maplibreMap: MapLibreMap): CameraPosition? {
                        return cameraPosition
                    }
                })

                else -> map.cameraPosition = cameraPosition
            }
        }
    }

    override fun moveToBounds(bounds: BoundingBox, padding: Int, animate: Boolean) {
        mapView?.getMapAsync { map ->
            when (animate) {
                true -> map.animateCamera(object : CameraUpdate {
                    override fun getCameraPosition(maplibreMap: MapLibreMap): CameraPosition? {
                        return map.getCameraForLatLngBounds(
                            bounds.toBoundsLibre(),
                            intArrayOf(padding, padding, padding, padding)
                        )
                    }
                })

                else -> map.setLatLngBoundsForCameraTarget(bounds.toBoundsLibre())
            }
        }
    }

    override fun addMarker(point: IGeoPoint, markerConfiguration: MarkerConfiguration) {
        mapLibre!!.style!!.addImage(point.toString(), markerConfiguration.markerIcon)
        val symbolOp = SymbolOptions().withLatLng(point.toLngLat()).withIconImage(point.toString())
            .withIconAnchor(markerConfiguration.markerAnchor.name)
            .withIconSize(
                markerConfiguration.factorSize
                    .toFloat()
            )

        markerManager?.create(symbolOp)
        markerManager?.addClickListener(object : OnSymbolClickListener {
            override fun onAnnotationClick(t: Symbol?): Boolean {
                if (t != null) {
                    singleClickMarker?.invoke(t.latLng.toGeoPoint())
                    val hashMap = HashMap<String, Double>()
                    hashMap["lon"] = t.latLng.longitude
                    hashMap["lat"] = t.latLng.latitude
                    methodChannel.invokeMethod("receiveGeoPoint", hashMap)
                }
                return true
            }
        })
        markerManager?.addLongClickListener(object : OnSymbolLongClickListener {
            override fun onAnnotationLongClick(t: Symbol?): Boolean {
                if (t != null) {
                    longClickMarker?.invoke(t.latLng.toGeoPoint())
                    val hashMap = HashMap<String, Double>()
                    hashMap["lon"] = t.latLng.longitude
                    hashMap["lat"] = t.latLng.latitude
                    methodChannel.invokeMethod("receiveLongPressGeoPoint", hashMap)
                }
                return true
            }
        })
    }

    override fun removeMarker(point: IGeoPoint) {
        val symbol = markerManager?.annotations?.where { s ->
            s.latLng.toGeoPoint() == point
        }
        if (symbol != null) {
            mapLibre!!.style!!.removeImage(symbol.latLng.toGeoPoint().toString())
        }
        markerManager?.delete(symbol)
    }

    override fun setStaticMarkerIcons(id: String, icon: ByteArray, factorSize: Double?) {
        var bitmapIcon = icon.toBitmap()//.resize(factorSize?:1.0)

        mapLibre?.style?.addImage(id, bitmapIcon)
        staticMarkerIcon[id] = bitmapIcon
        if (staticPoints.containsKey(id)) {
            markerStaticManager?.updateSource()
        }
    }


    override fun setStaticMarkers(
        id: String, markers: List<FlutterGeoPoint>,
    ) {
        if (staticPoints.contains(id)) {
            staticPoints[id]?.clear()
        }
        staticPoints[id] = markers.toMutableList()
        val symbolOptions = staticPoints[id]?.toSymbols(id) ?: emptyList()
        val others: List<Symbol> = markerStaticManager?.annotations?.toList() ?: emptyList<Symbol>()
        markerStaticManager?.create(symbolOptions)
        markerStaticManager?.delete(others)

    }

    override fun drawPolyline(
        roadConfig: OSMRoadConfiguration, animate: Boolean,
    ): String {
        val road = FlutterMapLibreOSMRoad(idRoad = roadConfig.id, lineManager!!)
        for ((i, line) in roadConfig.linesConfig.withIndex()) {
            val linePoints = line.encodedPolyline.toPolyline()
            if (line.roadOption.roadBorderWidth > 0 && !line.roadOption.isDotted) {
                road.addSegment(
                    "${road.idRoad}-seg-$i-border",
                    linePoints,
                    line.roadOption,
                    isBorder = true
                )
            }
            road.addSegment("${road.idRoad}-seg-$i", linePoints, line.roadOption)
        }
        road.onRoadClickListener = object : FlutterRoad.OnRoadClickListener {
            override fun onClick(
                idRoad: String,
                lineId: String,
                lineDecoded: String
            ) {
                val map = HashMap<String, Any?>()

                map["key"] = when {
                    idRoad.contains("-border") -> idRoad.split("-border").first()
                    else -> idRoad
                }
                map["segId"] = lineId
                map["encoded"] = lineDecoded
                methodChannel.invokeMethod("receiveRoad", map)
            }

        }
        roads.add(road)
        val bounds = BoundingBox.fromGeoPoints(roadConfig.linesConfig.map {
            it.encodedPolyline.toPolyline()
        }.reduce { a, b -> (a + b) as ArrayList<GeoPoint> })
        moveToBounds(bounds, 64, roadConfig.zoomInto)
        return road.idRoad
    }

    override fun updatePolyline(road: OSMRoadConfiguration) {
        TODO("Not yet implemented")
    }

    override fun removePolyline(id: String) {
        val road = roads.firstOrNull {
            it.idRoad.contains(id)
        }
        road?.remove()
        roads.remove(road)
    }

    override fun clearAllPolylines() {
        lineManager!!.deleteAll()
        roads.clear()
    }

    override fun addShape(shapeConfiguration: OSMShapeConfiguration) {

        val shape = when (shapeConfiguration.shape) {
            Shape.CIRCLE -> {
                circleShapeManager?.create(
                    CircleOptions()
                        .withLatLng(shapeConfiguration.center)
                        .withCircleColor(ColorUtils.colorToRgbaString(shapeConfiguration.color))
                        .withCircleStrokeColor(ColorUtils.colorToRgbaString(shapeConfiguration.colorBorder))
                        .withCircleRadius(shapeConfiguration.distance.toFloat())
                        .withCircleStrokeWidth(shapeConfiguration.strokeWidth.toFloat())
                )

            }

            Shape.POLYGON -> {
                fillShapeManager?.create(
                    FillOptions()
                        .withLatLngs(listOf(shapeConfiguration.points.toArrayLatLng()))
                        .withFillColor(ColorUtils.colorToRgbaString(shapeConfiguration.color))
                        .withFillOutlineColor(ColorUtils.colorToRgbaString(shapeConfiguration.colorBorder))
                )
            }

        }
        if (shape != null) {
            idsShapes.add(Triple(shape, shapeConfiguration.key, shapeConfiguration.shape))
        }
    }

    override fun removeShape(id: String) {
        val shape = idsShapes.firstOrNull {
            it.second == id
        }
        when {
            shape != null && shape.third == Shape.POLYGON -> fillShapeManager?.delete(shape.first as Fill)
            shape != null && shape.third == Shape.CIRCLE -> circleShapeManager?.delete(shape.first as Circle)
        }
        idsShapes.remove(shape)
    }

    private fun removeShapesByType(shape: String) {
        val shapes = when (shape) {
            "rect" -> {
                val shapes = idsShapes.filter { shape ->
                    shape.third == Shape.POLYGON
                }
                fillShapeManager?.delete(shapes.map { it.first }.filterIsInstance<Fill>())
                shapes
            }

            "circle" -> {
                val shapes = idsShapes.filter { shape ->
                    shape.third == Shape.CIRCLE
                }
                circleShapeManager?.delete(shapes.map { it.first }.filterIsInstance<Circle>())
                shapes
            }

            else -> return
        }
        idsShapes.retainAll(shapes)
    }


    override fun zoomIn(step: Int, animate: Boolean) {
        mapView?.getMapAsync { map ->
            val cameraPosition =
                CameraPosition.Builder().zoom(map.cameraPosition.zoom + step)
                    .target(mapLibre!!.cameraPosition.target).build()
            when (animate) {
                true -> map.animateCamera(object : CameraUpdate {
                    override fun getCameraPosition(maplibreMap: MapLibreMap): CameraPosition? {
                        return cameraPosition
                    }
                })

                else -> map.cameraPosition = cameraPosition
            }
        }
    }

    override fun zoomOut(step: Int, animate: Boolean) {
        mapView?.getMapAsync { map ->
            val cameraPosition =
                CameraPosition.Builder().zoom(map.cameraPosition.zoom - step)
                    .target(mapLibre!!.cameraPosition.target).build()
            when (animate) {
                true -> map.animateCamera(object : CameraUpdate {
                    override fun getCameraPosition(maplibreMap: MapLibreMap): CameraPosition? {
                        return cameraPosition
                    }
                })

                else -> map.cameraPosition = cameraPosition
            }
        }
    }

    override fun setZoomLevel(zoomLevel: Double, animate: Boolean) {
        val camera =
            CameraPosition.Builder().zoom(zoomLevel).target(mapLibre!!.cameraPosition.target)
                .build()
        when (animate) {
            true -> mapLibre?.animateCamera(object : CameraUpdate {
                override fun getCameraPosition(maplibreMap: MapLibreMap): CameraPosition? {
                    return camera
                }
            })

            else -> mapLibre?.cameraPosition = camera
        }
    }

    override fun zoom(): Double {
        return mapLibre!!.cameraPosition.zoom
    }

    override fun center(): IGeoPoint {
        return mapLibre!!.cameraPosition.target!!.toGeoPoint()
    }


    override fun markers(): List<IGeoPoint> =
        markerManager?.annotations?.toGeoPoints() ?: emptyList()


    override fun bounds(): BoundingBox {
        return mapLibre!!.projection.visibleRegion.latLngBounds.toBoundingBox()
    }

    override fun startLocation() {
        TODO("Not yet implemented")
    }


    override fun stopLocation() {
        TODO("Not yet implemented")
    }

    override fun onMapClick(onClick: (IGeoPoint) -> Unit) {
        mapClick = onClick
    }

    override fun onMapMove(onMove: (BoundingBox, IGeoPoint) -> Unit) {
        mapMove = onMove
    }

    override fun onUserLocationChanged(onUserLocationChanged: (IGeoPoint) -> Unit) {
        userLocationChanged = onUserLocationChanged
    }

    override fun onMarkerSingleClick(onClick: (IGeoPoint) -> Unit) {
        singleClickMarker = onClick
    }

    override fun onMarkerLongClick(onClick: (IGeoPoint) -> Unit) {
        longClickMarker = onClick
    }

    override fun onPolylineClick(onClick: (IGeoPoint, String) -> Unit) {
        TODO("Not yet implemented")
    }

    override fun setActivity(activity: Activity) {
        this.activity = activity
    }
}

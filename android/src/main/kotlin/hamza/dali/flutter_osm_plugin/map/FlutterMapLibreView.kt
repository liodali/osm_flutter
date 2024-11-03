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
import hamza.dali.flutter_osm_plugin.models.FlutterGeoPoint
import hamza.dali.flutter_osm_plugin.models.MapMethodChannelCall
import hamza.dali.flutter_osm_plugin.models.OSMTile
import hamza.dali.flutter_osm_plugin.models.OnClickSymbols
import hamza.dali.flutter_osm_plugin.models.OnMapMove
import hamza.dali.flutter_osm_plugin.models.VectorOSMTile
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
import org.maplibre.android.plugins.annotation.*
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
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import org.osmdroid.api.IGeoPoint
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint


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
    private var markerManager: SymbolManager? = null
    private var userLocationManager: SymbolManager? = null
    private var markerStaticManager: SymbolManager? = null
    private var shapeManager: FillManager? = null
    private var lineManager: LineManager? = null
    private var singleClickMarker: OnClickSymbols? = null
    private var longClickMarker: OnClickSymbols? = null
    private var mapClick: OnClickSymbols? = null
    private var mapMove: OnMapMove? = null
    private var userLocationChanged: OnClickSymbols? = null

    private var zoomStep = 1.0

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
        init(OSMInitConfiguration(GeoPoint(0.0, 0.0)))
        mapView?.onCreate(null)
    }

    override fun onResume(owner: LifecycleOwner) {
        super.onResume(owner)
        mapView?.onResume()
    }

    override fun onStop(owner: LifecycleOwner) {
        super.onStop(owner)
        mapView?.onStop()
    }

    override fun onDestroy(owner: LifecycleOwner) {
        super.onDestroy(owner)
        mapView?.onDestroy()
        mapView = null
        mapLibre = null
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
                    moveTo(geoPoint, true)
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

            MapMethodChannelCall.LocationMarkers -> {
                // update user marker and direction marker
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
                result.success(200)
            }

            MapMethodChannelCall.ChangeTile -> {
                result.success(200)
            }

            MapMethodChannelCall.ClearRoads -> {
                result.success(200)
            }

            MapMethodChannelCall.ClearShapes -> {
                result.success(200)
            }

            MapMethodChannelCall.CurrentLocation -> {
                result.success(200)
            }

            MapMethodChannelCall.DeactivateTrackMe -> {
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
                result.success(200)
            }

            MapMethodChannelCall.DrawCircle -> {
                result.success(200)
            }

            MapMethodChannelCall.DrawMultiRoad -> {
                result.success(200)
            }

            MapMethodChannelCall.DrawRect -> {
                result.success(200)
            }

            MapMethodChannelCall.DrawRoadManually -> {
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
                moveTo(geoPoint, animate)
                result.success(200)
            }

            MapMethodChannelCall.RemoveCircle -> {
                result.success(200)
            }

            MapMethodChannelCall.RemoveLimitArea -> {
                result.success(200)
            }

            MapMethodChannelCall.RemoveMarkerPosition -> {
                result.success(200)
            }

            MapMethodChannelCall.RemoveRect -> {
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

            MapMethodChannelCall.StartLocationUpdating -> {
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
                    val bytes = (hashMap["bitmap"] as ByteArray)
                    setStaticMarkerIcons(key, bytes)

                } catch (e: java.lang.Exception) {
                    Log.e("id", hashMap["id"].toString())
                    Log.e("err static point marker", e.stackTraceToString())
                    result.error("400", "error to getBitmap static Position", "")
                    staticMarkerIcon = HashMap()
                }
                result.success(200)
            }

            MapMethodChannelCall.StopLocationUpdating -> {
                result.success(200)
            }

            MapMethodChannelCall.ToggleLayers -> {
                result.success(200)
            }

            MapMethodChannelCall.TrackMe -> {
                result.success(200)
            }

            MapMethodChannelCall.UpdateMarker -> {
                result.success(200)
            }

            MapMethodChannelCall.UserPosition -> {
                result.success(200)
            }

            MapMethodChannelCall.ZoomConfiguration -> {

                result.success(200)
            }

            MapMethodChannelCall.ZoomToRegion -> {
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


    override var customPersonMarkerIcon: Bitmap? = null


    override var customArrowMarkerIcon: Bitmap? = null
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
            val styleURL = when (configuration.customTile) {

                is VectorOSMTile -> configuration.customTile.style
                else -> "https://tiles.openfreemap.org/styles/liberty"
            }
            val style = Style.Builder().fromUri(styleURL)
            map.setStyle(style) { styleLoaded ->
                markerManager = SymbolManager(mapView!!, mapLibre!!, map.style!!)

                lineManager = LineManager(
                    mapView!!,
                    mapLibre!!,
                    map.style!!,
                    markerManager?.layerId,
                    null,
                )
                markerStaticManager = SymbolManager(
                    mapView!!,
                    mapLibre!!,
                    mapLibre!!.style!!,
                    null,
                    lineManager?.layerId
                )

                userLocationManager = SymbolManager(
                    mapView!!, mapLibre!!, mapLibre!!.style!!, null, markerManager?.layerId
                )
                shapeManager = FillManager(
                    mapView!!, mapLibre!!, mapLibre!!.style!!,
                    lineManager?.layerId, null,
                )

            }

            map.cameraPosition = CameraPosition.Builder().target(configuration.point.toLngLat())
                .zoom(configuration.initZoom).build()
            map.addOnMapClickListener { lng ->
                mapClick?.invoke(lng.toGeoPoint())
                methodChannel.invokeMethod("receiveSinglePress", lng.toGeoPoint().toHashMap())
                true
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

        }

    }

    override fun zoomConfig(zoomConfig: OSMZoomConfiguration) {
        zoomStep = zoomConfig.zoomStep
        mapLibre?.setMinZoomPreference(zoomConfig.minZoom)
        mapLibre?.setMaxZoomPreference(zoomConfig.maxZoom)
    }

    override fun setBoundingBox(bounds: BoundingBox) {
        mapLibre?.setLatLngBoundsForCameraTarget(bounds.toBoundsLibre())
    }

    override fun moveTo(point: IGeoPoint, animate: Boolean) {
        mapView?.getMapAsync { map ->
            val cameraPosition =
                CameraPosition.Builder().target(point.toLngLat()).zoom(map.cameraPosition.zoom)
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

    override fun moveToBounds(bounds: BoundingBox, animate: Boolean) {
        mapView?.getMapAsync { map ->
            when (animate) {
                true -> map.animateCamera(object : CameraUpdate {
                    override fun getCameraPosition(maplibreMap: MapLibreMap): CameraPosition? {
                        return map.getCameraForLatLngBounds(bounds.toBoundsLibre())
                    }
                })

                else -> map.setLatLngBoundsForCameraTarget(bounds.toBoundsLibre())
            }
        }
    }

    override fun addMarker(point: IGeoPoint, markerConfiguration: MarkerConfiguration) {
        mapLibre!!.style!!.addImage(point.toString(), markerConfiguration.markerIcon.toBitmap())
        val symbolOp = SymbolOptions().withLatLng(point.toLngLat()).withIconImage(point.toString())
            .withIconAnchor("center")
        markerManager?.create(symbolOp)
        markerManager?.addClickListener(object : OnSymbolClickListener {
            override fun onAnnotationClick(t: Symbol?): Boolean {
                if (t != null) {
                    singleClickMarker?.invoke(t.latLng.toGeoPoint())
                }
                return true
            }
        })
        markerManager?.addLongClickListener(object : OnSymbolLongClickListener {
            override fun onAnnotationLongClick(t: Symbol?): Boolean {
                if (t != null) {
                    singleClickMarker?.invoke(t.latLng.toGeoPoint())
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

    override fun setStaticMarkerIcons(id: String, icon: ByteArray) {
        val bitmapIcon = icon.toBitmap()
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
        polyline: List<IGeoPoint>, animate: Boolean,
    ): String {
        TODO("Not yet implemented")
    }

    override fun removePolyline(id: String) {
        TODO("Not yet implemented")
    }

    override fun drawEncodedPolyline(polylineEncoded: String): String {
        TODO("Not yet implemented")
    }

    override fun removeEncodedPolyline(id: String) {
        TODO("Not yet implemented")
    }

    override fun addShape(shapeConfiguration: OSMShapeConfiguration): String {
        TODO("Not yet implemented")
    }

    override fun removeShape(id: String) {
        TODO("Not yet implemented")
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
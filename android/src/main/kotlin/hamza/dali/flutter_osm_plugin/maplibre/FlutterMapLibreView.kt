package hamza.dali.flutter_osm_plugin.maplibre

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.widget.FrameLayout
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import hamza.dali.flutter_osm_plugin.MapMethodChannelCall
import hamza.dali.flutter_osm_plugin.ProviderLifecycle
import hamza.dali.flutter_osm_plugin.models.MarkerConfiguration
import hamza.dali.flutter_osm_plugin.models.OSMBase
import hamza.dali.flutter_osm_plugin.models.OSMInitConfiguration
import hamza.dali.flutter_osm_plugin.models.OSMShapeConfiguration
import hamza.dali.flutter_osm_plugin.models.OSMTile
import hamza.dali.flutter_osm_plugin.models.VectorOSMTile
import hamza.dali.flutter_osm_plugin.utilities.toBitmap
import org.maplibre.android.plugins.annotation.*
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding.OnSaveInstanceStateListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.platform.PlatformView
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdate
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.osmdroid.api.IGeoPoint
import org.osmdroid.util.BoundingBox
import java.util.HashMap

typealias OnClickSymbols = (IGeoPoint) -> Unit
typealias OnMapMove = (BoundingBox, IGeoPoint) -> Unit

class FlutterMapLibreView(
    private val context: Context,
    private val binaryMessenger: BinaryMessenger,
    private val id: Int,//viewId
    private val providerLifecycle: ProviderLifecycle,
    private val keyArgMapSnapShot: String,
    private val customTile: OSMTile?,
    private val isEnabledRotationGesture: Boolean = false,
    private val isStaticMap: Boolean = false
) : OnSaveInstanceStateListener, PlatformView, MethodCallHandler,
    PluginRegistry.ActivityResultListener, DefaultLifecycleObserver, OSMBase {
    private lateinit var methodChannel: MethodChannel
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
    private var mainLinearLayout: FrameLayout = FrameLayout(context).apply {
        this.layoutParams =
            FrameLayout.LayoutParams(FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
    }

    init {
        mapView = MapView(context)
        providerLifecycle.getOSMLifecycle()?.addObserver(this)
    }

    override fun onSaveInstanceState(bundle: Bundle) {
        TODO("Not yet implemented")
    }

    override fun onRestoreInstanceState(bundle: Bundle?) {
        TODO("Not yet implemented")
    }

    override fun getView(): View? = mainLinearLayout

    override fun dispose() {
        providerLifecycle.getOSMLifecycle()?.removeObserver(this)
        mapView?.onDestroy()
        mapView = null
        mapLibre = null
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        when(MapMethodChannelCall.fromMethodCall(call)){
            MapMethodChannelCall.Init -> {
                init(OSMInitConfiguration.fromMap(call.arguments as HashMap<String, Any>))
                result.success(200)
            }
            MapMethodChannelCall.LimitArea -> TODO()
            MapMethodChannelCall.LocationMarkers -> TODO()
            MapMethodChannelCall.AddMarker -> TODO()
            MapMethodChannelCall.Bounds -> TODO()
            MapMethodChannelCall.Center -> TODO()
            MapMethodChannelCall.ChangeMarker -> TODO()
            MapMethodChannelCall.ChangeTile -> TODO()
            MapMethodChannelCall.ClearRoads -> TODO()
            MapMethodChannelCall.ClearShapes -> TODO()
            MapMethodChannelCall.CurrentLocation -> TODO()
            MapMethodChannelCall.DeactivateTrackMe -> TODO()
            MapMethodChannelCall.DefaultMarkerIcon -> TODO()
            MapMethodChannelCall.DeleteMakers -> TODO()
            MapMethodChannelCall.DeleteRoad -> TODO()
            MapMethodChannelCall.DrawCircle -> TODO()
            MapMethodChannelCall.DrawMultiRoad -> TODO()
            MapMethodChannelCall.DrawRect -> TODO()
            MapMethodChannelCall.DrawRoadManually -> TODO()
            MapMethodChannelCall.GetMarkers -> TODO()
            MapMethodChannelCall.GetZoom -> TODO()
            MapMethodChannelCall.InfoWindowVisibility -> result.success(200)
            MapMethodChannelCall.MapOrientation -> TODO()
            MapMethodChannelCall.MoveTo -> TODO()
            MapMethodChannelCall.RemoveCircle -> TODO()
            MapMethodChannelCall.RemoveLimitArea -> TODO()
            MapMethodChannelCall.RemoveMarkerPosition -> TODO()
            MapMethodChannelCall.RemoveRect -> TODO()
            MapMethodChannelCall.SetStepZoom -> TODO()
            MapMethodChannelCall.SetZoom -> TODO()
            MapMethodChannelCall.ShowZoomController -> TODO()
            MapMethodChannelCall.StartLocationUpdating -> TODO()
            MapMethodChannelCall.StaticPosition -> TODO()
            MapMethodChannelCall.StaticPositionIconMarker -> TODO()
            MapMethodChannelCall.StopLocationUpdating -> TODO()
            MapMethodChannelCall.ToggleLayers -> TODO()
            MapMethodChannelCall.TrackMe -> TODO()
            MapMethodChannelCall.UpdateMarker -> TODO()
            MapMethodChannelCall.UserPosition -> TODO()
            MapMethodChannelCall.ZoomConfiguration -> TODO()
            MapMethodChannelCall.ZoomToRegion -> TODO()
            else -> result.notImplemented()
        }
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ): Boolean {
        TODO("Not yet implemented")
    }

    override fun onCreate(owner: LifecycleOwner) {
        super.onCreate(owner)
        methodChannel = MethodChannel(binaryMessenger, "plugins.dali.hamza/osmview_${id}")
        methodChannel.setMethodCallHandler(this)
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

    override fun init(configuration: OSMInitConfiguration) {

        mapView?.getMapAsync { map ->
            mapLibre = map
            mapLibre!!.setMinZoomPreference(configuration.minZoom)
            mapLibre!!.setMaxZoomPreference(configuration.maxZoom)
            if (configuration.bounds != null) {
                mapLibre!!.setLatLngBoundsForCameraTarget(configuration.bounds.toBoundsLibre())

            }
            when (configuration.customTile) {
                null -> map.setStyle("https://tiles.openfreemap.org/styles/liberty")
                is VectorOSMTile -> map.setStyle(configuration.customTile.style)
                else -> map.setStyle("https://tiles.openfreemap.org/styles/liberty")
            }
            markerManager = SymbolManager(mapView!!, mapLibre!!, mapLibre!!.style!!)
            userLocationManager = SymbolManager(mapView!!, mapLibre!!, mapLibre!!.style!!)
            markerStaticManager = SymbolManager(mapView!!, mapLibre!!, mapLibre!!.style!!)
            shapeManager = FillManager(mapView!!, mapLibre!!, mapLibre!!.style!!)
            lineManager = LineManager(mapView!!, mapLibre!!, mapLibre!!.style!!)
            map.cameraPosition = CameraPosition.Builder().target(configuration.point.toLngLat())
                .zoom(configuration.initZoom).build()
            map.addOnMapClickListener { lng ->
                mapClick?.invoke(lng.toGeoPoint())
                true
            }
            map.addOnCameraMoveListener {
                if (map.cameraPosition.target != null) {
                    val bounds = map.projection.visibleRegion.latLngBounds.toBoundingBox()
                    mapMove?.invoke(bounds, map.cameraPosition.target!!.toGeoPoint())
                }

            }

        }

    }

    override fun moveTo(point: IGeoPoint, animate: Boolean) {
        mapView?.getMapAsync { map ->
            val cameraPosition = CameraPosition.Builder().target(point.toLngLat())
                .zoom(map.cameraPosition.zoom).build()
            when (animate) {
                true -> map.moveCamera(object : CameraUpdate {
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
                true -> map.moveCamera(object : CameraUpdate {
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

        val symbolOp = SymbolOptions()
            .withLatLng(point.toLngLat())
            .withIconImage(point.toString())
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

    override fun drawPolyline(
        polyline: List<IGeoPoint>,
        animate: Boolean
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
                CameraPosition.Builder().zoom(map.cameraPosition.zoom + step).build()
            when (animate) {
                true -> map.moveCamera(object : CameraUpdate {
                    override fun getCameraPosition(maplibreMap: MapLibreMap): CameraPosition? {
                        return cameraPosition
                    }
                })

                else -> map.cameraPosition =
                    cameraPosition
            }
        }
    }

    override fun zoomOut(step: Int, animate: Boolean) {
        mapView?.getMapAsync { map ->
            val cameraPosition =
                CameraPosition.Builder().zoom(map.cameraPosition.zoom - step).build()
            when (animate) {
                true -> map.moveCamera(object : CameraUpdate {
                    override fun getCameraPosition(maplibreMap: MapLibreMap): CameraPosition? {
                        return cameraPosition
                    }
                })

                else -> map.cameraPosition =
                    cameraPosition
            }
        }
    }

    override fun zoom(): Double {
        return mapLibre!!.cameraPosition.zoom
    }

    override fun center(): IGeoPoint {
        return mapLibre!!.cameraPosition.target!!.toGeoPoint()
    }

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
}
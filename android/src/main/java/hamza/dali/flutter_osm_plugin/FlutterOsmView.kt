package hamza.dali.flutter_osm_plugin

import android.app.Activity
import android.app.Application
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.widget.LinearLayout
import androidx.core.content.ContextCompat
import androidx.core.graphics.BlendModeColorFilterCompat
import androidx.core.graphics.BlendModeCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.preference.PreferenceManager
import hamza.dali.flutter_osm_plugin.Constants.Companion.url
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding.OnSaveInstanceStateListener
import io.flutter.plugin.common.*
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.platform.PlatformView
import kotlinx.coroutines.Dispatchers.IO
import kotlinx.coroutines.Dispatchers.Main
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.osmdroid.bonuspack.routing.OSRMRoadManager
import org.osmdroid.bonuspack.routing.RoadManager
import org.osmdroid.config.Configuration
import org.osmdroid.events.MapEventsReceiver
import org.osmdroid.events.MapListener
import org.osmdroid.events.ScrollEvent
import org.osmdroid.events.ZoomEvent
import org.osmdroid.tileprovider.tilesource.TileSourceFactory.MAPNIK
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.CustomZoomButtonsController
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.FolderOverlay
import org.osmdroid.views.overlay.MapEventsOverlay
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polyline
import org.osmdroid.views.overlay.mylocation.GpsMyLocationProvider
import org.osmdroid.views.overlay.mylocation.MyLocationNewOverlay
import java.util.concurrent.atomic.AtomicInteger
import kotlin.collections.component1
import kotlin.collections.component2
import kotlin.collections.set

fun GeoPoint.toHashMap(): HashMap<String, Double> {
    return HashMap<String, Double>().apply {
        this.put(Constants.latLabel, latitude)
        this.put(Constants.lonLabel, longitude)
    }

}

class FlutterOsmView(
        private val context: Context?,
        private val register: PluginRegistry.Registrar,
        private val binaryMessenger: BinaryMessenger,
        private val id: Int,//viewId
        private val activityState: AtomicInteger,
        private var application: Application?,
        private val activity: Activity?,
        private val lifecycle: Lifecycle?,
        private val registrarActivityHashCode: Int,

        ) : Application.ActivityLifecycleCallbacks,
        DefaultLifecycleObserver,
        OnSaveInstanceStateListener,
        PlatformView,
        EventChannel.StreamHandler,
        MethodCallHandler {
    private var map: MapView
    private var locationNewOverlay: MyLocationNewOverlay? = null
    private var customMarkerIcon: Bitmap? = null
    private var staticMarkerIcon: HashMap<String, Bitmap> = HashMap()
    private val customRoadMarkerIcon = HashMap<String, Bitmap>()
    private val staticPoints: HashMap<String, MutableList<GeoPoint>> = HashMap()
    private val folderStaticPosition: FolderOverlay = FolderOverlay()
    private var flutterRoad: FlutterRoad? = null
    private var job: Job? = null

    private var methodChannel: MethodChannel
    private var eventChannel: EventChannel
    private var eventSink: EventSink? = null


    private var mapEventsOverlay: MapEventsOverlay? = null
    private var roadManager: OSRMRoadManager? = null
    private var roadColor: Int? = null
    private val defaultZoom = 10.0
    private var useSecureURL = true

    init {
        if (application == null) {
            application = register.activity().application
        }
        folderStaticPosition.name = Constants.nameFolderStatic
        Configuration.getInstance().load(context, PreferenceManager.getDefaultSharedPreferences(context))
        map = MapView(context).apply {
            this.layoutParams = MapView.LayoutParams(LinearLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
            this.isTilesScaledToDpi = true
            this.setMultiTouchControls(true)
            setTileSource(MAPNIK)
            zoomController.setVisibility(CustomZoomButtonsController.Visibility.NEVER)
        }
        map.addMapListener(object : MapListener {
            override fun onScroll(event: ScrollEvent?): Boolean {
                return false
            }

            override fun onZoom(event: ZoomEvent?): Boolean {
                if (event!!.zoomLevel < 12) {
                    val rect = Rect()
                    map.getDrawingRect(rect)
                    map.overlays.remove(folderStaticPosition)
                } else {
                    if (!map.overlays.contains(folderStaticPosition)) {
                        map.overlays.add(folderStaticPosition)
                    }
                }
                return false
            }
        })

        methodChannel = MethodChannel(binaryMessenger, "plugins.dali.hamza/osmview_${id}")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binaryMessenger, "plugins.dali.hamza/osmview_stream_${id}")
        eventChannel.setStreamHandler(this)

    }

    fun init() {

    }

    private fun setZoom(methodCall: MethodCall, result: MethodChannel.Result) {
        try {
            val zoom = methodCall.arguments as Double
            map.controller.setZoom(zoom)
            result.success(null)
        } catch (e: Exception) {
        }
    }

    private fun initPosition(methodCall: MethodCall, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val args = methodCall.arguments!! as HashMap<String, Double>

        map.overlays.clear()
        val geoPoint = GeoPoint(args["lat"]!!, args["lon"]!!)
        addMarker(geoPoint, defaultZoom, null)
        result.success(null)
    }

    private fun addMarker(geoPoint: GeoPoint, zoom: Double, color: Int?) {
        map.controller.setZoom(zoom)
        map.controller.animateTo(geoPoint)
        map.overlays.add(createMarker(geoPoint, color))
    }

    private fun createMarker(geoPoint: GeoPoint, color: Int?): Marker {
        val marker = FlutterMaker(application!!, map, geoPoint)
        val iconDrawable: Drawable = getDefaultIconDrawable(color)
        //marker.setPosition(geoPoint);
        marker.setIcon(iconDrawable)
        //marker.setInfoWindow(new FlutterInfoWindow(creatWindowInfoView(),map,geoPoint));
        marker.setPosition(geoPoint)
        return marker
    }

    private fun getDefaultIconDrawable(color: Int?): Drawable {
        val iconDrawable: Drawable
        if (customMarkerIcon != null) {
            iconDrawable = BitmapDrawable(activity!!.getResources(), customMarkerIcon)
            if (color != null) iconDrawable.setColorFilter(BlendModeColorFilterCompat.createBlendModeColorFilterCompat(color, BlendModeCompat.SRC_OVER))
        } else {
            iconDrawable = ContextCompat.getDrawable(activity!!, R.drawable.ic_location_on_red_24dp)!!
        }
        return iconDrawable
    }

    private fun enableMyLocation(result: MethodChannel.Result) {
        map.overlays.clear()
        if (staticPoints.isNotEmpty()) {
            val iterator = staticPoints.entries.iterator()
            while (iterator.hasNext()) {
                val mapEntry = iterator.next()
                showStaticPosition(mapEntry.key)
            }
        }
        locationNewOverlay = MyLocationNewOverlay(GpsMyLocationProvider(application), map)
        locationNewOverlay?.let { location ->
            location.enableMyLocation()
            location.runOnFirstFix {
                GlobalScope.launch(Main) {
                    val currentPosition = GeoPoint(location.lastFix.latitude, location.lastFix.longitude)
                    map.controller.setZoom(Constants.zoomMyLocation)
                    map.controller.animateTo(currentPosition)
                }
            }
        }

        map.overlays.add(locationNewOverlay)

        result.success(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "use#secure" -> {
                setSecureURL(call, result)
            }
            "Zoom" -> {
                setZoom(call, result)
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
                map.zoomController.setVisibility(visibility)
                result.success(null)
            }

            "initPosition" -> {
                initPosition(call, result)
            }

            "trackMe" -> {
                locationNewOverlay?.let {
                    if (it.isFollowLocationEnabled) {
                        it.disableFollowLocation()
                    } else {
                        it.enableFollowLocation()
                    }
                }
                result.success(null)
            }
            "user#position" -> {
                locationNewOverlay?.let {
                    if (!it.isMyLocationEnabled) {
                        result.error("404", "enabled track you current position fisrt", "")
                    } else {
                        currentUserPosition(call, result)
                    }
                } ?: result.error("400", "Opps!erreur locationOverlay is NULL", "")
            }

            "user#pickPosition" -> {
                pickPosition(call, result)
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
            "road#markers" -> {
                serRoadMaker(call, result)
            }
            "staticPosition" -> {
                staticPosition(call, result)
            }
            "staticPosition#IconMarker" -> {
                staticPositionIconMaker(call, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun drawRoad(call: MethodCall, result: MethodChannel.Result) {
        val listPointsArgs = call.arguments!! as List<HashMap<String, Double>>

        map.overlays.removeAll {
            it is Polyline
        }
        map.invalidate()

        if (roadManager == null)
            roadManager = OSRMRoadManager(application!!)
        roadManager?.let { manager ->

            job = GlobalScope.launch(IO) {
                if (useSecureURL) roadManager!!.setService("https://$url")
                val wayPoints = listPointsArgs.map {
                    GeoPoint(it["lat"]!!, it["lon"]!!)
                }.toMutableList()
                val road = manager.getRoad(ArrayList(wayPoints))
                if (road.mRouteHigh.size > 2) {
                    val polyLine = RoadManager.buildRoadOverlay(road)
                    withContext(Main) {
                        polyLine.outlinePaint.color = Color.GREEN
                        roadColor?.let { color ->
                            polyLine.getOutlinePaint().setColor(color)

                        }
                        flutterRoad = FlutterRoad(application!!, map)
                        flutterRoad?.let {
                            it.markersIcons = customRoadMarkerIcon
                            it.road = polyLine
                        }
                        map.invalidate()
                        result.success(null)
                    }
                }

            }
        }
    }

    private fun staticPositionIconMaker(call: MethodCall, result: MethodChannel.Result) {
        val hasmap = call.arguments as HashMap<String, Any>

        try {
            val bitmap = getBitmap((hasmap["bitmap"] as ByteArray))
            staticMarkerIcon[(hasmap["id"] as String)] = bitmap
            result.success(null)
        } catch (e: java.lang.Exception) {
            Log.e("id", hasmap["id"].toString())
            Log.e("err", e.message)
            result.error("400", "error to getBitmap static Position", "")
            staticMarkerIcon = HashMap()
        }
    }

    private fun staticPosition(call: MethodCall, result: MethodChannel.Result) {
        val map = call.arguments as HashMap<String, Any>
        val id = map["id"] as String?
        val points = map["point"] as MutableList<HashMap<String, Double>>?
        val geoPoints: MutableList<GeoPoint> = ArrayList()
        for (hashmap in points!!) {
            geoPoints.add(GeoPoint(hashmap["lat"]!!, hashmap["lon"]!!))
        }
        if (staticPoints.containsKey(id)) {
            Log.e(id, "" + points!!.size)
            staticPoints[id]?.clear()
            staticPoints[id]?.addAll(geoPoints)
        } else {
            staticPoints[id!!] = geoPoints
        }
        showStaticPosition(id!!)
        result.success(null)
    }

    private fun serRoadMaker(call: MethodCall, result: MethodChannel.Result) {
        try {
            val hashMap = call.arguments!! as HashMap<String, ByteArray>
            hashMap.forEach { (key, bytes) ->
                customRoadMarkerIcon.put(key, BitmapFactory.decodeByteArray(bytes, 0, bytes.size))
            }
            result.success(null)
        } catch (e: Exception) {
            Log.d("err", e.message)
            result.error("400", "Opss!Erreur", e.stackTrace.toString())

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
        } catch (e: java.lang.Exception) {
            Log.d("err", e.message!!)
            customMarkerIcon = null
            result.error("500", "Cannot make markerIcon custom", "")
        }
    }

    private fun pickPosition(call: MethodCall, result: MethodChannel.Result) {
        //val usingCamera=call.arguments as Boolean
        if (mapEventsOverlay == null) {
            mapEventsOverlay = MapEventsOverlay(object : MapEventsReceiver {
                override fun singleTapConfirmedHelper(p: GeoPoint?): Boolean {
                    mapEventsOverlay = null
                    map.overlays.removeFirst()
                    addMarker(p!!, Constants.zoomMyLocation, null)
                    result.success(p.toHashMap())

                    return true
                }

                override fun longPressHelper(p: GeoPoint?): Boolean {
                    TODO("Not yet implemented")
                }

            })
            map.overlays.add(0, mapEventsOverlay)
        }
    }

    private fun currentUserPosition(call: MethodCall, result: MethodChannel.Result) {
        locationNewOverlay!!.let {
            it.lastFix?.let {
                val point = GeoPoint(it.latitude, it.longitude)
                result.success(point.toHashMap())
            } ?: result.error("400", "we cannot get the current position!", "")

        }
    }

    private fun showStaticPosition(idStaticPosition: String) {

        folderStaticPosition.items.retainAll {
            (it as FolderOverlay).name?.equals(id) == true
        }

        val overlay = FolderOverlay().apply {
            name = idStaticPosition
        }
        staticPoints.get(idStaticPosition)?.forEach { geoPoint ->
            val maker = FlutterMaker(application!!, map)
            maker.position = geoPoint
            maker.defaultInfoWindow()
            maker.onClickListener = object : Marker.OnMarkerClickListener {
                override fun onMarkerClick(marker: Marker?, mapView: MapView?): Boolean {
                    val hashMap = HashMap<String, Double>()
                    hashMap["lon"] = marker!!.position.longitude
                    hashMap["lat"] = marker.position.latitude
                    eventSink!!.success(hashMap)
                    return true
                }
            }
            if (staticMarkerIcon.isNotEmpty()) {
                maker.setIconMaker(null, staticMarkerIcon[id])
            }
            overlay.items.add(maker)
        }
        folderStaticPosition.items.add(overlay)
        if (map.zoomLevelDouble > 10.0) {
            if (map.overlays.contains(folderStaticPosition)) {
                map.overlays.remove(folderStaticPosition)
                map.overlays.add(folderStaticPosition)
                map.invalidate()
            }
        }

    }

    private fun setSecureURL(call: MethodCall, result: MethodChannel.Result) {
        useSecureURL = call.arguments as Boolean
        result.success(null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    private fun getBitmap(bytes: ByteArray): Bitmap {
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
    }

    override fun onCancel(arguments: Any?) {
        TODO("Not yet implemented")
    }


    override fun getView(): View {
        return map.rootView
    }

    override fun dispose() {}

    override fun onFlutterViewAttached(flutterView: View) {
        map.onAttachedToWindow()
    }


    override fun onFlutterViewDetached() {
        map.onDetach()
    }


    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
        TODO("Not yet implemented")
    }

    override fun onActivityStarted(activity: Activity) {
        TODO("Not yet implemented")
    }

    override fun onActivityResumed(activity: Activity) {
        map.onResume()
    }

    override fun onActivityPaused(activity: Activity) {
        map.onPause()

    }

    override fun onActivityStopped(activity: Activity) {
        job?.let {
            if (it.isActive) {
                it.cancel()
            }
        }
        job = null
    }

    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {
        TODO("Not yet implemented")
    }

    override fun onActivityDestroyed(activity: Activity) {
        TODO("Not yet implemented")
    }

    override fun onSaveInstanceState(bundle: Bundle) {
        TODO("Not yet implemented")
    }

    override fun onRestoreInstanceState(bundle: Bundle?) {
        TODO("Not yet implemented")
    }


}
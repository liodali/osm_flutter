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
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.coroutineScope
import hamza.dali.flutter_osm_plugin.Constants.Companion.url
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.CREATED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.DESTROYED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.PAUSED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.STARTED
import hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.Companion.STOPPED
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding.OnSaveInstanceStateListener
import io.flutter.plugin.common.*
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.platform.PlatformView
import kotlinx.coroutines.*
import kotlinx.coroutines.Dispatchers.Default
import kotlinx.coroutines.Dispatchers.Main
import org.osmdroid.bonuspack.routing.OSRMRoadManager
import org.osmdroid.bonuspack.routing.RoadManager
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

class FlutterOsmView(
        private val context: Context?,
        register: PluginRegistry.Registrar?,
        private val binaryMessenger: BinaryMessenger,
        private val id: Int,//viewId
        private var application: Application?,
        private var activity: Activity?,
        lifecycle: Lifecycle?,

        ) :
        DefaultLifecycleObserver,
        OnSaveInstanceStateListener,
        PlatformView,
        EventChannel.StreamHandler,
        MethodCallHandler {


    private var map: MapView? = null
    private var locationNewOverlay: MyLocationNewOverlay? = null
    private var customMarkerIcon: Bitmap? = null
    private var staticMarkerIcon: HashMap<String, Bitmap> = HashMap()
    private val customRoadMarkerIcon = HashMap<String, Bitmap>()
    private val staticPoints: HashMap<String, MutableList<GeoPoint>> = HashMap()
    private val folderStaticPosition: FolderOverlay = FolderOverlay()
    private val folderRoad: FolderOverlay = FolderOverlay().apply {
        this.name = Constants.roadName
    }
    private var flutterRoad: FlutterRoad? = null
    private var job: Job? = null
    private var jobFlow: Job? = null
    private var scope: CoroutineScope? = null


    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventSink? = null

    private var provider:GpsMyLocationProvider? = null
    private var mapEventsOverlay: MapEventsOverlay? = null
    private var roadManager: OSRMRoadManager? = null
    private var roadColor: Int? = null
    private var defaultZoom = Constants.defaultZoom
    private val initPositionZoom = 10.0
    private var useSecureURL = true
    private var isTracking = false
    private var isEnabled = false

    private var mainLinearLayout: LinearLayout

    init {


        mainLinearLayout = LinearLayout(context).apply {
            this.layoutParams = MapView.LayoutParams(LinearLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
            this.orientation = LinearLayout.VERTICAL
        }
        lifecycle?.addObserver(this)


    }


    private fun initMap() {
        map = MapView(context).apply {
            this.layoutParams = MapView.LayoutParams(LinearLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
            this.isTilesScaledToDpi = true
            this.setMultiTouchControls(true)
            setTileSource(MAPNIK)
            zoomController.setVisibility(CustomZoomButtonsController.Visibility.NEVER)
        }
        map!!.addMapListener(object : MapListener {
            override fun onScroll(event: ScrollEvent?): Boolean {
                return true
            }

            override fun onZoom(event: ZoomEvent?): Boolean {
                if (event!!.zoomLevel < Constants.zoomStaticPosition) {
                    val rect = Rect()
                    map!!.getDrawingRect(rect)
                    map!!.overlays.remove(folderStaticPosition)
                } else {
                    if (!map!!.overlays.contains(folderStaticPosition)) {
                        map!!.overlays.add(folderStaticPosition)
                    }
                }
                return true
            }
        })
        mainLinearLayout.addView(map)
    }

    private fun setZoom(methodCall: MethodCall, result: MethodChannel.Result) {
        try {
            var zoomInput = methodCall.arguments as Double
            if (zoomInput == 0.0) {
                zoomInput = defaultZoom
            } else if (zoomInput == -1.0) {
                zoomInput = -defaultZoom
            }
            val zoom = map!!.zoomLevelDouble + zoomInput
            map!!.controller.setZoom(zoom)
            result.success(null)
        } catch (e: Exception) {
        }
    }

    private fun initPosition(methodCall: MethodCall, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val args = methodCall.arguments!! as HashMap<String, Double>

        map!!.overlays.clear()
        val geoPoint = GeoPoint(args["lat"]!!, args["lon"]!!)
        addMarker(geoPoint, initPositionZoom, null)
        result.success(null)
    }

    private fun addMarker(geoPoint: GeoPoint, zoom: Double, color: Int? = null) {
        map!!.controller.setZoom(zoom)
        map!!.controller.animateTo(geoPoint)
        map!!.overlays.add(createMarker(geoPoint, color))
    }

    private fun createMarker(geoPoint: GeoPoint, color: Int?): Marker {
        val marker = FlutterMaker(application!!, map!!, geoPoint)
        val iconDrawable: Drawable = getDefaultIconDrawable(color)
        //marker.setPosition(geoPoint);
        marker.icon = iconDrawable
        //marker.setInfoWindow(new FlutterInfoWindow(creatWindowInfoView(),map!!,geoPoint));
        marker.position = geoPoint
        return marker
    }

    private fun getDefaultIconDrawable(color: Int?): Drawable {
        val iconDrawable: Drawable
        if (customMarkerIcon != null) {
            iconDrawable = BitmapDrawable(activity!!.resources, customMarkerIcon)
            if (color != null) iconDrawable.setColorFilter(BlendModeColorFilterCompat.createBlendModeColorFilterCompat(color, BlendModeCompat.SRC_OVER))
        } else {
            iconDrawable = ContextCompat.getDrawable(activity!!, R.drawable.ic_location_on_red_24dp)!!
        }
        return iconDrawable
    }

    private fun enableMyLocation(result: MethodChannel.Result) {
        if (folderRoad.items.isNotEmpty()) {
            folderRoad.items.forEach {
                folderRoad.remove(it)
            }
            map!!.invalidate()
        }
        /*if (staticPoints.isNotEmpty()) {
            val iterator = staticPoints.entries.iterator()
            while (iterator.hasNext()) {
                val mapEntry = iterator.next()
                showStaticPosition(mapEntry.key)
            }
        }*/
        if (locationNewOverlay == null) {
             provider = GpsMyLocationProvider(application)
            locationNewOverlay = MyLocationNewOverlay(provider, map)

        }
        locationNewOverlay!!.setPersonIcon(customMarkerIcon)
        locationNewOverlay?.let { location ->
            if (!location.isMyLocationEnabled) {
                isEnabled = true
                location.enableMyLocation()
            }
            location.runOnFirstFix {
                GlobalScope.launch(Main) {
                    val currentPosition = GeoPoint(location.lastFix.latitude, location.lastFix.longitude)
                    map!!.controller.setZoom(Constants.zoomMyLocation)
                    map!!.controller.animateTo(currentPosition)
                }
            }
        }

        map!!.overlays.add(locationNewOverlay)

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
            "defaultZoom" -> {
                defaultZoom = call.arguments as Double
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
                map!!.zoomController.setVisibility(visibility)
                result.success(null)
            }

            "initPosition" -> {
                initPosition(call, result)
            }

            "trackMe" -> {
                locationNewOverlay?.let {
                    if (it.isFollowLocationEnabled) {
                        it.disableFollowLocation()
                        it.disableMyLocation()
                        isTracking = false
                        isEnabled = false
                    } else {
                        isTracking = true
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
                setRoadMaker(call, result)
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
            roadManager = OSRMRoadManager(application!!)
        roadManager?.let { manager ->

            job = scope?.launch(Default) {
                if (useSecureURL) roadManager!!.setService("https://$url")
                val wayPoints = listPointsArgs.map {
                    GeoPoint(it["lat"]!!, it["lon"]!!)
                }.toMutableList()
                withContext(Main) {
                    map!!.overlays.removeAll {
                        it is FlutterMaker && wayPoints.contains(it.position)
                    }
                    map!!.invalidate()
                }
                val road = manager.getRoad(ArrayList(wayPoints))
                withContext(Main) {
                    if (road.mRouteHigh.size > 2) {
                        val polyLine = RoadManager.buildRoadOverlay(road)
                        polyLine.outlinePaint.color = Color.GREEN
                        roadColor?.let { color ->
                            polyLine.outlinePaint.color = color
                        }
                        flutterRoad = FlutterRoad(application!!, map!!)
                        flutterRoad?.let {
                            it.markersIcons = customRoadMarkerIcon
                            polyLine.outlinePaint.strokeWidth = 5.0f
                            it.road = polyLine
                            folderRoad.items.add(it.start)
                            folderRoad.items.add(it.end)
                            folderRoad.items.add(it.road!!)
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
            Log.e("err static point marker", e.message as String)
            result.error("400", "error to getBitmap static Position", "")
            staticMarkerIcon = HashMap()
        }
    }

    private fun staticPosition(call: MethodCall, result: MethodChannel.Result) {
        val map = call.arguments as HashMap<String, Any>
        val id = map["id"] as String?
        val points = map["point"] as MutableList<HashMap<String, Double>>?
        val geoPoints: MutableList<GeoPoint> = emptyList<GeoPoint>().toMutableList()
        for (hashMap in points!!) {
            geoPoints.add(GeoPoint(hashMap["lat"]!!, hashMap["lon"]!!))
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
        showStaticPosition(id!!)
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
                    map!!.overlays.removeFirst()
                    addMarker(p!!, Constants.zoomMyLocation, null)
                    result.success(p.toHashMap())

                    return true
                }

                override fun longPressHelper(p: GeoPoint?): Boolean {
                    TODO("Not yet implemented")
                }

            })
            map!!.overlays.add(0, mapEventsOverlay)
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

        /* folderStaticPosition.items.retainAll {
             (it as FolderOverlay).name?.equals(idStaticPosition) == true
         }*/


        val overlay = FolderOverlay().apply {
            name = idStaticPosition
        }
        staticPoints[idStaticPosition]?.forEach { geoPoint ->
            val maker = FlutterMaker(application!!, map!!)
            maker.position = geoPoint
            maker.defaultInfoWindow()
            maker.onClickListener = Marker.OnMarkerClickListener { marker, _ ->
                val hashMap = HashMap<String, Double>()
                hashMap["lon"] = marker!!.position.longitude
                hashMap["lat"] = marker.position.latitude
                eventSink!!.success(hashMap)
                true
            }
            if (staticMarkerIcon.isNotEmpty()) {
                maker.setIconMaker(null, staticMarkerIcon[idStaticPosition])
            }
            overlay.add(maker)
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
        return mainLinearLayout
    }

    override fun dispose() {
        mainLinearLayout.removeAllViews()
        map = null
    }

    override fun onFlutterViewAttached(flutterView: View) {
        //   map!!.onAttachedToWindow()
        flutterView.requestLayout()
    }


    override fun onFlutterViewDetached() {
        //    map!!.onDetach()
    }


    override fun onSaveInstanceState(bundle: Bundle) {
        TODO("Not yet implemented")
    }

    override fun onRestoreInstanceState(bundle: Bundle?) {
        TODO("Not yet implemented")
    }

    override fun onCreate(owner: LifecycleOwner) {
        FlutterOsmPlugin.state.set(CREATED)
        methodChannel = MethodChannel(binaryMessenger, "plugins.dali.hamza/osmview_${id}")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binaryMessenger, "plugins.dali.hamza/osmview_stream_${id}")
        eventChannel.setStreamHandler(this)
        scope = owner.lifecycle.coroutineScope
        folderStaticPosition.name = Constants.nameFolderStatic

        initMap()


    }

    override fun onStart(owner: LifecycleOwner) {
        FlutterOsmPlugin.state.set(STARTED)
        Log.e("osm", "osm flutter plugin start")

    }

    override fun onResume(owner: LifecycleOwner) {
        FlutterOsmPlugin.state.set(FlutterOsmPlugin.RESUMED)
        Log.e("osm", "osm flutter plugin resume")
        map!!.onResume()
        locationNewOverlay?.also { myLocation ->
            if (isEnabled) {
                myLocation.enableMyLocation()
            }
            if (isTracking) {
                myLocation.enableFollowLocation()
            }

        }

    }

    override fun onPause(owner: LifecycleOwner) {
        FlutterOsmPlugin.state.set(PAUSED)
        locationNewOverlay?.also { myLocation ->
            if (myLocation.isFollowLocationEnabled) {
                myLocation.disableFollowLocation()
            }
            if (myLocation.isMyLocationEnabled) {
                myLocation.disableMyLocation()
            }
        }
        map!!.onPause()

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
        /*
        map!!.removeMapListener(mapListener)
        map!!.clearFindViewByIdCache()
        map!!.tileProvider.clearTileCache()
         */


    }

    override fun onDestroy(owner: LifecycleOwner) {
        FlutterOsmPlugin.state.set(DESTROYED)
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        mainLinearLayout.removeAllViews()
        map = null
    }

}
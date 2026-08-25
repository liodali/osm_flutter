package hamza.dali.flutter_osm_plugin.mapscore

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Existing Android command names, kept byte-for-byte compatible with Dart. */
internal enum class LegacyMapCommand(val methodName: String) {
    CHANGE_TILE("change#tile"),
    USE_VISIBILITY_INFO_WINDOW("use#visiblityInfoWindow"),
    CONFIG_ZOOM("config#Zoom"),
    ZOOM("Zoom"),
    GET_ZOOM("get#Zoom"),
    CHANGE_STEP_ZOOM("change#stepZoom"),
    ZOOM_TO_REGION("zoomToRegion"),
    SHOW_ZOOM_CONTROLLER("showZoomController"),
    CURRENT_LOCATION("currentLocation"),
    INIT_MAP("initMap"),
    LIMIT_AREA("limitArea"),
    REMOVE_LIMIT_AREA("remove#limitArea"),
    CHANGE_POSITION("changePosition"),
    TRACK_ME("trackMe"),
    DEACTIVATE_TRACK_ME("deactivateTrackMe"),
    START_LOCATION_UPDATING("startLocationUpdating"),
    STOP_LOCATION_UPDATING("stopLocationUpdating"),
    MAP_CENTER("map#center"),
    MAP_BOUNDS("map#bounds"),
    USER_POSITION("user#position"),
    MOVE_TO_POSITION("moveTo#position"),
    USER_REMOVE_MARKER_POSITION("user#removeMarkerPosition"),
    DELETE_ROAD("delete#road"),
    DRAW_MULTI_ROAD("draw#multi#road"),
    CLEAR_ROADS("clear#roads"),
    MARKER_ICON("marker#icon"),
    DRAW_ROAD_MANUALLY("drawRoad#manually"),
    STATIC_POSITION("staticPosition"),
    STATIC_POSITION_ICON_MARKER("staticPosition#IconMarker"),
    DRAW_CIRCLE("draw#circle"),
    DRAW_RECT("draw#rect"),
    REMOVE_CIRCLE("remove#circle"),
    REMOVE_RECT("remove#rect"),
    CLEAR_SHAPES("clear#shapes"),
    MAP_ORIENTATION("map#orientation"),
    USER_LOCATION_MARKERS("user#locationMarkers"),
    ADD_MARKER("add#Marker"),
    UPDATE_MARKER("update#Marker"),
    CHANGE_MARKER("change#Marker"),
    GET_GEOPOINTS("get#geopoints"),
    DELETE_MARKERS("delete#markers"),
    TOGGLE_ALL_LAYER("toggle#Alllayer"),
    ;

    companion object {
        private val byMethodName = values().associateBy(LegacyMapCommand::methodName)

        fun fromMethodName(methodName: String): LegacyMapCommand? = byMethodName[methodName]
    }
}

/** New typed fallback commands kept separate from the legacy method set. */
internal enum class TypedMapCommand(val methodName: String) {
    SET_ROTATION("android#camera#rotation"),
    ADD_MARKER("android#marker#add"),
    REMOVE_MARKER("android#marker#remove"),
    ;

    companion object {
        private val byMethodName = values().associateBy(TypedMapCommand::methodName)

        fun fromMethodName(methodName: String): TypedMapCommand? = byMethodName[methodName]
    }
}

/**
 * Compatibility transport for the existing Android MethodChannel contract.
 *
 * This adapter is the only component that decodes legacy string method names.
 * It forwards a typed command to the shared map session and also carries
 * native-to-Dart events for that session.
 */
internal class LegacyMethodChannelAdapter(
    messenger: BinaryMessenger,
    viewId: Int,
    private val dispatch: (LegacyMapCommand, MethodCall, MethodChannel.Result) -> Unit,
    private val typedDispatch: (TypedMapCommand, MethodCall, MethodChannel.Result) -> Unit,
) : MapEventSink, MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "plugins.dali.hamza/osmview_$viewId")
    private val eventSink = MethodChannelMapEventSink(channel)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val command = LegacyMapCommand.fromMethodName(call.method)
        if (command != null) {
            dispatch(command, call, result)
            return
        }
        val typedCommand = TypedMapCommand.fromMethodName(call.method)
        if (typedCommand != null) {
            typedDispatch(typedCommand, call, result)
            return
        }
        result.notImplemented()
    }

    override fun emit(method: String, arguments: Any?) {
        eventSink.emit(method, arguments)
    }

    override fun close() {
        eventSink.close()
        channel.setMethodCallHandler(null)
    }
}

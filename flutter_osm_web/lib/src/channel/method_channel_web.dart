import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_web/src/controller/web_osm_controller.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:stream_transform/stream_transform.dart';

import '../web_platform.dart';

class FlutterOsmPluginWeb extends OsmWebPlatform {
  late BinaryMessenger? messenger;

  FlutterOsmPluginWeb({
    required this.messenger,
  });

  final Map<int, MethodChannel> _channels = {};

  static String getViewType(int mapId) => 'osm_web_plugin_$mapId';

  Map<int, WebOsmController> mapsController = <int, WebOsmController>{};

  WebOsmController? map;

  //final Map<int, List<EventChannel>> _eventsChannels = {};
  StreamController _streamController = StreamController<EventOSM>.broadcast();

  // Returns a filtered view of the events in the _controller, by mapId.
  Stream<EventOSM> _events(int mapId) =>
      _streamController.stream.where((event) => event.mapId == mapId)
          as Stream<EventOSM>;

  static void registerWith(Registrar registrar) {
    final messenger = registrar;
    OSMPlatform.instance = FlutterOsmPluginWeb(messenger: messenger);
    BindingWebOSM();
  }

  @override
  Stream<MapInitialization> onMapIsReady(int idMap) {
    return _events(idMap).whereType<MapInitialization>();
  }

  @override
  Stream<SingleTapEvent> onSinglePressMapClickListener(int idMap) {
    return _events(idMap).whereType<SingleTapEvent>();
  }

  @override
  Stream<LongTapEvent> onLongPressMapClickListener(int idMap) {
    return _events(idMap).whereType<LongTapEvent>();
  }

  @override
  Stream<GeoPointEvent> onGeoPointClickListener(int idMap) {
    return _events(idMap).whereType<GeoPointEvent>();
  }

  @override
  Stream<UserLocationEvent> onUserPositionListener(int idMap) {
    return _events(idMap).whereType<UserLocationEvent>();
  }

  @override
  Future<void> init(int idOSM) {
    if (_streamController.isClosed) {
      _streamController = StreamController<EventOSM>.broadcast();
    }
    if (!_channels.containsKey(idOSM)) {
      _channels[idOSM] = MethodChannel(
        '${getViewType(idOSM)}',
        const StandardMethodCodec(),
        messenger,
      );
      handleMethodCall(idOSM);
    }
    return Future.microtask(() => close());
  }

  @override
  void close() {
    // mapsController.values.forEach(
    //         (WebTestController mapsController) => mapsController.dispose());
    //_streamController.close();
    mapsController.clear();
    _channels.clear();
  }

  /// Handles method calls over the MethodChannel of this plugin.
  /// Note: Check the "federated" architecture for a new way of doing this:
  /// https://flutter.dev/go/federated-plugins
  Future<dynamic> handleMethodCall(int idOSM) async {
    _channels[idOSM]!.setMethodCallHandler((call) async {
      switch (call.method) {
        case "initMap":
          final result = call.arguments as bool;
          print("channel init map : $result");
          _streamController.add(MapInitialization(idOSM, result));
          break;
        default:
          throw PlatformException(
            code: 'Unimplemented',
            details:
                'osm_web_plugin for web doesn\'t implement \'${call.method}\'',
          );
      }
    });
  }

  Widget buildMap(
    int idChannel,
    PlatformViewCreatedCallback onPlatformViewCreated,
    WebOsmController controller,
  ) {
    if (!mapsController.containsKey(idChannel)) {
      map = controller;
      map!.mapId = idChannel;
      mapsController.putIfAbsent(idChannel, () => map!);
      OsmWebPlatform.idOsmWeb++;
    }
    onPlatformViewCreated.call(idChannel);
    return mapsController[idChannel]!.widget!;
  }

  @override
  Future<void> initPositionMap(
    int idOSM,
    GeoPoint point,
  ) async {
    await mapsController[idOSM]!.initLocationMap(point);
  }

  @override
  Future<void> addPosition(int idOSM, GeoPoint p) async {
    await mapsController[idOSM]!.addPosition(p);
  }

  @override
  Future<void> currentLocation(int idOSM) {
    // TODO: implement currentLocation
    throw UnimplementedError();
  }

  @override
  Future<void> customMarker(
      int idOSM, GlobalKey<State<StatefulWidget>>? globalKey) {
    // TODO: implement customMarker
    throw UnimplementedError();
  }

  @override
  Future<RoadInfo> drawRoad(
    int idOSM,
    GeoPoint start,
    GeoPoint end, {
    List<GeoPoint>? interestPoints,
    RoadOption? roadOption,
  }) {
    // TODO: implement drawRoad
    throw UnimplementedError();
  }

  @override
  Future<void> enableTracking(int idOSM) {
    // TODO: implement enableTracking
    throw UnimplementedError();
  }

  @override
  Future<void> goToPosition(int idOSM, GeoPoint p) {
    // TODO: implement goToPosition
    throw UnimplementedError();
  }

  @override
  Future<GeoPoint> myLocation(int idMap) async {
    return await mapsController[idMap]!.currentLocation();
  }

  @override
  Future<GeoPoint> pickLocation(int idOSM,
      {GlobalKey<State<StatefulWidget>>? key, String imageURL = ""}) {
    // TODO: implement pickLocation
    throw UnimplementedError();
  }

  @override
  Future<void> removeLastRoad(int idOSM) {
    // TODO: implement removeLastRoad
    throw UnimplementedError();
  }

  @override
  Future<void> removePosition(int idOSM, GeoPoint p) {
    // TODO: implement removePosition
    throw UnimplementedError();
  }

  @override
  Future<void> setColorRoad(int idOSM, Color color) {
    // TODO: implement setColorRoad
    throw UnimplementedError();
  }

  @override
  Future<void> setMarkersRoad(
      int idOSM, List<GlobalKey<State<StatefulWidget>>?> keys) {
    // TODO: implement setMarkersRoad
    throw UnimplementedError();
  }

  @override
  Future<void> zoom(int idOSM, double zoom) {
    // TODO: implement zoom
    throw UnimplementedError();
  }

  @override
  Future<void> advancedPositionPicker(int idOSM) {
    // TODO: implement advancedPositionPicker
    throw UnimplementedError();
  }

  @override
  Future<void> cancelAdvancedPositionPicker(int idOSM) {
    // TODO: implement cancelAdvancedPositionPicker
    throw UnimplementedError();
  }

  @override
  Future<void> customAdvancedPickerMarker(
      int idMap, GlobalKey<State<StatefulWidget>> key) {
    // TODO: implement customAdvancedPickerMarker
    throw UnimplementedError();
  }

  @override
  Future<void> customMarkerStaticPosition(
      int idOSM, GlobalKey<State<StatefulWidget>>? globalKey, String id) {
    // TODO: implement customMarkerStaticPosition
    throw UnimplementedError();
  }

  @override
  Future<void> disableTracking(int idOSM) {
    // TODO: implement disableTracking
    throw UnimplementedError();
  }

  @override
  Future<void> drawCircle(int idOSM, CircleOSM circleOSM) {
    // TODO: implement drawCircle
    throw UnimplementedError();
  }

  @override
  Future<void> drawRect(int idOSM, RectOSM rectOSM) {
    // TODO: implement drawRect
    throw UnimplementedError();
  }

  @override
  Future<void> drawRoadManually(
      int idOSM, List<GeoPoint> road, Color roadColor, double width) {
    // TODO: implement drawRoadManually
    throw UnimplementedError();
  }

  @override
  Future<GeoPoint> getPositionOnlyAdvancedPositionPicker(int idOSM) {
    // TODO: implement getPositionOnlyAdvancedPositionPicker
    throw UnimplementedError();
  }

  @override
  Future<void> initIosMap(int idMap) {
    throw UnimplementedError();
  }

  @override
  Future<void> mapRotation(int idOSM, double? degree) {
    // TODO: implement mapRotation
    throw UnimplementedError();
  }

  @override
  Future<void> removeAllCircle(int idOSM) {
    // TODO: implement removeAllCircle
    throw UnimplementedError();
  }

  @override
  Future<void> removeAllRect(int idOSM) {
    // TODO: implement removeAllRect
    throw UnimplementedError();
  }

  @override
  Future<void> removeAllShapes(int idOSM) {
    // TODO: implement removeAllShapes
    throw UnimplementedError();
  }

  @override
  Future<void> removeCircle(int idOSM, String key) {
    // TODO: implement removeCircle
    throw UnimplementedError();
  }

  @override
  Future<void> removeRect(int idOSM, String key) {
    // TODO: implement removeRect
    throw UnimplementedError();
  }

  @override
  Future<GeoPoint> selectAdvancedPositionPicker(int idOSM) {
    // TODO: implement selectAdvancedPositionPicker
    throw UnimplementedError();
  }

  @override
  Future<void> setDefaultZoom(int idOSM, double defaultZoom) {
    // TODO: implement setDefaultZoom
    throw UnimplementedError();
  }

  @override
  Future<void> staticPosition(int idOSM, List<GeoPoint> pList, String id) {
    // TODO: implement staticPosition
    throw UnimplementedError();
  }

  Future<void> visibilityInfoWindow(int idOSM, bool visible) {
    // TODO: implement visibilityInfoWindow
    throw UnimplementedError();
  }
}

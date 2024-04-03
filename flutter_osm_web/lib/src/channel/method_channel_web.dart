import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_web/src/controller/web_osm_controller.dart';
import 'package:flutter_osm_web/src/web_platform.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:stream_transform/stream_transform.dart';

class FlutterOsmPluginWeb extends OsmWebPlatform {
  late BinaryMessenger? messenger;

  static const String viewType = "osm_web_plugin";

  FlutterOsmPluginWeb({
    required this.messenger,
  });

  final Map<int, MethodChannel> _channels = {};

  static String getViewType(int mapId) => "${viewType}_$mapId";

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
  Stream<RegionIsChangingEvent> onRegionIsChangingListener(int idMap) {
    return _events(idMap).whereType<RegionIsChangingEvent>();
  }

  @override
  Stream<RoadTapEvent> onRoadMapClickListener(int idMap) {
    return _events(idMap).whereType<RoadTapEvent>();
  }

  @override
  Future<void> init(int idOSM) async {
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
    // return Future.microtask(() => close(idOSM));
  }

  @override
  void close(int idOSM) {
    // mapsController.values.forEach(
    //         (WebTestController mapsController) => mapsController.dispose());
    //_streamController.close();
    mapsController.remove(idOSM);
    _channels.remove(idOSM);
    if (mapsController.isNotEmpty) {
      map = mapsController.values.last;
      mapId = mapsController.keys.last;
    }
  }

  /// Handles method calls over the MethodChannel of this plugin.
  /// Note: Check the "federated" architecture for a new way of doing this:
  /// https://flutter.dev/go/federated-plugins
  Future<dynamic> handleMethodCall(int idOSM) async {
    _channels[idOSM]!.setMethodCallHandler((call) async {
      switch (call.method) {
        case "initMap":
          final result = call.arguments as bool;
          _streamController.add(MapInitialization(idOSM, result));
          break;
        case "onSingleTapListener":
          final result = call.arguments as String;
          _streamController
              .add(SingleTapEvent(idOSM, GeoPoint.fromString(result)));
          break;
        case "receiveGeoPoint":
          final result = call.arguments as String;
          _streamController
              .add(GeoPointEvent(idOSM, GeoPoint.fromString(result)));
          break;
        case "receiveRegionIsChanging":
          final result = call.arguments;
          _streamController
              .add(RegionIsChangingEvent(idOSM, Region.fromMap(result)));
          break;
        case "receiveRoad":
          final roadKey = call.arguments as String;
          if (map != null && map!.roadsWebCache.containsKey(roadKey)) {
            _streamController
                .add(RoadTapEvent(idOSM, map!.roadsWebCache[roadKey]!));
          }
          break;
        case "receiveUserLocation":
          final result = call.arguments;
          final geoPt = GeoPoint.fromString(result);
          _streamController.add(
            UserLocationEvent(
              idOSM,
              UserLocation(
                latitude: geoPt.latitude,
                longitude: geoPt.latitude,
              ),
            ),
          );
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

  void setWebMapController(
    int idChannel,
    WebOsmController controller,
  ) {
    if (!mapsController.containsKey(idChannel)) {
      map = controller;
      mapsController.putIfAbsent(idChannel, () => map!);
    }
  }
}

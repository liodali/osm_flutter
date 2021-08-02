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

}

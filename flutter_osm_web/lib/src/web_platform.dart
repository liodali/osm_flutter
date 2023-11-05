import 'dart:js';

import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:js/js.dart';

import 'channel/method_channel_web.dart';
import 'interop/osm_interop.dart' as interop;

abstract class OsmWebPlatform extends OSMPlatform {
  OsmWebPlatform() : super();

//static FlutterOsmPluginWeb _instance = FlutterOsmPluginWeb(messenger: null);

// static FlutterOsmPluginWeb get instance => _instance;
//
// /// Platform-specific plugins should set this with their own platform-specific
// /// class that extends [UrlLauncherPlatform] when they register themselves.
// static set instance(FlutterOsmPluginWeb instance) {
//   PlatformInterface.verifyToken(instance, BaseOsmPlatform.token);
//   _instance = instance;
// }
}

void BindingWebOSM() {
  interop.initMapFinish = allowInterop(initMapFinished);
  interop.onStaticGeoPointClicked = allowInterop(onStaticGeoPointClicked);
  interop.onMapSingleTapListener = allowInterop(onMapSingleTapListener);
  interop.onRegionChangedListener = allowInterop(onRegionChangedListener);
  interop.onRoadListener = allowInterop(onRoadListener);
  interop.onUserPositionListener = allowInterop(onUserPositionListener);
}

void initMapFinished(int mapId, bool isReady) {
  final controller = (OSMPlatform.instance as FlutterOsmPluginWeb)
      .mapsController[mapId]!; //[OsmWebPlatform.idOsmWeb]!;
  controller.channel!.invokeMethod("initMap", isReady);
}

void onStaticGeoPointClicked(int mapId, double lon, double lat) {
  final controller = (OSMPlatform.instance as FlutterOsmPluginWeb)
      .mapsController[mapId]!; //.map!;
  controller.channel!.invokeMethod("receiveGeoPoint", "$lat,$lon");
}

void onMapSingleTapListener(int mapId, double lon, double lat) {
  final controller = (OSMPlatform.instance as FlutterOsmPluginWeb).mapsController[mapId]!; //.map!;
  controller.channel!.invokeMethod("onSingleTapListener", "$lat,$lon");
}

void onUserPositionListener(int mapId, double lon, double lat) {
  final controller = (OSMPlatform.instance as FlutterOsmPluginWeb).mapsController[mapId]!; //.map!;
  controller.channel!.invokeMethod("receiveUserLocation", "$lat,$lon");
}

void onRegionChangedListener(
  int mapId,
  double north,
  double east,
  double south,
  double west,
  double lon,
  double lat,
) {
  final region = {
    "bounding": {"south": south, "east": east, "north": north, "west": west},
    "center": {"lon": lon, "lat": lat}
  };
  final controller = (OSMPlatform.instance as FlutterOsmPluginWeb).map!;
  controller.channel!.invokeMethod("receiveRegionIsChanging", region);
}

void onRoadListener(
  int mapId,
  String roadKey,
) {
  final controller = (OSMPlatform.instance as FlutterOsmPluginWeb).map!;
  controller.channel!.invokeMethod("receiveRoad", roadKey);
}

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
}

void initMapFinished(bool isReady) {
  final controller = (OSMPlatform.instance as FlutterOsmPluginWeb)
      .map!; //.mapsController[OsmWebPlatform.idOsmWeb]!;
  controller.channel!.invokeMethod("initMap", isReady);
}

void onStaticGeoPointClicked(double lon, double lat) {
  final controller = (OSMPlatform.instance as FlutterOsmPluginWeb).map!;
  controller.channel!.invokeMethod("receiveGeoPoint", "$lat,$lon");
}

void onMapSingleTapListener(double lon, double lat) {
  final controller = (OSMPlatform.instance as FlutterOsmPluginWeb).map!;
  controller.channel!.invokeMethod("onSingleTapListener", "$lat,$lon");
}

void onRegionChangedListener(
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
  String roadKey,
) {
  final controller = (OSMPlatform.instance as FlutterOsmPluginWeb).map!;
  controller.channel!.invokeMethod("receiveRoad", roadKey);
}

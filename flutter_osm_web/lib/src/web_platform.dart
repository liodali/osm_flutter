import 'dart:js_interop';

import 'package:flutter_osm_interface/flutter_osm_interface.dart';

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

void bindingWebOSM() {
  interop.initMapFinish = initMapFinished.toJS;
  interop.onGeoPointClicked = onGeoPointClicked.toJS;
  interop.onGeoPointLongPress = onGeoPointLongPress.toJS;
  interop.onMapSingleTapListener = onMapSingleTapListener.toJS;
  interop.onRegionChangedListener = onRegionChangedListener.toJS;
  interop.onRoadListener = onRoadListener.toJS;
  interop.onUserPositionListener = onUserPositionListener.toJS;
  interop.onUserPositionListener = onUserPositionListener.toJS;
  // interop.initMapFinish = initMapFinished.toJS;
  // interop.onStaticGeoPointClicked = allowInterop(onStaticGeoPointClicked);
  // interop.onMapSingleTapListener = allowInterop(onMapSingleTapListener);
  // interop.onRegionChangedListener = allowInterop(onRegionChangedListener);
  // interop.onRoadListener = allowInterop(onRoadListener);
  // interop.onUserPositionListener = allowInterop(onUserPositionListener);
}

void initMapFinished(JSNumber mapId, JSBoolean isReady) {
  final controller = (OSMPlatform.instance as FlutterOsmPluginWeb)
      .mapsController[mapId.toDartInt]!; //[OsmWebPlatform.idOsmWeb]!;
  controller.channel!.invokeMethod("initMap", isReady.toDart);
}

void onGeoPointClicked(JSNumber mapId, JSNumber lon, JSNumber lat) {
  final controller = (OSMPlatform.instance as FlutterOsmPluginWeb)
      .mapsController[mapId.toDartInt]!; //.map!;
  controller.channel!.invokeMethod(
      "receiveGeoPoint", "${lat.toDartDouble},${lon.toDartDouble}");
}

void onGeoPointLongPress(JSNumber mapId, JSNumber lon, JSNumber lat) {
  final controller = (OSMPlatform.instance as FlutterOsmPluginWeb)
      .mapsController[mapId.toDartInt]!; //.map!;
  controller.channel!.invokeMethod(
      "receiveGeoPointLongPress", "${lat.toDartDouble},${lon.toDartDouble}");
}

void onMapSingleTapListener(JSNumber mapId, JSNumber lon, JSNumber lat) {
  final controller = (OSMPlatform.instance as FlutterOsmPluginWeb)
      .mapsController[mapId.toDartInt]!; //.map!;
  controller.channel!.invokeMethod(
      "onSingleTapListener", "${lat.toDartDouble},${lon.toDartDouble}");
}

void onUserPositionListener(JSNumber mapId, JSNumber lon, JSNumber lat) {
  final controller = (OSMPlatform.instance as FlutterOsmPluginWeb)
      .mapsController[mapId.toDartInt]!; //.map!;
  controller.channel!.invokeMethod(
      "receiveUserLocation", "${lat.toDartDouble},${lon.toDartDouble}");
}

void onRegionChangedListener(
  JSNumber mapId,
  JSNumber north,
  JSNumber east,
  JSNumber south,
  JSNumber west,
  JSNumber lon,
  JSNumber lat,
) {
  final region = {
    "bounding": {
      "south": south.toDartDouble,
      "east": east.toDartDouble,
      "north": north.toDartDouble,
      "west": west.toDartDouble
    },
    "center": {"lon": lon.toDartDouble, "lat": lat.toDartDouble}
  };
  final controller = (OSMPlatform.instance as FlutterOsmPluginWeb).map!;
  controller.channel!.invokeMethod("receiveRegionIsChanging", region);
}

void onRoadListener(
  JSNumber mapId,
  JSString roadKey,
) {
  final controller = (OSMPlatform.instance as FlutterOsmPluginWeb).map!;
  controller.channel!.invokeMethod("receiveRoad", roadKey.toDart);
}

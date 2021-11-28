import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_web/src/interop/models/geo_point_js.dart';
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

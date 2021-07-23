import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:js/js.dart';

import 'channel/method_channel_web.dart';
import 'interop/osm_interop.dart' as interop;
abstract class OsmWebPlatform extends OSMPlatform {

  OsmWebPlatform() : super();

  //static FlutterOsmPluginWeb _instance = FlutterOsmPluginWeb(messenger: null);

  static int idOsmWeb = 0;

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
}

void initMapFinished(bool isReady) {
  final controller =
      (OSMPlatform.instance as FlutterOsmPluginWeb).map!;//.mapsController[OsmWebPlatform.idOsmWeb]!;
  controller.channel!.invokeMethod("initMap", isReady);
}

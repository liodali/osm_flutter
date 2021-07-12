import 'package:flutter_osm_plugin/src/interface_osm/base_osm_platform.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'osm_web.dart';

abstract class OsmWebPlatform extends BaseOsmPlatform {
  OsmWebPlatform() : super();
  static FlutterOsmPluginWeb _instance = FlutterOsmPluginWeb(messenger: null);

  static int idOsmWeb = 0;

  static FlutterOsmPluginWeb get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [UrlLauncherPlatform] when they register themselves.
  static set instance(FlutterOsmPluginWeb instance) {
    PlatformInterface.verifyToken(instance, BaseOsmPlatform.token);
    _instance = instance;
  }
}
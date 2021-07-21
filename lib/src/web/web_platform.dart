part of osm_flutter;

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

void BindingWebOSM() {
  interop.initMapFinish = allowInterop(initMapFinished);
}

void initMapFinished(bool isReady) {
  final controller =
      OsmWebPlatform.instance._mapsController[OsmWebPlatform.idOsmWeb - 1]!;
  controller.channel!.invokeMethod("initMap", isReady);
}

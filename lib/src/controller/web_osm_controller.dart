part of osm_flutter;

class WebOsmController {
  late int _mapId;
  late MethodChannel _channel;

  WebOsmController() {
    _init(OsmWebPlatform.idOsmWeb);
  }

  void _init(int idMap) {
    this._mapId = idMap;

    final body = html.window.document.querySelector('body')!;

    _frame = html.IFrameElement()
      ..id = "frame_map"
      ..src = "packages/flutter_osm_plugin/src/asset/map.html";

    body.append(html.ScriptElement()
      ..src = 'packages/flutter_osm_plugin/src/asset/map.js'
      ..type = 'application/javascript');

    ui.platformViewRegistry.registerViewFactory(
        FlutterOsmPluginWeb.getViewType(_mapId), (int viewId) => _frame);

    _channel = MethodChannel(FlutterOsmPluginWeb.getViewType(_mapId));
    //print(_getViewType(_mapId));
  }

  Future<GeoPoint> currentLocation() async {
    Map<String, double> result = await Future.microtask(() async {
      Map<String, double> value =
          await html.promiseToFutureAsMap(interop.locateMe()) as Map<String, double>;
      return value;
    });
    return GeoPoint.fromMap(result);
  }

  Future<void> addPosition(GeoPoint point) async {
    await promiseToFuture(interop.addPosition(point.toMap()));
  }

  // The Flutter widget that contains the rendered Map.
  HtmlElementView? _widget;
  late html.IFrameElement _frame;

  /// The Flutter widget that will contain the rendered Map. Used for caching.
  Widget? get widget {
    if (_widget == null) {
      _widget = HtmlElementView(
        viewType: FlutterOsmPluginWeb.getViewType(_mapId),
      );
    }
    return _widget;
  }

  void dispose() {}

 Future<void> init({
    GeoPoint? initPosition,
    bool initWithUserPosition = false,
  })async {
    if(initPosition!=null && ! initWithUserPosition){
      await addPosition(initPosition);
    }
  }
}

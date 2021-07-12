part of osm_web;



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
      ..src = "packages/test_web_plugin/src/asset/map.html";


    body.append(html.ScriptElement()
      ..src = 'packages/test_web_plugin/src/asset/map.js'
      ..type = 'application/javascript');

    ui.platformViewRegistry
        .registerViewFactory(_getViewType(_mapId), (int viewId) => _frame);

    _channel = MethodChannel(_getViewType(_mapId));
    print(_getViewType(_mapId));
  }

  Future setLocation() async {
    final result = await Future.microtask(() async {
      final v = html.promiseToFutureAsMap(locateMe());
      return v;
    });

  }

  Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  // Creates the 'viewType' for the _widget
  String _getViewType(int mapId) => 'test_web_plugin_$mapId';

  // The Flutter widget that contains the rendered Map.
  HtmlElementView? _widget;
  late html.IFrameElement _frame;

  /// The Flutter widget that will contain the rendered Map. Used for caching.
  Widget? get widget {
    if (_widget == null) {
      _widget = HtmlElementView(
        viewType: _getViewType(_mapId),
      );
    }
    return _widget;
  }

  void dispose() {}
}
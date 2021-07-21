part of osm_flutter;

class WebOsmController with ControllerWebMixin {
  late int _mapId;
  late MethodChannel? channel;
  late _OsmWebWidgetState _osmWebFlutterState;

  WebOsmController(_OsmWebWidgetState _osmWebFlutterState) {
    _init(OsmWebPlatform.idOsmWeb);
    this._osmWebFlutterState = _osmWebFlutterState;
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

    channel = MethodChannel(FlutterOsmPluginWeb.getViewType(_mapId));
    //print(_getViewType(_mapId));
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

  void dispose() {
    channel = null;
    OsmWebPlatform.instance._mapsController.remove(this);
  }

  Future<void> init({
    GeoPoint? initPosition,
    bool initWithUserPosition = false,
  }) async {
    assert(initPosition != null || initWithUserPosition == true);

    OsmWebPlatform.instance
        .onLongPressMapClickListener(_mapId)
        .listen((event) {
      _osmWebFlutterState.widget.controller.listenerMapLongTapping.value =
          event.value;
    });

    OsmWebPlatform.instance
        .onSinglePressMapClickListener(_mapId)
        .listen((event) {
      _osmWebFlutterState.widget.controller.listenerMapSingleTapping.value =
          event.value;
    });
    OsmWebPlatform.instance.onMapIsReady(_mapId).listen((event) async {
      _osmWebFlutterState.widget.mapIsReadyListener.value = event.value;
    });

    if (_osmWebFlutterState.widget.onGeoPointClicked != null) {
      OsmWebPlatform.instance
          .onGeoPointClickListener(_mapId)
          .listen((event) {
        _osmWebFlutterState.widget.onGeoPointClicked!(event.value);
      });
    }
    if (_osmWebFlutterState.widget.onLocationChanged != null) {
      OsmWebPlatform.instance
          .onUserPositionListener(_mapId)
          .listen((event) {
        _osmWebFlutterState.widget.onLocationChanged!(event.value);
      });
      /* this._osmController.myLocationListener(widget.onLocationChanged, (err) {
          print(err);
        });*/
    }

    GeoPoint? initLocation = initPosition;

    if (initWithUserPosition) {
      initLocation = await currentLocation();
    }
    await initMap(initLocation!);
  }
}

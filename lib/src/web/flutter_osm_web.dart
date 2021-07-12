part of osm_flutter;

class FlutterOsmPluginWeb extends OsmWebPlatform {
  late BinaryMessenger? messenger;

  FlutterOsmPluginWeb({
    required this.messenger,
  });

  static String getViewType(int mapId) => 'osm_web_plugin_$mapId';

  Map<int, WebOsmController> _mapsController = <int, WebOsmController>{};

  late WebOsmController map;

  static void registerWith(Registrar registrar) {
    final messenger = registrar;
    OsmWebPlatform.instance = FlutterOsmPluginWeb(messenger: messenger);
    OsmWebPlatform.instance.init(OsmWebPlatform.idOsmWeb);
  }

  @override
  Future<void> init(int idOSM) {
    final MethodChannel channel = MethodChannel(
      '${getViewType(idOSM)}',
      const StandardMethodCodec(),
      messenger,
    );
    channel.setMethodCallHandler(OsmWebPlatform.instance.handleMethodCall);
    return Future.microtask(() => close());
  }

  @override
  void close() {
    // _mapsController.values.forEach(
    //         (WebTestController _mapsController) => _mapsController.dispose());
    _mapsController.clear();
  }

  /// Handles method calls over the MethodChannel of this plugin.
  /// Note: Check the "federated" architecture for a new way of doing this:
  /// https://flutter.dev/go/federated-plugins
  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details:
              'osm_web_plugin for web doesn\'t implement \'${call.method}\'',
        );
    }
  }

  Widget buildMap(
    int idChannel,
    PlatformViewCreatedCallback onPlatformViewCreated,
    WebOsmController controller,
  ) {
    if (!_mapsController.containsKey(idChannel)) {
      map = controller;
      _mapsController[idChannel] = map;
      OsmWebPlatform.idOsmWeb++;
    }
    onPlatformViewCreated.call(idChannel);
    return _mapsController[idChannel]!.widget!;
  }

  @override
  Future<void> addPosition(int idOSM, GeoPoint p) async{
   await _mapsController[idOSM]!.addPosition(p);
  }

  @override
  Future<void> currentLocation(int idOSM) {
    // TODO: implement currentLocation
    throw UnimplementedError();
  }

  @override
  Future<void> customMarker(
      int idOSM, GlobalKey<State<StatefulWidget>>? globalKey) {
    // TODO: implement customMarker
    throw UnimplementedError();
  }

  @override
  Future<RoadInfo> drawRoad(
    int idOSM,
    GeoPoint start,
    GeoPoint end, {
    List<GeoPoint>? interestPoints,
    RoadOption? roadOption,
  }) {
    // TODO: implement drawRoad
    throw UnimplementedError();
  }

  @override
  Future<void> enableTracking(int idOSM) {
    // TODO: implement enableTracking
    throw UnimplementedError();
  }

  @override
  Future<void> goToPosition(int idOSM, GeoPoint p) {
    // TODO: implement goToPosition
    throw UnimplementedError();
  }

  @override
  Future<GeoPoint> myLocation(int idMap) async {
    return await _mapsController[idMap]!.currentLocation();
  }

  @override
  Stream<GeoPointEvent> onGeoPointClickListener(int idMap) {
    // TODO: implement onGeoPointClickListener
    throw UnimplementedError();
  }

  @override
  Stream<LongTapEvent> onLongPressMapClickListener(int idMap) {
    // TODO: implement onLongPressMapClickListener
    throw UnimplementedError();
  }

  @override
  Stream<SingleTapEvent> onSinglePressMapClickListener(int idMap) {
    // TODO: implement onSinglePressMapClickListener
    throw UnimplementedError();
  }

  @override
  Stream<UserLocationEvent> onUserPositionListener(int idMap) {
    // TODO: implement onUserPositionListener
    throw UnimplementedError();
  }

  @override
  Future<GeoPoint> pickLocation(int idOSM,
      {GlobalKey<State<StatefulWidget>>? key, String imageURL = ""}) {
    // TODO: implement pickLocation
    throw UnimplementedError();
  }

  @override
  Future<void> removeLastRoad(int idOSM) {
    // TODO: implement removeLastRoad
    throw UnimplementedError();
  }

  @override
  Future<void> removePosition(int idOSM, GeoPoint p) {
    // TODO: implement removePosition
    throw UnimplementedError();
  }

  @override
  Future<void> setColorRoad(int idOSM, Color color) {
    // TODO: implement setColorRoad
    throw UnimplementedError();
  }

  @override
  Future<void> setMarkersRoad(
      int idOSM, List<GlobalKey<State<StatefulWidget>>?> keys) {
    // TODO: implement setMarkersRoad
    throw UnimplementedError();
  }

  @override
  Future<void> zoom(int idOSM, double zoom) {
    // TODO: implement zoom
    throw UnimplementedError();
  }
}

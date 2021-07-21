part of osm_flutter;

class FlutterOsmPluginWeb extends OsmWebPlatform {
  late BinaryMessenger? messenger;

  FlutterOsmPluginWeb({
    required this.messenger,
  });

  final Map<int, MethodChannel> _channels = {};

  static String getViewType(int mapId) => 'osm_web_plugin_$mapId';

  Map<int, WebOsmController> _mapsController = <int, WebOsmController>{};

  late WebOsmController map;

  //final Map<int, List<EventChannel>> _eventsChannels = {};
  StreamController _streamController = StreamController<EventOSM>.broadcast();

  // Returns a filtered view of the events in the _controller, by mapId.
  Stream<EventOSM> _events(int mapId) =>
      _streamController.stream.where((event) => event.mapId == mapId)
          as Stream<EventOSM>;

  static void registerWith(Registrar registrar) {
    final messenger = registrar;
    OsmWebPlatform.instance = FlutterOsmPluginWeb(messenger: messenger);
    OsmWebPlatform.instance.init(OsmWebPlatform.idOsmWeb);
  }

  @override
  Stream<MapInitialization> onMapIsReady(int idMap) {
    return _events(idMap).whereType<MapInitialization>();
  }

  @override
  Stream<SingleTapEvent> onSinglePressMapClickListener(int idMap) {
    return _events(idMap).whereType<SingleTapEvent>();
  }

  @override
  Stream<LongTapEvent> onLongPressMapClickListener(int idMap) {
    return _events(idMap).whereType<LongTapEvent>();
  }

  @override
  Stream<GeoPointEvent> onGeoPointClickListener(int idMap) {
    return _events(idMap).whereType<GeoPointEvent>();
  }

  @override
  Stream<UserLocationEvent> onUserPositionListener(int idMap) {
    return _events(idMap).whereType<UserLocationEvent>();
  }

  @override
  Future<void> init(int idOSM) {
    // if (!_mapsController.containsKey(idOSM)) {
    //   if (_streamController.isClosed) {
    //     _streamController = StreamController<EventOSM>.broadcast();
    //   }
    // }
    if (!_channels.containsKey(idOSM)) {
      _channels[idOSM] = MethodChannel(
        '${getViewType(idOSM)}',
        const StandardMethodCodec(),
        messenger,
      );
      _channels[idOSM]!
          .setMethodCallHandler(handleMethodCall);
    }
    return Future.microtask(() => close());
  }

  @override
  void close() {
    // _mapsController.values.forEach(
    //         (WebTestController _mapsController) => _mapsController.dispose());
    //_streamController.close();
    _mapsController.clear();
    _channels.clear();
  }

  /// Handles method calls over the MethodChannel of this plugin.
  /// Note: Check the "federated" architecture for a new way of doing this:
  /// https://flutter.dev/go/federated-plugins
  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case "initMap":
        final result = call.arguments as bool;
        print("init map : $result");
        _streamController.add(MapInitialization(map._mapId, result));
        break;
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
  Future<void> initMap(
    int idOSM,
    GeoPoint point,
  ) async {
    await _mapsController[idOSM]!.initMap(point);
  }

  @override
  Future<void> addPosition(int idOSM, GeoPoint p) async {
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

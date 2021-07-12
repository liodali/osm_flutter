part of osm_flutter;

///  [BaseMapController] : base controller for osm flutter
///
///
/// [initMapWithUserPosition] : (bool) if is true, map will show your current location
///
/// [initPosition] : (GeoPoint) if it isn't null, the map will be pointed at this position
abstract class BaseMapController {
  late OSMController _osmController;
  late WebOsmController _osmWebController;
  final bool initMapWithUserPosition;
  final GeoPoint? initPosition;

  late ValueNotifier<GeoPoint?> listenerMapLongTapping = ValueNotifier(null);
  late ValueNotifier<GeoPoint?> listenerMapSingleTapping = ValueNotifier(null);

  BaseMapController({
    this.initMapWithUserPosition = true,
    this.initPosition,
  }) : assert(initMapWithUserPosition || initPosition != null);

  void _init({
    OSMController? osmController,
    WebOsmController? osmWebController,
  }) {
      _initMobile(osmController!);
  }

  void _initMobile(
    OSMController osmController,
  ) {
    this._osmController = osmController;
    Future.delayed(Duration(milliseconds: 1250), () async {
      await this._osmController.initMap(
            initPosition: initPosition,
            initWithUserPosition: initMapWithUserPosition,
          );
    });
  }

  void _initWeb(
    WebOsmController osmController,
  ) {
    this._osmWebController = osmController;
    Future.delayed(Duration(milliseconds: 1250), () async {
      await this._osmWebController.init(
            initPosition: initPosition,
            initWithUserPosition: initMapWithUserPosition,
          );
    });
  }
}

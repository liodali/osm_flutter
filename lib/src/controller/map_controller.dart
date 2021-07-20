part of osm_flutter;

/// class [MapController] : map controller that will control map by select position,enable current location,
/// draw road , show static geoPoint,
///
/// [initMapWithUserPosition] : (bool) if is true, map will show your current location
///
/// [initPosition] : (GeoPoint) if it isn't null, the map will be pointed at this position
class MapController extends BaseMapController {
  MapController({
    bool initMapWithUserPosition = true,
    GeoPoint? initPosition,
  })  : assert(
          initMapWithUserPosition || initPosition != null,
        ),
        super(
          initMapWithUserPosition: initMapWithUserPosition,
          initPosition: initPosition,
        );

  @override
  void _init({
    OSMController? osmController,
    WebOsmController? osmWebController = null,
  }) {
    if (kIsWeb) {
      _initWeb(osmWebController!);
    } else {
      super._init(
        osmController: _osmController,
      );
    }
  }

  void dispose() {
    listenerMapLongTapping.dispose();
    listenerMapSingleTapping.dispose();
    _osmController.dispose();
  }

  /// initialise or change of position with creating marker in that specific position
  ///
  /// [p] : geoPoint
  ///
  Future<void> changeLocation(GeoPoint p) async {
    await _osmController.changeLocation(p);
  }

  ///animate  to specific position with out add marker into the map
  ///
  /// [p] : (GeoPoint) position that will be go to map
  Future<void> goToLocation(GeoPoint p) async {
    await _osmController.goToPosition(p);
  }

  ///remove marker from map of position
  /// [p] : geoPoint
  Future<void> removeMarker(GeoPoint p) async {
    _osmController.removeMarker(p);
  }

  ///change Icon Marker
  /// we need to global key to recuperate widget from tree element
  /// [key] : (GlobalKey) key of widget that represent the new marker
  Future changeIconMarker(GlobalKey key) async {
    await _osmController.changeDefaultIconMarker(key);
  }

  /*///change advanced picker Icon Marker
  /// we need to global key to recuperate widget from tree element
  /// [key] : (GlobalKey) key of widget that represent the new marker
  Future changeAdvPickerIconMarker(GlobalKey key) async {
    await _osmController.changeIconAdvPickerMarker(key);
  }*/

  /// change static position in runtime
  ///  [geoPoints] : list of static geoPoint
  ///  [id] : String of that list of static geoPoint
  Future<void> setStaticPosition(List<GeoPoint> geoPoints, String id) async {
    await _osmController.setStaticPosition(geoPoints, id);
  }

  ///change  Marker of specific static points
  /// we need to global key to recuperate widget from tree element
  /// [id] : (String) id  of the static group geopoint
  /// [markerIcon] : (MarkerIcon) new marker that will set to the static group geopoint
  Future<void> setMarkerOfStaticPoint({
    required String id,
    required MarkerIcon markerIcon,
  }) async {
    await _osmController.setIconStaticPositions(id, markerIcon);
  }

  /// zoom in/out
  /// [zoom] : (double) positive value:zoomIN or negative value:zoomOut
  Future<void> zoom(double zoom) async {
    await _osmController.zoom(zoom);
  }

  /// zoomIn use defaultZoom
  /// positive value:zoomIN
  Future<void> zoomIn() async {
    await _osmController.zoomIn();
  }

  /// zoomOut use defaultZoom
  /// negative value:zoomOut
  Future<void> zoomOut() async {
    await _osmController.zoom(-1);
  }

  /// activate current location position
  Future<void> currentLocation() async {
    await _osmController.currentLocation();
  }

  /// recuperation of user current position
  Future<GeoPoint> myLocation() async {
    return await _osmController.myLocation();
  }

  /// enabled tracking user location
  Future<void> enableTracking() async {
    await _osmController.enableTracking();
  }

  /// disabled tracking user location
  Future<void> disabledTracking() async {
    await _osmController.disabledTracking();
  }

  /// pick Position in map
  Future<GeoPoint> selectPosition({
    MarkerIcon? icon,
    String imageURL = "",
  }) async {
    GeoPoint p = await _osmController.selectPosition(
      icon: icon,
      imageURL: imageURL,
    );
    return p;
  }

  /// draw road
  ///  [start] : started point of your Road
  ///
  ///  [end] : last point of your road
  ///
  ///  [intersectPoint] : (List of GeoPoint) middle position that you want you road to pass through it
  ///
  ///  [roadColor] : (Color) indicate the color that you want to be drawing the road, if Color null will draw with default color that specified in OSMFlutter or red color (default of osm map)
  ///
  ///  [roadWidth] : (double) indicate the width of  your road
  Future<RoadInfo> drawRoad(
    GeoPoint start,
    GeoPoint end, {
    List<GeoPoint>? intersectPoint,
    RoadOption? roadOption,
  }) async {
    return await _osmController.drawRoad(
      start,
      end,
      interestPoints: intersectPoint,
      roadOption: roadOption,
    );
  }

  ///delete last road draw in the map
  Future<void> removeLastRoad() async {
    await _osmController.removeLastRoad();
  }

  /// draw circle into map
  Future<void> drawCircle(CircleOSM circleOSM) async {
    await _osmController.drawCircle(circleOSM);
  }

  /// remove specific circle in the map
  Future<void> removeCircle(String keyCircle) async {
    await _osmController.removeCircle(keyCircle);
  }

  /// draw rect into map
  Future<void> drawRect(RectOSM rectOSM) async {
    await _osmController.drawRect(rectOSM);
  }

  /// remove specific region in the map
  Future<void> removeRect(String keyRect) async {
    await _osmController.removeRect(keyRect);
  }

  /// remove all rect shape from map
  Future<void> removeAllRect() async {
    return await _osmController.removeAllRect();
  }

  /// clear all circle
  Future<void> removeAllCircle() async {
    await _osmController.removeAllCircle();
  }

  /// remove all shape from map
  Future<void> removeAllShapes() async {
    await _osmController.removeAllShapes();
  }

  Future<void> advancedPositionPicker() async {
    await _osmController.advancedPositionPicker();
  }

  /// select current position and finish advanced picker
  Future<GeoPoint> selectAdvancedPositionPicker() async {
    return await _osmController.selectAdvancedPositionPicker();
  }

  /// get current position
  Future<GeoPoint> getCurrentPositionAdvancedPositionPicker() async {
    return await _osmController.getCurrentPositionAdvancedPositionPicker();
  }

  /// cancel advanced picker
  Future<void> cancelAdvancedPositionPicker() async {
    return await _osmController.cancelAdvancedPositionPicker();
  }

  /// rotate camera of osm map
  Future<void> rotateMapCamera(double? degree) async {
    return await _osmController.mapOrientation(degree);
  }

  /// draw road manually
  ///  [path] : (list of GeoPoint) path of the road
  ///  [roadColor] : (Color) the color that uses to change the  default road color
  ///  [roadWidth] : (double) uses to change width of the  road
  Future<void> drawRoadManually(
    List<GeoPoint> path,
    Color roadColor,
    double roadWidth,
  ) async {
    assert(path.length > 3);
    await _osmController.drawRoadManually(
      path,
      roadColor,
      roadWidth,
    );
  }
}

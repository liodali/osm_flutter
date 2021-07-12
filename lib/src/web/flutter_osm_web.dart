part of osm_web;


class FlutterOsmPluginWeb extends OSMPlatform {
  @override
  Future<void> addPosition(int idOSM, GeoPoint p) {
    // TODO: implement addPosition
    throw UnimplementedError();
  }

  @override
  Future<void> advancedPositionPicker(int idOSM) {
    // TODO: implement advancedPositionPicker
    throw UnimplementedError();
  }

  @override
  Future<void> cancelAdvancedPositionPicker(int idOSM) {
    // TODO: implement cancelAdvancedPositionPicker
    throw UnimplementedError();
  }

  @override
  void close() {
    // TODO: implement close
  }

  @override
  Future<void> currentLocation(int idOSM) {
    // TODO: implement currentLocation
    throw UnimplementedError();
  }

  @override
  Future<void> customAdvancedPickerMarker(
      int idMap, GlobalKey<State<StatefulWidget>> key) {
    // TODO: implement customAdvancedPickerMarker
    throw UnimplementedError();
  }

  @override
  Future<void> customMarker(
      int idOSM, GlobalKey<State<StatefulWidget>>? globalKey) {
    // TODO: implement customMarker
    throw UnimplementedError();
  }

  @override
  Future<void> customMarkerStaticPosition(
      int idOSM, GlobalKey<State<StatefulWidget>>? globalKey, String id,
      {Color? colorIcon}) {
    // TODO: implement customMarkerStaticPosition
    throw UnimplementedError();
  }

  @override
  Future<void> disableTracking(int idOSM) {
    // TODO: implement disableTracking
    throw UnimplementedError();
  }

  @override
  Future<void> drawCircle(int idOSM, CircleOSM circleOSM) {
    // TODO: implement drawCircle
    throw UnimplementedError();
  }

  @override
  Future<void> drawRect(int idOSM, RectOSM rectOSM) {
    // TODO: implement drawRect
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
  Future<void> drawRoadManually(
      int idOSM, List<GeoPoint> road, Color roadColor, double width) {
    // TODO: implement drawRoadManually
    throw UnimplementedError();
  }

  @override
  Future<void> enableTracking(int idOSM) {
    // TODO: implement enableTracking
    throw UnimplementedError();
  }

  @override
  Future<GeoPoint> getPositionOnlyAdvancedPositionPicker(int idOSM) {
    // TODO: implement getPositionOnlyAdvancedPositionPicker
    throw UnimplementedError();
  }

  @override
  Future<void> goToPosition(int idOSM, GeoPoint p) {
    // TODO: implement goToPosition
    throw UnimplementedError();
  }

  @override
  Future<void> init(int idOSM) {
    // TODO: implement init
    throw UnimplementedError();
  }

  @override
  Future<void> initIosMap(int idMap) {
    // TODO: implement initIosMap
    throw UnimplementedError();
  }

  @override
  Future<void> mapRotation(int idOSM, double? degree) {
    // TODO: implement mapRotation
    throw UnimplementedError();
  }

  @override
  Future<GeoPoint> myLocation(int idMap) {
    // TODO: implement myLocation
    throw UnimplementedError();
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
  Future<void> removeAllCircle(int idOSM) {
    // TODO: implement removeAllCircle
    throw UnimplementedError();
  }

  @override
  Future<void> removeAllRect(int idOSM) {
    // TODO: implement removeAllRect
    throw UnimplementedError();
  }

  @override
  Future<void> removeAllShapes(int idOSM) {
    // TODO: implement removeAllShapes
    throw UnimplementedError();
  }

  @override
  Future<void> removeCircle(int idOSM, String key) {
    // TODO: implement removeCircle
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
  Future<void> removeRect(int idOSM, String key) {
    // TODO: implement removeRect
    throw UnimplementedError();
  }

  @override
  Future<GeoPoint> selectAdvancedPositionPicker(int idOSM) {
    // TODO: implement selectAdvancedPositionPicker
    throw UnimplementedError();
  }

  @override
  Future<void> setColorRoad(int idOSM, Color color) {
    // TODO: implement setColorRoad
    throw UnimplementedError();
  }

  @override
  Future<void> setDefaultZoom(int idOSM, double defaultZoom) {
    // TODO: implement setDefaultZoom
    throw UnimplementedError();
  }

  @override
  Future<void> setMarkersRoad(
      int idOSM, List<GlobalKey<State<StatefulWidget>>?> keys) {
    // TODO: implement setMarkersRoad
    throw UnimplementedError();
  }

  @override
  Future<void> staticPosition(int idOSM, List<GeoPoint> pList, String id) {
    // TODO: implement staticPosition
    throw UnimplementedError();
  }

  @override
  Future<void> visibilityInfoWindow(int idOSM, bool visible) {
    // TODO: implement visibilityInfoWindow
    throw UnimplementedError();
  }

  @override
  Future<void> zoom(int idOSM, double zoom) {
    // TODO: implement zoom
    throw UnimplementedError();
  }
}

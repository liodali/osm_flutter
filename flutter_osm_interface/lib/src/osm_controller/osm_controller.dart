import 'package:flutter/material.dart';

import '../types/types.dart';

abstract class IBaseOSMController {
  Future<void> initMap({
    GeoPoint? initPosition,
    bool initWithUserPosition = false,
  });

  ///initialise or change of position
  ///
  /// [p] : (GeoPoint) position that will be added to map
  Future<void> changeLocation(GeoPoint p);

  /// addMarker
  /// create marker int specific position without
  /// change map camera
  ///
  /// [p] : (GeoPoint) desired location
  ///
  /// [markerIcon] : (MarkerIcon) set icon of the marker
  Future<void> addMarker(
    GeoPoint p, {
    MarkerIcon? markerIcon,
    double? angle,
  });

  /// removeMarker
  /// remove marker from map of position
  ///
  /// [p] : geoPoint
  Future<void> removeMarker(GeoPoint p);

  /// setIconMarker
  /// this method change marker icon , marker should be already exist in the map
  /// or it will throw exception that marker not exist
  ///
  /// [point]      : (geoPoint) geoPoint that want to change Icon
  ///
  /// [markerIcon] : (MarkerIcon) the new icon marker that will replace old icon
  Future<void> setIconMarker(GeoPoint point, MarkerIcon markerIcon);

  /// change Home Icon Marker
  /// we need to global key to recuperate widget from tree element
  /// [homeMarker] : (MarkerIcon) key of widget that represent the new marker
  Future changeDefaultIconMarker(MarkerIcon homeMarker);

  ///change  Marker of specific static points
  /// we need to global key to recuperate widget from tree element
  /// [id] : (String) id  of the static group geopoint
  /// [markerIcon] : (MarkerIcon) new marker that will set to the static group geopoint
  Future<void> setIconStaticPositions(
    String id,
    MarkerIcon markerIcon, {
    bool refresh = false,
  });

  ///change Icon  of advanced picker Marker
  /// we need to global key to recuperate widget from tree element
  /// [key] : (GlobalKey) key of widget that represent the new marker
  Future changeIconAdvPickerMarker(GlobalKey key);

  /// change static position in runtime
  ///  [geoPoints] : list of static geoPoint
  ///  [id] : String of that list of static geoPoint
  Future<void> setStaticPosition(List<GeoPoint> geoPoints, String id);

  /// getZoom
  /// this method will return current zoom level of the map
  /// the type of the value returned is double,this value should be between minZoomLevel and maxZoomLevel
  Future<double> getZoom();

  Future<void> setZoom({
    double? zoomLevel,
    double? stepZoom,
  });

  /// zoomIn use stepZoom
  Future<void> zoomIn();

  /// zoomOut use stepZoom
  Future<void> zoomOut();

  Future<void> setStepZoom(
    int stepZoom,
  );

  Future<void> setMinimumZoomLevel(
    double minZoom,
  );

  Future<void> setMaximumZoomLevel(
    double maxZoom,
  );

  /// zoomToBoundingBox
  ///this method will change region and adjust the zoom level to the specific region
  ///
  /// [box] : (BoundingBox) the region that will change zoom level to be visible in the mapview
  ///
  ///  [paddinInPixel] : (int) the padding that will be added to region to adjust the zoomLevel
  Future<void> zoomToBoundingBox(
    BoundingBox box, {
    int paddinInPixel = 0,
  });

  Future<GeoPoint> getMapCenter();

  /// activate current location position
  Future<void> currentLocation();

  /// recuperation of user current position
  Future<GeoPoint> myLocation();

  /// goToPosition
  /// this method will to change current camera location
  /// to another specific position without create marker
  /// has attribute which is the desired location
  /// [p] : (GeoPoint) desired location
  Future<void> goToPosition(GeoPoint p);

  /// enabled tracking user location
  Future<void> enableTracking();

  /// disabled tracking user location
  Future<void> disabledTracking();

  /// pick Position in map
  Future<GeoPoint> selectPosition({
    MarkerIcon? icon,
    String imageURL = "",
  });

  /// [drawRoad]
  /// this method will call ORSM api to get list of geopoint and
  /// that will be transformed into polyline to be drawn in the map
  ///
  ///  parameters :
  ///  [start] : (GeoPoint) started point of your Road
  ///
  ///  [end] : (GeoPoint) destination point of your road
  ///
  ///  [interestPoints] : (List of GeoPoint) middle point that you want to be passed by your route
  ///
  ///  [roadType] : (RoadType)  indicate the type of the route  that you want to be road to be used (default :RoadType.car)
  ///
  ///  [roadOption] : (RoadOption) option of the road width, color,zoomInto,etc ...
  Future<RoadInfo> drawRoad(
    GeoPoint start,
    GeoPoint end, {
    RoadType roadType = RoadType.car,
    List<GeoPoint>? interestPoints,
    RoadOption? roadOption,
  });

  /// [drawRoadManually]
  /// this method allow to draw road manually without using any internal api
  /// the path should be provided from any external api like your own OSRM server or google map api
  /// and you can change color of the road and width also
  ///  [path]  : (list) list of GeoPoint that represent the path of the road
  ///
  ///  [color] : (Color) color of the road
  ///
  ///  [width] : (int) width of the road
  Future<void> drawRoadManually(
    List<GeoPoint> path, {
    Color roadColor = Colors.green,
    double width = 5.0,
    bool zoomInto = false,
    bool deleteOldRoads = false,
    MarkerIcon? interestPointIcon,
    List<GeoPoint> interestPoints = const [],
  });

  /// [drawMultipleRoad]
  /// this method will call draw list of roads in sametime with making  api continually
  /// to get list of GeoPoint for each configuration and you can define common configuration for all roads that share the same
  /// color,width,roadType using [commonRoadOption]
  /// this method return list of [RoadInfo] with the same order for each config
  ///
  ///  parameters :
  ///  [configs]        : (List) list of road configuration
  ///
  /// [commonRoadOption]  : (MultiRoadOption) common road config that can apply to all roads that doesn't define any inner roadOption
  Future<List<RoadInfo>> drawMultipleRoad(
    List<MultiRoadConfiguration> configs, {
    MultiRoadOption commonRoadOption,
  });

  /// [clearAllRoads]
  /// this method will delete all road drawn in the map
  Future<void> clearAllRoads();

  /// [removeLastRoad]
  /// this method will delete last road draw in the map
  Future<void> removeLastRoad();

  /// draw circle shape in the map
  ///
  /// [circleOSM] : (CircleOSM) represent circle in osm map
  Future<void> drawCircle(CircleOSM circleOSM);

  /// remove circle shape from map
  /// [key] : (String) key of the circle
  Future<void> removeCircle(String key);

  /// draw rect shape in the map
  /// [regionOSM] : (RegionOSM) represent region in osm map
  Future<void> drawRect(RectOSM rectOSM);

  /// remove region shape from map
  /// [key] : (String) key of the region
  Future<void> removeRect(String key);

  /// remove all rect shape from map
  Future<void> removeAllRect();

  /// remove all circle shapes from map
  Future<void> removeAllCircle();

  /// remove all shapes from map
  Future<void> removeAllShapes();

  /// to start assisted selection in the map
  Future<void> advancedPositionPicker();

  /// to retrieve location desired
  Future<GeoPoint> selectAdvancedPositionPicker();

  /// to retrieve current location without finish picker
  Future<GeoPoint> getCurrentPositionAdvancedPositionPicker();

  /// to cancel the assisted selection in tge map
  Future<void> cancelAdvancedPositionPicker();

  Future<void> mapOrientation(double degree);

  Future<BoundingBox> getBounds();

  Future<void> limitArea(
    BoundingBox box,
  );
  /// removeLimitArea
  ///
  /// this method will remove the region limitation for camera movement
  /// and the user can move freely
  Future<void> removeLimitArea();

  /// geoPoints
  ///
  /// this method will get location of existing marker in the mapview
  /// this method will not get static markers.
  ///
  /// return list of geopoint that represent location of the markers
  Future<List<GeoPoint>> geoPoints();
}

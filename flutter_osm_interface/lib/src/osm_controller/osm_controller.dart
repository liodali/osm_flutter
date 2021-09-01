import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/src/types/road.dart';

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

  /// create marker int specific position without change map camera
  ///
  /// [p] : (GeoPoint) desired location
  ///
  /// [markerIcon] : (MarkerIcon) set icon of the marker
  Future<void> addMarker(
    GeoPoint p, {
    MarkerIcon? markerIcon,
  });

  ///remove marker from map of position
  /// [p] : geoPoint
  Future<void> removeMarker(GeoPoint p);

  ///change Icon Marker
  /// we need to global key to recuperate widget from tree element
  /// [key] : (GlobalKey) key of widget that represent the new marker
  Future changeDefaultIconMarker(GlobalKey? key);

  ///change  Marker of specific static points
  /// we need to global key to recuperate widget from tree element
  /// [id] : (String) id  of the static group geopoint
  /// [markerIcon] : (MarkerIcon) new marker that will set to the static group geopoint
  Future<void> setIconStaticPositions(
    String id,
    MarkerIcon markerIcon,
  );

  ///change Icon  of advanced picker Marker
  /// we need to global key to recuperate widget from tree element
  /// [key] : (GlobalKey) key of widget that represent the new marker
  Future changeIconAdvPickerMarker(GlobalKey key);

  /// change static position in runtime
  ///  [geoPoints] : list of static geoPoint
  ///  [id] : String of that list of static geoPoint
  Future<void> setStaticPosition(List<GeoPoint> geoPoints, String id);

  Future<double> getZoom();

  Future<void> setZoom({
    double? zoomLevel,
    double? stepZoom,
  });

  Future<void> setStepZoom(
    int stepZoom,
  );

  Future<void> setMinimumZoomLevel(
    int minZoom,
  );

  Future<void> setMaximumZoomLevel(
    int maxZoom,
  );

  /// activate current location position
  Future<void> currentLocation();

  /// recuperation of user current position
  Future<GeoPoint> myLocation();

  /// go to specific position without create marker
  ///
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

  /// draw road
  ///  [start] : started point of your Road
  ///  [end] : last point of your road
  ///  [interestPoints] : middle point that you want to be passed by your route
  ///  [roadColor] : (color)  indicate the color that you want to be road colored
  ///  [roadWidth] : (double) indicate the width  of your road
  Future<RoadInfo> drawRoad(
    GeoPoint start,
    GeoPoint end, {
    RoadType roadType = RoadType.car,
    List<GeoPoint>? interestPoints,
    RoadOption? roadOption,
  });

  /// draw road
  ///  [path] : (list) path of the road
  Future<void> drawRoadManually(
    List<GeoPoint> path,
    Color roadColor,
    double width,
  );

  ///delete last road draw in the map
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

  Future<void> limitArea(
    BoundingBox box,
  );

  Future<void> removeLimitArea();
}

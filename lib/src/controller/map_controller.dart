import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin/src/controller/osm_controller.dart';

import 'base_map_controller.dart';

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
  void init(
    OSMController osmController,
  ) {
    super.init(osmController);
  }

  void dispose() {
    osmController.dispose();
  }

  /// initialise or change of position with creating marker in that specific position
  ///
  /// [p] : geoPoint
  ///
  Future<void> changeLocation(GeoPoint p) async {
    await osmController.changeLocation(p);
  }

  ///animate  to specific position with out add marker into the map
  ///
  /// [p] : (GeoPoint) position that will be go to map
  Future<void> goToLocation(GeoPoint p) async {
    await osmController.goToPosition(p);
  }

  ///remove marker from map of position
  /// [p] : geoPoint
  Future<void> removeMarker(GeoPoint p) async {
    osmController.removeMarker(p);
  }

  ///change Icon Marker
  /// we need to global key to recuperate widget from tree element
  /// [key] : (GlobalKey) key of widget that represent the new marker
  Future changeIconMarker(GlobalKey key) async {
    await osmController.changeDefaultIconMarker(key);
  }
  /*///change advanced picker Icon Marker
  /// we need to global key to recuperate widget from tree element
  /// [key] : (GlobalKey) key of widget that represent the new marker
  Future changeAdvPickerIconMarker(GlobalKey key) async {
    await osmController.changeIconAdvPickerMarker(key);
  }*/

  /// change static position in runtime
  ///  [geoPoints] : list of static geoPoint
  ///  [id] : String of that list of static geoPoint
  Future<void> setStaticPosition(List<GeoPoint> geoPoints, String id) async {
    await osmController.setStaticPosition(geoPoints, id);
  }

  /// zoom in/out
  /// [zoom] : (double) positive value:zoomIN or negative value:zoomOut
  Future<void> zoom(double zoom) async {
    await osmController.zoom(zoom);
  }

  /// zoomIn use defaultZoom
  /// positive value:zoomIN
  Future<void> zoomIn() async {
    await osmController.zoomIn();
  }

  /// zoomOut use defaultZoom
  /// negative value:zoomOut
  Future<void> zoomOut() async {
    await osmController.zoom(-1);
  }

  /// activate current location position
  Future<void> currentLocation() async {
    await osmController.currentLocation();
  }

  /// recuperation of user current position
  Future<GeoPoint> myLocation() async {
    return await osmController.myLocation();
  }

  /// enabled tracking user location
  Future<void> enableTracking() async {
    await osmController.enableTracking();
  }

  /// disabled tracking user location
  Future<void> disabledTracking() async {
    await osmController.disabledTracking();
  }

  /// pick Position in map
  Future<GeoPoint> selectPosition() async {
    GeoPoint p = await osmController.selectPosition();
    return p;
  }

  /// draw road
  ///  [start] : started point of your Road
  ///
  ///  [end] : last point of your road
  ///
  ///  [roadColor] : (Color) indicate the color that you want to be drawing the road, if Color null will draw with default color that specified in OSMFlutter or red color (default of osm map)
  ///
  ///  [roadWidth] : (double) indicate the width of  your road
  Future<RoadInfo> drawRoad(
    GeoPoint start,
    GeoPoint end, {
    Color? roadColor,
    double? roadWidth,
  }) async {
    return await osmController.drawRoad(
      start,
      end,
      roadColor: roadColor,
      roadWidth: roadWidth,
    );
  }

  ///delete last road draw in the map
  Future<void> removeLastRoad() async {
    await osmController.removeLastRoad();
  }

  /// draw circle into map
  Future<void> drawCircle(CircleOSM circleOSM) async {
    await osmController.drawCircle(circleOSM);
  }

  /// remove specific circle in the map
  Future<void> removeCircle(String keyCircle) async {
    await osmController.removeCircle(keyCircle);
  }

  /// draw rect into map
  Future<void> drawRect(RectOSM rectOSM) async {
    await osmController.drawRect(rectOSM);
  }

  /// remove specific region in the map
  Future<void> removeRect(String keyRect) async {
    await osmController.removeRect(keyRect);
  }

  /// remove all rect shape from map
  Future<void> removeAllRect() async {
    return await osmController.removeAllRect();
  }

  /// clear all circle
  Future<void> removeAllCircle() async {
    await osmController.removeAllCircle();
  }

  /// remove all shape from map
  Future<void> removeAllShapes() async {
    await osmController.removeAllShapes();
  }

  Future<void> advancedPositionPicker() async {
    await osmController.advancedPositionPicker();
  }

  /// select current position and finish advanced picker
  Future<GeoPoint> selectAdvancedPositionPicker() async {
    return await osmController.selectAdvancedPositionPicker();
  }

  /// get current position
  Future<GeoPoint> getCurrentPositionAdvancedPositionPicker() async {
    return await osmController.getCurrentPositionAdvancedPositionPicker();
  }

  /// cancel advanced picker
  Future<void> cancelAdvancedPositionPicker() async {
    return await osmController.cancelAdvancedPositionPicker();
  }

  /// rotate camera of osm map
  Future<void> rotateMapCamera(double? degree) async {
    return await osmController.mapOrientation(degree);
  }
/*
  /// draw road manually
  ///  [path] : (list) path of the road
  Future<void> drawRoadManually(
    List<GeoPoint> path,
  ) async {
    assert(path.length > 3);
    await osmController.drawRoadManually(path);
  }*/
}

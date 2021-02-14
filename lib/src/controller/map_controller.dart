import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin/src/controller/osm_controller.dart';

/// [initMapWithUserPosition] : (bool) if is true, map will show your current location
/// [initPosition] : (GeoPoint) if it isn't null, the map will be pointed at this position
class MapController {
  OSMController _osmController;
  final bool initMapWithUserPosition;
  final GeoPoint initPosition;

  MapController({
    this.initMapWithUserPosition = true,
    this.initPosition,
  }) : assert(initMapWithUserPosition || initPosition != null);

  void init(OSMController osmController,
      {initMapWithCurrentPosition = false, initPosition}) {
    _osmController = osmController;
  }

  void dispose() {
    _osmController.dispose();
    _osmController = null;
  }

  /// initialise or change of position
  /// [p] : geoPoint
  /// [circleOSM] : (CircleOSM) circle that will be draw with marker
  Future<void> changeLocation(GeoPoint p) async {
    if (p != null) _osmController.changeLocation(p);
  }

  ///remove marker from map of position
  /// [p] : geoPoint
  Future<void> removeMarker(GeoPoint p) async {
    if (p != null) _osmController.removeMarker(p);
  }

  ///change Icon Marker
  /// we need to global key to recuperate widget from tree element
  /// [key] : (GlobalKey) key of widget that represent the new marker
  Future changeIconMarker(GlobalKey key) async {
    await _osmController.changeIconMarker(key);
  }

  /// change static position in runtime
  ///  [geoPoints] : list of static geoPoint
  ///  [id] : String of that list of static geoPoint
  Future<void> setStaticPosition(List<GeoPoint> geoPoints, String id) async {
    await _osmController.setStaticPosition(geoPoints, id);
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
  Future<GeoPoint> selectPosition() async {
    GeoPoint p = await _osmController.selectPosition();
    return p;
  }

  /// draw road
  ///  [start] : started point of your Road
  ///  [end] : last point of your road
  Future<RoadInfo> drawRoad(GeoPoint start, GeoPoint end) async {
    return await _osmController.drawRoad(start, end);
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

  /// clear all circle
  Future<void> removeAllCircle() async {
    await _osmController.removeAllCircle();
  }
}

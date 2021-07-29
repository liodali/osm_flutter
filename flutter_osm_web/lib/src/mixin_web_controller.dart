import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:js/js_util.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'interop/models/geo_point_js.dart';
import 'interop/osm_interop.dart' as interop
    show addPosition, locateMe, initMapLocation,setDefaultIcon;

extension ExtGeoPoint on GeoPoint {
  GeoPointJs _toGeoJS() {
    return GeoPointJs(
      lon: longitude,
      lat: latitude,
    );
  }
}

mixin ControllerWebMixin {

  Future<void> initLocationMap(GeoPoint p) async {
    await promiseToFuture(interop.initMapLocation(p._toGeoJS()));
  }

  Future<void> addPosition(GeoPoint point) async {
    await promiseToFuture(interop.addPosition(GeoPointJs(
      lat: point.latitude,
      lon: point.longitude,
    )));
  }

  Future<GeoPoint> currentLocation() async {
    Map<String, dynamic>? value =
    await html.promiseToFutureAsMap(interop.locateMe());
    if (value!.containsKey("error")) {
      throw Exception(value["message"]);
    }
    return GeoPoint.fromMap(Map<String, double>.from(value));
  }
  
  Future<void> advancedPositionPicker() {
    // TODO: implement advancedPositionPicker
    throw UnimplementedError();
  }

  
  Future<void> cancelAdvancedPositionPicker() {
    // TODO: implement cancelAdvancedPositionPicker
    throw UnimplementedError();
  }

  
  Future changeDefaultIconMarker(GlobalKey<State<StatefulWidget>>? key) async{
     final base64 =  (await capturePng(key!)).convertToString();
     await interop.setDefaultIcon(base64);
  }

  
  Future changeIconAdvPickerMarker(GlobalKey<State<StatefulWidget>> key) {
    // TODO: implement changeIconAdvPickerMarker
    throw UnimplementedError();
  }

  
  Future<void> changeLocation(GeoPoint p) {
    // TODO: implement changeLocation
    throw UnimplementedError();
  }

  
  Future<void> defaultZoom(double zoom) {
    // TODO: implement defaultZoom
    throw UnimplementedError();
  }

  
  Future<void> disabledTracking() {
    // TODO: implement disabledTracking
    throw UnimplementedError();
  }

  
  Future<void> drawCircle(CircleOSM circleOSM) {
    // TODO: implement drawCircle
    throw UnimplementedError();
  }

  
  Future<void> drawRect(RectOSM rectOSM) {
    // TODO: implement drawRect
    throw UnimplementedError();
  }

  
  Future<RoadInfo> drawRoad(GeoPoint start, GeoPoint end,
      {List<GeoPoint>? interestPoints, RoadOption? roadOption}) {
    // TODO: implement drawRoad
    throw UnimplementedError();
  }

  
  Future<void> drawRoadManually(
      List<GeoPoint> path, Color roadColor, double width) {
    // TODO: implement drawRoadManually
    throw UnimplementedError();
  }

  
  Future<void> enableTracking() {
    // TODO: implement enableTracking
    throw UnimplementedError();
  }

  
  Future<GeoPoint> getCurrentPositionAdvancedPositionPicker() {
    // TODO: implement getCurrentPositionAdvancedPositionPicker
    throw UnimplementedError();
  }

  
  Future<void> goToPosition(GeoPoint p) {
    // TODO: implement goToPosition
    throw UnimplementedError();
  }

  
  Future<void> mapOrientation(double? degree) {
    // TODO: implement mapOrientation
    throw UnimplementedError();
  }

  
  Future<GeoPoint> myLocation() {
    // TODO: implement myLocation
    throw UnimplementedError();
  }

  
  Future<void> removeAllCircle() {
    // TODO: implement removeAllCircle
    throw UnimplementedError();
  }

  
  Future<void> removeAllRect() {
    // TODO: implement removeAllRect
    throw UnimplementedError();
  }

  
  Future<void> removeAllShapes() {
    // TODO: implement removeAllShapes
    throw UnimplementedError();
  }

  
  Future<void> removeCircle(String key) {
    // TODO: implement removeCircle
    throw UnimplementedError();
  }

  
  Future<void> removeLastRoad() {
    // TODO: implement removeLastRoad
    throw UnimplementedError();
  }

  
  Future<void> removeMarker(GeoPoint p) {
    // TODO: implement removeMarker
    throw UnimplementedError();
  }

  
  Future<void> removeRect(String key) {
    // TODO: implement removeRect
    throw UnimplementedError();
  }

  
  Future<GeoPoint> selectAdvancedPositionPicker() {
    // TODO: implement selectAdvancedPositionPicker
    throw UnimplementedError();
  }

  
  Future<GeoPoint> selectPosition({MarkerIcon? icon, String imageURL = ""}) {
    // TODO: implement selectPosition
    throw UnimplementedError();
  }

  
  Future<void> setIconStaticPositions(String id, MarkerIcon markerIcon) {
    // TODO: implement setIconStaticPositions
    throw UnimplementedError();
  }

  Future<void> setStaticPosition(List<GeoPoint> geoPoints, String id) {
    // TODO: implement setStaticPosition
    throw UnimplementedError();
  }

  Future<void> zoom(double zoom) {
    // TODO: implement zoom
    throw UnimplementedError();
  }

  Future<void> zoomIn() {
    // TODO: implement zoomIn
    throw UnimplementedError();
  }

  Future<void> zoomOut() {
    // TODO: implement zoomOut
    throw UnimplementedError();
  }
}



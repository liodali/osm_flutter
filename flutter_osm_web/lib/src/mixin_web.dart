import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:js/js_util.dart';

import 'common/extensions.dart';
import 'interop/models/geo_point_js.dart';
import 'interop/osm_interop.dart' as interop hide initMapFinish;

mixin WebMixin {
  Future<void> initLocationMap(GeoPoint p) async {
    await promiseToFuture(interop.initMapLocation(p.toGeoJS()));
  }

  Future<void> currentLocation() async {
    await interop.currentUserLocation();
  }

  Future<void> advancedPositionPicker() {
    // TODO: implement advancedPositionPicker
    throw UnimplementedError();
  }

  Future<void> cancelAdvancedPositionPicker() {
    // TODO: implement cancelAdvancedPositionPicker
    throw UnimplementedError();
  }

  Future changeDefaultIconMarker(GlobalKey<State<StatefulWidget>>? key) async {
    final base64 = (await capturePng(key!)).convertToString();
    await interop.setDefaultIcon(base64);
  }

  Future changeIconAdvPickerMarker(GlobalKey<State<StatefulWidget>> key) {
    // TODO: implement changeIconAdvPickerMarker
    throw UnimplementedError();
  }

  Future<void> changeLocation(GeoPoint p) async {
    await _addPosition(
      p,
      showMarker: true,
      animate: true,
    );
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

  Future<void> drawRoadManually(
    List<GeoPoint> path,
    Color roadColor,
    double width,
  ) {
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

  Future<void> goToPosition(GeoPoint p) async {
    await _addPosition(p, animate: true, showMarker: false);
  }

  Future<void> mapOrientation(double? degree) {
    // TODO: implement mapOrientation
    throw UnimplementedError();
  }

  Future<GeoPoint> myLocation() async {
    Map<String, dynamic>? value = await html.promiseToFutureAsMap(interop.locateMe());
    if (value!.containsKey("error")) {
      throw Exception(value["message"]);
    }
    return GeoPoint.fromMap(Map<String, double>.from(value));
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

  Future<void> setStaticPosition(List<GeoPoint> geoPoints, String id) async {
    await interop.setStaticGeoPoints(
      id,
      geoPoints.map((e) => e.toGeoJS()).toList(),
    );
  }

  Future<void> zoomIn() async {
    await interop.zoomIn();
  }

  Future<void> zoomOut() async {
    await interop.zoomOut();
  }



  Future<double> getZoom() async {
    return await promiseToFuture(interop.getZoom());
  }

  Future<void> limitArea(BoundingBox box) async {
    await interop.limitArea(box.toBoundsJS());
  }

  Future<void> removeLimitArea() async {
    await interop.limitArea(BoundingBox.world().toBoundsJS());
  }

  Future<void> setMaximumZoomLevel(double maxZoom) async {
    await interop.setMaxZoomLevel(maxZoom);
  }

  Future<void> setMinimumZoomLevel(double minZoom) async {
    await interop.setMinZoomLevel(minZoom);
  }

  Future<void> setStepZoom(int stepZoom) async {
    await interop.setZoomStep(stepZoom.toDouble());
  }

  Future<void> setZoom({double? zoomLevel, double? stepZoom}) async {
    assert(zoomLevel != null || stepZoom != null);
    if (zoomLevel != null) {
      await interop.setZoom(zoomLevel);
    } else if (stepZoom != null) {
      await interop.setZoomStep(stepZoom);
    }
  }

  Future<RoadInfo> drawRoad(
    GeoPoint start,
    GeoPoint end, {
    RoadType roadType = RoadType.car,
    List<GeoPoint>? interestPoints,
    RoadOption? roadOption,
  }) {
    // TODO: implement drawRoad
    throw UnimplementedError();
  }

  Future<void> configureZoomMap(
    double minZoomLevel,
    double maxZoomLevel,
    double stepZoom,
    double initZoom,
  ) async {
    await interop.configZoom(
      stepZoom,
      initZoom,
      minZoomLevel,
      maxZoomLevel,
    );
  }

  Future<void> _addPosition(
    GeoPoint point, {
    bool showMarker = true,
    bool animate = false,
  }) async {
    //await promiseToFuture();
    await interop.addPosition(
      GeoPointJs(
        lat: point.latitude,
        lon: point.longitude,
      ),
      showMarker,
      animate,
    );
  }

  Future<GeoPoint> selectPosition({
    MarkerIcon? icon,
    String imageURL = "",
  }) {
    // TODO: implement selectPosition
    throw UnimplementedError();
  }

  Future<GeoPoint> getMapCenter() async {
    final mapCenterPoint = await html.promiseToFutureAsMap(interop.centerMap());
    if (mapCenterPoint == null) {
      throw Exception("web osm : error to get center geopoint");
    }
    return GeoPoint.fromMap(Map<String, double>.from(mapCenterPoint));
  }

  Future<BoundingBox> getBounds() async {
    final boundingBoxMap = await html.promiseToFutureAsMap(interop.getBounds());
    if (boundingBoxMap == null) {
      throw Exception("web osm : error to get bounds");
    }
    return BoundingBox.fromMap(Map<String, double>.from(boundingBoxMap));
  }

  Future<void> zoomToBoundingBox(BoundingBox box, {int paddinInPixel = 0}) async {
    await promiseToFuture(interop.flyToBounds(
      box.toBoundsJS(),
      paddinInPixel,
    ));
  }
}

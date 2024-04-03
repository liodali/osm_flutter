import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_web/src/interop/models/custom_tile_js.dart';
import 'package:flutter_osm_web/src/interop/models/geo_point_js.dart';
import 'package:flutter_osm_web/src/interop/models/shape_js.dart';
import 'package:js/js_util.dart';
import 'package:routing_client_dart/routing_client_dart.dart' as routing;

import 'common/extensions.dart';
import 'interop/osm_interop.dart' as interop hide initMapFinish;
import 'osm_web.dart';

mixin WebMixin {
  late int mapIdMixin;
  final manager = routing.OSRMManager();

  late OsmWebWidgetState _osmWebFlutterState;
  RoadOption? defaultRoadOption;
  Map<String, RoadInfo> roadsWebCache = {};

  Future<void> initLocationMap(GeoPoint p) async {
    await promiseToFuture(interop.initMapLocation(mapIdMixin, p.toGeoJS()));
  }

  Future<void> changeTileLayer({CustomTile? tileLayer}) async {
    final urls = tileLayer?.urlsServers.first.toWeb();
    await promiseToFuture(
      interop.changeTileLayer(
        mapIdMixin,
        tileLayer != null && urls != null && urls.isNotEmpty
            ? CustomTileJs(
                url: urls.first,
                subDomains: urls.last,
                apiKey: tileLayer.keyApi != null
                    ? '?${tileLayer.keyApi!.key}=${tileLayer.keyApi!.value}'
                    : '',
                maxZoom: tileLayer.maxZoomLevel,
                minZoom: tileLayer.minZoomLevel,
                tileExtension: tileLayer.tileExtension,
                tileSize: tileLayer.tileSize,
              )
            : null,
      ),
    );
  }

  Future<void> currentLocation() async {
    await interop.currentUserLocation(
      mapIdMixin,
    );
  }

  Future<void> changeLocation(GeoPoint p) async {
    await _addPosition(
      p,
      showMarker: true,
      animate: true,
    );
  }

  Future<void> disabledTracking() async {
    await interop.disableTracking(
      mapIdMixin,
    );
  }

  Future<void> startLocationUpdating() async {
    await interop.startLocationUpdating(mapIdMixin);
  }

  Future<void> stopLocationUpdating() async {
    await interop.stopLocationUpdating(mapIdMixin);
  }

  Future<void> drawCircle(CircleOSM circleOSM) async {
    final opacity = circleOSM.color.opacity;
    final shapeConfig = CircleShapeJS(
      key: circleOSM.key,
      center: circleOSM.centerPoint.toGeoJS(),
      radius: circleOSM.radius,
      color: circleOSM.color.withOpacity(1).toHexColor(),
      borderColor: circleOSM.borderColor?.toHexColor(),
      opacityFilled: opacity,
      strokeWidth: circleOSM.strokeWidth,
    );
    await promiseToFuture(
      interop.drawCircle(
        mapIdMixin,
        shapeConfig,
      ),
    );
  }

  Future<void> drawRect(RectOSM rectOSM) async {
    final rect = geoPointAsRect(
      center: rectOSM.centerPoint,
      lengthInMeters: rectOSM.distance,
      widthInMeters: rectOSM.distance,
    );
    final opacity = rectOSM.color.opacity;
    final shapeConfig = RectShapeJS(
      key: rectOSM.key,
      color: rectOSM.color.withOpacity(1).toHexColor(),
      strokeWidth: rectOSM.strokeWidth,
      opacityFilled: opacity,
      borderColor: rectOSM.borderColor?.toHexColor(),
    );
    await promiseToFuture(interop.drawRect(
      mapIdMixin,
      shapeConfig,
      rect.map((e) => e.toGeoJS()).toList(),
    ));
  }

  Future<void> enableTracking({
    bool enableStopFollow = false,
    bool disableMarkerRotation = false,
    Anchor anchor = Anchor.center,
    bool useDirectionMarker = false,
  }) async {
    await interop.enableTracking(
      mapIdMixin,
      enableStopFollow,
      useDirectionMarker,
      IconAnchorJS(
        x: anchor.value.$1,
        y: anchor.value.$2,
      ),
      //anchor.toPlatformMap(),
    );
  }

  Future<void> goToPosition(
    GeoPoint p, {
    bool animate = false,
  }) =>
      _addPosition(
        p,
        animate: animate,
        showMarker: false,
      );

  Future<void> mapOrientation(double? degree) async {
    debugPrint("not implemented in web side");
  }

  Future<GeoPoint> myLocation() async {
    Map<String, dynamic>? value =
        await html.promiseToFutureAsMap(interop.locateMe(
      mapIdMixin,
    ));
    if (value!.containsKey("error")) {
      throw Exception(value["message"]);
    }
    return GeoPoint.fromMap(Map<String, double>.from(value));
  }

  Future<void> removeAllCircle() async {
    promiseToFuture(interop.removeAllCircle(mapIdMixin));
  }

  Future<void> removeAllRect() async {
    promiseToFuture(interop.removeAllRect(mapIdMixin));
  }

  Future<void> removeAllShapes() async {
    promiseToFuture(interop.removeAllShapes(mapIdMixin));
  }

  Future<void> removeCircle(String key) async {
    await promiseToFuture(interop.removePath(mapIdMixin, key));
  }

  Future<void> removeLastRoad() async {
    await promiseToFuture(interop.removeLastRoad(mapIdMixin));
    roadsWebCache.remove(roadsWebCache.keys.last);
  }

  Future<void> removeMarker(GeoPoint p) async {
    interop.removeMarker(mapIdMixin, p.toGeoJS());
  }

  Future<void> removeMarkers(
    List<GeoPoint> markers,
  ) async {
    final futures = <Future>[];
    markers.forEach((geoPoint) {
      futures.add(removeMarker(geoPoint));
    });
    await Future.wait(futures);
  }

  Future<void> removeRect(String key) async {
    await promiseToFuture(interop.removePath(mapIdMixin, key));
  }

  Future<void> setStaticPosition(List<GeoPoint> geoPoints, String id) async {
    var listWithoutOrientation =
        geoPoints.skipWhile((p) => p is GeoPointWithOrientation).toList();
    if (listWithoutOrientation.isNotEmpty) {
      await interop.setStaticGeoPoints(
        mapIdMixin,
        id,
        listWithoutOrientation.map((point) => point.toGeoJS()).toList(),
      );
    }
    if (listWithoutOrientation.length != geoPoints.length) {
      List<GeoPointWithOrientation> listOrientation =
          geoPoints.whereType<GeoPointWithOrientation>().toList();
      if (listOrientation.isNotEmpty) {
        await interop.setStaticGeoPointsWithOrientation(
          mapIdMixin,
          id,
          listOrientation.map((point) => point.toGeoJS()).toList(),
        );
      }
    }
  }

  Future<void> zoomIn() async {
    await interop.zoomIn(
      mapIdMixin,
    );
  }

  Future<void> zoomOut() async {
    await interop.zoomOut(
      mapIdMixin,
    );
  }

  Future<double> getZoom() async {
    return await promiseToFuture(interop.getZoom());
  }

  Future<void> limitArea(BoundingBox box) async {
    await interop.limitArea(mapIdMixin, box.toBoundsJS());
  }

  Future<void> removeLimitArea() async {
    await interop.limitArea(mapIdMixin, BoundingBox.world().toBoundsJS());
  }

  Future<void> setMaximumZoomLevel(double maxZoom) async {
    await interop.setMaxZoomLevel(mapIdMixin, maxZoom);
  }

  Future<void> setMinimumZoomLevel(double minZoom) async {
    await interop.setMinZoomLevel(mapIdMixin, minZoom);
  }

  Future<void> setStepZoom(int stepZoom) async {
    await interop.setZoomStep(mapIdMixin, stepZoom.toDouble());
  }

  Future<void> setZoom({double? zoomLevel, double? stepZoom}) async {
    assert(zoomLevel != null || stepZoom != null);
    if (zoomLevel != null) {
      await interop.setZoom(mapIdMixin, zoomLevel);
    } else if (stepZoom != null) {
      await interop.setZoomStep(mapIdMixin, stepZoom);
    }
  }

  Future<RoadInfo> drawRoad(
    GeoPoint start,
    GeoPoint end, {
    RoadType roadType = RoadType.car,
    List<GeoPoint>? interestPoints,
    RoadOption? roadOption,
  }) async {
    final geoPoints = [start, end];
    if (interestPoints != null && interestPoints.isNotEmpty) {
      geoPoints.insertAll(1, interestPoints);
    }
    final waypoints = geoPoints.toLngLatList();
    final road = await manager.getRoad(
      waypoints: waypoints,
      roadType: routing.RoadType.values[roadType.index],
      alternative: false,
      geometries: routing.Geometries.geojson,
    );
    final routeJs = road.polyline!.mapToListGeoJS();

    debugPrint((roadOption?.roadBorderColor ?? Colors.green).toHexColor());
    var roadInfo = RoadInfo();
    interop.drawRoad(
      mapIdMixin,
      roadInfo.key,
      routeJs,
      ((roadOption ?? defaultRoadOption)?.roadColor ?? Colors.green)
          .toHexColor(),
      ((roadOption ?? defaultRoadOption)?.roadWidth ?? 5.0).toDouble(),
      (roadOption ?? defaultRoadOption)?.zoomInto ?? true,
      ((roadOption ?? defaultRoadOption)?.roadBorderColor ?? Colors.green)
          .toHexColor(),
      (roadOption ?? defaultRoadOption)?.roadBorderWidth ?? 0,
      interestPoints?.toListGeoPointJs() ?? [],
      null,
    );
    final instructions = await manager.buildInstructions(road);
    roadInfo = roadInfo.copyWith(
      duration: road.duration,
      distance: road.distance,
      instructions: instructions
          .map((e) => Instruction(
                instruction: e.instruction,
                geoPoint: e.location.toGeoPoint(),
              ))
          .toList(),
      route: road.polyline!.mapToListGeoPoints(),
    );
    roadsWebCache[roadInfo.key] = roadInfo;
    return roadInfo;
  }

  Future<String> drawRoadManually(
    String roadKey,
    List<GeoPoint> path,
    RoadOption roadOption,
  ) async {
    final routeJs = path.toListGeoPointJs();

    interop.drawRoad(
      mapIdMixin,
      roadKey,
      routeJs,
      roadOption.roadColor.toHexColor(),
      roadOption.roadWidth.toDouble(),
      roadOption.zoomInto,
      (roadOption.roadBorderColor ?? Colors.green).toHexColor(),
      roadOption.roadBorderWidth?.toDouble() ?? 0,
      [],
      null,
    );

    roadsWebCache[roadKey] = RoadInfo(route: path).copyWith(
      roadKey: roadKey,
    );
    return roadKey;
  }

  Future<void> clearAllRoads() async {
    await promiseToFuture(interop.clearAllRoads(mapIdMixin));
    roadsWebCache.clear();
  }

  Future<void> removeRoad({required String roadKey}) async {
    await promiseToFuture(interop.removeRoad(mapIdMixin, roadKey));
    roadsWebCache.remove(roadKey);
  }

  Future<List<RoadInfo>> drawMultipleRoad(
    List<MultiRoadConfiguration> configs, {
    MultiRoadOption commonRoadOption = const MultiRoadOption.empty(),
  }) async {
    List<Future<RoadInfo>> futureRoads = [];
    configs.forEach((config) {
      futureRoads.add(
        drawRoad(
          config.startPoint,
          config.destinationPoint,
          interestPoints: config.intersectPoints,
          roadOption: config.roadOptionConfiguration ?? commonRoadOption,
        ),
      );
    });
    final infos = await Future.wait(futureRoads);
    infos.forEach((roadInfo) {
      roadsWebCache[roadInfo.key] = roadInfo;
    });
    return infos;
  }

  Future<void> configureZoomMap(
    double minZoomLevel,
    double maxZoomLevel,
    double stepZoom,
    double initZoom,
  ) async {
    await interop.configZoom(
      mapIdMixin,
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
      mapIdMixin,
      point.toGeoJS(),
      showMarker,
      animate,
    );
  }

  Future<GeoPoint> selectPosition({
    MarkerIcon? icon,
    String imageURL = "",
  }) {
    throw Exception("stop use this method,use addMarker");
  }

  Future<GeoPoint> getMapCenter() async {
    final mapCenterPoint = await html.promiseToFutureAsMap(interop.centerMap(
      mapIdMixin,
    ));
    if (mapCenterPoint == null) {
      throw Exception("web osm : error to get center geopoint");
    }
    return GeoPoint.fromMap(Map<String, double>.from(mapCenterPoint));
  }

  Future<BoundingBox> getBounds() async {
    final boundingBoxMap = await html.promiseToFutureAsMap(interop.getBounds(
      mapIdMixin,
    ));
    if (boundingBoxMap == null) {
      throw Exception("web osm : error to get bounds");
    }
    return BoundingBox.fromMap(Map<String, double>.from(boundingBoxMap));
  }

  Future<void> zoomToBoundingBox(BoundingBox box,
      {int paddinInPixel = 0}) async {
    await promiseToFuture(interop.flyToBounds(
      mapIdMixin,
      box.toBoundsJS(),
      paddinInPixel,
    ));
  }

  Future<List<GeoPoint>> geoPoints() async {
    var map = await html.promiseToFutureAsMap(interop.getGeoPoints(
      mapIdMixin,
    ));
    if (map == null || map["list"] == null) {
      return [];
    }
    map = Map.from(map);
    final mapGeoPoints = json.decode(map["list"]);
    return (List.castFrom(mapGeoPoints))
        .map((elem) => GeoPoint.fromMap(Map<String, double>.from(elem)))
        .toList();
  }

  Future<void> toggleLayer({required bool toggle}) async {
    await promiseToFuture(interop.toggleAlllayers(mapIdMixin, toggle));
  }
}

extension PrivateAccessMixinWeb on WebMixin {
  OsmWebWidgetState get osmWebFlutterState => _osmWebFlutterState;

  void setWidgetState(OsmWebWidgetState osmWebFlutterState) {
    _osmWebFlutterState = osmWebFlutterState;
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_web/src/interop/models/bounding_box_js.dart';
import 'package:flutter_osm_web/src/interop/models/custom_tile_js.dart';
import 'package:flutter_osm_web/src/interop/models/geo_point_js.dart';
import 'package:flutter_osm_web/src/interop/models/shape_js.dart';
import 'dart:js_interop';
import 'package:routing_client_dart/routing_client_dart.dart' as routing;

import 'common/extensions.dart';
import 'interop/osm_interop.dart' as interop;
import 'osm_web.dart';

mixin WebMixin {
  late int mapIdMixin;
  final manager = routing.OSRMManager();

  late OsmWebWidgetState _osmWebFlutterState;
  RoadOption? defaultRoadOption;
  Map<String, RoadInfo> roadsWebCache = {};

  Future<void> initLocationMap(GeoPoint p) async {
    await interop.initMapLocation(mapIdMixin.toJS, p.toGeoJS()).toDart;
  }

  Future<void> changeTileLayer({CustomTile? tileLayer}) async {
    final urls = tileLayer?.urlsServers.first.toWeb();
    await interop
        .changeTileLayer(
          mapIdMixin.toJS,
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
        )
        .toDart;
  }

  Future<void> currentLocation() async {
    await interop
        .currentUserLocation(
          mapIdMixin.toJS,
        )
        .toDart;
  }

  Future<void> changeLocation(GeoPoint p) async {
    await _addPosition(
      p,
      showMarker: true,
      animate: true,
    );
  }

  Future<void> disabledTracking() async {
    await interop
        .disableTracking(
          mapIdMixin.toJS,
        )
        .toDart;
  }

  Future<void> startLocationUpdating() async {
    await interop.startLocationUpdating(mapIdMixin.toJS).toDart;
  }

  Future<void> stopLocationUpdating() async {
    await interop.stopLocationUpdating(mapIdMixin.toJS).toDart;
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
    await interop
        .drawCircle(
          mapIdMixin.toJS,
          shapeConfig,
        )
        .toDart;
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
    await interop
        .drawRect(
          mapIdMixin.toJS,
          shapeConfig,
          rect.map((e) => e.toGeoJS()).toList().toJS,
        )
        .toDart;
  }

  Future<void> enableTracking({
    bool enableStopFollow = false,
    bool disableMarkerRotation = false,
    Anchor anchor = Anchor.center,
    bool useDirectionMarker = false,
  }) async {
    await interop
        .enableTracking(
          mapIdMixin.toJS,
          enableStopFollow.toJS,
          useDirectionMarker.toJS,
          IconAnchorJS(
            x: anchor.value.$1,
            y: anchor.value.$2,
          ),
          //anchor.toPlatformMap(),
        )
        .toDart;
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
    final locateResp = (await interop.locateMe(mapIdMixin.toJS).toDart).toDart;
    Map<String, dynamic>? value = json.decode(locateResp);
    if (value!.containsKey("error")) {
      throw Exception(value["message"]);
    }
    return GeoPoint.fromMap(Map<String, double>.from(value));
  }

  Future<void> removeAllCircle() async {
    interop.removeAllCircle(mapIdMixin.toJS).toDart;
  }

  Future<void> removeAllRect() async {
    interop.removeAllRect(mapIdMixin.toJS).toDart;
  }

  Future<void> removeAllShapes() async {
    interop.removeAllShapes(mapIdMixin.toJS).toDart;
  }

  Future<void> removeCircle(String key) async {
    await interop.removePath(mapIdMixin.toJS, key.toJS).toDart;
  }

  Future<void> removeLastRoad() async {
    await interop.removeLastRoad(mapIdMixin.toJS).toDart;
    roadsWebCache.remove(roadsWebCache.keys.last);
  }

  Future<void> removeMarker(GeoPoint p) async {
    interop.removeMarker(mapIdMixin.toJS, p.toGeoJS());
  }

  Future<void> removeMarkers(
    List<GeoPoint> markers,
  ) async {
    final futures = <Future>[];
    for (var geoPoint in markers) {
      futures.add(removeMarker(geoPoint));
    }
    await Future.wait(futures);
  }

  Future<void> removeRect(String key) async {
    await interop.removePath(mapIdMixin.toJS, key.toJS).toDart;
  }

  Future<void> setStaticPosition(List<GeoPoint> geoPoints, String id) async {
    var listWithoutOrientation =
        geoPoints.skipWhile((p) => p is GeoPointWithOrientation).toList();
    if (listWithoutOrientation.isNotEmpty) {
      await interop
          .setStaticGeoPoints(
            mapIdMixin.toJS,
            id.toJS,
            listWithoutOrientation
                .map((point) => point.toGeoJS())
                .toList()
                .toJS,
          )
          .toDart;
    }
    if (listWithoutOrientation.length != geoPoints.length) {
      List<GeoPointWithOrientation> listOrientation =
          geoPoints.whereType<GeoPointWithOrientation>().toList();
      if (listOrientation.isNotEmpty) {
        await interop
            .setStaticGeoPointsWithOrientation(
              mapIdMixin.toJS,
              id.toJS,
              listOrientation.map((point) => point.toGeoJS()).toList().toJS,
            )
            .toDart;
      }
    }
  }

  Future<void> zoomIn() async {
    await interop
        .zoomIn(
          mapIdMixin.toJS,
        )
        .toDart;
  }

  Future<void> zoomOut() async {
    await interop
        .zoomOut(
          mapIdMixin.toJS,
        )
        .toDart;
  }

  Future<double> getZoom() async {
    return (await interop
            .getZoom(
              mapIdMixin.toJS,
            )
            .toDart)
        .toDartDouble;
  }

  Future<void> limitArea(BoundingBox box) async {
    interop.limitArea(mapIdMixin.toJS, box.toBoundsJS());
  }

  Future<void> removeLimitArea() async {
    interop.limitArea(
      mapIdMixin.toJS,
      const BoundingBox.world().toBoundsJS(),
    );
  }

  Future<void> setMaximumZoomLevel(double maxZoom) async {
    await interop.setMaxZoomLevel(mapIdMixin.toJS, maxZoom.toJS).toDart;
  }

  Future<void> setMinimumZoomLevel(double minZoom) async {
    await interop.setMinZoomLevel(mapIdMixin.toJS, minZoom.toJS).toDart;
  }

  Future<void> setStepZoom(int stepZoom) async {
    await interop.setZoomStep(mapIdMixin.toJS, stepZoom.toDouble().toJS).toDart;
  }

  Future<void> setZoom({double? zoomLevel, double? stepZoom}) async {
    assert(zoomLevel != null || stepZoom != null);
    if (zoomLevel != null) {
      await interop.setZoom(mapIdMixin.toJS, zoomLevel.toJS).toDart;
    } else if (stepZoom != null) {
      await interop.setZoomStep(mapIdMixin.toJS, stepZoom.toJS).toDart;
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

    var roadInfo = RoadInfo();
    final roadConfig =
        roadOption ?? defaultRoadOption ?? const RoadOption.empty();
    debugPrint(roadOption?.toString());

    interop.drawRoad(
      mapIdMixin.toJS,
      roadInfo.key.toJS,
      routeJs.toJS,
      (interestPoints?.toListGeoPointJs() ?? []).toJS,
      roadConfig.toRoadOptionJS,
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
      mapIdMixin.toJS,
      roadKey.toJS,
      routeJs.toJS,
      <GeoPointJs>[].toJS,
      roadOption.toRoadOptionJS,
    );

    roadsWebCache[roadKey] = RoadInfo(route: path).copyWith(
      roadKey: roadKey,
    );
    return roadKey;
  }

  Future<void> clearAllRoads() async {
    await interop.clearAllRoads(mapIdMixin.toJS).toDart;
    roadsWebCache.clear();
  }

  Future<void> removeRoad({required String roadKey}) async {
    await interop.removeRoad(mapIdMixin.toJS, roadKey.toJS).toDart;
    roadsWebCache.remove(roadKey);
  }

  Future<List<RoadInfo>> drawMultipleRoad(
    List<MultiRoadConfiguration> configs, {
    MultiRoadOption commonRoadOption = const MultiRoadOption.empty(),
  }) async {
    List<Future<RoadInfo>> futureRoads = [];
    for (var config in configs) {
      futureRoads.add(
        drawRoad(
          config.startPoint,
          config.destinationPoint,
          interestPoints: config.intersectPoints,
          roadOption: config.roadOptionConfiguration ?? commonRoadOption,
        ),
      );
    }
    final infos = await Future.wait(futureRoads);
    for (var roadInfo in infos) {
      roadsWebCache[roadInfo.key] = roadInfo;
    }
    return infos;
  }

  Future<void> configureZoomMap(
    double minZoomLevel,
    double maxZoomLevel,
    double stepZoom,
    double initZoom,
  ) async {
    await interop
        .configZoom(
          mapIdMixin.toJS,
          stepZoom.toJS,
          initZoom.toJS,
          minZoomLevel.toJS,
          maxZoomLevel.toJS,
        )
        .toDart;
  }

  Future<void> _addPosition(
    GeoPoint point, {
    bool showMarker = true,
    bool animate = false,
  }) async {
    //await promiseToFuture();
    await interop
        .addPosition(
          mapIdMixin.toJS,
          point.toGeoJS(),
          showMarker.toJS,
          animate.toJS,
        )
        .toDart;
  }

  Future<GeoPoint> selectPosition({
    MarkerIcon? icon,
    String imageURL = "",
  }) {
    throw Exception("stop use this method,use addMarker");
  }

  Future<GeoPoint> getMapCenter() async {
    final mapCenterPoint = interop
        .centerMap(
          mapIdMixin.toJS,
        )
        .toMap();

    return GeoPoint.fromMap(Map<String, double>.from(mapCenterPoint));
  }

  Future<BoundingBox> getBounds() async {
    final boundingBoxMap = interop.getBounds(mapIdMixin.toJS).toDart();

    return BoundingBox.fromMap(Map<String, double>.from(boundingBoxMap));
  }

  Future<void> zoomToBoundingBox(
    BoundingBox box, {
    int paddinInPixel = 0,
  }) async {
    await interop
        .flyToBounds(
          mapIdMixin.toJS,
          box.toBoundsJS(),
          paddinInPixel.toJS,
        )
        .toDart;
  }

  Future<List<GeoPoint>> geoPoints() async {
    var mapJsonJS = await interop
        .getGeoPoints(
          mapIdMixin.toJS,
        )
        .toDart;
    final mapGeoPoints = json.decode(mapJsonJS.toDart);
    return (List.castFrom(mapGeoPoints))
        .map((elem) => GeoPoint.fromMap(Map<String, double>.from(elem)))
        .toList();
  }

  Future<void> toggleLayer({required bool toggle}) async {
    await interop.toggleAlllayers(mapIdMixin.toJS, toggle.toJS).toDart;
  }
}

extension PrivateAccessMixinWeb on WebMixin {
  OsmWebWidgetState get osmWebFlutterState => _osmWebFlutterState;

  void setWidgetState(OsmWebWidgetState osmWebFlutterState) {
    _osmWebFlutterState = osmWebFlutterState;
  }

  Future<void> removeMapControls() async {
    await interop.removeControls(mapIdMixin.toJS).toDart;
  }
}

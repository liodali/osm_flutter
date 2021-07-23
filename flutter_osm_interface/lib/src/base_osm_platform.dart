
import 'package:flutter/material.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'common/osm_event.dart';
import 'types/types.dart';

abstract class BaseOsmPlatform extends PlatformInterface {

  static final Object token = Object();

  BaseOsmPlatform() : super(token: token);

  Stream<MapInitialization> onMapIsReady(int idMap);

  Stream<SingleTapEvent> onSinglePressMapClickListener(int idMap);

  Stream<LongTapEvent> onLongPressMapClickListener(int idMap);

  Stream<GeoPointEvent> onGeoPointClickListener(int idMap);

  Stream<UserLocationEvent> onUserPositionListener(int idMap);

  Future<void> init(
    int idOSM,
  );

  void close();

  Future<void> initPositionMap(
    int idOSM,
    GeoPoint point,
  );

  Future<void> currentLocation(
    int idOSM,
  );

  Future<GeoPoint> myLocation(
    int idMap,
  );

  Future<void> zoom(
    int idOSM,
    double zoom,
  );

  Future<GeoPoint> pickLocation(
    int idOSM, {
    GlobalKey? key,
    String imageURL = "",
  });

  Future<void> customMarker(
    int idOSM,
    GlobalKey? globalKey,
  );

  Future<void> setColorRoad(
    int idOSM,
    Color color,
  );

  Future<void> setMarkersRoad(
    int idOSM,
    List<GlobalKey?> keys,
  );

  Future<void> enableTracking(
    int idOSM,
  );

  Future<void> addPosition(
    int idOSM,
    GeoPoint p,
  );

  Future<void> goToPosition(
    int idOSM,
    GeoPoint p,
  );

  Future<void> removePosition(
    int idOSM,
    GeoPoint p,
  );

  Future<void> removeLastRoad(
    int idOSM,
  );

  Future<RoadInfo> drawRoad(
    int idOSM,
    GeoPoint start,
    GeoPoint end, {
    List<GeoPoint>? interestPoints,
    RoadOption roadOption,
  });
}




import 'package:flutter/material.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'channel/osm_method_channel.dart';
import 'base_osm_platform.dart';
import 'types/types.dart';
abstract class OSMPlatform extends BaseOsmPlatform {
  OSMPlatform() : super();


  static late  OSMPlatform _instance = MethodChannelOSM();

  static OSMPlatform get instance => _instance;


  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [OSMPlatformInterface] when they register themselves.
  static set instance(OSMPlatform instance) {
    PlatformInterface.verifyToken(instance, BaseOsmPlatform.token);
    _instance = instance;
  }

  Future<void> drawCircle(
    int idOSM,
    CircleOSM circleOSM,
  );

  Future<void> removeCircle(
    int idOSM,
    String key,
  );

  Future<void> drawRect(
    int idOSM,
    RectOSM rectOSM,
  );

  Future<void> removeRect(
    int idOSM,
    String key,
  );

  Future<void> removeAllRect(
    int idOSM,
  );

  Future<void> removeAllCircle(
    int idOSM,
  );

  Future<void> removeAllShapes(
    int idOSM,
  );

  Future<void> customMarkerStaticPosition(
    int idOSM,
    GlobalKey? globalKey,
    String id,
  );

  Future<void> staticPosition(
    int idOSM,
    List<GeoPoint> pList,
    String id,
  );

  Future<void> setDefaultZoom(
    int idOSM,
    double defaultZoom,
  );

  Future<void> disableTracking(
    int idOSM,
  );

  Future<void> visibilityInfoWindow(
    int idOSM,
    bool visible,
  );

  Future<void> advancedPositionPicker(
    int idOSM,
  );

  Future<GeoPoint> getPositionOnlyAdvancedPositionPicker(
    int idOSM,
  );

  Future<GeoPoint> selectAdvancedPositionPicker(
    int idOSM,
  );

  Future<void> cancelAdvancedPositionPicker(
    int idOSM,
  );

  Future<void> drawRoadManually(
    int idOSM,
    List<GeoPoint> road,
    Color roadColor,
    double width,
  );

  Future<void> mapRotation(
    int idOSM,
    double? degree,
  );

  Future<void> customAdvancedPickerMarker(
    int idMap,
    GlobalKey key,
  );

  Future<void> initIosMap(
    int idMap,
  );
}

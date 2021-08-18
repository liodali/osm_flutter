library osm_flutter;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:location/location.dart';

import '../../flutter_osm_plugin.dart';
import '../controller/osm_controller.dart';
import '../types/geo_point.dart';
import '../types/types.dart';
import '../widgets/copyright_osm_widget.dart';
import 'osm_controller.dart';

part '../osm_flutter.dart';

part '../widgets/custom_picker_location.dart';

part 'map_controller.dart';

part 'picker_map_controller.dart';

///  [BaseMapController] : base controller for osm flutter
///
///
/// [initMapWithUserPosition] : (bool) if is true, map will show your current location
///
/// [initPosition] : (GeoPoint) if it isn't null, the map will be pointed at this position
///
/// [boundingBox] : (BoundingBox) if it isn't null, the map will be pointed at this position
abstract class BaseMapController {
  late OSMController _osmController;
  final bool initMapWithUserPosition;
  final GeoPoint? initPosition;
  final BoundingBox? areaLimit;

  late ValueNotifier<GeoPoint?> _listenerMapLongTapping = ValueNotifier(null);
  late ValueNotifier<GeoPoint?> _listenerMapSingleTapping = ValueNotifier(null);
  late ValueNotifier<bool> _listenerMapIsReady = ValueNotifier(false);

  ValueListenable<GeoPoint?> get listenerMapLongTapping =>
      _listenerMapLongTapping;

  ValueListenable<GeoPoint?> get listenerMapSingleTapping =>
      _listenerMapSingleTapping;

  ValueListenable<bool> get listenerMapIsReady => _listenerMapIsReady;

  BaseMapController({
    this.initMapWithUserPosition = true,
    this.initPosition,
    this.areaLimit = const BoundingBox.world(),
  }) : assert(initMapWithUserPosition || initPosition != null);

  void _init(
    OSMController osmController,
  ) {
    this._osmController = osmController;
    Future.delayed(Duration(milliseconds: 1250), () async {
      await this._osmController.initMap(
          initPosition: initPosition,
          initWithUserPosition: initMapWithUserPosition,
          box: areaLimit);
    });
  }
}

extension setLiteners on BaseMapController {
  void setValueListenerMapLongTapping(GeoPoint p) {
    _listenerMapLongTapping.value = p;
  }

  void setValueListenerMapSingleTapping(GeoPoint p) {
    _listenerMapSingleTapping.value = p;
  }

  void setValueListenerMapIsReady(bool isReady) {
    _listenerMapIsReady.value = isReady;
  }
}

library osm_flutter;

import 'package:flutter/material.dart';

import '../../flutter_osm_plugin.dart';
import '../types/geo_point.dart';
import 'osm_controller.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:location/location.dart';

import '../controller/osm_controller.dart';
import '../types/types.dart';
import '../widgets/copyright_osm_widget.dart';

part '../widgets/custom_picker_location.dart';

part 'map_controller.dart';

part 'picker_map_controller.dart';

part '../osm_flutter.dart';

///  [BaseMapController] : base controller for osm flutter
///
///
/// [initMapWithUserPosition] : (bool) if is true, map will show your current location
///
/// [initPosition] : (GeoPoint) if it isn't null, the map will be pointed at this position
abstract class BaseMapController {
  late OSMController _osmController;
  final bool initMapWithUserPosition;
  final GeoPoint? initPosition;

  late ValueNotifier<GeoPoint?> listenerMapLongTapping = ValueNotifier(null);
  late ValueNotifier<GeoPoint?> listenerMapSingleTapping = ValueNotifier(null);

  BaseMapController({
    this.initMapWithUserPosition = true,
    this.initPosition,
  }) : assert(initMapWithUserPosition || initPosition != null);

  void _init(
    OSMController osmController,
  ) {
    this._osmController = osmController;
    Future.delayed(Duration(milliseconds: 1250), () async {
      await this._osmController.initMap(
            initPosition: initPosition,
            initWithUserPosition: initMapWithUserPosition,
          );
    });
  }
}

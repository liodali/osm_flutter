import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import '../types/types.dart';

///  [BaseMapController] : base controller for osm flutter
///
///
/// [initMapWithUserPosition] : (bool) if is true, map will show your current location
///
/// [initPosition] : (GeoPoint) if it isn't null, the map will be pointed at this position
abstract class IBaseMapController {
  final bool initMapWithUserPosition;
  final GeoPoint? initPosition;


  late ValueNotifier<GeoPoint?> listenerMapLongTapping = ValueNotifier(null);
  late ValueNotifier<GeoPoint?> listenerMapSingleTapping = ValueNotifier(null);

  IBaseMapController({
    this.initMapWithUserPosition = true,
    this.initPosition,
  }) : assert(initMapWithUserPosition || initPosition != null);

  void init();

  void dispose();
}

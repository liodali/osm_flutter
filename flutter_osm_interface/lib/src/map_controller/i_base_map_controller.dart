import 'package:flutter/foundation.dart';

import 'package:flutter_osm_interface/src/mixin/osm_mixin.dart';
import 'package:flutter_osm_interface/src/types/types.dart';
import 'package:flutter_osm_interface/src/map_controller/base_map_controller.dart';

///  [BaseMapController] : base controller for osm flutter
///
///
/// [initMapWithUserPosition] : (bool) if is true, map will show your current location
///
/// [initPosition] : (GeoPoint) if it isn't null, the map will be pointed at this position
abstract class IBaseMapController {
  final UserTrackingOption? initMapWithUserPosition;
  final GeoPoint? initPosition;
  final BoundingBox? areaLimit;
  final List<OSMMixinObserver> _mixinObserver = [];

  late ValueNotifier<GeoPoint?> _listenerMapLongTapping = ValueNotifier(null);
  late ValueNotifier<GeoPoint?> _listenerMapSingleTapping = ValueNotifier(null);
  late ValueNotifier<bool> _listenerMapIsReady = ValueNotifier(false);
  late ValueNotifier<Region?> _listenerRegionIsChanging = ValueNotifier(null);
  late ValueNotifier<RoadInfo?> _listenerRoadTapped = ValueNotifier(null);

  ValueListenable<GeoPoint?> get listenerMapLongTapping =>
      _listenerMapLongTapping;

  ValueListenable<GeoPoint?> get listenerMapSingleTapping =>
      _listenerMapSingleTapping;

  ValueListenable<RoadInfo?> get listenerRoadTapped => _listenerRoadTapped;

  ValueListenable<Region?> get listenerRegionIsChanging =>
      _listenerRegionIsChanging;

  IBaseMapController({
    this.initMapWithUserPosition,
    this.initPosition,
    this.areaLimit = const BoundingBox.world(),
  }) : assert((initMapWithUserPosition != null) ^ (initPosition != null));

  void init();

  void dispose() {
    // _listenerMapLongTapping.dispose();
    // _listenerMapSingleTapping.dispose();
    // _listenerMapIsReady.dispose();
    // _listenerRegionIsChanging.dispose();
  }
  void addObserver(OSMMixinObserver osmMixinObserver) {
    if (!_mixinObserver.contains(osmMixinObserver)) {
      _mixinObserver.add(osmMixinObserver);
    }
  }

  void removeObserver(OSMMixinObserver osmMixinObserver) {
    _mixinObserver.remove(osmMixinObserver);
  }
}

extension setLiteners on IBaseMapController {
  void setValueListenerMapLongTapping(GeoPoint p) {
    _listenerMapLongTapping.value = p;
  }

  void setValueListenerMapSingleTapping(GeoPoint p) {
    _listenerMapSingleTapping.value = p;
  }

  void setValueListenerMapIsReady(bool isReady) {
    _listenerMapIsReady.value = isReady;
  }

  void setValueListenerRegionIsChanging(Region region) {
    _listenerRegionIsChanging.value = region;
  }

  void setValueListenerMapRoadTapping(RoadInfo road) {
    _listenerRoadTapped.value = road;
  }
}

extension PrivateBaseMapController on IBaseMapController {
  List<OSMMixinObserver> get osMMixins => _mixinObserver;

  void removeObservers() {
    _mixinObserver.clear();
  }
}

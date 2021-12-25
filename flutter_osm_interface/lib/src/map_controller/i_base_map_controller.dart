import 'package:flutter/foundation.dart';

import '../types/types.dart';
import 'base_map_controller.dart';

///  [BaseMapController] : base controller for osm flutter
///
///
/// [initMapWithUserPosition] : (bool) if is true, map will show your current location
///
/// [initPosition] : (GeoPoint) if it isn't null, the map will be pointed at this position
abstract class IBaseMapController {
  final bool initMapWithUserPosition;
  final GeoPoint? initPosition;
  final BoundingBox? areaLimit;

  late ValueNotifier<GeoPoint?> _listenerMapLongTapping = ValueNotifier(null);
  late ValueNotifier<GeoPoint?> _listenerMapSingleTapping = ValueNotifier(null);
  late ValueNotifier<bool> _listenerMapIsReady = ValueNotifier(false);
  late ValueNotifier<Region?> _listenerRegionIsChanging = ValueNotifier(null);

  ValueListenable<GeoPoint?> get listenerMapLongTapping =>
      _listenerMapLongTapping;

  ValueListenable<GeoPoint?> get listenerMapSingleTapping =>
      _listenerMapSingleTapping;

  @Deprecated("this callback is deprecated,will be removed in the future,"
      "use OSMMixinObserver instead,see readme for more details")
  ValueListenable<bool> get listenerMapIsReady => _listenerMapIsReady;
  ValueListenable<Region?> get listenerRegionIsChanging =>
      _listenerRegionIsChanging;

  IBaseMapController({
    this.initMapWithUserPosition = true,
    this.initPosition,
    this.areaLimit = const BoundingBox.world(),
  }) : assert(initMapWithUserPosition || initPosition != null);

  void init();

  void dispose() {
    // _listenerMapLongTapping.dispose();
    // _listenerMapSingleTapping.dispose();
    // _listenerMapIsReady.dispose();
    // _listenerRegionIsChanging.dispose();
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

  void setValueListenerRegionIsChanging(Region region) {
    _listenerRegionIsChanging.value = region;
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/src/osm_controller/osm_controller.dart';
import 'package:flutter_osm_interface/src/types/types.dart';
import 'package:flutter_osm_interface/src/map_controller/i_base_map_controller.dart';

///  class [BaseMapController] : base controller for osm flutter
///
///
/// [initMapWithUserPosition] : (bool) if is true, map will show your current location
///
/// [initPosition] : (GeoPoint) if it isn't null, the map will be pointed at this position
abstract class BaseMapController extends IBaseMapController {
  late IBaseOSMController _osmBaseController;
  final BoundingBox? areaLimit;
  final CustomTile? customTile;
  late Timer? _timer;

  IBaseOSMController get osmBaseController => _osmBaseController;

  BaseMapController({
    UserTrackingOption? initMapWithUserPosition,
    GeoPoint? initPosition,
    this.areaLimit = const BoundingBox.world(),
    this.customTile,
  })  : assert((initMapWithUserPosition != null) ^ (initPosition != null)),
        super(
          initMapWithUserPosition: initMapWithUserPosition,
          initPosition: initPosition,
          areaLimit: areaLimit,
        );

  /// implement this method,should be end with super.dispose()
  @mustCallSuper
  @override
  void dispose() {
    if (_timer != null && _timer!.isActive) {
      _timer?.cancel();
    }
    removeObservers();
    super.dispose();
  }

  /// implement this method,should be start with super.init()
  @mustCallSuper
  @override
  void init() {
    _timer = Timer(Duration(milliseconds: 1250), () async {
      await osmBaseController.initPositionMap(
        initPosition: initPosition,
        userPositionOption: initMapWithUserPosition,
      );
      _timer?.cancel();
    });
  }
}

extension OSMControllerOfBaseMapController on BaseMapController {
  void setBaseOSMController(IBaseOSMController controller) {
    _osmBaseController = controller;
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';

///  class [BaseMapController] : base controller for osm flutter
///
///
/// [initMapWithUserPosition] : (bool) if is true, map will show your current location
///
/// [initPosition] : (GeoPoint) if it isn't null, the map will be pointed at this position
abstract class BaseMapController extends IBaseMapController {
  late IBaseOSMController _osmBaseController;
  final BoundingBox? areaLimit;

  late Timer? _timer;

  OSMMixinObserver? _mixinObserver;

  IBaseOSMController get osmBaseController => _osmBaseController;

  BaseMapController({
    initMapWithUserPosition = true,
    GeoPoint? initPosition,
    this.areaLimit = const BoundingBox.world(),
  })  : assert(initMapWithUserPosition || initPosition != null),
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
    removeObserver();
    super.dispose();
  }

  /// implement this method,should be start with super.init()
  @mustCallSuper
  @override
  void init() {
    _timer = Timer(Duration(milliseconds: 1250), () async {
      await osmBaseController.initMap(
        initPosition: initPosition,
        initWithUserPosition: initMapWithUserPosition,
      );
      _timer?.cancel();
    });
  }

  void addObserver(OSMMixinObserver osmMixinObserver) {
    _mixinObserver = osmMixinObserver;
  }
}

extension OSMControllerOfBaseMapController on BaseMapController {
  void setBaseOSMController(IBaseOSMController controller) {
    _osmBaseController = controller;
  }
}

extension PrivateBaseMapController on BaseMapController {
  OSMMixinObserver? get osMMixin => _mixinObserver;

  void removeObserver() {
    _mixinObserver = null;
  }
}

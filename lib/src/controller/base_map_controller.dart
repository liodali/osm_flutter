import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';

import '../../flutter_osm_plugin.dart';
import 'osm/osm_stub.dart'
    if (dart.library.io) 'osm/osm_controller.dart'
    if (dart.library.html) 'package:flutter_osm_web/flutter_osm_web.dart';

///  [BaseMapController] : base controller for osm flutter
///
///
/// [initMapWithUserPosition] : (bool) if is true, map will show your current location
///
/// [initPosition] : (GeoPoint) if it isn't null, the map will be pointed at this position
abstract class BaseMapController extends IBaseMapController {
  late IBaseOSMController _osmBaseController = getOSMMap();

  late ValueNotifier<GeoPoint?> listenerMapLongTapping = ValueNotifier(null);
  late ValueNotifier<GeoPoint?> listenerMapSingleTapping = ValueNotifier(null);

  BaseMapController({
    initMapWithUserPosition = true,
    GeoPoint? initPosition,
  })  : assert(initMapWithUserPosition || initPosition != null),
        super(
          initMapWithUserPosition: initMapWithUserPosition,
          initPosition: initPosition,
        );

  void dispose();
}

extension OSMControllerOfBaseMapController on BaseMapController {
  @protected
  IBaseOSMController get osmBaseController => _osmBaseController;

  void setBaseOSMController(IBaseOSMController controller) {
    _osmBaseController = controller;
  }
}

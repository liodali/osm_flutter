import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';


///  class [BaseMapController] : base controller for osm flutter
///
///
/// [initMapWithUserPosition] : (bool) if is true, map will show your current location
///
/// [initPosition] : (GeoPoint) if it isn't null, the map will be pointed at this position
abstract class BaseMapController extends IBaseMapController {
  late IBaseOSMController _osmBaseController ;
  IBaseOSMController get osmBaseController => _osmBaseController;

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

  void setBaseOSMController(IBaseOSMController controller) {
    _osmBaseController = controller;
  }
}

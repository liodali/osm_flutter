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

  IBaseOSMController get osmBaseController => _osmBaseController;
  final BoundingBox? areaLimit;


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

  void dispose(){
    super.dispose();
  }


}

extension OSMControllerOfBaseMapController on BaseMapController {
  void setBaseOSMController(IBaseOSMController controller) {
    _osmBaseController = controller;
  }
  void init() {
    Future.delayed(Duration(milliseconds: 1250), () async {
      await osmBaseController.initMap(
        initPosition: initPosition,
        initWithUserPosition: initMapWithUserPosition,
      );
    });
  }
}



import '../types/geo_point.dart';
import 'osm_controller.dart';

/// class [BaseMapController] : base map controller
abstract class BaseMapController {
  late OSMController osmController;
  final bool initMapWithUserPosition;
  final GeoPoint? initPosition;

  BaseMapController({
    this.initMapWithUserPosition = true,
    this.initPosition,
  }) : assert(initMapWithUserPosition || initPosition != null);

  void init(
    OSMController osmController,
  ) {
    this.osmController = osmController;
    Future.delayed(Duration(milliseconds: 1250), () async {
      await this.osmController.initMap(
        initPosition: initPosition,
        initWithUserPosition: initMapWithUserPosition,
      );
    });
  }
}

import '../types/geo_point.dart';
import 'osm_controller.dart';

/// class [BaseMapController] : base controller for osm flutter
///
///
/// [initMapWithUserPosition] : (bool) if is true, map will show your current location
///
/// [initPosition] : (GeoPoint) if it isn't null, the map will be pointed at this position
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

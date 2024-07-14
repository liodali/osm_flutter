import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

class SimpleMapController extends BaseMapController {
  final MarkerIcon markerHome;
  SimpleMapController({
    required GeoPoint super.initPosition,
    required this.markerHome,
  });
  @override
  void init() {
    super.init();
    Future.delayed(const Duration(seconds: 1), () async {
      await osmBaseController.addMarker(
        initPosition!,
        markerIcon: markerHome,
      );
      final limtArea = BoundingBox.fromCenter(initPosition!, 0.1);
      await osmBaseController.limitArea(
        limtArea,
      );
    });
  }
}

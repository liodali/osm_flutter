import 'package:flutter_osm_interface/flutter_osm_interface.dart';

class Region {
  final GeoPoint center;
  final BoundingBox boundingBox;

  Region({
    required this.center,
    required this.boundingBox,
  });
  Region.fromMap(Map map):
      this.center = GeoPoint.fromMap(map["center"]),
      this.boundingBox = BoundingBox.fromMap(map["bounding"]);
}

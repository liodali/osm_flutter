import 'package:flutter_osm_interface/flutter_osm_interface.dart';

class Region {
  final GeoPoint center;
  final BoundingBox boundingBox;

  Region({
    required this.center,
    required this.boundingBox,
  });
  Region.fromMap(Map map)
      : this.center = GeoPoint.fromMap(map["center"]),
        this.boundingBox = BoundingBox.fromMap(map["bounding"]);

  @override
  String toString() {
    return "region : ${boundingBox.toString()},center:$center";
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Region &&
          runtimeType == other.runtimeType &&
          center == other.center &&
          boundingBox == other.boundingBox;

  @override
  int get hashCode => center.hashCode ^ boundingBox.hashCode;
}

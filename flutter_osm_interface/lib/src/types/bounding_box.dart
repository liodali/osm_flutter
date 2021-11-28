import 'geo_point.dart';

class BoundingBox {
  final double north;
  final double east;
  final double south;
  final double west;

  const BoundingBox({
    required this.north,
    required this.east,
    required this.south,
    required this.west,
  })  : assert(north <= 85.0),
        assert(east <= 180.0),
        assert(south >= -85.0),
        assert(west > -180.0);

  const BoundingBox.world()
      : this.north = 85.0,
        this.east = 180.0,
        this.south = -85.0,
        this.west = -180.0;

   BoundingBox.fromMap(Map map):
      this.north = map["north"],
      this.east = map["east"],
      this.south = map["south"],
      this.west = map["west"];

}

extension ExtBoundingBox on BoundingBox {
  bool isWorld() {
    return north == 85.0 && east == 180.0 && south == -85.0 && west == -180.0;
  }

  bool inBoundingBox(GeoPoint point) {
    bool latMatch = false;
    bool lonMatch = false;
    if (north < south) {
      latMatch = true;
    } else {
      latMatch = (point.latitude < north) && (point.latitude > south);
    }
    if (east < west) {
      lonMatch = point.longitude <= east && point.longitude >= west;
    } else {
      lonMatch = point.longitude < east && point.longitude > west;
    }

    return lonMatch && latMatch;
  }
}

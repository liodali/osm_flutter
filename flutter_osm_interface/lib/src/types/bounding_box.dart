import 'dart:math';

import 'package:flutter/foundation.dart';

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
  })  : assert(north <= 86.0),
        assert(east <= 180.0),
        assert(south >= -86.0),
        assert(west >= -180.0);

  const BoundingBox.world()
      : north = 85.0,
        east = 180.0,
        south = -85.0,
        west = -180.0;

  static BoundingBox fromGeoPoints(List<GeoPoint> geoPoints) {
    if (geoPoints.isEmpty) {
      throw Exception("list of geopint shouldn't be empty");
    }
    double maxLat = -86.0;
    double maxLon = -180.0;
    double minLat = 86.0;
    double minLon = 180.0;
    for (final gp in geoPoints) {
      final lat = gp.latitude;
      final lng = gp.longitude;
      maxLat = max(maxLat, lat);
      maxLon = max(maxLon, lng);
      minLat = min(minLat, lat);
      minLon = min(minLon, lng);
    }
    return BoundingBox(
      north: maxLat,
      east: maxLon,
      south: minLat,
      west: minLon,
    );
  }

  static Future<BoundingBox> fromGeoPointsAsync(
      List<GeoPoint> geoPoints) async {
    return await compute(
      (List<GeoPoint> list) async => BoundingBox.fromGeoPoints(list),
      geoPoints,
    );
  }

  factory BoundingBox.fromCenter(GeoPoint center, double distanceKm) {
    // Earth's radius in kilometers
    const double R = 6371;

    // Convert latitude and longitude to radians
    double lat = center.latitude * pi / 180;
    double lon = center.longitude * pi / 180;

    // Angular distance in radians on a great circle
    double angularDistance = distanceKm / R;

    // Calculate min and max latitudes
    double minLat = lat - angularDistance;
    double maxLat = lat + angularDistance;

    // Calculate min and max longitudes
    double deltaLon = asin(sin(angularDistance) / cos(lat));
    double minLon = lon - deltaLon;
    double maxLon = lon + deltaLon;

    // Convert back to degrees
    minLat = minLat * 180 / pi;
    maxLat = maxLat * 180 / pi;
    minLon = minLon * 180 / pi;
    maxLon = maxLon * 180 / pi;

    return BoundingBox(
      north: maxLat,
      east: maxLon,
      south: minLat,
      west: minLon,
    );
  }

  BoundingBox.fromMap(Map map)
      : north = map["north"],
        east = map["east"],
        south = map["south"],
        west = map["west"];

  @override
  String toString() {
    return "north:$north,east:$east,south:$south,west:$west";
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoundingBox &&
          runtimeType == other.runtimeType &&
          north == other.north &&
          east == other.east &&
          south == other.south &&
          west == other.west;

  @override
  int get hashCode =>
      north.hashCode ^ east.hashCode ^ south.hashCode ^ west.hashCode;

  Map<String, double> toMap() {
    return {
      "north": north,
      "east": east,
      "west": west,
      "south": south,
    };
  }
}

extension ExtBoundingBox on BoundingBox {
  bool isWorld() {
    return north >= 85.0 && east == 180.0 && south <= -85.0 && west == -180.0;
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

  List<double> toIOSList() {
    return [south, west, north, east];
  }
}

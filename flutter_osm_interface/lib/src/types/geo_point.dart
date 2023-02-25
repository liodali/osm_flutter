import 'dart:math';

import 'package:flutter_osm_interface/src/common/utilities.dart';

///[GeoPoint]:class contain longitude and latitude of geographic position
/// [longitude] : (double)
/// [latitude] : (double)
class GeoPoint {
  final double longitude;
  final double latitude;

  GeoPoint({
    required this.latitude,
    required this.longitude,
  });

  GeoPoint.fromMap(Map m)
      : this.latitude = m["lat"],
        this.longitude = m["lon"];

  GeoPoint.fromString(String m)
      : this.latitude = double.parse(m.split(",").first),
        this.longitude = double.parse(m.split(",").last);

  Map<String, double> toMap() {
    return {
      "lon": longitude,
      "lat": latitude,
    };
  }

  /// [destinationPoint]
  ///
  /// this method will calculate  new [GeoPoint] using giving distance [distanceInMeters]
  /// using [bearingInDegrees] we will determine direction of that [GeoPoint]
  ///
  /// return [GeoPoint]
  GeoPoint destinationPoint(
      {required double distanceInMeters, required bearingInDegrees}) {
    // convert distance to angular distance
    final double dist = distanceInMeters / earthRadiusMeters;

    // convert bearing to radians
    final double brng = deg2rad * bearingInDegrees;

    // get current location in radians
    final double lat1 = deg2rad * latitude;
    final double lon1 = deg2rad * longitude;

    final double lat2 =
        asin(sin(lat1) * cos(dist) + cos(lat1) * sin(dist) * cos(brng));
    final double lon2 = lon1 +
        atan2(sin(brng) * sin(dist) * cos(lat1),
            cos(dist) - sin(lat1) * sin(lat2));

    final double lat2deg = lat2 / deg2rad;
    final double lon2deg = lon2 / deg2rad;

    return GeoPoint(
      latitude: lat2deg,
      longitude: lon2deg,
    );
  }

  @override
  String toString() {
    return 'GeoPoint{latitude: $latitude , longitude: $longitude}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPoint &&
          runtimeType == other.runtimeType &&
          longitude == other.longitude &&
          latitude == other.latitude;

  @override
  int get hashCode => longitude.hashCode ^ latitude.hashCode;
}

class GeoPointWithOrientation extends GeoPoint {
  final double angle;

  GeoPointWithOrientation({
    this.angle = 0.0,
    required double latitude,
    required double longitude,
  }) : super(
          latitude: latitude,
          longitude: longitude,
        );
  GeoPointWithOrientation.radian({
    double radianAngle = 0.0,
    required double latitude,
    required double longitude,
  })  : angle = radianAngle * (180 / pi),
        super(
          latitude: latitude,
          longitude: longitude,
        );

  Map<String, double> toMap() {
    return super.toMap()..putIfAbsent("angle", () => angle);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is GeoPointWithOrientation &&
          runtimeType == other.runtimeType &&
          angle == other.angle &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode =>
      super.hashCode ^ angle.hashCode ^ longitude.hashCode ^ latitude.hashCode;
}

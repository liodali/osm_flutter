import 'dart:math';

import 'package:flutter_osm_interface/src/common/utilities.dart';

typedef UserLocation = GeoPointWithOrientation;

///[GeoPoint]
///
/// illustrate geographique location thats contain longitude and latitude position
///
/// [GeoPoint] accept Map that has two keys with values which keys should be has names as lat,lon
///
/// [GeoPoint] accept String where in should be in format lat,lon example
///  ``` GeoPoint('8.42,12.435') ```
///
/// [longitude] : (double)
/// [latitude] : (double)
class GeoPoint {
  final double longitude;
  final double latitude;

  GeoPoint({
    required this.latitude,
    required this.longitude,
  });

  GeoPoint.fromMap(
    Map m,
  )   : latitude = double.parse(m["lat"].toString()),
        longitude = double.parse(m["lon"].toString());

  GeoPoint.fromString(
    String m,
  )   : latitude = double.parse(m.split(",").first),
        longitude = double.parse(m.split(",").last);

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
    double angle = 0.0,
    required double latitude,
    required double longitude,
  })  : this.angle = angle * pi / 180,
        super(
          latitude: latitude,
          longitude: longitude,
        );
  GeoPointWithOrientation.radian({
    double radianAngle = 0.0,
    required double latitude,
    required double longitude,
  })  : angle = radianAngle, // * (180 / pi),
        super(
          latitude: latitude,
          longitude: longitude,
        );
  GeoPointWithOrientation.fromMap(Map json)
      : angle = json.containsKey("heading")
            ? double.tryParse(json["heading"].toString()) ?? 0
            : 0,
        super(
          latitude: json["lat"],
          longitude: json["lon"],
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

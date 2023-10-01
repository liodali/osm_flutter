import 'dart:math';

import 'package:flutter_osm_interface/src/common/utilities.dart';

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
  late double _longitude;
  late double _latitude;

  GeoPoint({
    required double latitude,
    required double longitude,
  })  : _latitude = latitude,
        _longitude = longitude;

  GeoPoint.fromMap(
    Map m, {
    int precision = 7,
  }) {
    final latPrecision = m["lat"].toString().split('.').last.length < precision
        ? m["lat"].toString().split('.').last.length
        : precision;
    final lngPrecision = m["lon"].toString().split('.').last.length < precision
        ? m["lon"].toString().split('.').last.length
        : precision;
    _latitude = double.parse(
      double.parse(m["lat"].toString()).toStringAsPrecision(latPrecision),
    );
    _longitude = double.parse(
      double.parse(m["lon"].toString()).toStringAsPrecision(lngPrecision),
    );
  }

  GeoPoint.fromString(
    String m, {
    int precision = 7,
  }) {
    final mLat = m.split(",").first;
    final mLng = m.split(",").last;
    final latPrecision = mLat.split(".").last.length < precision
        ? mLat.split(".").last.length
        : precision;
    final lngPrecision = mLat.split(".").last.length < precision
        ? mLat.split(".").last.length
        : precision;
    _latitude = double.parse(
      double.parse(mLat).toStringAsPrecision(latPrecision),
    );
    _longitude = double.parse(
      double.parse(mLng).toStringAsPrecision(lngPrecision),
    );
  }
  double get latitude => _latitude;
  double get longitude => _longitude;
  Map<String, double> toMap() {
    return {
      "lon": _longitude,
      "lat": _latitude,
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

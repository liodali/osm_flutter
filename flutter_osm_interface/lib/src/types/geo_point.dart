import 'dart:math';

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

  Map<String, double> toMap() {
    return {
      "lon": longitude,
      "lat": latitude,
    };
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

  Map<String, double> toMap() {
    return super.toMap()
      ..putIfAbsent(
        "angle",
        () => angle * (180 / pi),
      );
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
  int get hashCode => super.hashCode ^ angle.hashCode ^ longitude.hashCode ^ latitude.hashCode;
}

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

  @override
  String toString() {
    return 'GeoPoint{latitude: $latitude , longitude: $longitude}';
  }
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
}

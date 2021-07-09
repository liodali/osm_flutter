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

  Map<String, double?> toMap() {
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

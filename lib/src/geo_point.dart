///[GeoPoint]:class contain longitude and latitude of geographic position
/// [longitude] : (double)
/// [latitude] : (double)
class GeoPoint {
  final double longitude;
  final double latitude;

  GeoPoint({
    this.latitude,
    this.longitude,
  });

  Map<String, double> toMap() {
    return {
      "lon": longitude,
      "lat": latitude,
    };
  }
}

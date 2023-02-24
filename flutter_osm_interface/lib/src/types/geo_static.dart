import 'geo_point.dart';

import 'marker.dart';

class StaticPositionGeoPoint {
  final String id;
  final MarkerIcon? markerIcon;
  final List<GeoPoint> geoPoints;

  StaticPositionGeoPoint(
    this.id,
    this.markerIcon,
    this.geoPoints,
  );
}

import 'package:flutter_osm_plugin/src/types/geo_point.dart';

import 'marker.dart';

class StaticPositionGeoPoint {
  final String id;
  final MarkerIcon? markerIcon;
  final List<GeoPoint>? geoPoints;

  StaticPositionGeoPoint(
    this.id,
    this.markerIcon,
    this.geoPoints,
  );
}

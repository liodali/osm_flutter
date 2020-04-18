import 'package:flutter_osm_plugin/src/geo_point.dart';
import 'package:flutter_osm_plugin/src/marker.dart';

class StaticPositionGeoPoint{
  final String id;
  final MarkerIcon markerIcon;
  final List<GeoPoint> geoPoints;

  StaticPositionGeoPoint(this.id,this.markerIcon,this.geoPoints);

}
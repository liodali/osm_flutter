import 'package:flutter_osm_plugin/src/geo_point.dart';
import 'package:flutter_osm_plugin/src/marker.dart';

class StaticPositionGeoPoint{

  final MarkerIcon markerIcon;
  final List<GeoPoint> geoPoints;

  StaticPositionGeoPoint(this.markerIcon,this.geoPoints);

}
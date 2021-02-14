import 'package:flutter/material.dart';

import '../../flutter_osm_plugin.dart';

/// CircleOSM : class that represent circle with be draw into map
/// [key] : (String) unique key should be given to each circle
/// [centerPoint] : (GeoPoint) center point of circle
/// [radius] : (double) rayon of circle should be in meter
/// [color] : (Color) color of the circle
/// [stokeWidth] : (double) width stoke of the circle
class CircleOSM {
  final String key;
  final GeoPoint centerPoint;
  final double radius;
  final Color color;
  final double stokeWidth;

  CircleOSM({
    @required this.key,
    @required this.centerPoint,
    @required this.radius,
    @required this.color,
    @required this.stokeWidth,
  });
}

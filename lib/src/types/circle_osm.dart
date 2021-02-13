import 'package:flutter/material.dart';

import '../../flutter_osm_plugin.dart';

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

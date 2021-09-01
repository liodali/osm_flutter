import 'package:flutter/material.dart';

import 'geo_point.dart';

/// ShapeOSM : class that represent shape with be draw into map
/// can be circle or rect
/// [key] : (String) unique key should be given to each shape
/// [centerPoint] : (GeoPoint) center point of shape
/// [color] : (Color) color of the shape
/// [strokeWidth] : (double) width stoke of the circle
abstract class ShapeOSM {
  final String key;
  final GeoPoint centerPoint;
  final Color color;
  final double strokeWidth;

  ShapeOSM({
    required this.key,
    required this.centerPoint,
    required this.color,
    required this.strokeWidth,
  });
}

/// RectOSM : class that represent circle with be draw into map
/// [distance] : (double) size of region, should be in meter
class RectOSM extends ShapeOSM {
  final double distance;

  RectOSM({
    required String key,
    required GeoPoint centerPoint,
    required this.distance,
    required Color color,
    required double strokeWidth,
  }) : super(
          color: color,
          centerPoint: centerPoint,
          key: key,
          strokeWidth: strokeWidth,
        );
}

/// CircleOSM : class that represent circle with be draw into map
/// [radius] : (double) rayon of circle should be in meter
class CircleOSM extends ShapeOSM {
  final double radius;

  CircleOSM({
    required String key,
    required GeoPoint centerPoint,
    required this.radius,
    required Color color,
    required double strokeWidth,
  }) : super(
          color: color,
          centerPoint: centerPoint,
          key: key,
          strokeWidth: strokeWidth,
        );
}

import 'package:flutter/material.dart';

import 'geo_point.dart';

/// ShapeOSM
/// this class that represent shape will be draw into  the map
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RectOSM &&
          runtimeType == other.runtimeType &&
          distance == other.distance &&
          centerPoint == other.centerPoint &&
          color.value == other.color.value &&
          strokeWidth == other.strokeWidth;

  @override
  int get hashCode =>
      distance.hashCode ^ strokeWidth.hashCode ^ color.hashCode ^ centerPoint.hashCode;
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CircleOSM &&
          runtimeType == other.runtimeType &&
          radius == other.radius &&
          centerPoint == other.centerPoint &&
          color.value == other.color.value &&
          strokeWidth == other.strokeWidth;

  @override
  int get hashCode =>
      radius.hashCode ^ strokeWidth.hashCode ^ color.hashCode ^ centerPoint.hashCode;
}

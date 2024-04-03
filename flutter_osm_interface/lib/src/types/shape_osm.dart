import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/src/common/utilities.dart';
import 'package:flutter_osm_interface/src/types/types.dart';

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
  final Color? borderColor;
  final double strokeWidth;

  ShapeOSM({
    required this.key,
    required this.centerPoint,
    required this.color,
    this.borderColor,
    required this.strokeWidth,
  });

  Map<String, dynamic> toMap() {
    final map = {
      "lon": centerPoint.longitude,
      "lat": centerPoint.latitude,
      "key": key,
      "strokeWidth": strokeWidth,
      "color": color.toARGBList(),
    };
    if (borderColor != null) {
      map.putIfAbsent("colorBorder", () => borderColor!.toARGBList());
    }
    return map;
  }
}

/// RectOSM : class that represent circle with be draw into map
/// [distance] : (double) size of region, should be in meter
class RectOSM extends ShapeOSM {
  final double distance;

  RectOSM({
    required super.key,
    required super.centerPoint,
    required this.distance,
    required super.color,
    super.borderColor,
    required super.strokeWidth,
  });

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.putIfAbsent("distance", () => distance);
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RectOSM &&
          runtimeType == other.runtimeType &&
          distance == other.distance &&
          centerPoint == other.centerPoint &&
          color.value == other.color.value &&
          borderColor?.value == other.borderColor?.value &&
          strokeWidth == other.strokeWidth;

  @override
  int get hashCode =>
      distance.hashCode ^
      strokeWidth.hashCode ^
      color.hashCode ^
      centerPoint.hashCode;
}

/// CircleOSM : class that represent circle with be draw into map
/// [radius] : (double) rayon of circle should be in meter
class CircleOSM extends ShapeOSM {
  final double radius;

  CircleOSM({
    required super.key,
    required super.centerPoint,
    required this.radius,
    required super.color,
    required super.strokeWidth,
    super.borderColor,
  });
  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.putIfAbsent("radius", () => radius);
    return map;
  }

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
      radius.hashCode ^
      strokeWidth.hashCode ^
      color.hashCode ^
      centerPoint.hashCode;
}

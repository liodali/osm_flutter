import 'package:flutter/material.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';

import 'geo_point.dart';
import 'marker.dart';

enum RoadType {
  car,
  foot,
  bike,
}

class Road {
  final Color roadColor;
  final MarkerIcon? startIcon;
  final MarkerIcon? endIcon;
  final MarkerIcon? middleIcon;

  Road({
    this.roadColor = Colors.blue,
    this.startIcon,
    this.middleIcon,
    this.endIcon,
  });
}

class RoadOption {
  final Color? roadColor;
  final int? roadWidth;
  final bool showMarkerOfPOI;

  RoadOption({
    this.roadColor,
    this.roadWidth,
    this.showMarkerOfPOI = false,
  });

  const RoadOption.empty()
      : this.roadWidth = null,
        this.roadColor = null,
        this.showMarkerOfPOI = false;
}

class RoadInfo {
  final double? distance;
  final double? duration;
  final List<GeoPoint> route;

  RoadInfo({
    this.distance,
    this.duration,
    this.route = const [],
  });

  RoadInfo.fromMap(Map map)
      : this.duration = map["duration"],
        this.distance = map["distance"],
        this.route = decodePolyline(
          map["routePoints"],
          accuracyExponent: 10,
        )
            .map((e) => GeoPoint(
                  latitude: e.first.toDouble(),
                  longitude: e.last.toDouble(),
                ))
            .toList();
}

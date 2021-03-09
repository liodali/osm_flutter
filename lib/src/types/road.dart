import 'package:flutter/material.dart';

import 'marker.dart';

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

class RoadInfo {
  final double? distance;
  final double? duration;

  RoadInfo({
    this.distance,
    this.duration,
  });

  RoadInfo.fromMap(Map map)
      : this.duration = map["duration"],
        this.distance = map["distance"];
}

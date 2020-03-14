import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/src/marker.dart';

class Road {
  final Color roadColor;
  final MarkerIcon startIcon;
  final MarkerIcon endIcon;
  final MarkerIcon middleIcon;

  Road({
    this.roadColor = Colors.blue,
    this.startIcon,
    this.middleIcon,
    this.endIcon,
  });
}

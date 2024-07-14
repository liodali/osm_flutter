import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

class OSMViewer extends StatelessWidget {
  final SimpleMapController controller;
  final ZoomOption zoomOption;
  const OSMViewer({
    super.key,
    required this.controller,
    this.zoomOption = const ZoomOption(),
  });

  @override
  Widget build(BuildContext context) {
    return OSMFlutter(
      controller: controller,
      osmOption: OSMOption(
        zoomOption: zoomOption,
      ),
    );
  }
}

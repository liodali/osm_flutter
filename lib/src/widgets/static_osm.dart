import 'package:flutter/widgets.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

class const OSMViewer({
  super.key,
  required this.controller,
  this.zoomOption = const ZoomOption(),
}) extends StatelessWidget {
  final SimpleMapController controller;
  final ZoomOption zoomOption;
  @override
  Widget build(BuildContext context) {
    return OSMFlutter(
      controller: controller,
      osmOption: OSMOption(zoomOption: zoomOption),
    );
  }
}

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:forui/forui.dart';

class SimpleOSM extends StatelessWidget {
  const SimpleOSM({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: const FHeader(title: Text('simple')),
      child: OSMViewer(
        controller: SimpleMapController(
          initPosition: GeoPoint(
            latitude: 47.4358055,
            longitude: 8.4737324,
          ),
          markerHome: const MarkerIcon(icon: Icon(Icons.home)),
        ),
        zoomOption: const ZoomOption(initZoom: 16, minZoomLevel: 11),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

class WebTestOsm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OSMFlutter(
      controller: MapController(
        initMapWithUserPosition: true,
        // initPosition: GeoPoint(
        //   latitude: 47.4358055,
        //   longitude: 8.4737324,
        // ),
      ),
      showContributorBadgeForOSM: true,
    );
  }
}

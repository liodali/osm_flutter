import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
//import 'package:flutter_osm_plugin/web_osm_plugin.dart';

class WebTestOsm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: OSMFlutter(
          controller: MapController(
            initMapWithUserPosition: true,
            // initPosition: GeoPoint(
            //   latitude: 47.4358055,
            //   longitude: 8.4737324,
            // ),
          ),
          mapIsLoading: Center(
            child: Text("map is Loading"),
          ),
          showContributorBadgeForOSM: true,
        ),
      ),
    );
  }
}

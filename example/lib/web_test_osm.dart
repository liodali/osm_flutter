import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
//import 'package:flutter_osm_plugin/web_osm_plugin.dart';

class WebTestOsm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: OSMWeb(),
      ),
    );
  }
}

class OSMWeb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OSMFlutter(
      controller: MapController(
        initMapWithUserPosition: false,
        initPosition: GeoPoint(
          latitude: 47.4358055,
          longitude: 8.4737324,
        ),
      ),
      onGeoPointClicked: (geoPoint) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            geoPoint.toString(),
          ),
          action: SnackBarAction(
            label: "hide",
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ));
      },
      mapIsLoading: Center(
        child: Text("map is Loading"),
      ),
      markerOption: MarkerOption(
        defaultMarker: MarkerIcon(
          icon: Icon(
            Icons.add_location,
            color: Colors.amber,
          ),
        ),
      ),
      staticPoints: [
        StaticPositionGeoPoint(
          "line 1",
          MarkerIcon(
            icon: Icon(
              Icons.train,
              color: Colors.green,
              size: 48,
            ),
          ),
          [
            GeoPoint(latitude: 47.4333594, longitude: 8.4680184),
            GeoPoint(latitude: 47.4317782, longitude: 8.4716146),
          ],
        )
      ],
      showContributorBadgeForOSM: true,
    );
  }
}

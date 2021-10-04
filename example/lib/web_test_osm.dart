import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
//import 'package:flutter_osm_plugin/web_osm_plugin.dart';

class WebTestOsm extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _WebTestOsmState();
}

class _WebTestOsmState extends State<WebTestOsm> {
  late final MapController controller = MapController(
    initMapWithUserPosition: false,
    initPosition: GeoPoint(
      latitude: 47.4358055,
      longitude: 8.4737324,
    ),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 2), () async {
      await controller.setZoom(zoomLevel: 8);
      await controller.changeLocation(
        GeoPoint(
          latitude: 47.433358,
          longitude: 8.4690184,
        ),
      );
      double zoom = await controller.getZoom();
      print("zoom:$zoom");
    });

  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text("osm web"),
          actions: [
            IconButton(
              onPressed: () async {
                await controller.currentLocation();
              },
              icon: Icon(Icons.location_history),
            ),
          ],
        ),
        body: OSMFlutter(
          controller: controller,
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
        ),
      ),
    );
  }
}

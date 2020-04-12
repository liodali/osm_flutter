import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GlobalKey<OSMFlutterState> osmKey;
  GlobalKey<ScaffoldState> scaffoldKey;
  
  @override
  void initState() {
    super.initState();
    osmKey = GlobalKey<OSMFlutterState>();
    scaffoldKey = GlobalKey<ScaffoldState>();
  }

  @override
  Widget build(BuildContext loncontext) {
    return MaterialApp(
      home: Scaffold(
        key: scaffoldKey,
        appBar: AppBar(
          title: const Text('OSM Plugin app'),
          actions: <Widget>[
            
            IconButton(
              onPressed: () async {
                try {
                  await osmKey.currentState.drawRoad(
                      GeoPoint(latitude: 47.35387, longitude: 8.43609),
                      GeoPoint(latitude: 47.4371, longitude: 8.6136));
                } on RoadException catch (e) {
                  scaffoldKey.currentState.showSnackBar(
                    SnackBar(
                      content: Text(
                        "${e.errorMessage()}",
                      ),
                    ),
                  );
                }
              },
              icon: Icon(Icons.map),
            ),
            IconButton(
              onPressed: () async {
                GeoPoint p = await osmKey.currentState.selectPosition();
                scaffoldKey.currentState.showSnackBar(
                  SnackBar(
                    content: Text(
                      "the picked position:lat ${p.latitude},lon ${p.longitude}",
                    ),
                  ),
                );
              },
              icon: Icon(Icons.search),
            ),
          ],
        ),
        body: Container(
          child: OSMFlutter(
            key: osmKey,
            currentLocation: false,
            onGeoPointClicked: (geoPoint) {
              scaffoldKey.currentState.showSnackBar(
                SnackBar(
                  content: Text(
                    "lat:${geoPoint.latitude},lon${geoPoint.longitude}",
                  ),
                  action: SnackBarAction(
                    onPressed: () =>
                        scaffoldKey.currentState.hideCurrentSnackBar(),
                    label: "hide",
                  ),
                ),
              );
            },
            staticPoints: StaticPositionGeoPoint(
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
                ]),
            road: Road(
                startIcon: MarkerIcon(
                  icon: Icon(
                    Icons.person,
                    size: 64,
                    color: Colors.brown,
                  ),
                ),
                roadColor: Colors.yellowAccent),
            markerIcon: MarkerIcon(
              icon: Icon(
                Icons.person_pin_circle,
                color: Colors.blue,
                size: 56,
              ),
            ),
            trackMyPosition: false,
            initPosition: GeoPoint(latitude: 47.4358055, longitude: 8.4737324),
            useSecureURL: false,
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await osmKey.currentState.currentLocation();
          },
          child: Icon(Icons.my_location),
        ),
      ),
    );
  }
}

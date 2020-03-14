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
                //get current position
                try {
                  GeoPoint p = await osmKey.currentState.myLocation();
                  scaffoldKey.currentState.showSnackBar(
                    SnackBar(
                      content: Text(
                        "lat:${p.latitude},lon:${p.longitude}",
                      ),
                    ),
                  );
                } on GeoPointException catch (e) {
                  scaffoldKey.currentState.showSnackBar(
                    SnackBar(
                      content: Text(
                        "${e.errorMessage()}",
                      ),
                    ),
                  );
                }
              },
              icon: Icon(
                Icons.location_on,
                color: Colors.white,
              ),
            ),
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
            initPosition: GeoPoint(latitude: 47.35387, longitude: 8.43609),
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

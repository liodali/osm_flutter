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
                GeoPoint p = await osmKey.currentState.myLocation();
                if (p.getErr() == null) {
                  scaffoldKey.currentState.showSnackBar(
                    SnackBar(
                      content: Text(
                        "lat:${p.latitude},lon:lat:${p.longitude}",
                      ),
                    ),
                  );
                } else {
                  scaffoldKey.currentState.showSnackBar(
                    SnackBar(
                      content: Text(
                        "${p.getErr()}",
                      ),
                    ),
                  );
                }
              },
              icon: Icon(
                Icons.location_on,
                color: Colors.white,
              ),
            )
          ],
        ),
        body: Container(
          child: OSMFlutter(
            key: osmKey,
            currentLocation: false,
            markerIcon: MarkerIcon(
              icon: Icon(
                Icons.person_pin_circle,
                color: Colors.blue,
                size: 56,
              ),
            ),
            initPosition: GeoPoint(latitude: 47.35387, longitude: 8.43609),
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

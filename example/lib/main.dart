import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GlobalKey<OSMFlutterState> osmKey;
  @override
  void initState() {
    super.initState();
    osmKey = GlobalKey<OSMFlutterState>();
  }

  @override
  Widget build(BuildContext loncontext) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('OSM Plugin app'),
        ),
        body: Container(
          child: OSMFlutter(
            key: osmKey,
            currentLocation: false,
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

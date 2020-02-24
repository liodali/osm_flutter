import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  
  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext loncontext) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Container(
          child: OSMFlutter(
            currentLocation: false,
            initPosition: GeoPoint(latitude: 47.35387,longitude: 8.43609),
          )
        ),
      ),
    );
  }

}
  

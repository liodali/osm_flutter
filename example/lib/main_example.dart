import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

class MainExample extends StatefulWidget {
  MainExample({Key key}) : super(key: key);

  @override
  _MainExampleState createState() => _MainExampleState();
}

class _MainExampleState extends State<MainExample> {
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
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: const Text('OSM Plugin app'),
        actions: <Widget>[
          IconButton(
            onPressed: () async {
              try {
                ///selection geoPoint
                GeoPoint point = await osmKey.currentState.selectPosition();
                GeoPoint point2 = await osmKey.currentState.selectPosition();
                await osmKey.currentState.drawRoad(point, point2);
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
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () async {
              await osmKey.currentState.setStaticPosition([
                GeoPoint(latitude: 47.434541, longitude: 8.467369),
                GeoPoint(latitude: 47.436207, longitude: 8.464072),
                GeoPoint(latitude: 47.437688, longitude: 8.460832),
              ], "static");
              scaffoldKey.currentState.showSnackBar(SnackBar(
                content: Text("static point changed"),
                duration: Duration(seconds: 10),
              ));
            },
          )
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
          staticPoints: [
            StaticPositionGeoPoint(
              "static",
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
            ),
          ],
          road: Road(
            startIcon: MarkerIcon(
              icon: Icon(
                Icons.person,
                size: 64,
                color: Colors.brown,
              ),
            ),
            roadColor: Colors.red,
          ),
          markerIcon: MarkerIcon(
            icon: Icon(
              Icons.home,
              color: Colors.orange,
              size: 64,
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
          await osmKey.currentState.enableTracking();
        },
        child: Icon(Icons.my_location),
      ),
    );
  }
}

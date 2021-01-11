import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MainExample(),
    );
  }
}

class MainExample extends StatefulWidget {
  MainExample({Key key}) : super(key: key);

  @override
  _MainExampleState createState() => _MainExampleState();
}

class _MainExampleState extends State<MainExample> {
  GlobalKey<OSMFlutterState> osmKey;
  GlobalKey<ScaffoldState> scaffoldKey;
  ValueNotifier<bool> zoomNotifierActivation = ValueNotifier(false);
  ValueNotifier<bool> trackingNotifier = ValueNotifier(false);

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
        title: const Text('OSM'),
        actions: <Widget>[
          IconButton(
            onPressed: () async {
              try {
                ///selection geoPoint
                GeoPoint point = await osmKey.currentState.selectPosition();
                GeoPoint point2 = await osmKey.currentState.selectPosition();
                RoadInfo roadInformation =
                    await osmKey.currentState.drawRoad(point, point2);
                print(
                    "duration:${Duration(seconds: roadInformation.duration.toInt()).inMinutes}");
                print("distance:${roadInformation.distance}Km");
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
              zoomNotifierActivation.value = !zoomNotifierActivation.value;
            },
            icon: Icon(Icons.zoom_out_map),
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
        child: Stack(
          children: [
            OSMFlutter(
              key: osmKey,
              currentLocation: false,
              defaultZoom: 3.0,
              onLocationChanged: (myLocation){
                print(myLocation);
              },
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
                ),
                StaticPositionGeoPoint(
                  "line 2",
                  MarkerIcon(
                    icon: Icon(
                      Icons.train,
                      color: Colors.red,
                      size: 48,
                    ),
                  ),
                  [
                    GeoPoint(latitude: 47.4433594, longitude: 8.4680184),
                    GeoPoint(latitude: 47.4517782, longitude: 8.4716146),
                  ],
                )
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
              initPosition:
                  GeoPoint(latitude: 47.4358055, longitude: 8.4737324),
              useSecureURL: false,
            ),
            Positioned(
              bottom: 10,
              left: 10,
              child: ValueListenableBuilder<bool>(
                valueListenable: zoomNotifierActivation,
                builder: (ctx, visible, child) {
                  return AnimatedOpacity(
                    opacity: visible ? 1.0 : 0.0,
                    duration: Duration(milliseconds: 500),
                    child: child,
                  );
                },
                child: Column(
                  children: [
                    RaisedButton(
                      child: Icon(Icons.add),
                      onPressed: () async {
                        osmKey.currentState.zoomIn();
                      },
                      elevation: 0,
                    ),
                    RaisedButton(
                      child: Icon(Icons.remove),
                      elevation: 0,
                      onPressed: () async {
                        osmKey.currentState.zoomOut();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if(!trackingNotifier.value){
            await osmKey.currentState.currentLocation();
            await osmKey.currentState.enableTracking();
          }else{
            await osmKey.currentState.disabledTracking();
          }
          trackingNotifier.value=!trackingNotifier.value;
        },
        child: ValueListenableBuilder<bool>(
          valueListenable: trackingNotifier,
          builder: (ctx,isTracking,_){
            if(isTracking){
              return Icon(Icons.gps_off_sharp);
            }
            return Icon(Icons.my_location);
          },
        ),
      ),
    );
  }
}

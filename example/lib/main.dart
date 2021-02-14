import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MainExample(),
      routes: {
        "/home": (ctx) => MainExample(),
        "/second": (ctx) => Scaffold(
              body: Center(
                child: RaisedButton(
                  onPressed: () {
                    Navigator.popAndPushNamed(ctx, "/home");
                  },
                  child: Text("another page"),
                ),
              ),
            ),
      },
    );
  }
}

class MainExample extends StatefulWidget {
  MainExample({Key key}) : super(key: key);

  @override
  _MainExampleState createState() => _MainExampleState();
}

class _MainExampleState extends State<MainExample> {
  MapController controller;
  GlobalKey<ScaffoldState> scaffoldKey;
  ValueNotifier<bool> zoomNotifierActivation = ValueNotifier(false);
  ValueNotifier<bool> trackingNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    controller = MapController(
      initMapWithUserPosition: false,
      initPosition: GeoPoint(latitude: 47.4358055, longitude: 8.4737324),
    );
    scaffoldKey = GlobalKey<ScaffoldState>();
    Future.delayed(Duration(seconds: 10), () async {
      await controller.drawCircle(CircleOSM(
        key: "circle0",
        centerPoint: GeoPoint(latitude: 47.4333594, longitude: 8.4680184),
        radius: 1200.0,
        color: Colors.red,
        stokeWidth: 0.3,
      ));
    });
    Future.delayed(Duration(seconds: 20), () async {
      await controller.removeCircle("circle0");
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: const Text('OSM'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.info),
            onPressed: () async {
              await Navigator.popAndPushNamed(context, "/second");
            },
          ),
          IconButton(
            onPressed: () async {
              try {
                await controller.removeLastRoad();

                ///selection geoPoint
                GeoPoint point = await controller.selectPosition();
                GeoPoint point2 = await controller.selectPosition();
                RoadInfo roadInformation =
                    await controller.drawRoad(point, point2);
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
              GeoPoint p = await controller.selectPosition();
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
              await controller.setStaticPosition([
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
      body: OrientationBuilder(
        builder: (ctx, orientation) {
          return Container(
            child: Stack(
              children: [
                OSMFlutter(
                  controller: controller,
                  //trackMyPosition: trackingNotifier.value,
                  useSecureURL: false,
                  showDefaultInfoWindow: false,
                  defaultZoom: 3.0,

                  onLocationChanged: (myLocation) {
                    print(myLocation);
                  },
                  onGeoPointClicked: (geoPoint) async {
                    scaffoldKey.currentState.showSnackBar(
                      SnackBar(
                        content: Text(
                          "${geoPoint.toMap().toString()}",
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
                            controller.zoomIn();
                          },
                          elevation: 0,
                        ),
                        RaisedButton(
                          child: Icon(Icons.remove),
                          elevation: 0,
                          onPressed: () async {
                            controller.zoomOut();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (!trackingNotifier.value) {
            await controller.currentLocation();
            await controller.enableTracking();
          } else {
            await controller.disabledTracking();
          }
          trackingNotifier.value = !trackingNotifier.value;
        },
        child: ValueListenableBuilder<bool>(
          valueListenable: trackingNotifier,
          builder: (ctx, isTracking, _) {
            if (isTracking) {
              return Icon(Icons.gps_off_sharp);
            }
            return Icon(Icons.my_location);
          },
        ),
      ),
    );
  }
}

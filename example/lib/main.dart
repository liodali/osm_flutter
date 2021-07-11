import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin_example/search_example.dart';

import 'utilities.dart';

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
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.popAndPushNamed(ctx, "/home");
                  },
                  child: Text("another page"),
                ),
              ),
            ),
        "/picker-result": (ctx) => LocationAppExample(),
        "/search": (ctx) => SearchPage(),
      },
    );
  }
}

class MainExample extends StatefulWidget {
  MainExample({Key? key}) : super(key: key);

  @override
  _MainExampleState createState() => _MainExampleState();
}

class _MainExampleState extends State<MainExample> {
  late MapController controller;
  late GlobalKey<ScaffoldState> scaffoldKey;
  ValueNotifier<bool> zoomNotifierActivation = ValueNotifier(false);
  ValueNotifier<bool> visibilityZoomNotifierActivation = ValueNotifier(false);
  ValueNotifier<bool> advPickerNotifierActivation = ValueNotifier(false);
  ValueNotifier<bool> trackingNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    controller = MapController(
      initMapWithUserPosition: false,
      initPosition: GeoPoint(latitude: 47.4358055, longitude: 8.4737324),
    );
    scaffoldKey = GlobalKey<ScaffoldState>();
    controller.listenerMapLongTapping.addListener(() {
      if (controller.listenerMapLongTapping.value != null) {
        print(controller.listenerMapLongTapping.value);
      }
    });
    controller.listenerMapSingleTapping.addListener(() {
      if (controller.listenerMapSingleTapping.value != null) {
        print(controller.listenerMapSingleTapping.value);
      }
    });

    Future.delayed(Duration(seconds: 5), () async {
      await controller.zoomIn();
    });
    Future.delayed(Duration(seconds: 15), () async {
      await controller
          .changeLocation(GeoPoint(latitude: 47.433358, longitude: 8.4690184));
    });

    Future.delayed(Duration(seconds: 10), () async {
      final waysPoint = list
          .map((e) => GeoPoint(
                latitude: e.last,
                longitude: e.first,
              ))
          .toList();
      await controller.drawRoadManually(
        waysPoint,
        Colors.purpleAccent,
        6.0,
      );
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
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('OSM'),
        leading: ValueListenableBuilder<bool>(
          valueListenable: advPickerNotifierActivation,
          builder: (ctx, isAdvancedPicker, _) {
            if (isAdvancedPicker) {
              return IconButton(
                onPressed: () {
                  advPickerNotifierActivation.value = false;
                  controller.cancelAdvancedPositionPicker();
                },
                icon: Icon(Icons.close),
              );
            }
            return SizedBox.shrink();
          },
        ),
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
                GeoPoint point = await controller.selectPosition(
                    icon: MarkerIcon(
                  icon: Icon(
                    Icons.location_history,
                    color: Colors.amber,
                    size: 48,
                  ),
                ));

                // GeoPoint pointM1 = await controller.selectPosition();
                // GeoPoint pointM2 = await controller.selectPosition(
                //     imageURL:
                //         "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/back/1.png");
                //
                GeoPoint point2 = await controller.selectPosition();
                RoadInfo roadInformation = await controller.drawRoad(
                    point, point2,
                    //interestPoints: [pointM1, pointM2],
                    roadOption: RoadOption(
                        roadWidth: 10,
                        roadColor: Colors.blue,
                        showMarkerOfPOI: false));
                print(
                    "duration:${Duration(seconds: roadInformation.duration!.toInt()).inMinutes}");
                print("distance:${roadInformation.distance}Km");
              } on RoadException catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
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
              visibilityZoomNotifierActivation.value =
                  !visibilityZoomNotifierActivation.value;
              zoomNotifierActivation.value = !zoomNotifierActivation.value;
            },
            icon: Icon(Icons.zoom_out_map),
          ),
          IconButton(
            onPressed: () async {
              await Navigator.pushNamed(context, "/picker-result");
            },
            icon: Icon(Icons.search),
          ),
          IconButton(
            icon: Icon(Icons.select_all),
            onPressed: () async {
              if (advPickerNotifierActivation.value == false) {
                advPickerNotifierActivation.value = true;
                await controller.advancedPositionPicker();
              }
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
                  showContributorBadgeForOSM: true,
                  //trackMyPosition: trackingNotifier.value,
                  showDefaultInfoWindow: false,
                  defaultZoom: 3.0,
                  onLocationChanged: (myLocation) {
                    print(myLocation);
                  },
                  onGeoPointClicked: (geoPoint) async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "${geoPoint.toMap().toString()}",
                        ),
                        action: SnackBarAction(
                          onPressed: () => ScaffoldMessenger.of(context)
                              .hideCurrentSnackBar(),
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
                  markerOption: MarkerOption(
                    defaultMarker: MarkerIcon(
                      icon: Icon(
                        Icons.home,
                        color: Colors.orange,
                        size: 64,
                      ),
                    ),
                    advancedPickerMarker: MarkerIcon(
                      icon: Icon(
                        Icons.location_searching,
                        color: Colors.green,
                        size: 64,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: advPickerNotifierActivation,
                    builder: (ctx, visible, child) {
                      return Visibility(
                        visible: visible,
                        child: AnimatedOpacity(
                          opacity: visible ? 1.0 : 0.0,
                          duration: Duration(milliseconds: 500),
                          child: child,
                        ),
                      );
                    },
                    child: FloatingActionButton(
                      key: UniqueKey(),
                      child: Icon(Icons.arrow_forward),
                      heroTag: "confirmAdvPicker",
                      onPressed: () async {
                        advPickerNotifierActivation.value = false;
                        GeoPoint p =
                            await controller.selectAdvancedPositionPicker();
                        print(p);
                      },
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: visibilityZoomNotifierActivation,
                    builder: (ctx, visibility, child) {
                      return Visibility(
                        visible: visibility,
                        child: child!,
                      );
                    },
                    child: ValueListenableBuilder<bool>(
                      valueListenable: zoomNotifierActivation,
                      builder: (ctx, isVisible, child) {
                        return AnimatedOpacity(
                          opacity: isVisible ? 1.0 : 0.0,
                          onEnd: () {
                            visibilityZoomNotifierActivation.value = isVisible;
                          },
                          duration: Duration(milliseconds: 500),
                          child: child,
                        );
                      },
                      child: Column(
                        children: [
                          ElevatedButton(
                            child: Icon(Icons.add),
                            onPressed: () async {
                              controller.zoomIn();
                            },
                          ),
                          ElevatedButton(
                            child: Icon(Icons.remove),
                            onPressed: () async {
                              controller.zoomOut();
                            },
                          ),
                        ],
                      ),
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
            //await controller.zoom(5.0);
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

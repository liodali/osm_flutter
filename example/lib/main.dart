import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin_example/search_example.dart';

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
    Future.delayed(Duration(seconds: 10), () async {
      final list = [
        [47.43571, 8.47362],
        [47.4358, 8.47347],
        [47.43579, 8.47328],
        [47.43573, 8.47324],
        [47.43555, 8.47293],
        [47.43548, 8.47282],
        [47.43536, 8.4726],
        [47.43531, 8.47251],
        [47.43525, 8.47241],
        [47.43518, 8.47228],
        [47.43499, 8.4719],
        [47.43486, 8.47162],
        [47.43481, 8.4715],
        [47.43474, 8.4713],
        [47.43467, 8.47111],
        [47.43475, 8.47105],
        [47.4351, 8.47055],
        [47.43531, 8.47026],
        [47.43599, 8.46931],
        [47.43632, 8.46876],
        [47.4364, 8.46859],
        [47.43647, 8.46844],
        [47.43652, 8.46832],
        [47.43678, 8.46785],
        [47.43739, 8.46663],
        [47.43769, 8.466],
        [47.43798, 8.46544],
        [47.43806, 8.46528],
        [47.43808, 8.46524],
        [47.43819, 8.46501],
        [47.43845, 8.4645],
        [47.43852, 8.46434],
        [47.43876, 8.46389],
        [47.43896, 8.46348],
        [47.43899, 8.46342],
        [47.43906, 8.46328],
        [47.43917, 8.46307],
        [47.43925, 8.46298],
        [47.43935, 8.4629],
        [47.43952, 8.46276],
        [47.4396, 8.46286],
        [47.43969, 8.46294],
        [47.43981, 8.463],
        [47.44018, 8.46318],
        [47.44065, 8.46346],
        [47.44099, 8.46366],
        [47.44124, 8.46382],
        [47.44139, 8.46392],
        [47.44154, 8.46405],
        [47.44172, 8.46422],
        [47.44199, 8.46453],
        [47.44214, 8.46473],
        [47.44222, 8.46484],
        [47.4422, 8.46488],
        [47.44219, 8.46492],
        [47.44219, 8.46497],
        [47.4422, 8.465],
        [47.44221, 8.46501],
        [47.44223, 8.46504],
        [47.44225, 8.46506],
        [47.44228, 8.46507],
        [47.44232, 8.46507],
        [47.44236, 8.46506],
        [47.44239, 8.46504],
        [47.44248, 8.46513],
        [47.44265, 8.46528],
        [47.44282, 8.46543],
        [47.44312, 8.46567],
        [47.44318, 8.46572],
        [47.44327, 8.46579],
        [47.44334, 8.46585],
        [47.44337, 8.46588],
        [47.44342, 8.46593],
        [47.44359, 8.46608],
        [47.44374, 8.46624],
        [47.4438, 8.46629],
        [47.44397, 8.46652],
        [47.44417, 8.4668],
        [47.44424, 8.46684],
        [47.44423, 8.46712],
        [47.44423, 8.46722],
        [47.44424, 8.46739],
        [47.44425, 8.46756],
        [47.44427, 8.46771],
        [47.4443, 8.46796],
        [47.44436, 8.4685],
        [47.4444, 8.46881],
        [47.44441, 8.46904],
        [47.4444, 8.46921],
        [47.44436, 8.46939],
        [47.44432, 8.46949],
        [47.44426, 8.46959],
        [47.44379, 8.47012],
        [47.44334, 8.4706],
        [47.44327, 8.47069],
        [47.44319, 8.47081],
        [47.44299, 8.47117]
      ];
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

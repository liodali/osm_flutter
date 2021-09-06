import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin_example/search_example.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: "/home",
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
  late MapController controller = MapController(
    initMapWithUserPosition: false,
    initPosition: GeoPoint(
      latitude: 47.4358055,
      longitude: 8.4737324,
    ),
    // areaLimit: BoundingBox(
    //   east: 10.4922941,
    //   north: 47.8084648,
    //   south: 45.817995,
    //   west: 5.9559113,
    // ),
  );
  late GlobalKey<ScaffoldState> scaffoldKey;
  ValueNotifier<bool> zoomNotifierActivation = ValueNotifier(false);
  ValueNotifier<bool> visibilityZoomNotifierActivation = ValueNotifier(false);
  ValueNotifier<bool> advPickerNotifierActivation = ValueNotifier(false);
  ValueNotifier<bool> trackingNotifier = ValueNotifier(false);
  ValueNotifier<bool> showFab = ValueNotifier(true);
  late ValueNotifier<double> extentHeight;
  late double maxHeight, minHeight;
  double minAlpha = 0.20;
  double maxAlpha = 0.55;
  late double diffAlpha = maxAlpha - minAlpha;
  ScrollController? scrollController;

  @override
  void initState() {
    super.initState();
    scaffoldKey = GlobalKey<ScaffoldState>();
    controller.listenerMapLongTapping.addListener(() async {
      if (controller.listenerMapLongTapping.value != null) {
        print(controller.listenerMapLongTapping.value);
        await controller.addMarker(controller.listenerMapLongTapping.value!,
            markerIcon: MarkerIcon(
              icon: Icon(
                Icons.store,
                color: Colors.brown,
                size: 48,
              ),
            ));
      }
    });
    controller.listenerMapSingleTapping.addListener(() {
      if (controller.listenerMapSingleTapping.value != null) {
        print(controller.listenerMapSingleTapping.value);
      }
    });

    controller.listenerMapIsReady.addListener(mapIsInitialized);
  }

  void mapIsInitialized() async {
    if (controller.listenerMapIsReady.value) {
      // Future.delayed(Duration(seconds: 5), () async {
      //   await controller.zoomIn();
      // });
      Future.delayed(Duration(seconds: 10), () async {
        await controller.setZoom(zoomLevel: 12);
        await controller.setMarkerOfStaticPoint(
          id: "line 2",
          markerIcon: MarkerIcon(
            icon: Icon(
              Icons.train,
              color: Colors.orange,
              size: 48,
            ),
          ),
        );
        await controller.setStaticPosition(
          [
            GeoPointWithOrientation(
              latitude: 47.4433594,
              longitude: 8.4680184,
              angle: pi / 4,
            ),
            GeoPointWithOrientation(
              latitude: 47.4517782,
              longitude: 8.4716146,
              angle: pi / 2,
            ),
          ],
          "line 2",
        );
      });
    }
  }

  @override
  void dispose() {
    controller.listenerMapIsReady.removeListener(mapIsInitialized);
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    maxHeight = MediaQuery.of(context).size.height * maxAlpha;
    minHeight = MediaQuery.of(context).size.height * minAlpha;
    extentHeight = ValueNotifier(maxHeight);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      resizeToAvoidBottomInset: false,
      /*appBar: AppBar(
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
          Builder(builder: (ctx) {
            return IconButton(
              onPressed: () => roadActionBt(ctx),
              icon: Icon(Icons.map),
            );
          }),
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
      ),*/
      body: NotificationListener<DraggableScrollableNotification>(
        onNotification: (notification) {
          extentHeight.value = notification.extent;
          return true;
        },
        child: Stack(
          children: [
            OSMFlutter(
              controller: controller,
              mapIsLoading: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    Text("Map is Loading..")
                  ],
                ),
              ),
              initZoom: 8,
              minZoomLevel: 8,
              maxZoomLevel: 14,
              stepZoom: 1.0,
              userLocationMarker: UserLocationMaker(
                personMarker: MarkerIcon(
                  icon: Icon(
                    Icons.location_history_rounded,
                    color: Colors.red,
                    size: 48,
                  ),
                ),
                directionArrowMarker: MarkerIcon(
                  icon: Icon(
                    Icons.double_arrow,
                    size: 48,
                  ),
                ),
              ),
              showContributorBadgeForOSM: true,
              //trackMyPosition: trackingNotifier.value,
              showDefaultInfoWindow: false,
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
                      onPressed: () =>
                          ScaffoldMessenger.of(context).hideCurrentSnackBar(),
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
            ValueListenableBuilder<double>(
              valueListenable: extentHeight,
              builder: (ctx, extent, child) {
                final scrollSheet = ((extent - minAlpha) / diffAlpha);
                return Positioned(
                  top: 32,
                  left: 12,
                  child: AnimatedContainer(
                    height: extent > minAlpha ? scrollSheet * 40 : 0,
                    width: extent > minAlpha ? scrollSheet * 40 : 0,
                    duration: Duration(
                      milliseconds: 250,
                    ),
                    child: FloatingActionButton(
                      onPressed: () {},
                      backgroundColor: Colors.white,
                      mini: true,
                      elevation: 0,
                      child: Icon(
                        Icons.settings,
                        color: Colors.black,
                        size: scrollSheet * 24,
                      ),
                    ),
                  ),
                );
              },
            ),
            ValueListenableBuilder<double>(
              valueListenable: extentHeight,
              builder: (ctx, extent, child) {
                return Visibility(
                  visible: extent > minAlpha ? false : true,
                  child: child!,
                );
              },
              child: Positioned(
                top: 32,
                right: 12,
                child: FloatingActionButton(
                  onPressed: () {},
                  backgroundColor: Colors.white,
                  mini: true,
                  elevation: 1.0,
                  child: Icon(
                    Icons.my_location,
                    color: Colors.black,
                    size: 24,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: minHeight + 24,
              right: 12,
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
              bottom: minHeight + 16,
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
            DraggableScrollableSheet(
              initialChildSize: 0.50,
              maxChildSize: maxAlpha,
              minChildSize: minAlpha,
              expand: true,
              builder: (ctx, controller) {
                if (scrollController == null) {
                  scrollController = controller;
                }
                return ScrollConfiguration(
                  behavior: ScrollBehavior().copyWith(
                    overscroll: false,
                    scrollbars: false,
                  ),
                  child: SingleChildScrollView(
                    controller: controller,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: minHeight,
                        maxHeight: maxHeight,
                      ),
                      child: LayoutBuilder(
                        builder: (ctx, constraint) {
                          final opacitySearch =
                              ((extentHeight.value - minAlpha) / diffAlpha);
                          print(opacitySearch);
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Positioned(
                                top: 32,
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  color: Colors.blue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(32.0),
                                      topRight: Radius.circular(32.0),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                left: 48,
                                right: 48,
                                child: Visibility(
                                  visible: opacitySearch == 0 ? false : true,
                                  child: Opacity(
                                    opacity: opacitySearch > 1.0
                                        ? 1.0
                                        : opacitySearch,
                                    child: Card(
                                      child: TextField(
                                        decoration: InputDecoration(
                                          focusedBorder: OutlineInputBorder(),
                                          enabledBorder: OutlineInputBorder(),
                                          border: OutlineInputBorder(),
                                          hintText: "search",
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      /*floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: showFab,
        builder: (ctx, isShow, child) {
          if (!isShow) {
            return SizedBox.shrink();
          }
          return child!;
        },
        child: FloatingActionButton(
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
      ),*/
    );
  }

  void roadActionBt(BuildContext ctx) async {
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
      GeoPoint point2 = await controller.selectPosition();
      showFab.value = false;
      ValueNotifier<RoadType> notifierRoadType = ValueNotifier(RoadType.car);
      final bottomPersistant = showBottomSheet(
        context: ctx,
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        builder: (ctx) {
          return Container(
            height: 96,
            child: WillPopScope(
              onWillPop: () async => false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 64,
                  width: 196,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  alignment: Alignment.center,
                  margin: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          notifierRoadType.value = RoadType.car;
                          Navigator.pop(ctx, RoadType.car);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.directions_car),
                            Text("Car"),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          notifierRoadType.value = RoadType.bike;
                          Navigator.pop(ctx, RoadType.bike);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.directions_bike),
                            Text("Bike"),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          notifierRoadType.value = RoadType.foot;
                          Navigator.pop(ctx, RoadType.foot);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.directions_walk),
                            Text("Foot"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

      await bottomPersistant.closed.whenComplete(() {
        showFab.value = true;
      }).then((roadType) async {
        RoadInfo roadInformation = await controller.drawRoad(
          point, point2,
          roadType: notifierRoadType.value,
          //interestPoints: [pointM1, pointM2],
          roadOption: RoadOption(
            roadWidth: 10,
            roadColor: Colors.blue,
            showMarkerOfPOI: false,
          ),
        );
        print(
            "duration:${Duration(seconds: roadInformation.duration!.toInt()).inMinutes}");
        print("distance:${roadInformation.distance}Km");
      });
    } on RoadException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${e.errorMessage()}",
          ),
        ),
      );
    }
  }
}

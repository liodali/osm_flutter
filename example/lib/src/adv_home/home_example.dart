import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

import 'map_navigation_sheet.dart';
import 'map_search_sheet.dart';

class AdvandedMainExample extends StatefulWidget {
  AdvandedMainExample({Key? key}) : super(key: key);

  @override
  _AdvancedMainExampleState createState() => _AdvancedMainExampleState();
}

class _AdvancedMainExampleState extends State<AdvandedMainExample> {
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
  ValueNotifier<double> maxAlphaNotifier = ValueNotifier(0.65);
  late ValueNotifier<double> diffAlphaNotifier =
      ValueNotifier(maxAlphaNotifier.value - minAlpha);

  var sheetIndexNotifier = ValueNotifier(0);

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
  void didUpdateWidget(covariant AdvandedMainExample oldWidget) {
    if (oldWidget != widget) {
      controller = MapController(
        initMapWithUserPosition: false,
        initPosition: GeoPoint(
          latitude: 47.4358055,
          longitude: 8.4737324,
        ),
      );
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
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    //controller.listenerMapIsReady.removeListener(mapIsInitialized);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    maxHeight = MediaQuery.of(context).size.height * maxAlphaNotifier.value;
    minHeight = MediaQuery.of(context).size.height * minAlpha;
    extentHeight = ValueNotifier(maxAlphaNotifier.value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      resizeToAvoidBottomInset: false,
      body: NotificationListener<DraggableScrollableNotification>(
        onNotification: (notification) {
          extentHeight.value = notification.extent;
          return true;
        },
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).size.height * (minAlpha) - 96,
              child: OSMFlutter(
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
            ),
            ValueListenableBuilder<int>(
              valueListenable: sheetIndexNotifier,
              builder: (ctx, index, child) {
                if (index == 1) {
                  return child!;
                }
                return SizedBox.shrink();
              },
              child: Positioned(
                top: 32,
                left: 12,
                child: AnimatedContainer(
                  height: sheetIndexNotifier.value == 1 ? 48 : 0,
                  width: sheetIndexNotifier.value == 1 ? 48 : 0,
                  duration: Duration(
                    milliseconds: 250,
                  ),
                  child: FloatingActionButton(
                    onPressed: () {
                      maxAlphaNotifier.value = 0.65;
                      sheetIndexNotifier.value = 0;
                      DraggableScrollableActuator.reset(
                        context,
                      );
                    },
                    backgroundColor: Colors.white,
                    mini: true,
                    elevation: 0,
                    child: Icon(
                      Icons.arrow_back_ios,
                      color: Colors.black,
                      size: 24,
                    ),
                  ),
                ),
              ),
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
            ValueListenableBuilder<double>(
              valueListenable: extentHeight,
              builder: (ctx, extent, child) {
                final scrollSheet =
                    ((extent - minAlpha) / diffAlphaNotifier.value);
                return Positioned(
                  top: 32,
                  left: 12,
                  child: AnimatedContainer(
                    height: extent > minAlpha && sheetIndexNotifier.value == 0
                        ? scrollSheet * 40
                        : 0,
                    width: extent > minAlpha && sheetIndexNotifier.value == 0
                        ? scrollSheet * 40
                        : 0,
                    duration: Duration(
                      milliseconds: 250,
                    ),
                    child: FloatingActionButton(
                      onPressed: () {
                        Navigator.popAndPushNamed(context, "/second");
                      },
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
            DraggableScrollableActuator(
              child: DraggableScrollableSheet(
                initialChildSize: maxAlphaNotifier.value == 0.90 ? 0.85 : 0.55,
                maxChildSize: maxAlphaNotifier.value,
                minChildSize: minAlpha,
                expand: true,
                builder: (draggableContext, sheetController) {
                  return ScrollConfiguration(
                    behavior: CustomScroll(),
                    child: SingleChildScrollView(
                      controller: sheetController,
                      physics: AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: minHeight,
                          maxHeight: maxHeight,
                        ),
                        child: LayoutBuilder(
                          builder: (layoutContext, constraint) {
                            diffAlphaNotifier.value =
                                maxAlphaNotifier.value - minAlpha;
                            final opacitySearch =
                                ((extentHeight.value - minAlpha) /
                                    diffAlphaNotifier.value);
                            return ValueListenableBuilder<int>(
                              valueListenable: sheetIndexNotifier,
                              builder: (ctx, index, _) {
                                return IndexedStack(
                                  index: index,
                                  children: [
                                    MapNavigationSheet(
                                      controller: controller,
                                      opacitySearch: opacitySearch,
                                      activeSearchModeCallback: () {
                                        maxAlphaNotifier.value = 0.90;
                                        sheetIndexNotifier.value = 1;
                                        DraggableScrollableActuator.reset(
                                          context,
                                        );
                                      },
                                    ),
                                    MapSearchSheet(
                                      controller: controller,
                                      opacitySearch: opacitySearch,
                                    )
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
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

class CustomScroll extends ScrollBehavior {
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

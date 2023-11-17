import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class OldMainExample extends StatefulWidget {
  OldMainExample({Key? key}) : super(key: key);

  @override
  _MainExampleState createState() => _MainExampleState();
}

class _MainExampleState extends State<OldMainExample>
    with OSMMixinObserver, TickerProviderStateMixin {
  late MapController controller;
  late GlobalKey<ScaffoldState> scaffoldKey;
  Key mapGlobalkey = UniqueKey();
  ValueNotifier<bool> zoomNotifierActivation = ValueNotifier(false);
  ValueNotifier<bool> visibilityZoomNotifierActivation = ValueNotifier(false);
  ValueNotifier<bool> advPickerNotifierActivation = ValueNotifier(false);
  ValueNotifier<bool> visibilityOSMLayers = ValueNotifier(false);
  ValueNotifier<double> positionOSMLayers = ValueNotifier(-200);
  ValueNotifier<GeoPoint?> centerMap = ValueNotifier(null);
  ValueNotifier<bool> trackingNotifier = ValueNotifier(false);
  ValueNotifier<bool> showFab = ValueNotifier(true);
  ValueNotifier<GeoPoint?> lastGeoPoint = ValueNotifier(null);
  ValueNotifier<bool> beginDrawRoad = ValueNotifier(false);
  List<GeoPoint> pointsRoad = [];
  Timer? timer;
  int x = 0;
  late AnimationController animationController;
  late Animation<double> animation =
      Tween<double>(begin: 0, end: 2 * pi).animate(animationController);
  final ValueNotifier<int> mapRotate = ValueNotifier(0);
  @override
  void initState() {
    super.initState();
    // controller = MapController.withUserPosition(
    //     trackUserLocation: UserTrackingOption(
    //   enableTracking: true,
    //   unFollowUser: false,
    // )
    controller = MapController.withPosition(
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
    //  controller = MapController.cyclOSMLayer(
    //   initMapWithUserPosition: false,
    //   initPosition: GeoPoint(
    //     latitude: 47.4358055,
    //     longitude: 8.4737324,
    //   ),
    //   // areaLimit: BoundingBox(
    //   //   east: 10.4922941,
    //   //   north: 47.8084648,
    //   //   south: 45.817995,
    //   //   west: 5.9559113,
    //   // ),
    // );
    //  controller = MapController.publicTransportationLayer(
    //   initMapWithUserPosition: false,
    //   initPosition: GeoPoint(
    //     latitude: 47.4358055,
    //     longitude: 8.4737324,
    //   ),
    // );

    /*  controller = MapController.customLayer(
      initMapWithUserPosition: false,
      initPosition: GeoPoint(
        latitude: 47.4358055,
        longitude: 8.4737324,
      ),
      customTile: CustomTile(
        sourceName: "outdoors",
        tileExtension: ".png",
        minZoomLevel: 2,
        maxZoomLevel: 19,
        urlsServers: [
          TileURLs(
            url: "https://tile.thunderforest.com/outdoors/",
          )
        ],
        tileSize: 256,
        keyApi: MapEntry(
          "apikey",
          dotenv.env['api']!,
        ),
      ),
    ); */

    /* controller = MapController.customLayer(
      initMapWithUserPosition: false,
      initPosition: GeoPoint(
        latitude: 47.4358055,
        longitude: 8.4737324,
      ),
      customTile: CustomTile(
        sourceName: "opentopomap",
        tileExtension: ".png",
        minZoomLevel: 2,
        maxZoomLevel: 19,
        urlsServers: [
          "https://a.tile.opentopomap.org/",
          "https://b.tile.opentopomap.org/",
          "https://c.tile.opentopomap.org/",
        ],
        tileSize: 256,
      ),
    );*/
    controller.addObserver(this);
    scaffoldKey = GlobalKey<ScaffoldState>();
    controller.listenerMapLongTapping.addListener(() async {
      if (controller.listenerMapLongTapping.value != null) {
        print(controller.listenerMapLongTapping.value);
        final randNum = Random.secure().nextInt(100).toString();
        print(randNum);
        await controller
            .changeLocation(controller.listenerMapLongTapping.value!);
        /* await controller.addMarker(
          controller.listenerMapLongTapping.value!,
          markerIcon: MarkerIcon(
            iconWidget: SizedBox.fromSize(
              size: Size.square(32),
              child: Stack(
                children: [
                  Icon(
                    Icons.store,
                    color: Colors.brown,
                    size: 32,
                  ),
                  Text(
                    randNum,
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
          //angle: pi / 3,
        );*/
      }
    });
    controller.listenerMapSingleTapping.addListener(() async {
      if (controller.listenerMapSingleTapping.value != null) {
        print(controller.listenerMapSingleTapping.value);
        if (beginDrawRoad.value) {
          pointsRoad.add(controller.listenerMapSingleTapping.value!);
          await controller.addMarker(
            controller.listenerMapSingleTapping.value!,
            markerIcon: MarkerIcon(
              icon: Icon(
                Icons.person_pin_circle,
                color: Colors.amber,
                size: 48,
              ),
            ),
          );
          if (pointsRoad.length >= 2 && showFab.value) {
            roadActionBt(context);
          }
        } else if (lastGeoPoint.value != null) {
          await controller.changeLocationMarker(
            oldLocation: lastGeoPoint.value!,
            newLocation: controller.listenerMapSingleTapping.value!,
            //angle: Random.secure().nextDouble() * (2 * pi),
            // iconAnchor: IconAnchor(
            //   anchor: Anchor.center,
            //   offset: (
            //     x: 32,
            //     y: 16,
            //   ),
            // ),
          );
          lastGeoPoint.value = controller.listenerMapSingleTapping.value;
        } else {
          await controller.addMarker(
            controller.listenerMapSingleTapping.value!,
            markerIcon: MarkerIcon(
              icon: Icon(
                Icons.person_pin,
                color: Colors.red,
                size: 48,
              ),
              // assetMarker: AssetMarker(
              //   image: AssetImage("asset/pin.png"),
              // ),
              // assetMarker: AssetMarker(
              //   image: AssetImage("asset/pin.png"),
              //   //scaleAssetImage: 2,
              // ),
            ),
            iconAnchor: IconAnchor(
              anchor: Anchor.top,
              //offset: (x: 32.5, y: -32),
            ),
            //angle: -pi / 4,
          );
          lastGeoPoint.value = controller.listenerMapSingleTapping.value;
        }
      }
    });
    controller.listenerRegionIsChanging.addListener(() async {
      if (controller.listenerRegionIsChanging.value != null) {
        print(controller.listenerRegionIsChanging.value);
        centerMap.value = controller.listenerRegionIsChanging.value!.center;
      }
    });
    animationController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 500,
      ),
    );
    //controller.listenerMapIsReady.addListener(mapIsInitialized);
  }

  Future<void> mapIsInitialized() async {
    await controller.setZoom(zoomLevel: 12);
    // await controller.setMarkerOfStaticPoint(
    //   id: "line 1",
    //   markerIcon: MarkerIcon(
    //     icon: Icon(
    //       Icons.train,
    //       color: Colors.red,
    //       size: 48,
    //     ),
    //   ),
    // );
    await controller.setMarkerOfStaticPoint(
      id: "line 2",
      markerIcon: MarkerIcon(
        icon: Icon(
          Icons.train,
          color: Colors.orange,
          size: 36,
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
    final bounds = await controller.bounds;
    print(bounds.toString());
    // Future.delayed(Duration(seconds: 5), () {
    //   controller.changeTileLayer(tileLayer: CustomTile.cycleOSM());
    // });
  }

  @override
  Future<void> mapIsReady(bool isReady) async {
    if (isReady) {
      await mapIsInitialized();
    }
  }

  @override
  void onRoadTap(RoadInfo road) {
    super.onRoadTap(road);
    debugPrint("road:" + road.toString());
    Future.microtask(() => controller.removeRoad(roadKey: road.key));
  }

  @override
  void dispose() {
    if (timer != null && timer!.isActive) {
      timer?.cancel();
    }
    //controller.listenerMapIsReady.removeListener(mapIsInitialized);
    animationController.dispose();
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
            return IconButton(
              onPressed: () async {
                 Navigator.pop(context);//, '/home');
              },
              icon: Icon(Icons.arrow_back),
            );
          },
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.layers),
            onPressed: () async {
              if (visibilityOSMLayers.value) {
                positionOSMLayers.value = -200;
                await Future.delayed(Duration(milliseconds: 700));
              }
              visibilityOSMLayers.value = !visibilityOSMLayers.value;
              showFab.value = !visibilityOSMLayers.value;
              Future.delayed(Duration(milliseconds: 500), () {
                positionOSMLayers.value = visibilityOSMLayers.value ? 32 : -200;
              });
            },
          ),
          Builder(builder: (ctx) {
            return GestureDetector(
              onLongPress: () => drawMultiRoads(),
              onDoubleTap: () async {
                await controller.clearAllRoads();
              },
              child: IconButton(
                onPressed: () {
                  beginDrawRoad.value = true;
                },
                icon: Icon(Icons.route),
              ),
            );
          }),
          IconButton(
            onPressed: () async {
              await drawRoadManually();
            },
            icon: Icon(Icons.alt_route),
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
          ),
        ],
      ),
      body: Container(
        child: Stack(
          children: [
            OSMFlutter(
              controller: controller,
              osmOption: OSMOption(
                enableRotationByGesture: true,
                zoomOption: ZoomOption(
                  initZoom: 8,
                  minZoomLevel: 3,
                  maxZoomLevel: 19,
                  stepZoom: 1.0,
                ),
                userLocationMarker: UserLocationMaker(
                    personMarker: MarkerIcon(
                      // icon: Icon(
                      //   Icons.car_crash_sharp,
                      //   color: Colors.red,
                      //   size: 48,
                      // ),
                      // iconWidget: SizedBox.square(
                      //   dimension: 56,
                      //   child: Image.asset(
                      //     "asset/taxi.png",
                      //     scale: .3,
                      //   ),
                      // ),
                      iconWidget: SizedBox(
                        width: 32,
                        height: 64,
                        child: Image.asset(
                          "asset/directionIcon.png",
                          scale: .3,
                        ),
                      ),
                      // assetMarker: AssetMarker(
                      //   image: AssetImage(
                      //     "asset/taxi.png",
                      //   ),
                      //   scaleAssetImage: 0.3,
                      // ),
                    ),
                    directionArrowMarker: MarkerIcon(
                      // icon: Icon(
                      //   Icons.navigation_rounded,
                      //   size: 48,
                      // ),
                      iconWidget: SizedBox(
                        width: 32,
                        height: 64,
                        child: Image.asset(
                          "asset/directionIcon.png",
                          scale: .3,
                        ),
                      ),
                    )
                    // directionArrowMarker: MarkerIcon(
                    //   assetMarker: AssetMarker(
                    //     image: AssetImage(
                    //       "asset/taxi.png",
                    //     ),
                    //     scaleAssetImage: 0.25,
                    //   ),
                    // ),
                    ),
                staticPoints: [
                  StaticPositionGeoPoint(
                    "line 1",
                    MarkerIcon(
                      icon: Icon(
                        Icons.train,
                        color: Colors.green,
                        size: 32,
                      ),
                    ),
                    [
                      GeoPoint(
                        latitude: 47.4333594,
                        longitude: 8.4680184,
                      ),
                      GeoPoint(
                        latitude: 47.4317782,
                        longitude: 8.4716146,
                      ),
                    ],
                  ),
                  /*StaticPositionGeoPoint(
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
                    )*/
                ],
                roadConfiguration: RoadOption(
                  roadColor: Colors.blueAccent,
                ),
                markerOption: MarkerOption(
                  defaultMarker: MarkerIcon(
                    icon: Icon(
                      Icons.home,
                      color: Colors.orange,
                      size: 32,
                    ),
                  ),
                  advancedPickerMarker: MarkerIcon(
                    icon: Icon(
                      Icons.location_searching,
                      color: Colors.green,
                      size: 56,
                    ),
                  ),
                ),
                showContributorBadgeForOSM: true,
                //trackMyPosition: trackingNotifier.value,
                showDefaultInfoWindow: false,
              ),
              mapIsLoading: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    Text("Map is Loading.."),
                  ],
                ),
              ),
              onMapIsReady: (isReady) {
                if (isReady) {
                  print("map is ready");
                }
              },
              onLocationChanged: (myLocation) {
                print('user location :$myLocation');
              },
              onGeoPointClicked: (geoPoint) async {
                if (geoPoint ==
                    GeoPoint(
                      latitude: 47.442475,
                      longitude: 8.4680389,
                    )) {
                  final newGeoPoint = GeoPoint(
                    latitude: 47.4517782,
                    longitude: 8.4716146,
                  );
                  await controller.changeLocationMarker(
                    oldLocation: geoPoint,
                    newLocation: newGeoPoint,
                    markerIcon: MarkerIcon(
                      icon: Icon(
                        Icons.bus_alert,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                  );
                }
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
                      SizedBox(
                        height: 16,
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
            ValueListenableBuilder<bool>(
              valueListenable: visibilityOSMLayers,
              builder: (ctx, isVisible, child) {
                if (!isVisible) {
                  return SizedBox.shrink();
                }
                return child!;
              },
              child: ValueListenableBuilder<double>(
                valueListenable: positionOSMLayers,
                builder: (ctx, position, child) {
                  return AnimatedPositioned(
                    bottom: position,
                    left: 24,
                    right: 24,
                    duration: Duration(milliseconds: 500),
                    child: OSMLayersChoiceWidget(
                      centerPoint: centerMap.value!,
                      setLayerCallback: (tile) async {
                        await controller.changeTileLayer(tileLayer: tile);
                      },
                    ),
                  );
                },
              ),
            ),
            if (!kIsWeb) ...[
              Positioned(
                top: 5,
                right: 12,
                child: FloatingActionButton(
                  key: UniqueKey(),
                  heroTag: "rotateCamera",
                  onPressed: () async {
                    animationController.forward().then((value) {
                      animationController.reset();
                    });
                    mapRotate.value = 0;
                    await controller
                        .rotateMapCamera(mapRotate.value.toDouble());
                  },
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: animation.value,
                        child: child!,
                      );
                    },
                    child: Icon(Icons.screen_rotation_alt_outlined),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: showFab,
        builder: (ctx, isShow, child) {
          if (!isShow) {
            return SizedBox.shrink();
          }
          return child!;
        },
        child: PointerInterceptor(
          child: FloatingActionButton(
            key: UniqueKey(),
            heroTag: "locationUser",
            onPressed: () async {
              if (!trackingNotifier.value) {
                await controller.currentLocation();
                await controller.enableTracking(
                  enableStopFollow: true,
                  disableUserMarkerRotation: false,
                  anchor: Anchor.left,
                );
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
        ),
      ),
    );
  }

  void roadActionBt(BuildContext ctx) async {
    try {
      ///selection geoPoint

      showFab.value = false;
      ValueNotifier<RoadType> notifierRoadType = ValueNotifier(RoadType.car);

      final bottomPersistant = scaffoldKey.currentState!.showBottomSheet(
        (ctx) {
          return PointerInterceptor(
            child: RoadTypeChoiceWidget(
              setValueCallback: (roadType) {
                notifierRoadType.value = roadType;
              },
            ),
          );
        },
        backgroundColor: Colors.transparent,
        elevation: 0.0,
      );
      await bottomPersistant.closed.then((roadType) async {
        showFab.value = true;
        beginDrawRoad.value = false;
        RoadInfo roadInformation = await controller.drawRoad(
          pointsRoad.first,
          pointsRoad.last,
          roadType: notifierRoadType.value,
          intersectPoint:
              pointsRoad.getRange(1, pointsRoad.length - 1).toList(),
          roadOption: RoadOption(
            roadWidth: 10,
            roadColor: Colors.blue,
            zoomInto: true,
            // roadBorderWidth: 4,
            // roadBorderColor: Colors.black,
          ),
        );
        pointsRoad.clear();
        debugPrint(
            "app duration:${Duration(seconds: roadInformation.duration!.toInt()).inMinutes}");
        debugPrint("app distance:${roadInformation.distance}Km");
        debugPrint("app road:" + roadInformation.toString());
        final console = roadInformation.instructions
            .map((e) => e.toString())
            .reduce(
              (value, element) => "$value -> \n $element",
            )
            .toString();
        debugPrint(
          console,
          wrapWidth: console.length,
        );
        // final box = await BoundingBox.fromGeoPointsAsync([point2, point]);
        // controller.zoomToBoundingBox(
        //   box,
        //   paddinInPixel: 64,
        // );
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

  @override
  Future<void> mapRestored() async {
    super.mapRestored();
    print("log map restored");
  }

  void drawMultiRoads() async {
    /*
      8.4638911095,47.4834379430|8.5046595453,47.4046149269
      8.5244329867,47.4814981476|8.4129691189,47.3982152237
      8.4371175094,47.4519015578|8.5147623089,47.4321999727
     */

    final configs = [
      MultiRoadConfiguration(
        startPoint: GeoPoint(
          latitude: 47.4834379430,
          longitude: 8.4638911095,
        ),
        destinationPoint: GeoPoint(
          latitude: 47.4046149269,
          longitude: 8.5046595453,
        ),
      ),
      MultiRoadConfiguration(
          startPoint: GeoPoint(
            latitude: 47.4814981476,
            longitude: 8.5244329867,
          ),
          destinationPoint: GeoPoint(
            latitude: 47.3982152237,
            longitude: 8.4129691189,
          ),
          roadOptionConfiguration: MultiRoadOption(
            roadColor: Colors.orange,
          )),
      MultiRoadConfiguration(
        startPoint: GeoPoint(
          latitude: 47.4519015578,
          longitude: 8.4371175094,
        ),
        destinationPoint: GeoPoint(
          latitude: 47.4321999727,
          longitude: 8.5147623089,
        ),
      ),
    ];
    final listRoadInfo = await controller.drawMultipleRoad(
      configs,
      commonRoadOption: MultiRoadOption(
        roadColor: Colors.red,
      ),
    );
    print(listRoadInfo);
  }

  Future<void> drawRoadManually() async {
    final encoded =
        "mfp_I__vpAqJ`@wUrCa\\dCgGig@{DwWq@cf@lG{m@bDiQrCkGqImHu@cY`CcP@sDb@e@hD_LjKkRt@InHpCD`F";
    final list = await encoded.toListGeo();
    await controller.drawRoadManually(
      list,
      RoadOption(
        zoomInto: true,
        roadColor: Colors.blueAccent,
      ),
    );
  }
}

class RoadTypeChoiceWidget extends StatelessWidget {
  final Function(RoadType road) setValueCallback;

  RoadTypeChoiceWidget({
    required this.setValueCallback,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      child: PopScope(
        canPop: false,
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
                    setValueCallback(RoadType.car);
                    Navigator.pop(context, RoadType.car);
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
                    setValueCallback(RoadType.bike);
                    Navigator.pop(context);
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
                    setValueCallback(RoadType.foot);
                    Navigator.pop(context);
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
  }
}

class OSMLayersChoiceWidget extends StatelessWidget {
  final Function(CustomTile? layer) setLayerCallback;
  final GeoPoint centerPoint;
  OSMLayersChoiceWidget({
    required this.setLayerCallback,
    required this.centerPoint,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 102,
          width: 342,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.0),
          ),
          alignment: Alignment.center,
          margin: const EdgeInsets.only(top: 8),
          child: PointerInterceptor(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setLayerCallback(CustomTile.publicTransportationOSM());
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 64,
                        child: Image.asset(
                          'asset/transport.png',
                          fit: BoxFit.fill,
                        ),
                      ),
                      Text("Transportation"),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setLayerCallback(CustomTile.cycleOSM());
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 64,
                        child: Image.asset(
                          'asset/cycling.png',
                          fit: BoxFit.fill,
                        ),
                      ),
                      Text("CycleOSM"),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setLayerCallback(null);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 64,
                        child: Image.asset(
                          'asset/earth.png',
                          fit: BoxFit.fill,
                        ),
                      ),
                      Text("OSM"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

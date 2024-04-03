import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class MainPageExample extends StatelessWidget {
  const MainPageExample({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Main(),
      drawer: PointerInterceptor(
        child: DrawerMain(),
      ),
    );
  }
}

class Main extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _MainState();
}

class _MainState extends State<Main> with OSMMixinObserver {
  late MapController controller;
  ValueNotifier<bool> trackingNotifier = ValueNotifier(false);
  ValueNotifier<bool> showFab = ValueNotifier(false);
  ValueNotifier<bool> disableMapControlUserTracking = ValueNotifier(true);
  ValueNotifier<IconData> userLocationIcon = ValueNotifier(Icons.near_me);
  ValueNotifier<GeoPoint?> lastGeoPoint = ValueNotifier(null);
  ValueNotifier<GeoPoint?> userLocationNotifier = ValueNotifier(null);
  final mapKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    controller = MapController(
      initPosition: GeoPoint(
        latitude: 47.4358055,
        longitude: 8.4737324,
      ),
      // initMapWithUserPosition: UserTrackingOption(
      //   enableTracking: trackingNotifier.value,
      // ),
      useExternalTracking: disableMapControlUserTracking.value,
    );
    controller.addObserver(this);
    trackingNotifier.addListener(() async {
      if (userLocationNotifier.value != null && !trackingNotifier.value) {
        await controller.removeMarker(userLocationNotifier.value!);
        userLocationNotifier.value = null;
      }
    });
  }

  @override
  Future<void> mapIsReady(bool isReady) async {
    if (isReady) {
      showFab.value = true;
    }
  }

  @override
  void onSingleTap(GeoPoint position) {
    super.onSingleTap(position);
    Future.microtask(() async {
      if (lastGeoPoint.value != null) {
        await controller.changeLocationMarker(
          oldLocation: lastGeoPoint.value!,
          newLocation: position,
          //iconAnchor: IconAnchor(anchor: Anchor.top),
        );
      } else {
        await controller.addMarker(
          position,
          markerIcon: MarkerIcon(
            icon: Icon(
              Icons.person_pin,
              color: Colors.red,
              size: 32,
            ),
          ),
          // iconAnchor: IconAnchor(
          //   anchor: Anchor.left,
          //   //offset: (x: 32.5, y: -32),
          // ),
          //angle: -pi / 4,
        );
      }
      await controller.moveTo(position, animate: true);
      lastGeoPoint.value = position;
    });
  }

  @override
  void onRegionChanged(Region region) {
    super.onRegionChanged(region);
    if (trackingNotifier.value) {
      final userLocation = userLocationNotifier.value;
      if (userLocation == null ||
          !region.center.isEqual(
            userLocation,
            precision: 1e4,
          )) {
        userLocationIcon.value = Icons.gps_not_fixed;
      } else {
        userLocationIcon.value = Icons.gps_fixed;
      }
    }
  }

  @override
  void onLocationChanged(UserLocation userLocation) async {
    super.onLocationChanged(userLocation);
    if (disableMapControlUserTracking.value && trackingNotifier.value) {
      await controller.moveTo(userLocation);
      if (userLocationNotifier.value == null) {
        await controller.addMarker(
          userLocation,
          markerIcon: MarkerIcon(
            icon: Icon(Icons.navigation),
          ),
          angle: userLocation.angle,
        );
      } else {
        await controller.changeLocationMarker(
          oldLocation: userLocationNotifier.value!,
          newLocation: userLocation,
          angle: userLocation.angle,
        );
      }
      userLocationNotifier.value = userLocation;
    } else {
      if (userLocationNotifier.value != null && !trackingNotifier.value) {
        await controller.removeMarker(userLocationNotifier.value!);
        userLocationNotifier.value = null;
      }
    }
  }

  @override
  void onRoadTap(RoadInfo road) {
    super.onRoadTap(road);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.maybeOf(context)?.viewPadding.top;
    return Stack(
      children: [
        Map(
          controller: controller,
        ),
        if (!kReleaseMode || kIsWeb) ...[
          Positioned(
            bottom: 23.0,
            left: 15,
            child: ZoomNavigation(
              controller: controller,
            ),
          )
        ],
        Positioned.fill(
          child: ValueListenableBuilder(
            valueListenable: showFab,
            builder: (context, isVisible, child) {
              if (!isVisible) {
                return SizedBox.shrink();
              }
              return Stack(
                children: [
                  if (!kIsWeb) ...[
                    Positioned(
                      top: (topPadding ?? 26) + 48,
                      right: 15,
                      child: MapRotation(
                        controller: controller,
                      ),
                    )
                  ],
                  Positioned(
                    top: kIsWeb ? 26 : topPadding ?? 26.0,
                    left: 12,
                    child: PointerInterceptor(
                      child: MainNavigation(),
                    ),
                  ),
                  Positioned(
                    bottom: 32,
                    right: 15,
                    child: ActivationUserLocation(
                      controller: controller,
                      trackingNotifier: trackingNotifier,
                      userLocation: userLocationNotifier,
                      userLocationIcon: userLocationIcon,
                    ),
                  ),
                  Positioned(
                    bottom: 92,
                    right: 15,
                    child: DirectionRouteLocation(
                      controller: controller,
                    ),
                  ),
                  Positioned(
                    top: kIsWeb ? 26 : topPadding,
                    left: 64,
                    right: 72,
                    child: SearchInMap(
                      controller: controller,
                    ),
                  ),
                ],
              );
            },
          ),
        )
      ],
    );
  }
}

class ZoomNavigation extends StatelessWidget {
  const ZoomNavigation({
    super.key,
    required this.controller,
  });
  final MapController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PointerInterceptor(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              maximumSize: Size(48, 48),
              minimumSize: Size(24, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
            child: Center(
              child: Icon(Icons.add),
            ),
            onPressed: () async {
              controller.zoomIn();
            },
          ),
        ),
        SizedBox(
          height: 16,
        ),
        PointerInterceptor(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              maximumSize: Size(48, 48),
              minimumSize: Size(24, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
            child: Center(
              child: Icon(Icons.remove),
            ),
            onPressed: () async {
              controller.zoomOut();
            },
          ),
        ),
      ],
    );
  }
}

class MapRotation extends HookWidget {
  const MapRotation({
    super.key,
    required this.controller,
  });
  final MapController controller;
  @override
  Widget build(BuildContext context) {
    final angle = useValueNotifier(0.0);
    return FloatingActionButton(
      key: UniqueKey(),
      onPressed: () async {
        angle.value += 30;
        if (angle.value > 360) {
          angle.value = 0;
        }
        await controller.rotateMapCamera(angle.value);
      },
      heroTag: "RotationMapFab",
      elevation: 1,
      mini: true,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ValueListenableBuilder(
          valueListenable: angle,
          builder: (ctx, angle, child) {
            return AnimatedRotation(
              turns: angle == 0 ? 0 : 360 / angle,
              duration: Duration(milliseconds: 250),
              child: child!,
            );
          },
          child: Image.asset("asset/compass.png"),
        ),
      ),
      backgroundColor: Colors.white,
    );
  }
}

class MainNavigation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      key: UniqueKey(),
      onPressed: () {
        Scaffold.of(context).openDrawer();
      },
      heroTag: "MainMenuFab",
      mini: true,
      child: Icon(Icons.menu),
      backgroundColor: Colors.white,
    );
  }
}

class DrawerMain extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (_) {
        Scaffold.of(context).closeDrawer();
      },
      child: Drawer(
        child: Column(
          children: [
            SizedBox(height: MediaQuery.viewPaddingOf(context).top),
            ListTile(
              onTap: () {},
              title: Text("search example"),
            ),
            ListTile(
              onTap: () {},
              title: Text("map with hook example"),
            ),
            ListTile(
              onTap: () async {
                Scaffold.of(context).closeDrawer();
                await Navigator.pushNamed(context, '/old-home');
              },
              title: Text("old home example"),
            )
          ],
        ),
      ),
    );
  }
}

class Map extends StatelessWidget {
  const Map({
    super.key,
    required this.controller,
  });
  final MapController controller;
  @override
  Widget build(BuildContext context) {
    return OSMFlutter(
      controller: controller,
      mapIsLoading: Center(
        child: CircularProgressIndicator(),
      ),
      onLocationChanged: (location) {
        debugPrint(location.toString());
      },
      osmOption: OSMOption(
        enableRotationByGesture: true,
        zoomOption: ZoomOption(
          initZoom: 16,
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
              icon: Icon(
                Icons.navigation_rounded,
                size: 48,
              ),
              // iconWidget: SizedBox(
              //   width: 32,
              //   height: 64,
              //   child: Image.asset(
              //     "asset/directionIcon.png",
              //     scale: .3,
              //   ),
              // ),
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
          /*
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
          */
        ],
        roadConfiguration: RoadOption(
          roadColor: Colors.blueAccent,
        ),
        showContributorBadgeForOSM: true,
        //trackMyPosition: trackingNotifier.value,
        showDefaultInfoWindow: false,
      ),
    );
  }
}

class SearchLocation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextField();
  }
}

class ActivationUserLocation extends StatelessWidget {
  final ValueNotifier<bool> trackingNotifier;
  final MapController controller;
  final ValueNotifier<IconData> userLocationIcon;
  final ValueNotifier<GeoPoint?> userLocation;

  const ActivationUserLocation({
    super.key,
    required this.trackingNotifier,
    required this.controller,
    required this.userLocationIcon,
    required this.userLocation,
  });
  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onLongPress: () async {
          //await controller.disabledTracking();
          await controller.stopLocationUpdating();
          trackingNotifier.value = false;
        },
        child: FloatingActionButton(
          key: UniqueKey(),
          onPressed: () async {
            if (!trackingNotifier.value) {
              /*await controller.currentLocation();
              await controller.enableTracking(
                enableStopFollow: true,
                disableUserMarkerRotation: false,
                anchor: Anchor.right,
                useDirectionMarker: true,
              );*/
              await controller.startLocationUpdating();
              trackingNotifier.value = true;

              //await controller.zoom(5.0);
            } else {
              if (userLocation.value != null) {
                await controller.moveTo(userLocation.value!);
              }

              /*await controller.enableTracking(
                  enableStopFollow: false,
                  disableUserMarkerRotation: true,
                  anchor: Anchor.center,
                  useDirectionMarker: true);*/
              // if (userLocationNotifier.value != null) {
              //   await controller
              //       .goToLocation(userLocationNotifier.value!);
              // }
            }
          },
          mini: true,
          heroTag: "UserLocationFab",
          child: ValueListenableBuilder<bool>(
            valueListenable: trackingNotifier,
            builder: (ctx, isTracking, _) {
              if (isTracking) {
                return ValueListenableBuilder<IconData>(
                  valueListenable: userLocationIcon,
                  builder: (context, icon, _) {
                    return Icon(icon);
                  },
                );
              }
              return Icon(Icons.near_me);
            },
          ),
        ),
      ),
    );
  }
}

class DirectionRouteLocation extends StatelessWidget {
  final MapController controller;

  const DirectionRouteLocation({
    super.key,
    required this.controller,
  });
  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: FloatingActionButton(
        key: UniqueKey(),
        onPressed: () async {},
        mini: true,
        heroTag: "directionFab",
        backgroundColor: Colors.blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Icon(
          Icons.directions,
          color: Colors.white,
        ),
      ),
    );
  }
}

class SearchInMap extends StatefulWidget {
  final MapController controller;

  const SearchInMap({
    super.key,
    required this.controller,
  });
  @override
  State<StatefulWidget> createState() => _SearchInMapState();
}

class _SearchInMapState extends State<SearchInMap> {
  final textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    textController.addListener(onTextChanged);
  }

  void onTextChanged() {}
  @override
  void dispose() {
    textController.removeListener(onTextChanged);
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Card(
        color: Colors.white,
        elevation: 2,
        shape: StadiumBorder(),
        child: TextField(
          controller: textController,
          onTap: () {},
          maxLines: 1,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.zero,
            filled: false,
            isDense: true,
            hintText: "search",
            prefixIcon: Icon(
              Icons.search,
              size: 22,
            ),
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}

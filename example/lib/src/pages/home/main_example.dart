import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin_example/src/models/map_widget_configuration.dart'
    show MoreActionConfig;
import 'package:flutter_osm_plugin_example/src/pages/home/component/header_home.dart';
import 'package:flutter_osm_plugin_example/src/pages/home/component/seach_map.dart'
    show SearchInMap;
import 'package:flutter_osm_plugin_example/src/pages/home/component/side_bar.dart';
import 'package:flutter_osm_plugin_example/src/widgets/action_buttons.dart'
    show ActionButton;
import 'package:forui/forui.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class MainPageExample extends StatefulWidget {
  const MainPageExample({super.key});

  @override
  State<MainPageExample> createState() => _MainPageExampleState();
}

class _MainPageExampleState extends State<MainPageExample> {
  late MapController controller;
  ValueNotifier<bool> trackingNotifier = ValueNotifier(false);
  ValueNotifier<IconData> userLocationIcon = ValueNotifier(Icons.near_me);
  ValueNotifier<GeoPoint?> userLocationNotifier = ValueNotifier(null);
  ValueNotifier<bool> disableMapControlUserTracking = ValueNotifier(true);
  late MoreActionConfig configuration;
  ValueNotifier<bool> showSidebar = ValueNotifier(false);
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
    configuration = (
      controller: controller,
      trackingNotifier: trackingNotifier,
      userLocationIcon: userLocationIcon,
      userLocationNotifier: userLocationNotifier,
      geos: ValueNotifier([]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 700;
    return FScaffold(
      resizeToAvoidBottomInset: false,
      scaffoldStyle: .delta(
        backgroundColor: FTheme.of(context).colors.background,
        systemOverlayStyle: FTheme.of(context).scaffoldStyle.systemOverlayStyle,
        childPadding: const EdgeInsetsGeometryDelta.value(EdgeInsets.zero),
      ),
      header: isDesktop
          ? HeaderHome(
              configuration: configuration,
              isCollapsedNotifier: showSidebar,
            )
          : null,
      sidebar: PointerInterceptor(
        child: ValueListenableBuilder(
          valueListenable: showSidebar,
          builder: (context, isCollapsed, child) {
            return SideBar(
              width: isCollapsed ? 0 : 250,
              onToggleCallback: () {
                showSidebar.value = !isCollapsed;
              },
            );
          },
        ),
      ),
      child: Main(
        configuration: configuration,
        disableMapControlUserTracking: disableMapControlUserTracking,
        showSidebar: showSidebar,
      ),
    );
  }
}

class Main extends StatefulWidget {
  const Main({
    super.key,
    required this.configuration,
    required this.disableMapControlUserTracking,
    required this.showSidebar,
  });
  final MoreActionConfig configuration;
  final ValueNotifier<bool> disableMapControlUserTracking;
  final ValueNotifier<bool> showSidebar;

  @override
  State<StatefulWidget> createState() => _MainState();
}

class _MainState extends State<Main> with OSMMixinObserver {
  ValueNotifier<bool> showFab = ValueNotifier(false);
  ValueNotifier<int> zoomLevelNotifier = ValueNotifier(16);
  final mapKey = GlobalKey();
  ValueNotifier<GeoPoint?> lastGeoPoint = ValueNotifier(null);

  @override
  void initState() {
    super.initState();

    widget.configuration.controller.addObserver(this);
    widget.configuration.trackingNotifier.addListener(() async {
      if (widget.configuration.userLocationNotifier.value != null &&
          !widget.configuration.trackingNotifier.value) {
        await widget.configuration.controller.removeMarker(
          widget.configuration.userLocationNotifier.value!,
        );
        widget.configuration.userLocationNotifier.value = null;
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
        // await controller.changeLocationMarker(
        //   oldLocation: lastGeoPoint.value!,
        //   newLocation: position,
        //   //iconAnchor: IconAnchor(anchor: Anchor.top),
        // );
        //controller.removeMarker(lastGeoPoint.value!);
        await widget.configuration.controller.addMarker(
          position,
          markerIcon: const MarkerIcon(
            icon: Icon(
              Icons.person_pin,
              color: Colors.red,
              size: 56,
            ),
          ),
          //angle: userLocation.angle,
        );
      } else {
        await widget.configuration.controller.addMarker(
          position,
          markerIcon: const MarkerIcon(
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
      //await controller.moveTo(position, animate: true);
      lastGeoPoint.value = position;
      widget.configuration.geos.value.add(position);
    });
  }

  @override
  void onMarkerClicked(GeoPoint position) {
    super.onMarkerClicked(position);
    Future.microtask(() async {
      if (!mounted) {
        return;
      }
      showFToast(
        context: context,
        title: const Text("the marker will be clicked!"),
      );
    });
  }

  @override
  void onMarkerLongPress(GeoPoint position) {
    super.onMarkerLongPress(position);
    Future.microtask(() async {
      if (!mounted) {
        return;
      }

      showFToast(
        context: context,
        title: const Text("the marker will be deleted!"),
        suffixBuilder: (context, entry) => FTappable(
          onPress: () async {
            await widget.configuration.controller.removeMarker(position);
            widget.configuration.geos.value.remove(position);
            entry.dismiss();
          },
          child: const Text('proceed'),
        ),
      );
    });
  }

  @override
  void onRegionChanged(Region region) {
    super.onRegionChanged(region);
    widget.configuration.controller.getZoom().then((v) {
      zoomLevelNotifier.value = v.toInt();
    });
    if (widget.configuration.trackingNotifier.value) {
      final userLocation = widget.configuration.userLocationNotifier.value;
      if (userLocation == null ||
          !region.center.isEqual(
            userLocation,
            precision: 1e4,
          )) {
        widget.configuration.userLocationIcon.value = Icons.gps_not_fixed;
      } else {
        widget.configuration.userLocationIcon.value = Icons.gps_fixed;
      }
    }
  }

  @override
  void onLocationChanged(UserLocation userLocation) async {
    super.onLocationChanged(userLocation);
    if (widget.disableMapControlUserTracking.value &&
        widget.configuration.trackingNotifier.value) {
      await widget.configuration.controller.moveTo(userLocation);
      if (widget.configuration.userLocationNotifier.value == null) {
        await widget.configuration.controller.addMarker(
          userLocation,
          markerIcon: const MarkerIcon(
            icon: Icon(
              Icons.navigation,
              size: 48,
            ),
          ),
          angle: userLocation.angle,
        );
      } else {
        await widget.configuration.controller.changeLocationMarker(
          oldLocation: widget.configuration.userLocationNotifier.value!,
          newLocation: userLocation,
          angle: userLocation.angle,
        );
      }
      widget.configuration.userLocationNotifier.value = userLocation;
    } else {
      if (widget.configuration.userLocationNotifier.value != null &&
          !widget.configuration.trackingNotifier.value) {
        await widget.configuration.controller.removeMarker(
          widget.configuration.userLocationNotifier.value!,
        );
        widget.configuration.userLocationNotifier.value = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.maybeOf(context)?.viewPadding.top ?? 0;
    return Stack(
      children: [
        Map(
          controller: widget.configuration.controller,
        ),
        Positioned(
          top: topPadding + 8,
          left: 16,
          right: 16,
          child: PointerInterceptor(
            child: Row(
              children: [
                ValueListenableBuilder(
                  valueListenable: widget.showSidebar,
                  builder: (context, isVisible, _) {
                    return ActionButton(
                      onPressed: () {
                        widget.showSidebar.value = !isVisible;
                      },
                      buttonStyle: (style) => style.copyWith(
                        minimumSize: WidgetStateProperty.resolveWith(
                          (_) => const Size(48, 48),
                        ),
                        maximumSize: WidgetStateProperty.resolveWith(
                          (_) => const Size(48, 48),
                        ),
                      ),
                      child: Icon(
                        FIcons.menu,
                        size: 18,
                        color: FTheme.of(context).colors.foreground,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SearchInMap(
                    controller: widget.configuration.controller,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 23.0,
          right: 15,
          child: Column(
            spacing: 8,
            children: [
              ActivationUserLocation(
                controller: widget.configuration.controller,
                trackingNotifier: widget.configuration.trackingNotifier,
                userLocation: widget.configuration.userLocationNotifier,
                userLocationIcon: widget.configuration.userLocationIcon,
              ),
              ZoomNavigation(
                controller: widget.configuration.controller,
                zoomNotifier: zoomLevelNotifier,
              ),
              ChangeTileButton(
                controller: widget.configuration.controller,
              ),
            ],
          ),
        ),
        Positioned.fill(
          child: ValueListenableBuilder(
            valueListenable: showFab,
            builder: (context, isVisible, child) {
              if (!isVisible) {
                return const SizedBox.shrink();
              }
              return Stack(
                children: [
                  if (!kIsWeb) ...[
                    Positioned(
                      top: topPadding + 56,
                      right: 15,
                      child: MapRotation(
                        controller: widget.configuration.controller,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class ZoomNavigation extends StatelessWidget {
  const ZoomNavigation({
    super.key,
    required this.controller,
    required this.zoomNotifier,
  });
  final MapController controller;
  final ValueNotifier<int> zoomNotifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PointerInterceptor(
          child: ActionButton(
            onPressed: () async {
              controller.zoomIn();
            },
            buttonStyle: (style) => style.copyWith(
              shape: WidgetStateOutlinedBorder.resolveWith(
                (_) => const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
              ),
            ),
            child: Center(
              child: Icon(
                FIcons.plus,
                color: FTheme.of(context).colors.foreground,
              ),
            ),
          ),
        ),
        PointerInterceptor(
          child: ActionButton(
            onPressed: () async {
              controller.zoomOut();
            },
            buttonStyle: (style) => style.copyWith(
              shape: WidgetStateOutlinedBorder.resolveWith(
                (_) => const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
              ),
            ),
            child: Center(
              child: Icon(
                FIcons.minus,
                color: FTheme.of(context).colors.foreground,
              ),
            ),
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
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ValueListenableBuilder(
          valueListenable: angle,
          builder: (ctx, angle, child) {
            return AnimatedRotation(
              turns: angle == 0 ? 0 : 360 / angle,
              duration: const Duration(milliseconds: 250),
              child: child!,
            );
          },
          child: Image.asset("asset/compass.png"),
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
      // mapIsLoading: Center(
      //   child: CircularProgressIndicator(),
      // ),
      onLocationChanged: (location) {
        debugPrint(location.toString());
      },
      osmOption: OSMOption(
        enableRotationByGesture: true,
        zoomOption: const ZoomOption(
          initZoom: 16,
          minZoomLevel: 3,
          maxZoomLevel: 19,
          stepZoom: 1.0,
        ),
        userLocationMarker: UserLocationMaker(
          personMarker: MarkerIcon(
            iconWidget: SizedBox(
              width: 32,
              height: 64,
              child: Image.asset(
                "asset/directionIcon.png",
                scale: .3,
              ),
            ),
          ),
          directionArrowMarker: const MarkerIcon(
            icon: Icon(
              Icons.navigation_rounded,
              size: 48,
            ),
          ),
        ),
        staticPoints: [
          StaticPositionGeoPoint(
            "line 1",
            const MarkerIcon(
              icon: Icon(
                Icons.train,
                color: Colors.green,
                size: 48,
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
        ],
        roadConfiguration: const RoadOption(
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
  const SearchLocation({super.key});

  @override
  Widget build(BuildContext context) {
    return const TextField();
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
        child: ActionButton(
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
          buttonStyle: (style) => style.copyWith(
            minimumSize: WidgetStateProperty.resolveWith(
              (_) => const Size(56, 48),
            ),
            maximumSize: WidgetStateProperty.resolveWith(
              (_) => const Size(56, 48),
            ),
            padding: WidgetStateProperty.resolveWith(
              (_) => const EdgeInsets.all(12),
            ),
            shape: .all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (_) => FTheme.of(context).colors.background,
            ),
          ),
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
              return Icon(
                FIcons.navigation,
                size: 18,
                color: FTheme.of(context).colors.foreground,
              );
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
        child: const Icon(
          Icons.directions,
          color: Colors.white,
        ),
      ),
    );
  }
}

class ChangeTileButton extends StatefulWidget {
  const ChangeTileButton({
    super.key,
    required this.controller,
  });
  final MapController controller;

  @override
  State<ChangeTileButton> createState() => _ChangeTileButtonState();
}

class _ChangeTileButtonState extends State<ChangeTileButton> {
  final _layers = [
    (
      name: 'Basic',
      icon: FIcons.map,
      tile: null,
    ),
    (
      name: 'Cycle',
      icon: FIcons.bike,
      tile: CustomTile.cycleOSM(),
    ),
    (
      name: 'Transport',
      icon: FIcons.bus,
      tile: CustomTile.publicTransportationOSM(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: ActionButton(
        onPressed: () async {
          await showFSheet(
            context: context,
            side: FLayout.btt,
            builder: (context) => FTileGroup(
              children: [
                for (final layer in _layers)
                  FTile(
                    prefix: Icon(layer.icon),
                    title: Text(layer.name),
                    onPress: () async {
                      await widget.controller.changeTileLayer(
                        tileLayer: layer.tile,
                      );
                      if (context.mounted) {
                        showFToast(
                          context: context,
                          title: Text('${layer.name} layer'),
                        );
                        Navigator.of(context).pop();
                      }
                    },
                  ),
              ],
            ),
          );
        },
        child: Center(
          child: Icon(
            FIcons.layers,
            color: FTheme.of(context).colors.foreground,
          ),
        ),
      ),
    );
  }
}

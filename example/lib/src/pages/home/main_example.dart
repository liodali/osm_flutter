import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin_example/src/models/map_style_configuration.dart';
import 'package:flutter_osm_plugin_example/src/models/map_widget_configuration.dart'
    show MoreActionConfig;
import 'package:flutter_osm_plugin_example/src/pages/home/component/route_search_panel.dart'
    show RouteSearchPanel;
import 'package:flutter_osm_plugin_example/src/pages/home/component/side_bar.dart';
import 'package:flutter_osm_plugin_example/src/services/location_storage.dart';
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
    return FScaffold(
      resizeToAvoidBottomInset: false,
      scaffoldStyle: .delta(
        backgroundColor: FTheme.of(context).colors.background,
        systemOverlayStyle: FTheme.of(context).scaffoldStyle.systemOverlayStyle,
        childPadding: const EdgeInsetsGeometryDelta.value(EdgeInsets.zero),
      ),
      child: Main(
        configuration: configuration,
        disableMapControlUserTracking: disableMapControlUserTracking,
      ),
    );
  }
}

class Main extends StatefulWidget {
  const Main({
    super.key,
    required this.configuration,
    required this.disableMapControlUserTracking,
  });
  final MoreActionConfig configuration;
  final ValueNotifier<bool> disableMapControlUserTracking;

  @override
  State<StatefulWidget> createState() => _MainState();
}

class _MainState extends State<Main> with OSMMixinObserver {
  ValueNotifier<bool> showFab = ValueNotifier(false);
  ValueNotifier<int> zoomLevelNotifier = ValueNotifier(16);
  final mapKey = GlobalKey();
  ValueNotifier<GeoPoint?> lastGeoPoint = ValueNotifier(null);
  bool _isApplyingWebLocationUpdate = false;
  UserLocation? _pendingWebLocationUpdate;
  UserLocation? _lastAppliedWebLocation;
  DateTime? _lastAppliedWebLocationAt;
  bool _sidebarExpanded = true;
  bool _routePanelCollapsed = false;
  final ValueNotifier<List<RouteHistoryEntry>> _routeHistoryNotifier =
      ValueNotifier([]);
  final ExampleMapStyleConfiguration _styleConfig =
      ExampleMapStyleConfiguration.instance;

  void _handleStyleChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    widget.configuration.controller.addObserver(this);
    _styleConfig.addListener(_handleStyleChanged);
    _routeHistoryNotifier.addListener(() {
      if (mounted) setState(() {});
    });
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
  void dispose() {
    _styleConfig.removeListener(_handleStyleChanged);
    _routeHistoryNotifier.dispose();
    super.dispose();
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
          markerIcon: _styleConfig.buildMarkerIcon(),
          //angle: userLocation.angle,
        );
      } else {
        await widget.configuration.controller.addMarker(
          position,
          markerIcon: _styleConfig.buildMarkerIcon(),
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

        suffixBuilder: (context, entry) => PointerInterceptor(
          child: FTappable(
            onPress: () async {
              await widget.configuration.controller.removeMarker(position);
              widget.configuration.geos.value.remove(position);
              entry.dismiss();
            },
            child: Text(
              'proceed',
              style: context.theme.typography.md,
            ),
          ),
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
  void onLocationChanged(UserLocation userLocation) {
    super.onLocationChanged(userLocation);
    if (kIsWeb) {
      _handleWebLocationChanged(userLocation);
      return;
    }
    _applyLocationChanged(userLocation);
  }

  Future<void> _handleWebLocationChanged(UserLocation userLocation) async {
    if (_shouldIgnoreWebLocationUpdate(userLocation)) {
      return;
    }

    _pendingWebLocationUpdate = userLocation;
    if (_isApplyingWebLocationUpdate) {
      return;
    }

    _isApplyingWebLocationUpdate = true;
    try {
      while (_pendingWebLocationUpdate != null) {
        final nextLocation = _pendingWebLocationUpdate!;
        _pendingWebLocationUpdate = null;

        if (_shouldIgnoreWebLocationUpdate(nextLocation)) {
          continue;
        }

        _lastAppliedWebLocation = nextLocation;
        _lastAppliedWebLocationAt = DateTime.now();
        await _applyLocationChanged(nextLocation);
      }
    } finally {
      _isApplyingWebLocationUpdate = false;
    }
  }

  bool _shouldIgnoreWebLocationUpdate(UserLocation userLocation) {
    final lastLocation = _lastAppliedWebLocation;
    final lastLocationAt = _lastAppliedWebLocationAt;
    if (lastLocation == null || lastLocationAt == null) {
      return false;
    }

    final isSameLocation = userLocation.isEqual(lastLocation, precision: 1e6);
    final isSameOrientation =
        (userLocation.angle - lastLocation.angle).abs() <= 1e-6;
    return isSameLocation &&
        isSameOrientation &&
        DateTime.now().difference(lastLocationAt).inMilliseconds < 250;
  }

  Future<void> _applyLocationChanged(UserLocation userLocation) async {
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
    if (kIsWeb) {
      return Row(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _sidebarExpanded
                ? SizedBox(
                    width: 320,
                    child: SideBar(
                      onHistoryItemTap: (entry) async {
                        // Handle history item tap
                        final path = entry.polylineBase64.stringToGeoPoints();
                        if (path.isEmpty) {
                          debugPrint(
                            'Skipping manual road redraw: empty history polyline for ${entry.startAddress} -> ${entry.destinationAddress}',
                          );
                          return;
                        }
                        final roadOption = _styleConfig.buildRoadOption();
                        await widget.configuration.controller.clearAllRoads();
                        await widget.configuration.controller.drawRoadManually(
                          path,
                          roadOption,
                        );
                      },
                      onToggleCallback: () {
                        setState(() => _sidebarExpanded = false);
                      },
                      showToggleButton: true,
                      topContent: RouteSearchPanel(
                        controller: widget.configuration.controller,
                        embeddedInSidebar: true,
                        historyNotifier: _routeHistoryNotifier,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: Stack(
              children: [
                Map(
                  controller: widget.configuration.controller,
                ),
                if (!_sidebarExpanded) ...[
                  Positioned(
                    top: 8,
                    left: 16,
                    child: PointerInterceptor(
                      child: ActionButton(
                        onPressed: () {
                          setState(() => _sidebarExpanded = true);
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
                      ),
                    ),
                  ),
                ],

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
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        Map(
          controller: widget.configuration.controller,
        ),
        Positioned(
          top: topPadding + 8,
          left: 16,
          right: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PointerInterceptor(
                  child: ActionButton(
                    onPressed: () async {
                      await showFSheet(
                        context: context,
                        side: FLayout.ltr,
                        builder: (context) => SideBar(
                          onToggleCallback: () => Navigator.of(context).pop(),
                          onHistoryItemTap: (entry) async {
                            // Handle history item tap
                            final path = entry.polylineBase64
                                .stringToGeoPoints();
                            if (path.isEmpty) {
                              debugPrint(
                                'Skipping manual road redraw: empty history polyline for ${entry.startAddress} -> ${entry.destinationAddress}',
                              );
                              return;
                            }
                            final roadOption = _styleConfig.buildRoadOption();
                            await widget.configuration.controller
                                .clearAllRoads();
                            await widget.configuration.controller
                                .drawRoadManually(
                                  path,
                                  roadOption,
                                );
                          },
                        ),
                      );
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
                  ),
                ),
              ),
              Expanded(
                child: RouteSearchPanel(
                  controller: widget.configuration.controller,
                  collapsed: _routePanelCollapsed,
                  onToggleCollapsed: () {
                    setState(
                      () => _routePanelCollapsed = !_routePanelCollapsed,
                    );
                  },
                  historyNotifier: _routeHistoryNotifier,
                ),
              ),
            ],
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
                  Positioned(
                    bottom: 23,
                    left: 15,
                    child: PointerInterceptor(
                      child: MapRotation(
                        controller: widget.configuration.controller,
                      ),
                    ),
                  ),
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
    final styleConfig = ExampleMapStyleConfiguration.instance;
    return OSMFlutter(
      controller: controller,
      // mapIsLoading: Center(
      //   child: CircularProgressIndicator(),
      // ),
      onLocationChanged: (location) {
        debugPrint(location.toString());
      },
      osmOption: OSMOption(
        useWebMapLibre: true,
        enableRotationByGesture: true,
        zoomOption: const ZoomOption(
          initZoom: 16,
          minZoomLevel: 3,
          maxZoomLevel: 19,
          stepZoom: 1.0,
        ),
        userLocationMarker: styleConfig.buildUserLocationMarker(),
        staticPoints: [
          StaticPositionGeoPoint(
            "line 1",
            styleConfig.buildMarkerIcon(),
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
        roadConfiguration: styleConfig.buildRoadOption(),
        showContributorBadgeForOSM: true,
        //trackMyPosition: trackingNotifier.value,
        showDefaultInfoWindow: false,
      ),
    );
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
    (
      name: 'Vector',
      icon: Icons.public,
      tile: CustomTile.openFreeMap(),
    ),
  ];

  bool get _isVectorTileSupported =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: ActionButton(
        onPressed: () async {
          final isDesktop = MediaQuery.of(context).size.width > 700;
          FToasterEntry? entry;
          if (isDesktop) {
            entry ??= showFToast(
              context: context,
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Select Layer',
                      style: FTheme.of(context).typography.lg,
                    ),
                  ),
                  PointerInterceptor(
                    child: GestureDetector(
                      onTap: () {
                        entry?.dismiss();
                        entry = null;
                      },
                      child: const Icon(
                        Icons.close,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              description: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final layer in _layers) ...[
                    PointerInterceptor(
                      child: FTappable(
                        onPress: () async {
                          if (layer.tile?.styleURL != null &&
                              !_isVectorTileSupported) {
                            entry?.dismiss();
                            entry = null;
                            return;
                          }
                          await widget.controller.changeTileLayer(
                            tileLayer: layer.tile,
                          );
                          entry?.dismiss();
                          entry = null;
                          if (context.mounted) {
                            showFToast(
                              context: context,
                              duration: const Duration(seconds: 2),
                              swipeToDismiss: [
                                AxisDirection.down,
                              ],
                              title: Text(
                                '${layer.name} layer',
                                style: FTheme.of(context).typography.md,
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 2,
                            horizontal: 12,
                          ),
                          child: Row(
                            spacing: 8,
                            children: [
                              Icon(layer.icon),
                              Expanded(
                                child: Text(
                                  layer.name,
                                  style: FTheme.of(context).typography.md,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              duration: const Duration(days: 1),
            );
          } else {
            await showFSheet(
              context: context,
              side: FLayout.btt,
              builder: (context) => PointerInterceptor(
                child: FTileGroup(
                  children: [
                    for (final layer in _layers)
                      FTile(
                        prefix: Icon(layer.icon),
                        title: Text(layer.name),
                        onPress: () async {
                          if (layer.tile?.styleURL != null &&
                              !_isVectorTileSupported) {
                            Navigator.of(context).pop();
                            return;
                          }
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
              ),
            );
          }
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

import 'package:flutter/widgets.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/src/common/osm_option.dart';

import 'package:flutter_osm_plugin/src/widgets/stub.dart'
    if (dart.library.io) 'package:flutter_osm_plugin/src/widgets/platform/mobile_osm_widget.dart'
    if (dart.library.js_interop) 'package:flutter_osm_plugin/src/widgets/platform/web_osm_widget.dart';

Widget buildWidget({
  required BaseMapController controller,
  UserTrackingOption? userTrackingOption,
  OnGeoPointClicked? onGeoPointClicked,
  OnLocationChanged? onLocationChanged,
  OnMapMoved? onMapMoved,
  required ValueNotifier<bool> mapIsReadyListener,
  required ValueNotifier<Widget?> dynamicMarkerWidgetNotifier,
  List<StaticPositionGeoPoint> staticPoints = const [],
  Widget? mapIsLoading,
  Function(bool)? onMapIsReady,
  required List<GlobalKey> globalKeys,
  required Map<String, GlobalKey> staticIconGlobalKeys,
  RoadOption? roadConfiguration,
  bool showZoomController = false,
  bool showDefaultInfoWindow = false,
  bool isPicker = false,
  bool showContributorBadgeForOSM = false,
  ZoomOption zoomOption = const ZoomOption(),
  UserLocationMaker? userLocationMarker,
  bool enableRotationByGesture = false,
}) => getWidget(
  controller: controller,
  userTrackingOption: userTrackingOption ?? controller.initMapWithUserPosition,
  mapIsReadyListener: mapIsReadyListener,
  dynamicMarkerWidgetNotifier: dynamicMarkerWidgetNotifier,
  globalKeys: globalKeys,
  staticIconGlobalKeys: staticIconGlobalKeys,
  isPicker: isPicker,
  showContributorBadgeForOSM: showContributorBadgeForOSM,
  showDefaultInfoWindow: showDefaultInfoWindow,
  mapIsLoading: mapIsLoading,
  onGeoPointClicked: onGeoPointClicked,
  onLocationChanged: onLocationChanged,
  onMapMoved: onMapMoved,
  roadConfiguration: roadConfiguration,
  zoomOption: zoomOption,
  userLocationMarker: userLocationMarker,
  onMapIsReady: onMapIsReady,
  showZoomController: showZoomController,
  staticPoints: staticPoints,
  enableRotationByGesture: enableRotationByGesture,
);

class OSMMap extends StatefulWidget {
  const OSMMap({
    super.key,
    required this.controller,
    this.userTrackingOption,
    this.onGeoPointClicked,
    this.onGeoPointLongPress,
    this.onLocationChanged,
    this.onMapMoved,
    required this.mapIsReadyListener,
    required this.dynamicMarkerWidgetNotifier,
    this.onMapIsReady,
    this.staticPoints = const [],
    this.mapIsLoading,
    this.userLocationMarker,
    required this.globalKeys,
    required this.staticIconGlobalKeys,
    this.roadConfiguration,
    this.showZoomController = false,
    this.zoomOption = const ZoomOption(),
    this.showDefaultInfoWindow = false,
    this.isPicker = false,
    this.showContributorBadgeForOSM = false,
    this.enableRotationByGesture = false,
    this.useTypedCameraRoute = true,
    this.useTypedMarkers = true,
    this.useTypedLayers = true,
    this.useTypedShapes = true,
    this.useTypedRoads = true,
    this.useTypedLocation = true,
    this.useTypedLocationUpdates = true,
    this.useTypedTracking = true,
    this.useTypedLocationIcons = true,
    this.useTypedLifecycleEvents = true,
    this.useTypedInteractionEvents = true,
    this.useTypedMarkerEvents = true,
    this.useTypedRoadEvents = true,
    this.useTypedLocationEvents = true,
    this.useTypedRegionEvents = true,
  });
  final BaseMapController controller;
  final UserTrackingOption? userTrackingOption;
  final OnGeoPointClicked? onGeoPointClicked;
  final OnGeoPointClicked? onGeoPointLongPress;
  final OnLocationChanged? onLocationChanged;
  final OnMapMoved? onMapMoved;
  final ValueNotifier<bool> mapIsReadyListener;
  final ValueNotifier<Widget?> dynamicMarkerWidgetNotifier;
  final Function(bool)? onMapIsReady;
  final List<StaticPositionGeoPoint> staticPoints;
  final Widget? mapIsLoading;
  final UserLocationMaker? userLocationMarker;
  final List<GlobalKey> globalKeys;
  final Map<String, GlobalKey> staticIconGlobalKeys;
  final RoadOption? roadConfiguration;
  final bool showZoomController;
  final ZoomOption zoomOption;
  final bool showDefaultInfoWindow;
  final bool isPicker;
  final bool showContributorBadgeForOSM;
  final bool enableRotationByGesture;
  /// Typed routing of camera commands through the typed generated channel (the
  /// default; `false` keeps the legacy route).
  final bool useTypedCameraRoute;
  /// Typed routing of marker commands through the typed generated channel (the
  /// default; `false` keeps the legacy route).
  final bool useTypedMarkers;
  /// Typed routing of layer commands (tile sources, overlay visibility) (the
  /// default; `false` keeps the legacy route).
  final bool useTypedLayers;
  /// Typed routing of shape commands (circles, rectangles) (the default;
  /// `false` keeps the legacy route).
  final bool useTypedShapes;
  /// Typed routing of road commands (drawing, removal, clearing) (the default;
  /// `false` keeps the legacy route).
  final bool useTypedRoads;
  /// Typed routing of location commands (my-location layer, fixes) (the
  /// default; `false` keeps the legacy route).
  final bool useTypedLocation;
  /// Typed routing of continuous-updates commands (start/stop) (the default;
  /// `false` keeps the legacy route).
  final bool useTypedLocationUpdates;
  /// Typed routing of follow-me tracking commands (enable/disable) (the
  /// default; `false` keeps the legacy route).
  final bool useTypedTracking;
  /// Typed routing of the person/direction icon replacement (the default;
  /// `false` keeps the legacy route).
  final bool useTypedLocationIcons;
  /// Typed routing of the native-to-Dart lifecycle events (readiness,
  /// restoration) (the default; `false` keeps the legacy route).
  final bool useTypedLifecycleEvents;
  /// Typed routing of the native-to-Dart map interactions (single presses, long
  /// presses) (the default; `false` keeps the legacy route).
  final bool useTypedInteractionEvents;
  /// Typed routing of the native-to-Dart marker interactions (the default;
  /// `false` keeps the legacy route).
  final bool useTypedMarkerEvents;
  /// Typed routing of the native-to-Dart road taps (the default; `false` keeps
  /// the legacy route).
  final bool useTypedRoadEvents;
  /// Typed routing of the native-to-Dart user-location fixes (the default;
  /// `false` keeps the legacy route).
  final bool useTypedLocationEvents;
  /// Typed routing of the native-to-Dart visible-region changes (the default;
  /// `false` keeps the legacy route).
  final bool useTypedRegionEvents;

  @override
  State<StatefulWidget> createState() => _OSMMapState();
}

class _OSMMapState extends State<OSMMap> {
  final GlobalKey key = GlobalKey();
  @override
  void didUpdateWidget(covariant OSMMap oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return OSMMapWidget(
      //key: key,
      controller: widget.controller,
      mapIsReadyListener: widget.mapIsReadyListener,
      dynamicMarkerWidgetNotifier: widget.dynamicMarkerWidgetNotifier,
      globalKeys: widget.globalKeys,
      staticIconGlobalKeys: widget.staticIconGlobalKeys,
      zoomOption: widget.zoomOption,
      isPicker: widget.isPicker,
      mapIsLoading: widget.mapIsLoading,
      onGeoPointClicked: widget.onGeoPointClicked,
      onLocationChanged: widget.onLocationChanged,
      onMapMoved: widget.onMapMoved,
      onMapIsReady: widget.onMapIsReady,
      roadConfiguration: widget.roadConfiguration,
      showContributorBadgeForOSM: widget.showContributorBadgeForOSM,
      showDefaultInfoWindow: widget.showDefaultInfoWindow,
      showZoomController: widget.showZoomController,
      staticPoints: widget.staticPoints,
      userLocationMarker: widget.userLocationMarker,
      userTrackingOption: widget.userTrackingOption,
      enableRotationByGesture: widget.enableRotationByGesture,
      useTypedCameraRoute: widget.useTypedCameraRoute,
      useTypedMarkers: widget.useTypedMarkers,
      useTypedLayers: widget.useTypedLayers,
      useTypedShapes: widget.useTypedShapes,
      useTypedRoads: widget.useTypedRoads,
      useTypedLocation: widget.useTypedLocation,
      useTypedLocationUpdates: widget.useTypedLocationUpdates,
      useTypedTracking: widget.useTypedTracking,
      useTypedLocationIcons: widget.useTypedLocationIcons,
      useTypedLifecycleEvents: widget.useTypedLifecycleEvents,
      useTypedInteractionEvents: widget.useTypedInteractionEvents,
      useTypedMarkerEvents: widget.useTypedMarkerEvents,
      useTypedRoadEvents: widget.useTypedRoadEvents,
      useTypedLocationEvents: widget.useTypedLocationEvents,
      useTypedRegionEvents: widget.useTypedRegionEvents,
    );
  }
}

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
    this.useTypedCameraRoute = false,
    this.useTypedMarkers = false,
    this.useTypedLayers = false,
    this.useTypedShapes = false,
    this.useTypedRoads = false,
    this.useTypedLocation = false,
    this.useTypedLocationUpdates = false,
    this.useTypedTracking = false,
    this.useTypedLocationIcons = false,
    this.useTypedLifecycleEvents = false,
    this.useTypedInteractionEvents = false,
    this.useTypedMarkerEvents = false,
    this.useTypedRoadEvents = false,
    this.useTypedLocationEvents = false,
    this.useTypedRegionEvents = false,
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
  /// Opt-in routing of camera commands through the typed generated channel.
  final bool useTypedCameraRoute;
  /// Opt-in routing of marker commands through the typed generated channel.
  final bool useTypedMarkers;
  /// Opt-in routing of layer commands (tile sources, overlay visibility).
  final bool useTypedLayers;
  /// Opt-in routing of shape commands (circles, rectangles).
  final bool useTypedShapes;
  /// Opt-in routing of road commands (drawing, removal, clearing).
  final bool useTypedRoads;
  /// Opt-in routing of location commands (my-location layer, fixes).
  final bool useTypedLocation;
  /// Opt-in routing of continuous-updates commands (start/stop).
  final bool useTypedLocationUpdates;
  /// Opt-in routing of follow-me tracking commands (enable/disable).
  final bool useTypedTracking;
  /// Opt-in routing of the person/direction icon replacement.
  final bool useTypedLocationIcons;
  /// Opt-in routing of the native-to-Dart lifecycle events (readiness,
  /// restoration).
  final bool useTypedLifecycleEvents;
  /// Opt-in routing of the native-to-Dart map interactions (single presses,
  /// long presses).
  final bool useTypedInteractionEvents;
  /// Opt-in routing of the native-to-Dart marker interactions.
  final bool useTypedMarkerEvents;
  /// Opt-in routing of the native-to-Dart road taps.
  final bool useTypedRoadEvents;
  /// Opt-in routing of the native-to-Dart user-location fixes.
  final bool useTypedLocationEvents;
  /// Opt-in routing of the native-to-Dart visible-region changes.
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

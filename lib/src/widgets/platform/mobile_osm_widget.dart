import 'package:flutter/widgets.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/src/common/osm_option.dart';
import 'package:flutter_osm_plugin/src/widgets/mobile_osm_flutter.dart';

Widget getWidget({
  required BaseMapController controller,
  UserTrackingOption? userTrackingOption,
  OnGeoPointClicked? onGeoPointClicked,
  OnGeoPointClicked? onGeoPointLongPress,
  OnLocationChanged? onLocationChanged,
  OnMapMoved? onMapMoved,
  required ValueNotifier<bool> mapIsReadyListener,
  required ValueNotifier<Widget?> dynamicMarkerWidgetNotifier,
  List<StaticPositionGeoPoint> staticPoints = const [],
  Widget? mapIsLoading,
  required List<GlobalKey> globalKeys,
  required Map<String, GlobalKey> staticIconGlobalKeys,
  RoadOption? roadConfiguration,
  bool showZoomController = false,
  bool showDefaultInfoWindow = false,
  bool isPicker = false,
  bool showContributorBadgeForOSM = false,
  ZoomOption zoomOption = const ZoomOption(),
  UserLocationMaker? userLocationMarker,
  Function(bool)? onMapIsReady,
  bool enableRotationByGesture = false,
  bool useTypedCameraRoute = false,
  bool useTypedMarkers = false,
  bool useTypedLayers = false,
  bool useTypedShapes = false,
  bool useTypedRoads = false,
  bool useTypedLocation = false,
  bool useTypedLocationUpdates = false,
  bool useTypedTracking = false,
}) => MobileOsmFlutter(
  controller: controller,
  userTrackingOption: userTrackingOption ?? controller.initMapWithUserPosition,
  onGeoPointClicked: onGeoPointClicked,
  onGeoPointLongPress: onGeoPointLongPress,
  onLocationChanged: onLocationChanged,
  onMapMoved: onMapMoved,
  mapIsReadyListener: mapIsReadyListener,
  mapIsLoading: mapIsLoading,
  staticIconGlobalKeys: staticIconGlobalKeys,
  dynamicMarkerWidgetNotifier: dynamicMarkerWidgetNotifier,
  showZoomController: showZoomController,
  showDefaultInfoWindow: showDefaultInfoWindow,
  showContributorBadgeForOSM: showContributorBadgeForOSM,
  isPicker: isPicker,
  roadConfig: roadConfiguration ?? const RoadOption.empty(),
  staticPoints: staticPoints,
  globalKeys: globalKeys,
  onMapIsReady: onMapIsReady,
  userLocationMarker: userLocationMarker,
  zoomOption: zoomOption,
  enableRotationByGesture: enableRotationByGesture,
  useTypedMarkers: useTypedMarkers,
  useTypedLayers: useTypedLayers,
  useTypedShapes: useTypedShapes,
  useTypedRoads: useTypedRoads,
  useTypedLocation: useTypedLocation,
  useTypedLocationUpdates: useTypedLocationUpdates,
  useTypedTracking: useTypedTracking,
);

class const OSMMapWidget({
  super.key,
  required this.controller,
  this.userTrackingOption,
  this.onGeoPointClicked,
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
  this.zoomOption = const ZoomOption(),
  this.showZoomController = false,
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
}) extends StatelessWidget {
  final BaseMapController controller;
  final UserTrackingOption? userTrackingOption;
  final OnGeoPointClicked? onGeoPointClicked;
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
  final bool useTypedCameraRoute;
  final bool useTypedMarkers;
  final bool useTypedLayers;
  final bool useTypedShapes;
  final bool useTypedRoads;
  final bool useTypedLocation;
  final bool useTypedLocationUpdates;
  final bool useTypedTracking;
  @override
  Widget build(BuildContext context) {
    return MobileOsmFlutter(
      controller: controller,
      userTrackingOption:
          userTrackingOption ?? controller.initMapWithUserPosition,
      onGeoPointClicked: onGeoPointClicked,
      onLocationChanged: onLocationChanged,
      onMapMoved: onMapMoved,
      mapIsReadyListener: mapIsReadyListener,
      mapIsLoading: mapIsLoading,
      staticIconGlobalKeys: staticIconGlobalKeys,
      dynamicMarkerWidgetNotifier: dynamicMarkerWidgetNotifier,
      showZoomController: showZoomController,
      showDefaultInfoWindow: showDefaultInfoWindow,
      showContributorBadgeForOSM: showContributorBadgeForOSM,
      isPicker: isPicker,
      roadConfig: roadConfiguration ?? const RoadOption.empty(),
      staticPoints: staticPoints,
      globalKeys: globalKeys,
      onMapIsReady: onMapIsReady,
      userLocationMarker: userLocationMarker,
      zoomOption: zoomOption,
      enableRotationByGesture: enableRotationByGesture,
      useTypedCameraRoute: useTypedCameraRoute,
      useTypedMarkers: useTypedMarkers,
      useTypedLayers: useTypedLayers,
      useTypedShapes: useTypedShapes,
      useTypedRoads: useTypedRoads,
      useTypedLocation: useTypedLocation,
      useTypedLocationUpdates: useTypedLocationUpdates,
      useTypedTracking: useTypedTracking,
    );
  }
}

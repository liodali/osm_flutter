import 'package:flutter/widgets.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/src/common/osm_option.dart';

Widget getWidget({
  required BaseMapController controller,
  UserTrackingOption? userTrackingOption,
  OnGeoPointClicked? onGeoPointClicked,
  OnGeoPointClicked? onGeoPointLongPressed,
  OnLocationChanged? onLocationChanged,
  OnMapMoved? onMapMoved,
  required ValueNotifier<bool> mapIsReadyListener,
  required ValueNotifier<Widget?> dynamicMarkerWidgetNotifier,
  Function(bool)? onMapIsReady,
  List<StaticPositionGeoPoint> staticPoints = const [],
  Widget? mapIsLoading,
  UserLocationMaker? userLocationMarker,
  required List<GlobalKey> globalKeys,
  required Map<String, GlobalKey> staticIconGlobalKeys,
  MarkerOption? markerOption,
  RoadOption? roadConfiguration,
  bool showZoomController = false,
  ZoomOption zoomOption = const ZoomOption(),
  bool showDefaultInfoWindow = false,
  bool isPicker = false,
  bool showContributorBadgeForOSM = false,
  bool enableRotationByGesture = false,
}) => throw UnsupportedError("");

class const OSMMapWidget({
  super.key,
  required this.controller,
  this.userTrackingOption,
  this.onGeoPointClicked,
  this.onGeoPointLongPressed,
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
  this.markerOption,
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
}) extends StatelessWidget {
  final BaseMapController controller;
  final UserTrackingOption? userTrackingOption;
  final OnGeoPointClicked? onGeoPointClicked;
  final OnGeoPointClicked? onGeoPointLongPressed;
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
  final MarkerOption? markerOption;
  final RoadOption? roadConfiguration;
  final bool showZoomController;
  final ZoomOption zoomOption;
  final bool showDefaultInfoWindow;
  final bool isPicker;
  final bool showContributorBadgeForOSM;
  final bool enableRotationByGesture;
  /// Accepted for signature compatibility; native generated routes do not
  /// apply to this platform.
  final bool useTypedCameraRoute;
  /// Accepted for signature compatibility; native generated routes do not
  /// apply to this platform.
  final bool useTypedMarkers;
  final bool useTypedLayers;
  final bool useTypedShapes;
  final bool useTypedRoads;
  final bool useTypedLocation;
  final bool useTypedLocationUpdates;
  final bool useTypedTracking;
  /// Accepted for signature compatibility; native generated routes do not
  /// apply to this platform.
  final bool useTypedLocationIcons;

  /// Accepted for signature compatibility; native generated routes do not
  /// apply to this platform.
  final bool useTypedLifecycleEvents;

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError();
  }
}

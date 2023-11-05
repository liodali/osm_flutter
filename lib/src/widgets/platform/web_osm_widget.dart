import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_web/flutter_osm_web.dart';

Widget getWidget({
  required BaseMapController controller,
  UserTrackingOption? userTrackingOption,
  OnGeoPointClicked? onGeoPointClicked,
  OnLocationChanged? onLocationChanged,
  required ValueNotifier<bool> mapIsReadyListener,
  required ValueNotifier<Widget?> dynamicMarkerWidgetNotifier,
  List<StaticPositionGeoPoint> staticPoints = const [],
  Widget? mapIsLoading,
  required List<GlobalKey> globalKeys,
  required Map<String, GlobalKey> staticIconGlobalKeys,
  MarkerOption? markerOption,
  RoadOption? roadConfiguration,
  bool showZoomController = false,
  bool showDefaultInfoWindow = false,
  bool isPicker = false,
  bool showContributorBadgeForOSM = false,
  bool androidHotReloadSupport = false,
  double stepZoom = 1,
  double initZoom = 2,
  double minZoomLevel = 2,
  double maxZoomLevel = 18,
  UserLocationMaker? userLocationMarker,
  Function(bool)? onMapIsReady,
  bool enableRotationByGesture = false,
}) =>
    OsmWebWidget(
      controller: controller,
      userTrackingOption:
          userTrackingOption ?? controller.initMapWithUserPosition,
      staticPoints: staticPoints,
      onGeoPointClicked: onGeoPointClicked,
      onLocationChanged: onLocationChanged,
      mapIsReadyListener: mapIsReadyListener,
      mapIsLoading: mapIsLoading,
      staticIconGlobalKeys: staticIconGlobalKeys,
      globalKeys: globalKeys,
      dynamicMarkerWidgetNotifier: dynamicMarkerWidgetNotifier,
      isPicker: isPicker,
      markerOption: markerOption,
      roadConfiguration: roadConfiguration ?? RoadOption.empty(),
      showDefaultInfoWindow: showDefaultInfoWindow,
      onMapIsReady: onMapIsReady,
      userLocationMarker: userLocationMarker,
      initZoom: initZoom,
      minZoomLevel: minZoomLevel,
      maxZoomLevel: maxZoomLevel,
      stepZoom: stepZoom,
    );

class OSMMapWidget extends StatelessWidget {
  OSMMapWidget({
    super.key,
    required this.controller,
    this.userTrackingOption,
    this.onGeoPointClicked,
    this.onLocationChanged,
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
    this.stepZoom = 1,
    this.initZoom = 2,
    this.minZoomLevel = 2,
    this.maxZoomLevel = 18,
    this.showDefaultInfoWindow = false,
    this.isPicker = false,
    this.showContributorBadgeForOSM = false,
    this.enableRotationByGesture = false,
  });
  final BaseMapController controller;
  final UserTrackingOption? userTrackingOption;
  final OnGeoPointClicked? onGeoPointClicked;
  final OnLocationChanged? onLocationChanged;
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
  final double stepZoom;
  final double initZoom;
  final double minZoomLevel;
  final double maxZoomLevel;
  final bool showDefaultInfoWindow;
  final bool isPicker;
  final bool showContributorBadgeForOSM;
  final bool enableRotationByGesture;

  @override
  Widget build(BuildContext context) {
    return OsmWebWidget(
      controller: controller,
      userTrackingOption:
          userTrackingOption ?? controller.initMapWithUserPosition,
      staticPoints: staticPoints,
      onGeoPointClicked: onGeoPointClicked,
      onLocationChanged: onLocationChanged,
      mapIsReadyListener: mapIsReadyListener,
      mapIsLoading: mapIsLoading,
      staticIconGlobalKeys: staticIconGlobalKeys,
      globalKeys: globalKeys,
      dynamicMarkerWidgetNotifier: dynamicMarkerWidgetNotifier,
      isPicker: isPicker,
      markerOption: markerOption,
      roadConfiguration: roadConfiguration ?? RoadOption.empty(),
      showDefaultInfoWindow: showDefaultInfoWindow,
      onMapIsReady: onMapIsReady,
      userLocationMarker: userLocationMarker,
      initZoom: initZoom,
      minZoomLevel: minZoomLevel,
      maxZoomLevel: maxZoomLevel,
      stepZoom: stepZoom,
    );
  }
}

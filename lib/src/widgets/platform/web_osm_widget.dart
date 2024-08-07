import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_web/flutter_osm_web.dart';

Widget getWidget({
  required BaseMapController controller,
  UserTrackingOption? userTrackingOption,
  OnGeoPointClicked? onGeoPointClicked,
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
  bool androidHotReloadSupport = false,
  ZoomOption zoomOption = const ZoomOption(),
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
      onMapMoved: onMapMoved,
      mapIsReadyListener: mapIsReadyListener,
      mapIsLoading: mapIsLoading,
      staticIconGlobalKeys: staticIconGlobalKeys,
      globalKeys: globalKeys,
      dynamicMarkerWidgetNotifier: dynamicMarkerWidgetNotifier,
      isPicker: isPicker,
      roadConfiguration: roadConfiguration ?? const RoadOption.empty(),
      showDefaultInfoWindow: showDefaultInfoWindow,
      onMapIsReady: onMapIsReady,
      userLocationMarker: userLocationMarker,
      initZoom: zoomOption.initZoom,
      minZoomLevel: zoomOption.minZoomLevel,
      maxZoomLevel: zoomOption.maxZoomLevel,
      stepZoom: zoomOption.stepZoom,
    );

class OSMMapWidget extends StatelessWidget {
  const OSMMapWidget({
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
    this.showZoomController = false,
    this.zoomOption = const ZoomOption(),
    this.showDefaultInfoWindow = false,
    this.isPicker = false,
    this.showContributorBadgeForOSM = false,
    this.enableRotationByGesture = false,
  });
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

  @override
  Widget build(BuildContext context) {
    return OsmWebWidget(
      controller: controller,
      userTrackingOption:
          userTrackingOption ?? controller.initMapWithUserPosition,
      staticPoints: staticPoints,
      onGeoPointClicked: onGeoPointClicked,
      onLocationChanged: onLocationChanged,
      onMapMoved: onMapMoved,
      mapIsReadyListener: mapIsReadyListener,
      mapIsLoading: mapIsLoading,
      staticIconGlobalKeys: staticIconGlobalKeys,
      globalKeys: globalKeys,
      dynamicMarkerWidgetNotifier: dynamicMarkerWidgetNotifier,
      isPicker: isPicker,
      roadConfiguration: roadConfiguration ?? const RoadOption.empty(),
      showDefaultInfoWindow: showDefaultInfoWindow,
      onMapIsReady: onMapIsReady,
      userLocationMarker: userLocationMarker,
      initZoom: zoomOption.initZoom,
      minZoomLevel: zoomOption.minZoomLevel,
      maxZoomLevel: zoomOption.maxZoomLevel,
      stepZoom: zoomOption.stepZoom,
      isStatic: controller is SimpleMapController,
    );
  }
}

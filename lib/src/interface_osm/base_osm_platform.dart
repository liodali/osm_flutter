import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';

import 'package:flutter_osm_plugin/src/widgets/stub.dart'
    if (dart.library.io) 'package:flutter_osm_plugin/src/widgets/platform/mobile_osm_widget.dart'
    if (dart.library.html) 'package:flutter_osm_plugin/src/widgets/platform/web_osm_widget.dart';

Widget buildWidget({
  required BaseMapController controller,
  UserTrackingOption? userTrackingOption,
  OnGeoPointClicked? onGeoPointClicked,
  OnLocationChanged? onLocationChanged,
  required ValueNotifier<bool> mapIsReadyListener,
  required ValueNotifier<Widget?> dynamicMarkerWidgetNotifier,
  List<StaticPositionGeoPoint> staticPoints = const [],
  Widget? mapIsLoading,
  Function(bool)? onMapIsReady,
  required List<GlobalKey> globalKeys,
  required Map<String, GlobalKey> staticIconGlobalKeys,
  MarkerOption? markerOption,
  RoadOption? roadConfiguration,
  bool showZoomController = false,
  bool showDefaultInfoWindow = false,
  bool isPicker = false,
  bool showContributorBadgeForOSM = false,
  double stepZoom = 1,
  double initZoom = 2,
  double minZoomLevel = 2,
  double maxZoomLevel = 18,
  UserLocationMaker? userLocationMarker,
  bool enableRotationByGesture = false,
}) =>
    getWidget(
      controller: controller,
      userTrackingOption:
          userTrackingOption ?? controller.initMapWithUserPosition,
      mapIsReadyListener: mapIsReadyListener,
      dynamicMarkerWidgetNotifier: dynamicMarkerWidgetNotifier,
      globalKeys: globalKeys,
      staticIconGlobalKeys: staticIconGlobalKeys,
      isPicker: isPicker,
      showContributorBadgeForOSM: showContributorBadgeForOSM,
      showDefaultInfoWindow: showDefaultInfoWindow,
      mapIsLoading: mapIsLoading,
      markerOption: markerOption,
      onGeoPointClicked: onGeoPointClicked,
      onLocationChanged: onLocationChanged,
      roadConfiguration: roadConfiguration,
      stepZoom: stepZoom,
      maxZoomLevel: maxZoomLevel,
      minZoomLevel: minZoomLevel,
      initZoom: initZoom,
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
      key: key,
      controller: widget.controller,
      mapIsReadyListener: widget.mapIsReadyListener,
      dynamicMarkerWidgetNotifier: widget.dynamicMarkerWidgetNotifier,
      globalKeys: widget.globalKeys,
      staticIconGlobalKeys: widget.staticIconGlobalKeys,
      initZoom: widget.initZoom,
      stepZoom: widget.stepZoom,
      maxZoomLevel: widget.maxZoomLevel,
      minZoomLevel: widget.minZoomLevel,
      isPicker: widget.isPicker,
      mapIsLoading: widget.mapIsLoading,
      markerOption: widget.markerOption,
      onGeoPointClicked: widget.onGeoPointClicked,
      onLocationChanged: widget.onLocationChanged,
      onMapIsReady: widget.onMapIsReady,
      roadConfiguration: widget.roadConfiguration,
      showContributorBadgeForOSM: widget.showContributorBadgeForOSM,
      showDefaultInfoWindow: widget.showDefaultInfoWindow,
      showZoomController: widget.showZoomController,
      staticPoints: widget.staticPoints,
      userLocationMarker: widget.userLocationMarker,
      userTrackingOption: widget.userTrackingOption,
      enableRotationByGesture: widget.enableRotationByGesture,
    );
  }
}

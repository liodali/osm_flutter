import 'package:flutter/material.dart';
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
    );
  }
}

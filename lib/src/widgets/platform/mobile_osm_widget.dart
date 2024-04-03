import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/src/common/osm_option.dart';
import 'package:flutter_osm_plugin/src/widgets/mobile_osm_flutter.dart';

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
  ZoomOption zoomOption = const ZoomOption(),
  UserLocationMaker? userLocationMarker,
  Function(bool)? onMapIsReady,
  bool enableRotationByGesture = false,
}) =>
    MobileOsmFlutter(
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
      roadConfig: roadConfiguration ?? RoadOption.empty(),
      staticPoints: staticPoints,
      globalKeys: globalKeys,
      onMapIsReady: onMapIsReady,
      userLocationMarker: userLocationMarker,
      zoomOption: zoomOption,
      enableRotationByGesture: enableRotationByGesture,
    );

class OSMMapWidget extends StatelessWidget {
  OSMMapWidget({
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
      roadConfig: roadConfiguration ?? RoadOption.empty(),
      staticPoints: staticPoints,
      globalKeys: globalKeys,
      onMapIsReady: onMapIsReady,
      userLocationMarker: userLocationMarker,
      zoomOption: zoomOption,
      enableRotationByGesture: enableRotationByGesture,
    );
  }
}

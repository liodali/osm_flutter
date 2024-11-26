import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/src/common/osm_option.dart';


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
    this.markerOption,
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
  final MarkerOption? markerOption;
  final PolylineOption? roadConfiguration;
  final bool showZoomController;
  final ZoomOption zoomOption;
  final bool showDefaultInfoWindow;
  final bool isPicker;
  final bool showContributorBadgeForOSM;
  final bool enableRotationByGesture;

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError();
  }
}

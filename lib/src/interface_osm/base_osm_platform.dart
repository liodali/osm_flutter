import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';

import '../widgets/stub.dart'
    if (dart.library.io) '../widgets/platform/mobile_osm_widget.dart'
    if (dart.library.html) '../widgets/platform/web_osm_widget.dart';

Widget buildWidget({
  required BaseMapController controller,
  required bool trackMyPosition,
  OnGeoPointClicked? onGeoPointClicked,
  OnLocationChanged? onLocationChanged,
  required ValueNotifier<bool> mapIsReadyListener,
  required ValueNotifier<Widget?> dynamicMarkerWidgetNotifier,
  List<StaticPositionGeoPoint> staticPoints = const [],
  Widget? mapIsLoading,
  required List<GlobalKey> globalKeys,
  required Map<String, GlobalKey> staticIconGlobalKeys,
  MarkerOption? markerOption,
  Road? road,
  bool showZoomController = false,
  double defaultZoom = 1.0,
  bool showDefaultInfoWindow = false,
  bool isPicker = false,
  bool showContributorBadgeForOSM = false,
}) =>
    getWidget(
      controller: controller,
      trackMyPosition: trackMyPosition,
      mapIsReadyListener: mapIsReadyListener,
      dynamicMarkerWidgetNotifier: dynamicMarkerWidgetNotifier,
      globalKeys: globalKeys,
      staticIconGlobalKeys: staticIconGlobalKeys,
      defaultZoom: defaultZoom,
      isPicker: isPicker,
      showContributorBadgeForOSM: showContributorBadgeForOSM,
      showDefaultInfoWindow: showDefaultInfoWindow,
      mapIsLoading: mapIsLoading,
      markerOption: markerOption,
      onGeoPointClicked: onGeoPointClicked,
      onLocationChanged: onLocationChanged,
      road: road,
      showZoomController: showZoomController,
      staticPoints: staticPoints,
    );

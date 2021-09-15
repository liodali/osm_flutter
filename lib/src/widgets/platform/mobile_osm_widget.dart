import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../controller/map_controller.dart';
import '../../widgets/mobile_osm_flutter.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';

Widget getWidget({
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
  bool showDefaultInfoWindow = false,
  bool isPicker = false,
  bool showContributorBadgeForOSM = false,
  double stepZoom = 1,
  double initZoom = 2,
  int minZoomLevel = 2,
  int maxZoomLevel = 18,
  UserLocationMaker? userLocationMarker,
  Function(bool)? onMapIsReady,
}) =>
    MobileOsmFlutter(
      controller: controller,
      onGeoPointClicked: onGeoPointClicked,
      onLocationChanged: onLocationChanged,
      mapIsReadyListener: mapIsReadyListener,
      mapIsLoading: mapIsLoading,
      staticIconGlobalKeys: staticIconGlobalKeys,
      trackMyPosition: trackMyPosition,
      dynamicMarkerWidgetNotifier: dynamicMarkerWidgetNotifier,
      showZoomController: showZoomController,
      showDefaultInfoWindow: showDefaultInfoWindow,
      showContributorBadgeForOSM: showContributorBadgeForOSM,
      markerOption: markerOption,
      isPicker: isPicker,
      road: road,
      staticPoints: staticPoints,
      globalKeys: globalKeys,
      onMapIsReady: onMapIsReady,
      userLocationMarker: userLocationMarker,
      initZoom: initZoom,
      minZoomLevel: minZoomLevel,
      maxZoomLevel: maxZoomLevel,
      stepZoom: stepZoom,
    );

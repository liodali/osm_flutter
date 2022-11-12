import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';

import '../widgets/stub.dart'
    if (dart.library.io) '../widgets/platform/mobile_osm_widget.dart'
    if (dart.library.html) '../widgets/platform/web_osm_widget.dart';

Widget buildWidget(
        {required BaseMapController controller,
        required bool trackMyPosition,
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
        RoadConfiguration? roadConfiguration,
        bool showZoomController = false,
        bool showDefaultInfoWindow = false,
        bool isPicker = false,
        bool showContributorBadgeForOSM = false,
        double stepZoom = 1,
        double initZoom = 2,
        double minZoomLevel = 2,
        double maxZoomLevel = 18,
        UserLocationMaker? userLocationMarker,
        bool androidHotReloadSupport = false,
        }) =>
    getWidget(
        controller: controller,
        trackMyPosition: trackMyPosition,
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
        androidHotReloadSupport: androidHotReloadSupport,
        );

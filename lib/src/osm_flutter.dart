import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/src/common/osm_option.dart';

import 'interface_osm/base_osm_platform.dart';
import 'widgets/copyright_osm_widget.dart';

/// [OSMFlutter]
///
/// Principal widget to show OSMMap using osm api (native sdks)
/// you can track you current location,show static points like position of your stores
/// show road(s)
///
/// [mapIsLoading]   :(Widget) show custom  widget when the map finish initialization
///
/// [onGeoPointClicked] : (callback) is trigger when you clicked on marker,return current  geoPoint of the Marker
///
/// [onLocationChanged] : (callback) it's fired when you activate tracking and  user position has been changed
/// 
/// [onMapMoved] : (callback) it's fired when you activate tracking and  user position has been changed
///
/// [onMapIsReady] : (callabck) it's fired when map initialization is complet
class OSMFlutter extends StatefulWidget {
  final BaseMapController controller;
  final Widget? mapIsLoading;
  final OnGeoPointClicked? onGeoPointClicked;
  final OnLocationChanged? onLocationChanged;
  final OnMapMoved? onMapMoved;
  final Function(bool)? onMapIsReady;
  final OSMOption osmOption;
  OSMFlutter({
    Key? key,
    required this.controller,
    required this.osmOption,
    this.mapIsLoading,
    this.onGeoPointClicked,
    this.onLocationChanged,
    this.onMapMoved,
    this.onMapIsReady,
  }) : super(key: key);

  @override
  _OSMFlutterState createState() => _OSMFlutterState();
}

class _OSMFlutterState extends State<OSMFlutter> {
  ValueNotifier<Widget?> dynamicMarkerWidgetNotifier = ValueNotifier(null);
  final ValueNotifier<bool> mapIsReadyListener = ValueNotifier(false);

  //_OsmCreatedCallback _osmCreatedCallback;
  late GlobalKey defaultMarkerKey,
      advancedPickerMarker,
      startIconKey,
      endIconKey,
      middleIconKey,
      dynamicMarkerKey,
      personIconMarkerKey,
      arrowDirectionMarkerKey;
  late Map<String, GlobalKey> staticMarkersKeys;

  @override
  void initState() {
    super.initState();
    if (widget.osmOption.staticPoints.isNotEmpty &&
        widget.osmOption.staticPoints.length > 1) {
      List<String> ids = [];
      for (int i = 0; i < widget.osmOption.staticPoints.length; i++) {
        ids.add(widget.osmOption.staticPoints[i].id);
      }

      ids.asMap().forEach((i, id) {
        var count = ids.where((_id) => id == _id).length;
        if (count > 1) {
          assert(false, "you have duplicated ids for static points");
        }
      });
    }
    dynamicMarkerKey = GlobalKey();
    defaultMarkerKey = GlobalKey();
    advancedPickerMarker = GlobalKey();
    startIconKey = GlobalKey();
    endIconKey = GlobalKey();
    middleIconKey = GlobalKey();
    personIconMarkerKey = GlobalKey();
    arrowDirectionMarkerKey = GlobalKey();
    staticMarkersKeys = {};
    widget.osmOption.staticPoints.forEach((gs) {
      staticMarkersKeys.putIfAbsent(gs.id, () => GlobalKey());
    });
  }

  @override
  void didUpdateWidget(covariant OSMFlutter oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        MapConfiguration(
          userLocationMarker: widget.osmOption.userLocationMarker,
          staticPoints: widget.osmOption.staticPoints,
          dynamicMarkerWidgetNotifier: dynamicMarkerWidgetNotifier,
          defaultMarkerKey: defaultMarkerKey,
          advancedPickerMarker: advancedPickerMarker,
          startIconKey: startIconKey,
          endIconKey: endIconKey,
          middleIconKey: middleIconKey,
          dynamicMarkerKey: dynamicMarkerKey,
          personIconMarkerKey: personIconMarkerKey,
          arrowDirectionMarkerKey: arrowDirectionMarkerKey,
          staticMarkersKeys: staticMarkersKeys,
        ),
        Container(
          color: Colors.white,
          child: widget.mapIsLoading != null
              ? Stack(
                  children: [
                    Container(
                      color: Colors.white,
                      child: OSMMap(
                        controller: widget.controller,
                        userTrackingOption: widget.osmOption.userTrackingOption,
                        onGeoPointClicked: widget.onGeoPointClicked,
                        onLocationChanged: widget.onLocationChanged,
                        onMapMoved: widget.onMapMoved,
                        dynamicMarkerWidgetNotifier:
                            dynamicMarkerWidgetNotifier,
                        mapIsLoading: widget.mapIsLoading,
                        mapIsReadyListener: mapIsReadyListener,
                        staticIconGlobalKeys: staticMarkersKeys,
                        roadConfiguration: widget.osmOption.roadConfiguration,
                        showContributorBadgeForOSM:
                            widget.osmOption.showContributorBadgeForOSM,
                        isPicker: widget.osmOption.isPicker,
                        showDefaultInfoWindow:
                            widget.osmOption.showDefaultInfoWindow,
                        showZoomController: widget.osmOption.showZoomController,
                        staticPoints: widget.osmOption.staticPoints,
                        globalKeys: [
                          defaultMarkerKey,
                          advancedPickerMarker,
                          startIconKey,
                          endIconKey,
                          middleIconKey,
                          dynamicMarkerKey,
                          personIconMarkerKey,
                          arrowDirectionMarkerKey,
                        ],
                        zoomOption: widget.osmOption.zoomOption,
                        userLocationMarker: widget.osmOption.userLocationMarker,
                        onMapIsReady: widget.onMapIsReady,
                        enableRotationByGesture:
                            widget.osmOption.enableRotationByGesture,
                      ),
                    ),
                    Positioned.fill(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: mapIsReadyListener,
                        builder: (ctx, isReady, child) {
                          return Visibility(
                            visible: !isReady,
                            child: child!,
                          );
                        },
                        child: Container(
                          color: Colors.white,
                          child: widget.mapIsLoading!,
                        ),
                      ),
                    ),
                  ],
                )
              : OSMMap(
                  controller: widget.controller,
                  userTrackingOption: widget.osmOption.userTrackingOption,
                  onGeoPointClicked: widget.onGeoPointClicked,
                  onLocationChanged: widget.onLocationChanged,
                  onMapMoved: widget.onMapMoved,
                  dynamicMarkerWidgetNotifier: dynamicMarkerWidgetNotifier,
                  mapIsLoading: widget.mapIsLoading,
                  mapIsReadyListener: mapIsReadyListener,
                  staticIconGlobalKeys: staticMarkersKeys,
                  roadConfiguration: widget.osmOption.roadConfiguration,
                  showContributorBadgeForOSM:
                      widget.osmOption.showContributorBadgeForOSM,
                  isPicker: widget.osmOption.isPicker,
                  showDefaultInfoWindow: widget.osmOption.showDefaultInfoWindow,
                  showZoomController: widget.osmOption.showZoomController,
                  staticPoints: widget.osmOption.staticPoints,
                  globalKeys: [
                    defaultMarkerKey,
                    advancedPickerMarker,
                    startIconKey,
                    endIconKey,
                    middleIconKey,
                    dynamicMarkerKey,
                    personIconMarkerKey,
                    arrowDirectionMarkerKey,
                  ],
                  zoomOption: widget.osmOption.zoomOption,
                  userLocationMarker: widget.osmOption.userLocationMarker,
                  onMapIsReady: widget.onMapIsReady,
                  enableRotationByGesture:
                      widget.osmOption.enableRotationByGesture,
                ),
        ),
        if (widget.osmOption.showContributorBadgeForOSM && !kIsWeb) ...[
          Positioned(
            bottom: 0,
            right: 5,
            child: CopyrightOSMWidget(),
          ),
        ],
      ],
    );
  }
}

class MapConfiguration extends StatelessWidget {
  final ValueNotifier<Widget?> dynamicMarkerWidgetNotifier;

  final MarkerOption? markerOption;
  final GlobalKey defaultMarkerKey,
      advancedPickerMarker,
      startIconKey,
      endIconKey,
      middleIconKey,
      dynamicMarkerKey,
      personIconMarkerKey,
      arrowDirectionMarkerKey;
  final Map<String, GlobalKey> staticMarkersKeys;
  final List<StaticPositionGeoPoint> staticPoints;
  final UserLocationMaker? userLocationMarker;

  const MapConfiguration({
    Key? key,
    required this.dynamicMarkerWidgetNotifier,
    this.markerOption,
    this.userLocationMarker,
    required this.staticPoints,
    required this.dynamicMarkerKey,
    required this.defaultMarkerKey,
    required this.advancedPickerMarker,
    required this.startIconKey,
    required this.endIconKey,
    required this.middleIconKey,
    required this.personIconMarkerKey,
    required this.arrowDirectionMarkerKey,
    required this.staticMarkersKeys,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      bottom: 0,
      left: 0,
      right: 0,
      child: Stack(
        children: <Widget>[
          ValueListenableBuilder<Widget?>(
            valueListenable: dynamicMarkerWidgetNotifier,
            builder: (ctx, widget, child) {
              if (widget == null) {
                return SizedBox.fromSize();
              }
              return RepaintBoundary(
                key: dynamicMarkerKey,
                child: widget,
              );
            },
          ),
          if ((markerOption?.defaultMarker != null)) ...[
            RepaintBoundary(
              key: defaultMarkerKey,
              child: markerOption!.defaultMarker!,
            ),
          ],
          if (staticPoints.isNotEmpty) ...[
            for (int i = 0; i < staticPoints.length; i++) ...[
              RepaintBoundary(
                key: staticMarkersKeys[staticPoints[i].id],
                child: staticPoints[i].markerIcon,
              ),
            ]
          ],
          if (userLocationMarker?.personMarker != null) ...[
            RepaintBoundary(
              key: personIconMarkerKey,
              child: userLocationMarker?.personMarker,
            ),
          ],
          if (userLocationMarker?.directionArrowMarker != null) ...[
            RepaintBoundary(
              key: arrowDirectionMarkerKey,
              child: userLocationMarker?.directionArrowMarker,
            ),
          ],
        ],
      ),
    );
  }
}

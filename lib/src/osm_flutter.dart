import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';

import 'controller/base_map_controller.dart';
import 'controller/map_controller.dart';
import 'interface_osm/base_osm_platform.dart';
import 'widgets/copyright_osm_widget.dart';

/// Principal widget to show OSMMap using osm api
/// you can track you current location,show static points like position of your stores
/// show road between 2 points
/// [isPicker] : (bool) if is true, map will behave as picker and will start advanced picker
///
/// [trackMyPosition] : (bool) if is true, map will track your location
///
/// [mapIsLoading]   :(Widget) show custom  widget when the map finish initialization
///
/// [showZoomController] : (bool) if us true, you can zoomIn zoomOut directly in the map
///
/// [staticPoints] : (List<StaticPositionGeoPoint>) if you have static point that  you want to show,like static of taxi or location of your stores
///
/// [onGeoPointClicked] : (callback) is trigger when you clicked on marker,return current  geoPoint of the Marker
///
/// [onLocationChanged] : (callback) it's hire when you activate tracking and  user position has been changed
///
/// [markerOption] :  contain marker of geoPoint and customisation of advanced picker marker
///
/// [road] : set color and icons marker of road
///
/// [defaultZoom] : set default zoom value (default = 1)
///
/// [showDefaultInfoWindow] : (bool) enable/disable default infoWindow of marker (default = false)
///
/// [showContributorBadgeForOSM] : (bool) for copyright of osm, we need to add badge in bottom of the map (default false)
class OSMFlutter extends StatefulWidget {
  final BaseMapController controller;
  final bool trackMyPosition;
  final bool showZoomController;
  final Widget? mapIsLoading;
  final List<StaticPositionGeoPoint> staticPoints;
  final OnGeoPointClicked? onGeoPointClicked;
  final OnLocationChanged? onLocationChanged;
  final MarkerOption? markerOption;
  final Road? road;
  final double defaultZoom;
  final bool showDefaultInfoWindow;
  final bool isPicker;
  final bool showContributorBadgeForOSM;

  OSMFlutter({
    Key? key,
    required this.controller,
    this.mapIsLoading,
    this.trackMyPosition = false,
    this.showZoomController = false,
    this.staticPoints = const [],
    this.markerOption,
    this.onGeoPointClicked,
    this.onLocationChanged,
    this.road,
    this.defaultZoom = 1.0,
    this.showDefaultInfoWindow = false,
    this.isPicker = false,
    this.showContributorBadgeForOSM = false,
  }) : super(key: key);

  @override
  OSMFlutterState createState() => OSMFlutterState();
}

class OSMFlutterState extends State<OSMFlutter> {
  GlobalKey androidViewKey = GlobalKey();
  ValueNotifier<Widget?> dynamicMarkerWidgetNotifier = ValueNotifier(null);
  ValueNotifier<bool> mapIsReadyListener = ValueNotifier(false);

  late GlobalKey defaultMarkerKey,
      advancedPickerMarker,
      startIconKey,
      endIconKey,
      middleIconKey,
      dynamicMarkerKey;
  late Map<String, GlobalKey> staticMarkersKeys;

  @override
  void initState() {
    super.initState();
    if (widget.staticPoints.isNotEmpty && widget.staticPoints.length > 1) {
      List<String> ids = [];
      for (int i = 0; i < widget.staticPoints.length; i++) {
        ids.add(widget.staticPoints[i].id);
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
    staticMarkersKeys = {};
    widget.staticPoints.forEach((gs) {
      staticMarkersKeys.putIfAbsent(gs.id, () => GlobalKey());
    });
  }

  @override
  void didUpdateWidget(covariant OSMFlutter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (this.widget != oldWidget) {}
  }

  @override
  void dispose() {
    //this._osmController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final widgetMap = buildWidget(
      controller: widget.controller as MapController,
      onGeoPointClicked: widget.onGeoPointClicked,
      onLocationChanged: widget.onLocationChanged,
      dynamicMarkerWidgetNotifier: dynamicMarkerWidgetNotifier,
      mapIsLoading: widget.mapIsLoading,
      trackMyPosition: widget.trackMyPosition,
      mapIsReadyListener: mapIsReadyListener,
      staticIconGlobalKeys: staticMarkersKeys,
      road: widget.road,
      defaultZoom: widget.defaultZoom,
      showContributorBadgeForOSM: widget.showContributorBadgeForOSM,
      isPicker: widget.isPicker,
      markerOption: widget.markerOption,
      showDefaultInfoWindow: widget.showDefaultInfoWindow,
      showZoomController: widget.showZoomController,
      staticPoints: widget.staticPoints,
      globalKeys: [
        defaultMarkerKey,
        advancedPickerMarker,
        startIconKey,
        endIconKey,
        middleIconKey,
        dynamicMarkerKey
      ],
    );
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        widgetConfigMap(),
        Container(
          color: Colors.white,
          child: widget.mapIsLoading != null
              ? Stack(
                  children: [
                    Container(
                      color: Colors.white,
                      child: widgetMap,
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
              : widgetMap,
        ),
        if (widget.showContributorBadgeForOSM && !kIsWeb) ...[
          Positioned(
            bottom: 0,
            right: 5,
            child: CopyrightOSMWidget(),
          ),
        ],
      ],
    );
  }

  Widget widgetConfigMap() {
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
          if ((widget.markerOption?.defaultMarker != null)) ...[
            RepaintBoundary(
              key: defaultMarkerKey,
              child: widget.markerOption!.defaultMarker!,
            ),
          ],
          if (widget.markerOption?.advancedPickerMarker != null) ...[
            RepaintBoundary(
              key: advancedPickerMarker,
              child: widget.markerOption?.advancedPickerMarker,
            ),
          ],
          if (widget.staticPoints.isNotEmpty) ...[
            for (int i = 0; i < widget.staticPoints.length; i++) ...[
              RepaintBoundary(
                key: staticMarkersKeys[widget.staticPoints[i].id],
                child: widget.staticPoints[i].markerIcon,
              ),
            ]
          ],
          if (widget.road?.endIcon != null) ...[
            RepaintBoundary(
              key: endIconKey,
              child: widget.road!.endIcon,
            ),
          ],
          if (widget.road?.startIcon != null) ...[
            RepaintBoundary(
              key: startIconKey,
              child: widget.road!.startIcon,
            ),
          ],
          if (widget.road?.middleIcon != null) ...[
            RepaintBoundary(
              key: middleIconKey,
              child: widget.road!.middleIcon,
            ),
          ],
        ],
      ),
    );
  }
}

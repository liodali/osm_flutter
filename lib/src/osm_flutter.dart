import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';

import 'interface_osm/base_osm_platform.dart';
import 'widgets/copyright_osm_widget.dart';

// typedef OnGeoPointClicked = void Function(GeoPoint);
// typedef OnLocationChanged = void Function(GeoPoint);

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
/// [onLocationChanged] : (callback) it's fired when you activate tracking and  user position has been changed
///
/// [onMapIsReady] : (callabck) it's fired when map initialization is complet
///
/// [markerOption] :  contain marker of geoPoint and customisation of advanced picker marker
///
/// [userLocationMarker] : change user marker or direction marker icon in tracking location
///
/// [roadConfiguration] : (RoadConfiguration) set color and icons marker of road
///
/// [stepZoom] : set default step zoom value (default = 1)
///
/// [initZoom] : set initialized zoom in specific location  (default = 2)
///
/// [minZoomLevel] : set default zoom value (default = 1)
///
/// [maxZoomLevel] : set default zoom value (default = 1)
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
  final Function(bool)? onMapIsReady;
  final MarkerOption? markerOption;
  final UserLocationMaker? userLocationMarker;
  final RoadConfiguration? roadConfiguration;
  final double stepZoom;
  final double initZoom;
  final double minZoomLevel;
  final double maxZoomLevel;
  final bool showDefaultInfoWindow;
  final bool isPicker;
  final bool showContributorBadgeForOSM;
  final bool androidHotReloadSupport;

  OSMFlutter({
    Key? key,
    required this.controller,
    this.mapIsLoading,
    this.trackMyPosition = false,
    this.showZoomController = false,
    this.staticPoints = const [],
    this.markerOption,
    this.userLocationMarker,
    this.onGeoPointClicked,
    this.onLocationChanged,
    this.onMapIsReady,
    this.roadConfiguration,
    this.stepZoom = 1,
    this.initZoom = 2,
    this.minZoomLevel = 2,
    this.maxZoomLevel = 18,
    this.showDefaultInfoWindow = false,
    this.isPicker = false,
    this.showContributorBadgeForOSM = false,
    this.androidHotReloadSupport = false,
  })  : assert(maxZoomLevel <= 19),
        assert(minZoomLevel >= 2),
        assert(initZoom >= 2 && initZoom <= 19),
        super(key: key);

  @override
  OSMFlutterState createState() => OSMFlutterState();
}

class OSMFlutterState extends State<OSMFlutter> {
  ValueNotifier<Widget?> dynamicMarkerWidgetNotifier = ValueNotifier(null);
  ValueNotifier<bool> mapIsReadyListener = ValueNotifier(false);

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
    personIconMarkerKey = GlobalKey();
    arrowDirectionMarkerKey = GlobalKey();
    staticMarkersKeys = {};
    widget.staticPoints.forEach((gs) {
      staticMarkersKeys.putIfAbsent(gs.id, () => GlobalKey());
    });
  }

  @override
  void didUpdateWidget(covariant OSMFlutter oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
    widget.controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (ctx, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            MapConfiguration(
              userLocationMarker: widget.userLocationMarker,
              roadConfiguration: widget.roadConfiguration,
              markerOption: widget.markerOption,
              staticPoints: widget.staticPoints,
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
                          child: buildWidget(
                              controller: widget.controller,
                              onGeoPointClicked: widget.onGeoPointClicked,
                              onLocationChanged: widget.onLocationChanged,
                              dynamicMarkerWidgetNotifier:
                                  dynamicMarkerWidgetNotifier,
                              mapIsLoading: widget.mapIsLoading,
                              trackMyPosition: widget.trackMyPosition,
                              mapIsReadyListener: mapIsReadyListener,
                              staticIconGlobalKeys: staticMarkersKeys,
                              roadConfiguration: widget.roadConfiguration,
                              showContributorBadgeForOSM:
                                  widget.showContributorBadgeForOSM,
                              isPicker: widget.isPicker,
                              markerOption: widget.markerOption,
                              showDefaultInfoWindow:
                                  widget.showDefaultInfoWindow,
                              showZoomController: widget.showZoomController,
                              staticPoints: widget.staticPoints,
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
                              stepZoom: widget.stepZoom,
                              initZoom: widget.initZoom,
                              minZoomLevel: widget.minZoomLevel,
                              maxZoomLevel: widget.maxZoomLevel,
                              userLocationMarker: widget.userLocationMarker,
                              onMapIsReady: widget.onMapIsReady,
                              androidHotReloadSupport:
                                  widget.androidHotReloadSupport),
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
                  : buildWidget(
                      controller: widget.controller,
                      onGeoPointClicked: widget.onGeoPointClicked,
                      onLocationChanged: widget.onLocationChanged,
                      dynamicMarkerWidgetNotifier: dynamicMarkerWidgetNotifier,
                      mapIsLoading: widget.mapIsLoading,
                      trackMyPosition: widget.trackMyPosition,
                      mapIsReadyListener: mapIsReadyListener,
                      staticIconGlobalKeys: staticMarkersKeys,
                      roadConfiguration: widget.roadConfiguration,
                      androidHotReloadSupport: widget.androidHotReloadSupport,
                      showContributorBadgeForOSM:
                          widget.showContributorBadgeForOSM,
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
                        dynamicMarkerKey,
                        personIconMarkerKey,
                        arrowDirectionMarkerKey,
                      ],
                      stepZoom: widget.stepZoom,
                      initZoom: widget.initZoom,
                      minZoomLevel: widget.minZoomLevel,
                      maxZoomLevel: widget.maxZoomLevel,
                      userLocationMarker: widget.userLocationMarker,
                      onMapIsReady: widget.onMapIsReady,
                    ),
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
      },
    );
  }

  /*Widget widgetConfigMap() {
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
              return Offstage(
                child: RepaintBoundary(
                  key: dynamicMarkerKey,
                  child: widget,
                ),
              );
            },
          ),
          if ((widget.markerOption?.defaultMarker != null)) ...[
            Offstage(
              child: RepaintBoundary(
                key: defaultMarkerKey,
                child: widget.markerOption!.defaultMarker!,
              ),
            ),
          ],
          if (widget.markerOption?.advancedPickerMarker != null) ...[
            Offstage(
              child: RepaintBoundary(
                key: advancedPickerMarker,
                child: widget.markerOption?.advancedPickerMarker,
              ),
            ),
          ],
          if (widget.staticPoints.isNotEmpty) ...[
            for (int i = 0; i < widget.staticPoints.length; i++) ...[
              Offstage(
                child: RepaintBoundary(
                  key: staticMarkersKeys[widget.staticPoints[i].id],
                  child: widget.staticPoints[i].markerIcon,
                ),
              ),
            ]
          ],
          if (widget.roadConfiguration?.endIcon != null) ...[
            Offstage(
              child: RepaintBoundary(
                key: endIconKey,
                child: widget.roadConfiguration!.endIcon,
              ),
            ),
          ],
          if (widget.roadConfiguration?.startIcon != null) ...[
            Offstage(
              child: RepaintBoundary(
                key: startIconKey,
                child: widget.roadConfiguration!.startIcon,
              ),
            ),
          ],
          if (widget.roadConfiguration?.middleIcon != null) ...[
            Offstage(
              child: RepaintBoundary(
                key: middleIconKey,
                child: widget.roadConfiguration!.middleIcon,
              ),
            ),
          ],
          if (widget.userLocationMarker?.personMarker != null) ...[
            Offstage(
              child: RepaintBoundary(
                key: personIconMarkerKey,
                child: widget.userLocationMarker?.personMarker,
              ),
            ),
          ],
          if (widget.userLocationMarker?.directionArrowMarker != null) ...[
            Offstage(
              child: RepaintBoundary(
                key: arrowDirectionMarkerKey,
                child: widget.userLocationMarker?.directionArrowMarker,
              ),
            ),
          ],
        ],
      ),
    );
  }*/
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
  final RoadConfiguration? roadConfiguration;
  final List<StaticPositionGeoPoint> staticPoints;
  final UserLocationMaker? userLocationMarker;

  const MapConfiguration({
    Key? key,
    required this.dynamicMarkerWidgetNotifier,
    this.markerOption,
    this.roadConfiguration,
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
          if (markerOption?.advancedPickerMarker != null) ...[
            RepaintBoundary(
              key: advancedPickerMarker,
              child: markerOption?.advancedPickerMarker,
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
          if (roadConfiguration?.endIcon != null) ...[
            RepaintBoundary(
              key: endIconKey,
              child: roadConfiguration!.endIcon,
            ),
          ],
          if (roadConfiguration?.startIcon != null) ...[
            RepaintBoundary(
              key: startIconKey,
              child: roadConfiguration!.startIcon,
            ),
          ],
          if (roadConfiguration?.middleIcon != null) ...[
            RepaintBoundary(
              key: middleIconKey,
              child: roadConfiguration!.middleIcon,
            ),
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

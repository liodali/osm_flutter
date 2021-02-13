import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:location_permissions/location_permissions.dart';

import 'controller/map_controller.dart';
import 'controller/osm_controller.dart';
import 'types/types.dart';

typedef OnGeoPointClicked = void Function(GeoPoint);
typedef OnLocationChanged = void Function(GeoPoint);

/// Principal widget to show OSMMap using osm api
/// you can track you current location,show static points like position of your stores
/// show road between 2 points
/// [trackMyPosition] : (bool) if is true, map will track your location
/// [showZoomController] : (bool) if us true, you can zoomIn zoomOut directly in the map
/// [staticPoints] : (List<StaticPositionGeoPoint>) if you have static point that  you want to show,like static of taxi or location of your stores
/// [onGeoPointClicked] : (callback) is trigger when you clicked on marker,return current  geoPoint of the Marker
/// [onLocationChanged] : (callback) it's hire when you activate tracking and  user position has been changed
/// [markerIcon] : (Icon/AssertImage) marker of geoPoint
/// [road] : set color and icons marker of road
/// [defaultZoom] : set default zoom value (default = 1)
/// [showDefaultInfoWindow] : (bool) enable/disable default infoWindow of marker (default = false)
/// [useSecureURL] : use https or http when we get data from osm api
class OSMFlutter extends StatefulWidget {
  final MapController controller;
  final bool trackMyPosition;
  final bool showZoomController;
  final List<StaticPositionGeoPoint> staticPoints;
  final OnGeoPointClicked onGeoPointClicked;
  final OnLocationChanged onLocationChanged;
  final MarkerIcon markerIcon;
  final Road road;
  final double defaultZoom;
  final bool showDefaultInfoWindow;
  final bool useSecureURL;

  OSMFlutter({
    Key key,
    this.controller,
    this.trackMyPosition = false,
    this.showZoomController = false,
    this.staticPoints = const [],
    this.markerIcon,
    this.onGeoPointClicked,
    this.onLocationChanged,
    this.road,
    this.defaultZoom = 1.0,
    this.showDefaultInfoWindow = false,
    this.useSecureURL = true,
  })  : assert(controller != null),
        super(key: key);

  static OSMFlutterState of<T>(BuildContext context, {bool nullOk = false}) {
    assert(context != null);
    assert(nullOk != null);
    final OSMFlutterState result =
        context.findAncestorStateOfType<OSMFlutterState>();
    if (nullOk || result != null) return result;
    throw FlutterError.fromParts(<DiagnosticsNode>[
      ErrorSummary(
          'FlutterOsmState.of() called with a context that does not contain an FlutterOsm.'),
      ErrorDescription(
          'No FlutterOsm ancestor could be found starting from the context that was passed to FlutterOsm.of().'),
      context.describeElement('The context used was')
    ]);
  }

  @override
  OSMFlutterState createState() => OSMFlutterState();
}

class OSMFlutterState extends State<OSMFlutter>
    with AfterLayoutMixin<OSMFlutter> {
  GlobalKey androidViewKey = GlobalKey();
  OSMController _osmController;

  //permission status
  PermissionStatus _permission;

  //_OsmCreatedCallback _osmCreatedCallback;
  GlobalKey key, startIconKey, endIconKey, middleIconKey;
  Map<String, GlobalKey> staticMarkersKeys;

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
      ids = null;
    }
    key = GlobalKey();
    startIconKey = GlobalKey();
    endIconKey = GlobalKey();
    middleIconKey = GlobalKey();
    staticMarkersKeys = {};
    widget.staticPoints.forEach((gs) {
      staticMarkersKeys.putIfAbsent(gs.id, () => GlobalKey());
    });
    Future.delayed(Duration.zero, () async {
      //check location permission
      if (widget.controller.initMapWithUserPosition || widget.trackMyPosition) {
        await requestPermission();
        if (widget.controller.initMapWithUserPosition) {
          await _osmController.checkServiceLocation();
        }
      }
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
    if (defaultTargetPlatform == TargetPlatform.android) {
      return Stack(
        children: <Widget>[
          widgetConfigMap(),
          AndroidView(
            key: androidViewKey,
            viewType: 'plugins.dali.hamza/osmview',
            onPlatformViewCreated: _onPlatformViewCreated,
            //creationParamsCodec:  StandardMessageCodec(),
          ),
        ],
      );
    }
    return Text(
        '$defaultTargetPlatform is not yet supported by the osm plugin');
  }

  /// requestPermission callback to request location in your phone
  Future<bool> requestPermission() async {
    _permission = await LocationPermissions().checkPermissionStatus();
    if (_permission == PermissionStatus.denied) {
      //request location permission
      _permission = await LocationPermissions().requestPermissions();
      if (_permission == PermissionStatus.granted) {
        await _osmController.checkServiceLocation();
      }
      return false;
    } else if (_permission == PermissionStatus.granted) {
      return true;
      //  if (widget.currentLocation) await _checkServiceLocation();
    }
    return false;
  }

  Widget widgetConfigMap() {
    return Positioned(
      top: -100,
      child: Stack(
        children: <Widget>[
          if (widget.markerIcon != null) ...[
            RepaintBoundary(
              key: key,
              child: widget.markerIcon,
            ),
          ],
          if (widget.staticPoints != null &&
              widget.staticPoints.isNotEmpty) ...[
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
              child: widget.road.endIcon,
            ),
          ],
          if (widget.road?.startIcon != null) ...[
            RepaintBoundary(
              key: startIconKey,
              child: widget.road.startIcon,
            ),
          ],
          if (widget.road?.middleIcon != null) ...[
            RepaintBoundary(
              key: middleIconKey,
              child: widget.road.middleIcon,
            ),
          ],
        ],
      ),
    );
  }

  void _onPlatformViewCreated(int id) async {
    this._osmController = await OSMController.init(id, this);
    widget.controller.init(this._osmController);
    Future.delayed(Duration(milliseconds: 1250), () async {
      await _osmController.initMap(
        initPosition: widget.controller.initPosition,
        initWithUserPosition: widget.controller.initMapWithUserPosition,
      );
      /*while(this._osmController==null){
        print("osm null");
      }*/
    });
  }

  @override
  void afterFirstLayout(BuildContext context) {}
}

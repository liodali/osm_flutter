import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin/src/geo_point_exception.dart';
import 'package:flutter_osm_plugin/src/job_alert_dialog.dart';
import 'package:flutter_osm_plugin/src/marker.dart';
import 'package:flutter_osm_plugin/src/road.dart';
import 'package:flutter_osm_plugin/src/road_exception.dart';
import 'package:location_permissions/location_permissions.dart';

class OSMFlutter extends StatefulWidget {
  final bool currentLocation;
  final bool trackMyPosition;
  final bool showZoomController;
  final GeoPoint initPosition;
  final MarkerIcon markerIcon;
  final Road road;
  final bool useSecureURL;
  OSMFlutter({
    Key key,
    this.currentLocation = true,
    this.trackMyPosition = false,
    this.showZoomController = false,
    this.initPosition,
    this.markerIcon,
    this.road,
    this.useSecureURL = true,
  }) : super(key: key);

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

class OSMFlutterState extends State<OSMFlutter> {
  //permission status
  PermissionStatus _permission;
  //_OsmCreatedCallback _osmCreatedCallback;
  _OsmController _osmController;
  GlobalKey _key, _startIconKey, _endIconKey, _midddleIconKey;

  @override
  void initState() {
    super.initState();
    _key = GlobalKey();
    _startIconKey = GlobalKey();
    _endIconKey = GlobalKey();
    _midddleIconKey = GlobalKey();
    Future.delayed(Duration(milliseconds: 150), () async {
      //check location permission
      _permission = await LocationPermissions().checkPermissionStatus();
      if (_permission == PermissionStatus.denied) {
        //request location permission
        _permission = await LocationPermissions().requestPermissions();
        if (_permission == PermissionStatus.granted) {
          await _checkServiceLocation();
        }
      } else if (_permission == PermissionStatus.granted) {
        if (widget.currentLocation) await _checkServiceLocation();
      }

      await this._osmController.setSecureURL(widget.useSecureURL);

      if (widget.markerIcon != null) {
        await changeIconMarker(_key);
      }
      if (widget.initPosition != null) {
        await changeLocation(widget.initPosition);
      }
      if (widget.road != null) {
        await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) {
              return JobAlertDialog(
                callback: () async {
                  await this._osmController.setColorRoad(
                        widget.road.roadColor.red,
                        widget.road.roadColor.green,
                        widget.road.roadColor.blue,
                      );
                  await this._osmController.setMarkersRoad(
                        _startIconKey,
                        _endIconKey,
                        _midddleIconKey,
                      );
                  Navigator.pop(ctx);
                },
              );
            });
      }
    });
  }

  ///initialise or change of position
  Future<void> changeLocation(GeoPoint p) async {
    assert(p != null);
    this._osmController.addPosition(p);
  }

  Future changeIconMarker(GlobalKey key) async {
    await this._osmController.customMarker(key);
  }

  ///zoom in/out
  /// positive value:zoomIN
  /// negative value:zoomOut
  void zoom(double zoom) {
    this._osmController.zoom(zoom);
  }

  ///activate current location position
  Future<void> currentLocation() async {
    await this._osmController.currentLocation();
  }

  //recuperation of user current position
  Future<GeoPoint> myLocation() async {
    return await this._osmController.myLocation();
  }

  ///enabled/disabled tracking user location
  Future<void> enableTracking() async {
    await this._osmController.enableTracking();
  }

  //pick Position in map
  Future<GeoPoint> selectPosition() async {
    GeoPoint p = await this._osmController.pickLocation();
    return p;
  }

  //draw road
  Future<void> drawRoad(GeoPoint start, GeoPoint end) async {
    assert(
        start != null && end != null, "you cannot make road without 2 point");
    assert(start.latitude != end.latitude || start.longitude != end.longitude,
        "you cannot make road with same geopoint");
    await this._osmController.drawRoad(start, end);
  }

  Future<void> _checkServiceLocation() async {
    ServiceStatus serviceStatus =
        await LocationPermissions().checkServiceStatus();
    if (serviceStatus == ServiceStatus.disabled) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            title: Text("GPS service is disabled"),
            content: Text(
                "We need to get your current location,you should turn on your gps location "),
            actions: <Widget>[
              FlatButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "annuler",
                  style: TextStyle(color: Colors.black),
                ),
              ),
              FlatButton(
                onPressed: () => Navigator.pop(context),
                color: Theme.of(context).primaryColor,
                child: Text(
                  "ok",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else if (serviceStatus == ServiceStatus.enabled) {
      currentLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return Stack(
        children: <Widget>[
          widgetConfigMap(),
          AndroidView(
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

  Widget widgetConfigMap() {
    return Positioned(
      top: -100,
      child: Stack(
        children: <Widget>[
          RepaintBoundary(
            key: _key,
            child: widget.markerIcon,
          ),
          if (widget.road?.endIcon != null) ...[
            RepaintBoundary(
              key: _endIconKey,
              child: widget.road.endIcon,
            ),
          ],
          if (widget.road?.startIcon != null) ...[
            RepaintBoundary(
              key: _startIconKey,
              child: widget.road.startIcon,
            ),
          ],
          if (widget.road?.middleIcon != null) ...[
            RepaintBoundary(
              key: _midddleIconKey,
              child: widget.road.middleIcon,
            ),
          ],
        ],
      ),
    );
  }

  void _onPlatformViewCreated(int id) {
    this._osmController = _OsmController._(id);
  }
}

class _OsmController {
  _OsmController._(int id)
      : _channel = new MethodChannel('plugins.dali.hamza/osmview_$id');
  //_eventChannel=null;

  final MethodChannel _channel;
  //final EventChannel _eventChannel;

  Future<void> setSecureURL(bool secure) async {
    return await _channel.invokeMethod('use#secure', secure);
  }

  Future<void> zoom(double zoom) async {
    assert(zoom != null);
    return await _channel.invokeMethod('Zoom', zoom);
  }

  Future<void> currentLocation() async {
    return await _channel.invokeMethod('currentLocation', null);
  }

  Future<GeoPoint> myLocation() async {
    try {
      Map<String, dynamic> map =
          await _channel.invokeMapMethod("user#position", null);
      return GeoPoint(latitude: map["lat"], longitude: map["lon"]);
    } on PlatformException catch (e) {
      throw GeoPointException(msg: e.message);
    }
  }

  Future<GeoPoint> pickLocation() async {
    try {
      Map<String, dynamic> map =
          await _channel.invokeMapMethod("user#pickPosition", null);
      return GeoPoint(latitude: map["lat"], longitude: map["lon"]);
    } on PlatformException catch (e) {
      throw GeoPointException(msg: e.message);
    }
  }

  Future<void> customMarker(GlobalKey globalKey) async {
    Uint8List icon = await _capturePng(globalKey);
    await _channel.invokeMethod("marker#icon", icon);
  }

  Future<void> setColorRoad(int r, int g, int b) async {
    await _channel.invokeMethod("road#color", [r, g, b]);
  }

  Future<void> setMarkersRoad(
      GlobalKey startKey, GlobalKey endKey, GlobalKey middleKey) async {
    Map<String, Uint8List> bitmaps = {};
    if (startKey.currentContext != null) {
      print("start");
      Uint8List marker = await _capturePng(startKey);
      bitmaps.putIfAbsent("START", () => marker);
    }
    if (endKey.currentContext != null) {
      print("end");
      Uint8List marker = await _capturePng(endKey);
      bitmaps.putIfAbsent("END", () => marker);
    }
    if (middleKey.currentContext != null) {
      print("end");
      Uint8List marker = await _capturePng(middleKey);
      bitmaps.putIfAbsent("MIDDLE", () => marker);
    }
    await _channel.invokeMethod("road#markers", bitmaps);
  }

  Future<Uint8List> _capturePng(GlobalKey globalKey) async {
    RenderRepaintBoundary boundary =
        globalKey.currentContext.findRenderObject();
    ui.Image image = await boundary.toImage();
    ByteData byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    Uint8List pngBytes = byteData.buffer.asUint8List();
    return pngBytes;
  }

  ///enable tracking your location
  Future<void> enableTracking() async {
    await _channel.invokeMethod('trackMe', null);
  }

  ///change and init position
  Future<void> addPosition(GeoPoint p) async {
    return await _channel.invokeListMethod(
        "initPosition", {"lon": p.longitude, "lat": p.latitude});
  }

  ///draw road
  Future<void> drawRoad(GeoPoint p, GeoPoint p2) async {
    try {
      return await _channel.invokeMethod("road", [
        {"lon": p.longitude, "lat": p.latitude},
        {"lon": p2.longitude, "lat": p2.latitude}
      ]);
    } on PlatformException catch (e) {
      throw RoadException(msg: e.message);
    }
  }
}

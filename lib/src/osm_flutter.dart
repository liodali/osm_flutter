import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:after_layout/after_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin/src/geo_point_exception.dart';
import 'package:flutter_osm_plugin/src/geo_static.dart';
import 'package:flutter_osm_plugin/src/job_alert_dialog.dart';
import 'package:flutter_osm_plugin/src/marker.dart';
import 'package:flutter_osm_plugin/src/road.dart';
import 'package:flutter_osm_plugin/src/road_exception.dart';
import 'package:location_permissions/location_permissions.dart';

typedef OnGeoPointClicked = void Function(GeoPoint);
typedef OnLocationChanged = void Function(GeoPoint);

/// Principal widget to show OSMMap using osm api
/// you can track you current location,show static points like position of your stores
/// show road between 2 points
/// [currentLocation] : (bool) if is true, map will show your current location
/// [trackMyPosition] : (bool) if is true, map will track your location
/// [showZoomController] : (bool) if us true, you can zoomIn zoomOut directly in the map
/// [initPosition] : (GeoPoint) if it isn't null, the map will be pointed at this position
/// [staticPoints] : (List<StaticPositionGeoPoint>) if you have static point that  you want to show,like static of taxi or location of your stores
/// [onGeoPointClicked] : (callback) is trigger when you clicked on geoPoint
/// [markerIcon] : (Icon/AssertImage) marker of geopoint
/// [road] : set color and icons marker of road
/// [defaultZoom] : set default zoom value (default = 1)
/// [useSecureURL] : use https or http when we get data from osm api
class OSMFlutter extends StatefulWidget {
  final bool currentLocation;
  final bool trackMyPosition;
  final bool showZoomController;
  final GeoPoint initPosition;
  final List<StaticPositionGeoPoint> staticPoints;
  final OnGeoPointClicked onGeoPointClicked;
  final OnLocationChanged onLocationChanged;
  final MarkerIcon markerIcon;
  final Road road;
  final double defaultZoom;
  final bool useSecureURL;

  OSMFlutter({
    Key key,
    this.currentLocation = true,
    this.trackMyPosition = false,
    this.showZoomController = false,
    this.initPosition,
    this.staticPoints = const [],
    this.markerIcon,
    this.onGeoPointClicked,
    this.onLocationChanged,
    this.road,
    this.defaultZoom = 1.0,
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

class OSMFlutterState extends State<OSMFlutter>
    with AfterLayoutMixin<OSMFlutter> {
  GlobalKey androidViewKey = GlobalKey();

  //permission status
  PermissionStatus _permission;

  //_OsmCreatedCallback _osmCreatedCallback;
  _OsmController _osmController;
  GlobalKey _key, _startIconKey, _endIconKey, _midddleIconKey;
  Map<String, GlobalKey> _staticMarkersKeys;
  bool _isTracking = false;

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
    _key = GlobalKey();
    _startIconKey = GlobalKey();
    _endIconKey = GlobalKey();
    _midddleIconKey = GlobalKey();
    _staticMarkersKeys = {};
    widget.staticPoints.forEach((gs) {
      _staticMarkersKeys.putIfAbsent(gs.id, () => GlobalKey());
    });
    Future.delayed(Duration.zero, () async {
      //check location permission
      if (widget.currentLocation || widget.trackMyPosition) {
        await requestPermission();
      }
    });
  }

  /// requestPermission callback to request location in your phone
  Future<void> requestPermission() async {
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
  }

  @override
  void dispose() {
    this._osmController?.closeListen();
    super.dispose();
  }

  ///initialise or change of position
  /// [p] : geoPoint
  Future<void> changeLocation(GeoPoint p) async {
    if (p != null) this._osmController.addPosition(p);
  }

  //change Icon Marker
  Future changeIconMarker(GlobalKey key) async {
    await this._osmController.customMarker(key);
  }

  /// change static position in runtime
  ///  [geos] : list of static geoPoint
  ///  [id] : String of that list of static geoPoint
  Future<void> setStaticPosition(List<GeoPoint> geos, String id) async {
    assert(
        widget.staticPoints != null &&
            widget.staticPoints.firstWhere((p) => p.id == id) != null,
        "static points null,you should initialize them before you set their positions!");
    await this._osmController.staticPosition(geos, id);
  }

  /// zoom in/out
  /// positive value:zoomIN
  /// negative value:zoomOut
  Future<void> zoom(double zoom) async {
    assert(zoom != 0, "zoom value should different from zero");
    await this._osmController.zoom(zoom);
  }

  /// zoomIn use defaultZoom
  /// positive value:zoomIN
  Future<void> zoomIn() async {
    await this._osmController.zoom(0);
  }

  /// zoomOut use defaultZoom
  /// negative value:zoomOut
  Future<void> zoomOut() async {
    await this._osmController.zoom(-1);
  }

  /// activate current location position
  Future<void> currentLocation() async {
    await requestPermission();
    await this._osmController.currentLocation();
  }

  /// recuperation of user current position
  Future<GeoPoint> myLocation() async {
    return await this._osmController.myLocation();
  }

  /// enabled tracking user location
  Future<void> enableTracking() async {
    if (!_isTracking) {
      await requestPermission();
      await this._osmController.enableTracking();
      _isTracking = true;
    }
  }

  /// disabled tracking user location
  Future<void> disabledTracking() async {
    if (_isTracking) {
      await this._osmController.enableTracking();
      _isTracking = false;
    }
  }

  /// pick Position in map
  Future<GeoPoint> selectPosition() async {
    GeoPoint p = await this._osmController.pickLocation();
    return p;
  }

  /// draw road
  ///  [start] : started point of your Road
  ///  [end] : last point of your road
  Future<RoadInfo> drawRoad(GeoPoint start, GeoPoint end) async {
    assert(
        start != null && end != null, "you cannot make road without 2 point");
    assert(start.latitude != end.latitude || start.longitude != end.longitude,
        "you cannot make road with same geopoint");
    return await this._osmController.drawRoad(start, end);
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

  Widget widgetConfigMap() {
    return Positioned(
      top: -100,
      child: Stack(
        children: <Widget>[
          if (widget.markerIcon != null) ...[
            RepaintBoundary(
              key: _key,
              child: widget.markerIcon,
            ),
          ],
          if (widget.staticPoints != null &&
              widget.staticPoints.isNotEmpty) ...[
            for (int i = 0; i < widget.staticPoints.length; i++) ...[
              RepaintBoundary(
                key: _staticMarkersKeys[widget.staticPoints[i].id],
                child: widget.staticPoints[i].markerIcon,
              ),
            ]
          ],
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

  @override
  void afterFirstLayout(BuildContext context) {
    print("after layout");
    Future.delayed(Duration(milliseconds: 1250), () async {
      /*while(this._osmController==null){
        print("osm null");
      }*/

      this._osmController.setDefaultZoom(widget.defaultZoom);

      this._osmController.setSecureURL(widget.useSecureURL);
      if (widget.onGeoPointClicked != null) {
        this._osmController.startListen(widget.onGeoPointClicked, (err) {
          print(err);
        });
      }
      if (widget.onLocationChanged != null) {
        this._osmController.myLocationListener(widget.onLocationChanged, (err) {
          print(err);
        });
      }
      if (widget.trackMyPosition) {
        await enableTracking();
        await currentLocation();
      }
      if (widget.markerIcon != null) {
        await changeIconMarker(_key);
      }
      if (widget.initPosition != null) {
        await changeLocation(widget.initPosition);
      }

      if (widget.staticPoints != null) {
        if (widget.staticPoints.isNotEmpty) {
          widget.staticPoints.asMap().forEach((index, points) async {
            if (points.markerIcon != null) {
              await this._osmController.customMarkerStaticPosition(
                  _staticMarkersKeys[points.id], points.id);
            }
            if (points.geoPoints != null && points.geoPoints.isNotEmpty) {
              await this
                  ._osmController
                  .staticPosition(points.geoPoints, points.id);
            }
          });
        }
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
}

class _OsmController {
  _OsmController._(int id)
      : _channel = MethodChannel('plugins.dali.hamza/osmview_$id'),
        _eventChannel = EventChannel("plugins.dali.hamza/osmview_stream_$id"),
        _eventLocationChannel =
            EventChannel("plugins.dali.hamza/osmview_stream_location_$id");

  //_eventChannel=null;

  final MethodChannel _channel;
  final EventChannel _eventChannel;
  final EventChannel _eventLocationChannel;
  StreamSubscription eventOSM, eventLocationUser;

  void myLocationListener(
      OnLocationChanged onChanged, Function(dynamic d) onError) {
    eventLocationUser =
        _eventLocationChannel.receiveBroadcastStream().listen((data) {
      if (onChanged != null) {
        GeoPoint p = GeoPoint(latitude: data["lat"], longitude: data["lon"]);
        onChanged(p);
      }
    }, onError: (e) {
      onError(e);
    });
  }

  //final EventChannel _eventChannel;
  void startListen(
      OnGeoPointClicked geoPointClicked, Function(dynamic d) onError) {
    eventOSM = _eventChannel.receiveBroadcastStream().listen((data) {
      if (geoPointClicked != null) {
        GeoPoint p = GeoPoint(latitude: data["lat"], longitude: data["lon"]);
        geoPointClicked(p);
      }
    }, onError: (err) {
      onError(err);
    });
  }

  void closeListen() {
    eventOSM?.cancel();
    eventLocationUser?.cancel();
  }

  Future<void> setSecureURL(bool secure) async {
    return await _channel.invokeMethod('use#secure', secure);
  }

  Future<void> zoom(double zoom) async {
    if (zoom != null) await _channel.invokeMethod('Zoom', zoom);
  }

  Future<void> currentLocation() async {
    await _channel.invokeMethod('currentLocation', null);
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
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      var base64Str = base64.encode(icon);
      await _channel.invokeMethod("marker#icon", base64Str);
    } else
      await _channel.invokeMethod("marker#icon", icon);
  }

  Future<void> setColorRoad(int r, int g, int b) async {
    await _channel.invokeMethod("road#color", [r, g, b]);
  }

  Future<void> setMarkersRoad(
      GlobalKey startKey, GlobalKey endKey, GlobalKey middleKey) async {
    Map<String, Uint8List> bitmaps = {};
    if (startKey.currentContext != null) {
      Uint8List marker = await _capturePng(startKey);
      bitmaps.putIfAbsent("START", () => marker);
    }
    if (endKey.currentContext != null) {
      Uint8List marker = await _capturePng(endKey);
      bitmaps.putIfAbsent("END", () => marker);
    }
    if (middleKey.currentContext != null) {
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
  Future<RoadInfo> drawRoad(GeoPoint p, GeoPoint p2) async {
    try {
      Map map = await _channel.invokeMethod("road", [
        {"lon": p.longitude, "lat": p.latitude},
        {"lon": p2.longitude, "lat": p2.latitude}
      ]);
      return RoadInfo.fromMap(map);
    } on PlatformException catch (e) {
      throw RoadException(msg: e.message);
    }
  }

  /// static custom marker
  Future<void> customMarkerStaticPosition(
      GlobalKey globalKey, String id) async {
    Uint8List icon = await _capturePng(globalKey);
    await _channel.invokeMethod(
      "staticPosition#IconMarker",
      {
        "id": id,
        "bitmap": icon,
      },
    );
  }

  ///static position
  Future<void> staticPosition(List<GeoPoint> pList, String id) async {
    try {
      List<Map<String, double>> listGeos = [];
      for (GeoPoint p in pList) {
        listGeos.add({"lon": p.longitude, "lat": p.latitude});
      }
      return await _channel
          .invokeMethod("staticPosition", {"id": id, "point": listGeos});
    } on PlatformException catch (e) {
      print(e.message);
    }
  }

  Future<void> setDefaultZoom(double defaultZoom) async {
    try {
      return await _channel.invokeMethod("defaultZoom", defaultZoom);
    } on PlatformException catch (e) {
      print(e.message);
    }
  }
}

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
  void afterFirstLayout(BuildContext context) {
    print("after layout");
  }
}
/*
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

  /// cancel StreamSubscription
  /// should be called in dispose
  void closeListen() {
    eventOSM?.cancel();
    eventLocationUser?.cancel();
  }

  /// to enable https calls of osm
  ///  [secure] : (bool)
  Future<void> setSecureURL(bool secure) async {
    return await _channel.invokeMethod('use#secure', secure);
  }

  /// [zoom] : (double) zoom value that will send to osm
  Future<void> zoom(double zoom) async {
    if (zoom != null) await _channel.invokeMethod('Zoom', zoom);
  }

  /// change map camera to current location of user
  Future<void> currentLocation() async {
    final result = await _channel.invokeMethod('currentLocation', null);
    print(result);
  }

  /// recuperate current user position
  Future<GeoPoint> myLocation() async {
    try {
      Map<String, dynamic> map =
          await _channel.invokeMapMethod("user#position", null);
      return GeoPoint(latitude: map["lat"], longitude: map["lon"]);
    } on PlatformException catch (e) {
      throw GeoPointException(msg: e.message);
    }
  }

  /// select position and show marker on it
  Future<GeoPoint> pickLocation() async {
    try {
      Map<String, dynamic> map =
          await _channel.invokeMapMethod("user#pickPosition", null);
      return GeoPoint(latitude: map["lat"], longitude: map["lon"]);
    } on PlatformException catch (e) {
      throw GeoPointException(msg: e.message);
    }
  }

  /// change marker with you own widget
  Future<void> customMarker(GlobalKey globalKey) async {
    Uint8List icon = await _capturePng(globalKey);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      var base64Str = base64.encode(icon);
      await _channel.invokeMethod("marker#icon", base64Str);
    } else
      await _channel.invokeMethod("marker#icon", icon);
  }

  /// change color of road
  Future<void> setColorRoad(int r, int g, int b) async {
    await _channel.invokeMethod("road#color", [r, g, b]);
  }

  /// change marker of road
  /// [startKey]   :(GlobalKey) key of widget of start custom marker in road
  /// [endKey]     : (GlobalKey) key of widget of end custom marker in road
  /// [middleKey] :(GlobalKey) key of widget of middle custom marker in road
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

  ///delete marker of this position
  ///[p] : (GeoPoint) position of marker that you want to remove it from the map
  Future<void> removePosition(GeoPoint p) async {
    return await _channel.invokeListMethod(
        "user#removeMarkerPosition", p.toMap());
  }

  ///delete last road draw in the map
  Future<void> removeLastRoad() async {
    return await _channel.invokeListMethod("user#removeroad");
  }

  ///draw road
  /// [start] :(GeoPoint) start point of road
  /// [end]   :(GeoPoint) destination ,last point or road
  Future<RoadInfo> drawRoad(GeoPoint start, GeoPoint end) async {
    try {
      Map map = await _channel.invokeMethod("road", [
        start.toMap(),
        end.toMap(),
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

  /// change or add static position
  /// [pList] : list of geoPoint
  /// [id] : (String) id of static position
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

  ///change default value zoom
  /// [defaultZoom] :(double) new default zoom in map
  Future<void> setDefaultZoom(double defaultZoom) async {
    try {
      return await _channel.invokeMethod("defaultZoom", defaultZoom);
    } on PlatformException catch (e) {
      print(e.message);
    }
  }

  Future<void> disableTracking() async {
    await _channel.invokeMethod('deactivateTrackMe', null);
  }
}
*/

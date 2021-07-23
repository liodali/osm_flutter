import 'dart:html' as html;
import 'dart:js_util';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import '../channel/method_channel_web.dart';
import '../interop/models/geo_point_js.dart';

import '../flutter_osm_web.dart';
import '../mixin_web_controller.dart';
import '../web_platform.dart';
import '../interop/osm_interop.dart' as interop;
WebOsmController getOSMMap() => WebOsmController();

class WebOsmController with ControllerWebMixin implements IBaseOSMController {
  late int _mapId;

  int get mapId => mapId;

  void set mapId (int mapId) {
    _mapId = mapId;
  }

  late MethodChannel? channel;
  late OsmWebWidgetState _osmWebFlutterState;

  FlutterOsmPluginWeb get webPlatform =>
      OSMPlatform.instance as FlutterOsmPluginWeb;

  WebOsmController();

  WebOsmController._(OsmWebWidgetState _osmWebFlutterState) {
    createHtml(OsmWebPlatform.idOsmWeb);
    this._osmWebFlutterState = _osmWebFlutterState;
  }

  static WebOsmController init(OsmWebWidgetState _osmWebFlutterState) {
    OSMPlatform.instance.init(OsmWebPlatform.idOsmWeb);
    return WebOsmController._(_osmWebFlutterState);
  }

  void createHtml(int idMap) {
    this._mapId = idMap;

    final body = html.window.document.querySelector('body')!;

    _frame = html.IFrameElement()
      ..id = "frame_map"
      ..src = "packages/flutter_osm_web/src/asset/map.html";

    body.append(html.ScriptElement()
      ..src = 'packages/flutter_osm_web/src/asset/map.js'
      ..type = 'application/javascript');

    ui.platformViewRegistry.registerViewFactory(
        FlutterOsmPluginWeb.getViewType(_mapId), (int viewId) => _frame);

    channel = MethodChannel(FlutterOsmPluginWeb.getViewType(_mapId));
    //print(_getViewType(_mapId));
  }

  // The Flutter widget that contains the rendered Map.
  HtmlElementView? _widget;
  late html.IFrameElement _frame;

  /// The Flutter widget that will contain the rendered Map. Used for caching.
  Widget? get widget {
    if (_widget == null) {
      _widget = HtmlElementView(
        viewType: FlutterOsmPluginWeb.getViewType(_mapId),
      );
    }
    return _widget;
  }

  void dispose() {
    channel = null;
    webPlatform.mapsController.remove(this);
  }

  @override
  Future<void> initMap({
    GeoPoint? initPosition,
    bool initWithUserPosition = false,
  }) async {
    assert(initPosition != null || initWithUserPosition == true);

    webPlatform.onLongPressMapClickListener(_mapId).listen((event) {
      _osmWebFlutterState.widget.controller.listenerMapLongTapping.value =
          event.value;
    });

    webPlatform.onSinglePressMapClickListener(_mapId).listen((event) {
      _osmWebFlutterState.widget.controller.listenerMapSingleTapping.value =
          event.value;
    });
    webPlatform.onMapIsReady(_mapId).listen((event) async {
      print(event.value);
      _osmWebFlutterState.widget.mapIsReadyListener.value = event.value;
    });

    if (_osmWebFlutterState.widget.onGeoPointClicked != null) {
      webPlatform.onGeoPointClickListener(_mapId).listen((event) {
        _osmWebFlutterState.widget.onGeoPointClicked!(event.value);
      });
    }
    if (_osmWebFlutterState.widget.onLocationChanged != null) {
      webPlatform.onUserPositionListener(_mapId).listen((event) {
        _osmWebFlutterState.widget.onLocationChanged!(event.value);
      });
      /* this._osmController.myLocationListener(widget.onLocationChanged, (err) {
          print(err);
        });*/
    }

    GeoPoint? initLocation = initPosition;

    if (initWithUserPosition) {
      initLocation = await currentLocation();
    }
    await initLocationMap(initLocation!);
  }

  Future<void> initLocationMap(GeoPoint p) async {
    await promiseToFuture(interop.initMapLocation(p._toGeoJS()));
  }



  Future<void> addPosition(GeoPoint point) async {
    await promiseToFuture(interop.addPosition(GeoPointJs(
      lat: point.latitude,
      lon: point.longitude,
    )));
  }

  Future<GeoPoint> currentLocation() async {
    Map<String, dynamic>? value =
    await html.promiseToFutureAsMap(interop.locateMe());
    if (value!.containsKey("error")) {
      throw Exception(value["message"]);
    }
    return GeoPoint.fromMap(Map<String, double>.from(value));
  }
}
extension ExtGeoPoint on GeoPoint {
  GeoPointJs _toGeoJS() {
    return GeoPointJs(
      lon: longitude,
      lat: latitude,
    );
  }
}
import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_web/src/mixin_web.dart';

import '../channel/method_channel_web.dart';
import '../interop/osm_interop.dart' as interop;
import '../osm_web.dart';
import '../web_platform.dart';

class WebOsmController with WebMixin implements IBaseOSMController {
  late int _mapId;

  int get mapId => mapId;

  void set mapId(int mapId) {
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

    if (_osmWebFlutterState.widget.markerOption?.defaultMarker != null) {
      await changeDefaultIconMarker(_osmWebFlutterState.defaultMarkerKey!);
    }
    if (_osmWebFlutterState.widget.staticIconGlobalKeys.isNotEmpty) {
      _osmWebFlutterState.widget.staticIconGlobalKeys.forEach((id, key) {
        markerIconsStaticPositions(id, key);
      });
    }

    await defaultZoom(_osmWebFlutterState.widget.defaultZoom);

    GeoPoint? initLocation = initPosition;

    if (initWithUserPosition) {
      initLocation = await myLocation();
    }
    await initLocationMap(initLocation!);

    if (_osmWebFlutterState.widget.staticPoints.isNotEmpty) {
      _osmWebFlutterState.widget.staticPoints.forEach((ele) {
        setStaticPosition(ele.geoPoints, ele.id);
      });
    }
  }

  @override
  Future<void> setIconStaticPositions(
    String id,
    MarkerIcon markerIcon,
  ) async {
    if (markerIcon.icon != null) {
      _osmWebFlutterState.widget.dynamicMarkerWidgetNotifier.value =
          markerIcon.icon;
    } else if (markerIcon.image != null) {
      _osmWebFlutterState.widget.dynamicMarkerWidgetNotifier.value = Image(
        image: markerIcon.image!,
      );
    }
    Future.delayed(Duration(milliseconds: 250), () async {
      final base64Icon =
          (await capturePng(_osmWebFlutterState.dynamicMarkerKey!))
              .convertToString();
      await interop.setIconStaticGeoPoints(
        id,
        base64Icon,
      );
    });
  }

  Future<void> markerIconsStaticPositions(
    String id,
    GlobalKey key,
  ) async {
    final base64Icon = (await capturePng(key)).convertToString();
    await interop.setIconStaticGeoPoints(
      id,
      base64Icon,
    );
  }

  Future<GeoPoint> selectPosition({
    MarkerIcon? icon,
    String imageURL = "",
  }) {
    // TODO: implement selectPosition
    throw UnimplementedError();
  }
}

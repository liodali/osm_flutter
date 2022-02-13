import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';

import '../channel/method_channel_web.dart';
import '../common/extensions.dart';
import '../interop/osm_interop.dart' as interop;
import '../mixin_web.dart';
import '../osm_web.dart';

class WebOsmController with WebMixin implements IBaseOSMController {
  late int _mapId;

  int get mapId => mapId;

  void set mapId(int mapId) {
    _mapId = mapId;
  }

  late MethodChannel? channel;
  late OsmWebWidgetState _osmWebFlutterState;

  FlutterOsmPluginWeb get webPlatform => OSMPlatform.instance as FlutterOsmPluginWeb;

  WebOsmController() {
    createHtml();
  }

  WebOsmController._(OsmWebWidgetState _osmWebFlutterState) {}

  void init(OsmWebWidgetState _osmWebFlutterState, int idMap) {
    OSMPlatform.instance.init(idMap);
    this._osmWebFlutterState = _osmWebFlutterState;
    this._mapId = idMap;
    channel = MethodChannel(FlutterOsmPluginWeb.getViewType(mapId: idMap));
  }

  void createHtml() {
    final body = html.window.document.querySelector('body')!;

    _frame = html.IFrameElement()
      ..id = "frame_map"
      ..src = "packages/flutter_osm_web/src/asset/map.html";

    body.append(html.ScriptElement()
      ..src = 'packages/flutter_osm_web/src/asset/map.js'
      ..type = 'application/javascript');

    ui.platformViewRegistry
        .registerViewFactory(FlutterOsmPluginWeb.getViewType(mapId: 0), (int viewId) => _frame);

    //print(_getViewType(_mapId));
  }

  // The Flutter widget that contains the rendered Map.
  HtmlElementView? _widget;
  late html.IFrameElement _frame;

  /// The Flutter widget that will contain the rendered Map. Used for caching.
  // Widget? get widget {
  //   if (_widget == null) {
  //     _widget = HtmlElementView(
  //       key: keyWidget,
  //       viewType: FlutterOsmPluginWeb.getViewType(_mapId),
  //     );
  //   }
  //   return _widget;
  // }

  void dispose() {
    channel = null;
    webPlatform.mapsController.remove(this);
  }

  @override
  Future<void> initPositionMap({
    GeoPoint? initPosition,
    bool initWithUserPosition = false,
  }) async {
    assert(initPosition != null || initWithUserPosition == true);

    webPlatform.onLongPressMapClickListener(_mapId).listen((event) {
      _osmWebFlutterState.widget.controller.setValueListenerMapLongTapping(event.value);
    });
    webPlatform.onSinglePressMapClickListener(_mapId).listen((event) {
      _osmWebFlutterState.widget.controller.setValueListenerMapSingleTapping(event.value);
      //event.value;
    });
    webPlatform.onMapIsReady(_mapId).listen((event) async {
      _osmWebFlutterState.widget.mapIsReadyListener.value = event.value;
      _osmWebFlutterState.widget.controller.setValueListenerMapIsReady(event.value);
      if (_osmWebFlutterState.widget.onMapIsReady != null) {
        _osmWebFlutterState.widget.onMapIsReady!(event.value);
      }
    });
    webPlatform.onRegionIsChangingListener(_mapId).listen((event) {
      print(event.value);
      _osmWebFlutterState.widget.controller.setValueListenerRegionIsChanging(event.value);
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
      await changeHomeIconMarker(_osmWebFlutterState.defaultMarkerKey!);
    }
    if (_osmWebFlutterState.widget.staticIconGlobalKeys.isNotEmpty) {
      _osmWebFlutterState.widget.staticIconGlobalKeys.forEach((id, key) {
        markerIconsStaticPositions(id, key);
      });
    }

    await configureZoomMap(
      _osmWebFlutterState.widget.minZoomLevel,
      _osmWebFlutterState.widget.maxZoomLevel,
      _osmWebFlutterState.widget.stepZoom,
      _osmWebFlutterState.widget.initZoom,
    );

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
    MarkerIcon markerIcon, {
    bool refresh = false,
  }) async {
    _osmWebFlutterState.widget.dynamicMarkerWidgetNotifier.value = markerIcon;

    Future.delayed(Duration(milliseconds: 250), () async {
      final base64Icon =
          (await capturePng(_osmWebFlutterState.dynamicMarkerKey!)).convertToString();
      await interop.setIconStaticGeoPoints(
        id,
        base64Icon,
      );
    });
  }

  @override
  Future<void> addMarker(
    GeoPoint p, {
    MarkerIcon? markerIcon,
    double? angle,
  }) async {
    if (markerIcon != null &&
        (markerIcon.icon != null  || markerIcon.assetMarker != null)) {
      _osmWebFlutterState.widget.dynamicMarkerWidgetNotifier.value =
          ((angle == null) || (angle == 0.0))
              ? markerIcon
              : Transform.rotate(
                  angle: angle,
                  child: markerIcon,
                );
      int duration = markerIcon.icon != null || markerIcon.assetMarker != null ? 300 : 350;
      Future.delayed(Duration(milliseconds: duration), () async {
        final icon = await capturePng(_osmWebFlutterState.dynamicMarkerKey!);
        await interop.addMarker(p.toGeoJS(), icon.convertToString());
      });
    }
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


}

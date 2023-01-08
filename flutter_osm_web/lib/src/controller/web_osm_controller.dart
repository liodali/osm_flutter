import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:js/js_util.dart';

import '../channel/method_channel_web.dart';
import '../common/extensions.dart';
import '../interop/osm_interop.dart' as interop;
import '../mixin_web.dart';
import '../osm_web.dart';

class WebOsmController with WebMixin implements IBaseOSMController {
  late int _mapId;
  int get mapId => _mapId;

  void set mapId(int mapId) {
    _mapId = mapId;
  }

  late MethodChannel? channel;
  AndroidLifecycleMixin? _androidOSMLifecycle;

  FlutterOsmPluginWeb get webPlatform =>
      OSMPlatform.instance as FlutterOsmPluginWeb;

  WebOsmController() {
    //createHtml(id: );
    _div = html.DivElement()
      ..id = 'osm_map'
      ..style.width = '100%'
      ..style.height = '100%';
    // ui.platformViewRegistry.registerViewFactory(
    //     FlutterOsmPluginWeb.getViewType(), (int viewId) => _div);

    ui.platformViewRegistry.registerViewFactory(
        FlutterOsmPluginWeb.getViewType(), (int viewId) => _div);
  }

  //WebOsmController._(OsmWebWidgetState _osmWebFlutterState) {}

  void init(OsmWebWidgetState osmWebFlutterState, int idMap) {
    OSMPlatform.instance.init(idMap);
    this.setWidgetState(osmWebFlutterState);
    this._mapId = idMap;
    mapIdMixin = idMap;
    channel = MethodChannel('${FlutterOsmPluginWeb.getViewType()}_$idMap');
  }

  void createHtml() {
    final body = html.window.document.querySelector('body')!;
    //final head = html.window.document.querySelector('head')!;

    _frame = html.IFrameElement()
      ..id = "frame_map_$_mapId"
      ..src = "packages/flutter_osm_web/src/asset/map.html"
      ..style.width = '100%'
      ..style.height = '100%';
    ;

    // final div = html.DivElement()
    //   ..id = 'osm_map_$_mapId'
    //   ..style.width = '100%'
    //   ..style.height = '100%';
    // _div.append(div);
    // _div.append(html.DivElement()
    //   ..id = 'render-icon-$_mapId'
    //   ..style.display = 'none');

    /*head.append(html.LinkElement()
          ..href = 'packages/flutter_osm_web/src/asset/leaflet.css'
        // ..integrity =
        //     'sha512-xodZBNTC5n17Xt2atTPuE1HxjVMSvLVW9ocqUKLsCC5CXdbqCmblAshOMAS6/keqq/sMZMZ19scR4PsZChSR7A=="'
        // ..crossOrigin = ''
        );
    final jsScript = html.ScriptElement()
      ..id = 'leaflet_osm'
      ..src = 'packages/flutter_osm_web/src/asset/leaflet.js'
      // ..integrity =
      //     'sha512-XQoYMqMTK8LvdxXYG3nZ448hOEQiglfqkJs1NOQV44cWnUrBc8PkAOcXy20w0vlaXaVUearIOBhiXZ5V3ynxwA=='
      // ..crossOrigin = ''
      ..type = 'application/javascript';
    body.append(jsScript);
    jsScript.onLoad.listen((event) {
      if (event.type == "load") {
        debugPrint('script loaded');
        body.append(html.ScriptElement()
          ..src =
              'https://cdn.jsdelivr.net/npm/leaflet-rotatedmarker@0.2.0/leaflet.rotatedMarker.min.js');
        body.append(html.ScriptElement()
          ..src = 'packages/flutter_osm_web/src/asset/map_js_ctrl.js'
          ..type = 'application/javascript');
      }
    });*/
    body.append(html.ScriptElement()
      ..src = 'packages/flutter_osm_web/src/asset/map.js'
      ..type = 'application/javascript');

    //ui.platformViewRegistry.registerViewFactory(
    //    FlutterOsmPluginWeb.getViewType(), (int viewId) => _frame);

    _div.append(_frame);

    //jsScript.addEventListener('load', (event) {});

    //print(_getViewType(_mapId));
  }

  // The Flutter widget that contains the rendered Map.
  //HtmlElementView? _widget;
  late html.IFrameElement _frame;
  late html.DivElement _div;

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

  void addObserver(AndroidLifecycleMixin androidOSMLifecycle) {
    _androidOSMLifecycle = androidOSMLifecycle;
  }

  @override
  Future<void> initPositionMap({
    GeoPoint? initPosition,
    bool initWithUserPosition = false,
  }) async {
    await promiseToFuture(interop.setUpMap(mapId));
    assert(initPosition != null || initWithUserPosition == true);

    webPlatform.onLongPressMapClickListener(_mapId).listen((event) {
      osmWebFlutterState.widget.controller
          .setValueListenerMapLongTapping(event.value);
    });
    webPlatform.onSinglePressMapClickListener(_mapId).listen((event) {
      osmWebFlutterState.widget.controller
          .setValueListenerMapSingleTapping(event.value);
      //event.value;
    });
    webPlatform.onMapIsReady(_mapId).listen((event) async {
      osmWebFlutterState.widget.mapIsReadyListener.value = event.value;
      osmWebFlutterState.widget.controller
          .setValueListenerMapIsReady(event.value);
      if (osmWebFlutterState.widget.onMapIsReady != null) {
        osmWebFlutterState.widget.onMapIsReady!(event.value);
      }
      if (_androidOSMLifecycle != null) {
        _androidOSMLifecycle!.mapIsReady(event.value);
      }
    });
    webPlatform.onRegionIsChangingListener(_mapId).listen((event) {
      print(event.value);
      osmWebFlutterState.widget.controller
          .setValueListenerRegionIsChanging(event.value);
    });

    if (osmWebFlutterState.widget.onGeoPointClicked != null) {
      webPlatform.onGeoPointClickListener(_mapId).listen((event) {
        osmWebFlutterState.widget.onGeoPointClicked!(event.value);
      });
    }
    if (osmWebFlutterState.widget.onLocationChanged != null) {
      webPlatform.onUserPositionListener(_mapId).listen((event) {
        osmWebFlutterState.widget.onLocationChanged!(event.value);
      });
      /* this._osmController.myLocationListener(widget.onLocationChanged, (err) {
          print(err);
        });*/
    }

    if (osmWebFlutterState.widget.markerOption?.defaultMarker != null) {
      await changeHomeIconMarker(osmWebFlutterState.defaultMarkerKey!);
    }
    if (osmWebFlutterState.widget.staticIconGlobalKeys.isNotEmpty) {
      var keys = osmWebFlutterState.widget.staticIconGlobalKeys;
      keys.removeWhere((key, value) =>
          osmWebFlutterState.widget.staticPoints
              .firstWhere((element) => element.id == key)
              .markerIcon ==
          null);
      keys.forEach((id, key) {
        markerIconsStaticPositions(id, key);
      });
    }
    if (osmWebFlutterState.widget.roadConfiguration != null) {
      final defaultColor =
          osmWebFlutterState.widget.roadConfiguration!.roadColor.toHexColor();
      final keyStartMarker =
          osmWebFlutterState.widget.roadConfiguration!.startIcon != null
              ? osmWebFlutterState.startIconKey != null
                  ? await capturePng(osmWebFlutterState.startIconKey!)
                  : null
              : null;
      final keyMiddleMarker =
          osmWebFlutterState.widget.roadConfiguration!.middleIcon != null
              ? osmWebFlutterState.middleIconKey != null
                  ? await capturePng(osmWebFlutterState.middleIconKey!)
                  : null
              : null;
      final keyEndMarker =
          osmWebFlutterState.widget.roadConfiguration!.endIcon != null
              ? osmWebFlutterState.endIconKey != null
                  ? await capturePng(osmWebFlutterState.endIconKey!)
                  : null
              : null;
      await interop.configRoad(
        _mapId,
        defaultColor,
        keyStartMarker?.convertToString() ?? "",
        keyMiddleMarker?.convertToString() ?? "",
        keyEndMarker?.convertToString() ?? "",
      );
    }

    if (osmWebFlutterState.widget.markerOption?.advancedPickerMarker != null) {
      if (osmWebFlutterState.advancedPickerMarker?.currentContext != null) {
        await changeIconAdvPickerMarker(
            osmWebFlutterState.advancedPickerMarker!);
      }
    }
    if (osmWebFlutterState.widget.markerOption?.advancedPickerMarker == null) {
      osmWebFlutterState.widget.dynamicMarkerWidgetNotifier.value = Icon(
        Icons.location_on,
        color: Colors.red,
        size: 32,
      );
      Future.delayed(const Duration(milliseconds: 300), () async {
        await changeIconAdvPickerMarker(osmWebFlutterState.dynamicMarkerKey!);
      });
    }

    /// change user person Icon and arrow Icon
    if (osmWebFlutterState.widget.userLocationMarker != null) {
      await customUserLocationMarker(
        osmWebFlutterState.personIconMarkerKey,
      );
    }

    await configureZoomMap(
      osmWebFlutterState.widget.minZoomLevel,
      osmWebFlutterState.widget.maxZoomLevel,
      osmWebFlutterState.widget.stepZoom,
      osmWebFlutterState.widget.initZoom,
    );

    GeoPoint? initLocation = initPosition;

    if (initWithUserPosition) {
      initLocation = await myLocation();
    }
    await initLocationMap(initLocation!);

    if (osmWebFlutterState.widget.staticPoints.isNotEmpty) {
      osmWebFlutterState.widget.staticPoints.forEach((ele) {
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
    osmWebFlutterState.widget.dynamicMarkerWidgetNotifier.value = markerIcon;

    await Future.delayed(Duration(milliseconds: 250), () async {
      final base64Icon =
          (await capturePng(osmWebFlutterState.dynamicMarkerKey!))
              .convertToString();
      await interop.setIconStaticGeoPoints(
        _mapId,
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
    Widget? icon = markerIcon;
    if (icon == null) {
      icon = Icon(
        Icons.location_on,
        size: 32,
        color: Colors.red,
      );
    }
    osmWebFlutterState.widget.dynamicMarkerWidgetNotifier.value =
        ((angle == null) || (angle == 0.0))
            ? icon
            : Transform.rotate(
                angle: angle,
                child: icon,
              );
    int duration = 350;
    await Future.delayed(Duration(milliseconds: duration), () async {
      final icon = await capturePng(osmWebFlutterState.dynamicMarkerKey!);
      interop.addMarker(_mapId, p.toGeoJS(), icon.convertToString());
    });
  }

  Future<void> markerIconsStaticPositions(
    String id,
    GlobalKey key,
  ) async {
    final base64Icon = (await capturePng(key)).convertToString();
    await interop.setIconStaticGeoPoints(
      _mapId,
      id,
      base64Icon,
    );
  }

  @override
  Future<void> setIconMarker(GeoPoint point, MarkerIcon markerIcon) async {
    osmWebFlutterState.widget.dynamicMarkerWidgetNotifier.value = markerIcon;
    await Future.delayed(Duration(milliseconds: 300), () async {
      final icon = await capturePng(osmWebFlutterState.dynamicMarkerKey!);
      final jsP = point.toGeoJS();
      await interop.modifyMarker(_mapId, jsP, icon.convertToString());
    });
  }

  @override
  Future changeDefaultIconMarker(MarkerIcon homeMarker) async {
    osmWebFlutterState.widget.dynamicMarkerWidgetNotifier.value = homeMarker;
    await Future.delayed(Duration(milliseconds: 300), () async {
      final icon = await capturePng(osmWebFlutterState.dynamicMarkerKey!);
      await interop.setDefaultIcon(_mapId, icon.convertToString());
    });
  }

  @override
  Future<void> changeMarker({
    required GeoPoint oldLocation,
    required GeoPoint newLocation,
    MarkerIcon? newMarkerIcon,
  }) async {
    var duration = 0;
    if (newMarkerIcon != null) {
      duration = 300;
      osmWebFlutterState.widget.dynamicMarkerWidgetNotifier.value =
          newMarkerIcon;
    }
    await Future.delayed(Duration(milliseconds: duration), () async {
      var icon = null;
      if (newMarkerIcon != null) {
        final iconPNG = await capturePng(osmWebFlutterState.dynamicMarkerKey!);
        icon = iconPNG.convertToString();
      }
      await interop.changeMarker(
        _mapId,
        oldLocation.toGeoJS(),
        newLocation.toGeoJS(),
        icon,
      );
    });
  }

  @override
  Future changeIconAdvPickerMarker(GlobalKey<State<StatefulWidget>> key) async {
    var base64 = "";
    try {
      base64 = (await capturePng(key)).convertToString();
    } finally {
      await interop.changeIconAdvPickerMarker(_mapId, base64, _mapId);
    }
  }

  @override
  Future<void> advancedPositionPicker() async {
    await interop.advSearchLocation(_mapId);
  }

  @override
  Future<void> cancelAdvancedPositionPicker() async {
    await interop.cancelAdvSearchLocation(_mapId);
  }

  Future<GeoPoint> selectAdvancedPositionPicker() async {
    Map<String, dynamic>? value =
        await html.promiseToFutureAsMap(interop.centerMap(
      _mapId,
    ));
    if (value!.containsKey("error")) {
      throw Exception(value["message"]);
    }
    final gp = GeoPoint.fromMap(Map<String, double>.from(value));

    await cancelAdvancedPositionPicker();
    changeLocation(gp);
    return gp;
  }

  Future customUserLocationMarker(
      GlobalKey<State<StatefulWidget>> personIconMarkerKey) async {
    if (personIconMarkerKey.currentContext != null) {
      final iconPNG = (await capturePng(personIconMarkerKey)).convertToString();
      interop.setUserLocationIconMarker(_mapId, iconPNG);
    }
  }
}

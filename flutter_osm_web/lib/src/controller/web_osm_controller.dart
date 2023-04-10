import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';

import 'package:flutter_osm_web/src/channel/method_channel_web.dart';
import 'package:flutter_osm_web/src/common/extensions.dart';
import 'package:flutter_osm_web/src/interop/osm_interop.dart' as interop;
import 'package:flutter_osm_web/src/mixin_web.dart';
import 'package:flutter_osm_web/src/osm_web.dart';

int mapId = 0;

class WebOsmController with WebMixin implements IBaseOSMController {
  late MethodChannel? channel;
  AndroidLifecycleMixin? _androidOSMLifecycle;

  FlutterOsmPluginWeb get webPlatform =>
      OSMPlatform.instance as FlutterOsmPluginWeb;

  WebOsmController() {
    //createHtml(id: );
    mapId++;
    _div = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%';
    // ui.platformViewRegistry.registerViewFactory(
    //     FlutterOsmPluginWeb.getViewType(), (int viewId) => _div);
    ui.platformViewRegistry.registerViewFactory(
        FlutterOsmPluginWeb.getViewType(mapId), (int viewId) {
      debugPrint("viewId : $viewId");
      mapId = viewId;
      _div.id = 'osm_map_$viewId';
      return _div;
    });
  }

  //WebOsmController._(OsmWebWidgetState _osmWebFlutterState) {}

  void init(OsmWebWidgetState osmWebFlutterState, int idMap) {
    debugPrint("idMap $idMap");
    OSMPlatform.instance.init(idMap);
    this.setWidgetState(osmWebFlutterState);
    mapIdMixin = idMap;
    channel = MethodChannel('${FlutterOsmPluginWeb.getViewType(idMap)}');
    debugPrint("in init _mapId $mapId");
  }

  void createHtml() {
    final body = html.window.document.querySelector('body')!;
    _frame = html.IFrameElement()
      ..id = "frame_map_$mapId"
      ..src = "packages/flutter_osm_web/src/asset/map.html"
      ..style.width = '100%'
      ..style.height = '100%';

    if (html.window.document.getElementById("mapScript") == null) {
      mapScript = html.ScriptElement()
        ..id = "mapScript"
        ..src = 'packages/flutter_osm_web/src/asset/map.js'
        ..type = 'application/javascript';
      body.append(mapScript!);
    }

    _div.append(_frame!);
  }

  // The Flutter widget that contains the rendered Map.
  //HtmlElementView? _widget;
  html.IFrameElement? _frame;
  late html.DivElement _div;
  html.ScriptElement? mapScript;

  void dispose() {
    _div.remove();
    _frame = null;
    mapScript?.remove();
    webPlatform.close(mapId);
    channel = null;
    webPlatform.mapsController.remove(this);
  }

  @override
  Future<void> initPositionMap({
    GeoPoint? initPosition,
    bool initWithUserPosition = false,
  }) async {
    interop.setUpMap(mapId);
    assert(initPosition != null || initWithUserPosition == true);

    webPlatform.onLongPressMapClickListener(mapId).listen((event) {
      osmWebFlutterState.widget.controller
          .setValueListenerMapLongTapping(event.value);
      osmWebFlutterState.widget.controller.osMMixins.forEach((osmMixin) {
        osmMixin.onLongTap(event.value);
      });
    });
    webPlatform.onSinglePressMapClickListener(mapId).listen((event) {
      osmWebFlutterState.widget.controller
          .setValueListenerMapSingleTapping(event.value);
      osmWebFlutterState.widget.controller.osMMixins.forEach((osmMixin) {
        osmMixin.onSingleTap(event.value);
      });
    });
    webPlatform.onMapIsReady(mapId).listen((event) async {
      osmWebFlutterState.widget.mapIsReadyListener.value = event.value;
      osmWebFlutterState.widget.controller
          .setValueListenerMapIsReady(event.value);
      if (osmWebFlutterState.widget.onMapIsReady != null) {
        osmWebFlutterState.widget.onMapIsReady!(event.value);
      }
      if (osmWebFlutterState.widget.controller.osMMixins.isNotEmpty) {
        osmWebFlutterState.widget.controller.osMMixins.forEach((element) async {
          await element.mapIsReady(event.value);
        });
      }
      if (_androidOSMLifecycle != null) {
        _androidOSMLifecycle!.mapIsReady(event.value);
      }
    });
    webPlatform.onRegionIsChangingListener(mapId).listen((event) {
      print(event.value);
      osmWebFlutterState.widget.controller
          .setValueListenerRegionIsChanging(event.value);
      osmWebFlutterState.widget.controller.osMMixins.forEach((osmMixin) {
        osmMixin.onRegionChanged(event.value);
      });
    });
    webPlatform.onRoadMapClickListener(mapId).listen((event) {
      osmWebFlutterState.widget.controller
          .setValueListenerMapRoadTapping(event.value);
      osmWebFlutterState.widget.controller.osMMixins.forEach((osmMixin) {
        osmMixin.onRoadTap(event.value);
      });
    });

    if (osmWebFlutterState.widget.onGeoPointClicked != null) {
      webPlatform.onGeoPointClickListener(mapId).listen((event) {
        osmWebFlutterState.widget.onGeoPointClicked!(event.value);
      });
    }
    if (osmWebFlutterState.widget.onLocationChanged != null) {
      webPlatform.onUserPositionListener(mapId).listen((event) {
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
      defaultRoadOption = osmWebFlutterState.widget.roadConfiguration!;
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
        mapId,
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
      interop.addMarker(mapId, p.toGeoJS(), icon.convertToString());
    });
  }

  Future<void> markerIconsStaticPositions(
    String id,
    GlobalKey key,
  ) async {
    final base64Icon = (await capturePng(key)).convertToString();
    await interop.setIconStaticGeoPoints(
      mapId,
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
      await interop.modifyMarker(mapId, jsP, icon.convertToString());
    });
  }

  @override
  Future changeDefaultIconMarker(MarkerIcon homeMarker) async {
    osmWebFlutterState.widget.dynamicMarkerWidgetNotifier.value = homeMarker;
    await Future.delayed(Duration(milliseconds: 300), () async {
      final icon = await capturePng(osmWebFlutterState.dynamicMarkerKey!);
      await interop.setDefaultIcon(mapId, icon.convertToString());
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
        mapId,
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
      await interop.changeIconAdvPickerMarker(mapId, base64, mapId);
    }
  }

  @override
  Future<void> advancedPositionPicker() async {
    await interop.advSearchLocation(mapId);
  }

  @override
  Future<void> cancelAdvancedPositionPicker() async {
    await interop.cancelAdvSearchLocation(mapId);
  }

  Future<GeoPoint> selectAdvancedPositionPicker() async {
    Map<String, dynamic>? value =
        await html.promiseToFutureAsMap(interop.centerMap(
      mapId,
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
      interop.setUserLocationIconMarker(mapId, iconPNG);
    }
  }
}

//import 'dart:html' as html;
//import 'dart:html';
import 'dart:js_interop';
import 'package:web/web.dart' as web; // Add
import 'dart:math';
import 'dart:ui_web' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';

import 'package:flutter_osm_web/src/channel/method_channel_web.dart';
import 'package:flutter_osm_web/src/common/extensions.dart';
import 'package:flutter_osm_web/src/interop/models/geo_point_js.dart';
import 'package:flutter_osm_web/src/interop/osm_interop.dart' as interop;
import 'package:flutter_osm_web/src/mixin_web.dart';
import 'package:flutter_osm_web/src/osm_web.dart';

int mapId = 0;

final class WebOsmController with WebMixin implements IBaseOSMController {
  late MethodChannel? channel;
  AndroidLifecycleMixin? _androidOSMLifecycle;
  final Duration duration = const Duration(milliseconds: 300);
  FlutterOsmPluginWeb get webPlatform =>
      OSMPlatform.instance as FlutterOsmPluginWeb;

  WebOsmController() {
    //createHtml(id: );
    mapId++;

    // ui.platformViewRegistry.registerViewFactory(
    //     FlutterOsmPluginWeb.getViewType(), (int viewId) => _div);
    mapIdMixin = mapId;
    _div = web.document.createElement('div')
        as web.HTMLDivElement; //web.HTMLDivElement(); //html.DivElement()
    _div.style.width = '100%';
    _div.style.height = '100%';
    ui.platformViewRegistry.registerViewFactory(
        FlutterOsmPluginWeb.getViewType(mapId), (int viewId) {
      debugPrint("viewId : $viewId");
      _div.id = 'osm_map_$mapIdMixin';
      final idFrame = "frame_map_$mapIdMixin";
      debugPrint(idFrame);
      _frame = web.document.createElement("iframe") as web.HTMLIFrameElement
        ..id = idFrame
        ..src =
            "${kReleaseMode ? "assets/" : ''}packages/flutter_osm_web/src/asset/map.html"
        ..allow = "cross-origin-anonymous"
        //..crossOrigin = "anonymous"
        ..style.width = '100%'
        ..style.height = '100%';
      _div.appendChild(_frame!);
      return _div;
    });
  }

  void init(OsmWebWidgetState osmWebFlutterState, int idMap) {
    debugPrint("idMap $idMap");
    OSMPlatform.instance.init(mapIdMixin);
    //mapIdMixin = idMap;
    setWidgetState(osmWebFlutterState);
    channel = MethodChannel(FlutterOsmPluginWeb.getViewType(mapIdMixin));
    debugPrint("in init _mapId $mapIdMixin");
    if (osmWebFlutterState.widget.isStatic) {
      Future.delayed(const Duration(seconds: 1), () async {
        await removeMapControls();
      });
    }
  }

  void createHtml() {
    final body = web.window.document.querySelector('body')!;

    debugPrint("div added iframe");
    if (web.window.document.getElementById("osm_interop") == null) {
      body.appendChild(
          web.document.createElement('script') as web.HTMLScriptElement
            ..id = "osm_interop"
            ..src =
                '${kReleaseMode ? "assets/" : ''}packages/flutter_osm_web/src/asset/osm_interop.js'
            ..type = 'application/javascript');
    }
    if (web.window.document.getElementById("mapScript") == null) {
      mapScript = web.document.createElement('script') as web.HTMLScriptElement
        ..id = "mapScript"
        ..src =
            '${kReleaseMode ? "assets/" : ''}packages/flutter_osm_web/src/asset/map.js'
        ..type = 'application/javascript';
      body.appendChild(mapScript!);
    }
  }

  // The Flutter widget that contains the rendered Map.
  //HtmlElementView? _widget;
  web.HTMLIFrameElement? _frame;
  late web.HTMLDivElement _div;
  web.HTMLScriptElement? mapScript;

  void dispose() {
    debugPrint("delete frame_map_$mapIdMixin");
    debugPrint("delete osm_map_$mapIdMixin");
    web.window.document.getElementById("frame_map_$mapIdMixin")?.remove();
    web.window.document.getElementById("osm_map_$mapIdMixin")?.remove();
    //_div.remove();
    _frame?.remove();
    _frame = null;
    //mapScript?.remove();
    webPlatform.close(mapIdMixin);
    channel = null;
    webPlatform.mapsController.removeWhere((key, value) => key == mapIdMixin);
  }

  @override
  Future<void> initPositionMap({
    GeoPoint? initPosition,
    UserTrackingOption? userPositionOption,
    bool useExternalTracking = false,
  }) async {
    interop.setUpMap(mapIdMixin.toJS);
    assert((initPosition != null) ^ (userPositionOption != null));
    if (osmWebFlutterState.widget.controller.customTile != null) {
      await changeTileLayer(
        tileLayer: osmWebFlutterState.widget.controller.customTile,
      );
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

    /// change user person Icon and arrow Icon
    if (osmWebFlutterState.widget.userLocationMarker != null) {
      await customUserLocationMarker(
        osmWebFlutterState.personIconMarkerKey,
        osmWebFlutterState.arrowDirectionMarkerKey,
      );
    }

    await configureZoomMap(
      osmWebFlutterState.widget.minZoomLevel,
      osmWebFlutterState.widget.maxZoomLevel,
      osmWebFlutterState.widget.stepZoom,
      osmWebFlutterState.widget.initZoom,
    );

    GeoPoint? initLocation = initPosition;

    if (userPositionOption != null && initLocation == null) {
      initLocation = await myLocation();
    }
    await initLocationMap(initLocation!);

    if (osmWebFlutterState.widget.staticPoints.isNotEmpty) {
      for (var ele in osmWebFlutterState.widget.staticPoints) {
        setStaticPosition(ele.geoPoints, ele.id);
      }
    }
    if (userPositionOption != null && userPositionOption.enableTracking) {
      switch (useExternalTracking) {
        case true:
          await startLocationUpdating();
          break;
        case false:
          await currentLocation();
          await enableTracking(
            enableStopFollow: userPositionOption.unFollowUser,
          );
          break;
      }
    }
  }

  void onListenToNativeChannel() {
    webPlatform.onLongPressMapClickListener(mapIdMixin).listen((event) {
      osmWebFlutterState.widget.controller
          .setValueListenerMapLongTapping(event.value);
      for (var osmMixin in osmWebFlutterState.widget.controller.osMMixins) {
        osmMixin.onLongTap(event.value);
      }
    });
    webPlatform.onSinglePressMapClickListener(mapIdMixin).listen((event) {
      osmWebFlutterState.widget.controller
          .setValueListenerMapSingleTapping(event.value);
      for (var osmMixin in osmWebFlutterState.widget.controller.osMMixins) {
        osmMixin.onSingleTap(event.value);
      }
    });
    webPlatform.onMapIsReady(mapIdMixin).listen((event) async {
      osmWebFlutterState.widget.mapIsReadyListener.value = event.value;
      osmWebFlutterState.widget.controller
          .setValueListenerMapIsReady(event.value);
      osmWebFlutterState.widget.onMapIsReady?.call(event.value);
      if (osmWebFlutterState.widget.controller.osMMixins.isNotEmpty) {
        Future.forEach(osmWebFlutterState.widget.controller.osMMixins,
            (osmMixin) async {
          osmMixin.mapIsReady(event.value);
        });
      }
      if (_androidOSMLifecycle != null) {
        _androidOSMLifecycle!.mapIsReady(event.value);
      }
    });
    webPlatform.onRegionIsChangingListener(mapIdMixin).listen((event) {
      osmWebFlutterState.widget.onMapMoved?.call(event.value);
      osmWebFlutterState.widget.controller
          .setValueListenerRegionIsChanging(event.value);
      for (var osmMixin in osmWebFlutterState.widget.controller.osMMixins) {
        osmMixin.onRegionChanged(event.value);
      }
    });
    webPlatform.onRoadMapClickListener(mapIdMixin).listen((event) {
      osmWebFlutterState.widget.controller
          .setValueListenerMapRoadTapping(event.value);
      for (var osmMixin in osmWebFlutterState.widget.controller.osMMixins) {
        osmMixin.onRoadTap(event.value);
      }
    });
    webPlatform.onGeoPointClickListener(mapIdMixin).listen((event) {
      osmWebFlutterState.widget.onGeoPointClicked?.call(event.value);
      for (final osmMixin in osmWebFlutterState.widget.controller.osMMixins) {
        osmMixin.onMarkerClicked(event.value);
      }
    });
    webPlatform.onGeoPointLongPressListener(mapIdMixin).listen((event) {
      osmWebFlutterState.widget.onGeoPointLongPress?.call(event.value);
      for (final osmMixin in osmWebFlutterState.widget.controller.osMMixins) {
        osmMixin.onMarkerLongPress(event.value);
      }
    });
    webPlatform.onUserPositionListener(mapIdMixin).listen((event) {
      osmWebFlutterState.widget.onLocationChanged?.call(event.value);

      for (var osmMixin in osmWebFlutterState.widget.controller.osMMixins) {
        osmMixin.onLocationChanged(event.value);
      }
    });
  }

  @override
  Future<void> setIconStaticPositions(
    String id,
    MarkerIcon markerIcon, {
    bool refresh = false,
  }) async {
    osmWebFlutterState.widget.dynamicMarkerWidgetNotifier.value = markerIcon;

    await Future.delayed(duration, () async {
      final base64Icon =
          (await capturePng(osmWebFlutterState.dynamicMarkerKey!))
              .convertToString();
      await interop
          .setIconStaticGeoPoints(
            mapIdMixin.toJS,
            id.toJS,
            base64Icon.toJS,
          )
          .toDart;
    });
  }

  @override
  Future<void> addMarker(
    GeoPoint p, {
    MarkerIcon? markerIcon,
    String? assetAnimatedIconMarker,
    double? angle,
    IconAnchor? iconAnchor,
  }) async {
    Widget? icon = markerIcon ??
        const Icon(
          Icons.location_on,
          size: 32,
          color: Colors.red,
        );
    osmWebFlutterState.widget.dynamicMarkerWidgetNotifier.value = icon;
    await Future.delayed(duration, () async {
      final icon = await capturePng(osmWebFlutterState.dynamicMarkerKey!);
      var sizeIcon = osmWebFlutterState.dynamicMarkerKey!.currentContext?.size;
      IconAnchorJS? anchor;
      if (iconAnchor != null) {
        anchor = iconAnchor.toAnchorJS;
      }
      interop.addMarker(
        mapIdMixin.toJS,
        p.toGeoJS(),
        sizeIcon.toSizeJS(),
        icon.convertToString().toJS,
        (angle != null ? (angle * (180 / pi)) : 0).toJS,
        anchor,
      );
    });
  }

  Future<void> markerIconsStaticPositions(
    String id,
    GlobalKey key,
  ) async {
    final base64Icon = (await capturePng(key)).convertToString();
    await interop
        .setIconStaticGeoPoints(
          mapIdMixin.toJS,
          id.toJS,
          base64Icon.toJS,
        )
        .toDart;
  }

  @override
  Future<void> setIconMarker(GeoPoint point, MarkerIcon markerIcon) async {
    osmWebFlutterState.widget.dynamicMarkerWidgetNotifier.value = markerIcon;
    await Future.delayed(duration, () async {
      final icon = await capturePng(osmWebFlutterState.dynamicMarkerKey!);
      final size = osmWebFlutterState.dynamicMarkerKey?.currentContext?.size;
      final iconSize = size.toSizeJS();
      final jsP = point.toGeoJS();
      debugPrint("setIconMarker");
      await interop
          .changeMarker(
            mapIdMixin.toJS,
            jsP,
            null,
            icon.convertToString().toJS,
            iconSize,
            null,
            null,
          )
          //.modifyMarker(mapIdMixin.toJS, jsP, icon.convertToString().toJS)
          .toDart;
    });
  }

  @override
  Future<void> changeMarker({
    required GeoPoint oldLocation,
    required GeoPoint newLocation,
    MarkerIcon? newMarkerIcon,
    double? angle,
    IconAnchor? iconAnchor,
  }) async {
    var duration = 0;
    if (newMarkerIcon != null) {
      duration = 300;
      osmWebFlutterState.widget.dynamicMarkerWidgetNotifier.value =
          newMarkerIcon;
    }
    await Future.delayed(Duration(milliseconds: duration), () async {
      String? icon;
      SizeJs? iconSize;
      if (newMarkerIcon != null) {
        final iconPNG = await capturePng(osmWebFlutterState.dynamicMarkerKey!);
        icon = iconPNG.convertToString();
        final size = osmWebFlutterState.dynamicMarkerKey?.currentContext?.size;
        iconSize = size.toSizeJS();
      }
      await interop
          .changeMarker(
            mapIdMixin.toJS,
            oldLocation.toGeoJS(),
            newLocation.toGeoJS(),
            icon?.toJS,
            iconSize,
            (angle != null ? (angle * (180 / pi)).toJS : null),
            iconAnchor?.toAnchorJS,
          )
          .toDart;
    });
  }

  Future customUserLocationMarker(
    GlobalKey<State<StatefulWidget>> personIconMarkerKey,
    GlobalKey<State<StatefulWidget>> directionIconMarkerKey,
  ) async {
    if (personIconMarkerKey.currentContext != null) {
      final iconPNG = (await capturePng(personIconMarkerKey)).convertToString();
      final size = personIconMarkerKey.toSizeJS();
      interop.setUserLocationIconMarker(mapIdMixin.toJS, iconPNG, size);
    }
    if (directionIconMarkerKey.currentContext != null) {
      final iconPNG =
          (await capturePng(directionIconMarkerKey)).convertToString();
      final size = directionIconMarkerKey.toSizeJS();
      interop.setUserLocationDirectionIconMarker(
        mapIdMixin.toJS,
        iconPNG.toJS,
        size,
      );
    }
  }
}

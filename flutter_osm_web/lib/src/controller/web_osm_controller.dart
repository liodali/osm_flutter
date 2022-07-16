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
  AndroidLifecycleMixin? _androidOSMLifecycle;

  FlutterOsmPluginWeb get webPlatform =>
      OSMPlatform.instance as FlutterOsmPluginWeb;

  WebOsmController() {
    createHtml();
  }

  //WebOsmController._(OsmWebWidgetState _osmWebFlutterState) {}

  void init(OsmWebWidgetState osmWebFlutterState, int idMap) {
    OSMPlatform.instance.init(idMap);
    this.setWidgetState(osmWebFlutterState);
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

    ui.platformViewRegistry.registerViewFactory(
        FlutterOsmPluginWeb.getViewType(mapId: 0), (int viewId) => _frame);

    //print(_getViewType(_mapId));
  }

  // The Flutter widget that contains the rendered Map.
  //HtmlElementView? _widget;
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

  void addObserver(AndroidLifecycleMixin androidOSMLifecycle) {
    _androidOSMLifecycle = androidOSMLifecycle;
  }

  @override
  Future<void> initPositionMap({
    GeoPoint? initPosition,
    bool initWithUserPosition = false,
  }) async {
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
      osmWebFlutterState.widget.staticIconGlobalKeys.forEach((id, key) {
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
      interop.addMarker(p.toGeoJS(), icon.convertToString());
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

  @override
  Future<void> setIconMarker(GeoPoint point, MarkerIcon markerIcon) async {
    osmWebFlutterState.widget.dynamicMarkerWidgetNotifier.value = markerIcon;
    await Future.delayed(Duration(milliseconds: 300), () async {
      final icon = await capturePng(osmWebFlutterState.dynamicMarkerKey!);
      final jsP = point.toGeoJS();
      await interop.modifyMarker(jsP, icon.convertToString());
    });
  }

  @override
  Future changeDefaultIconMarker(MarkerIcon homeMarker) async {
    osmWebFlutterState.widget.dynamicMarkerWidgetNotifier.value = homeMarker;
    await Future.delayed(Duration(milliseconds: 300), () async {
      final icon = await capturePng(osmWebFlutterState.dynamicMarkerKey!);
      await interop.setDefaultIcon(icon.convertToString());
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
        oldLocation.toGeoJS(),
        newLocation.toGeoJS(),
        icon,
      );
    });
  }
}

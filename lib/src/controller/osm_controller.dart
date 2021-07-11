import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:location/location.dart';

import '../common/utilities.dart';
import '../interface_osm/osm_interface.dart';
import '../types/shape_osm.dart';
import '../types/types.dart';
import 'base_map_controller.dart';

final OSMPlatform osmPlatform = OSMPlatform.instance;

class OSMController {
  late int _idMap;
  late OSMFlutterState _osmFlutterState;

  OSMController();

  OSMController._(this._idMap, this._osmFlutterState);

  static Future<OSMController> init(
    int id,
    OSMFlutterState osmState,
  ) async {
    await osmPlatform.init(id);
    return OSMController._(id, osmState);
  }

  /// dispose: close stream in osmPlatform,remove references
  void dispose() {
    osmPlatform.close();
  }

  /// initMap: initialisation of osm map
  /// [initPosition] : (geoPoint) animate map to initPosition
  /// [initWithUserPosition] : set map in user position
  Future<void> initMap({
    GeoPoint? initPosition,
    bool initWithUserPosition = false,
  }) async {
    osmPlatform.setDefaultZoom(_idMap, _osmFlutterState.widget.defaultZoom);

    if (_osmFlutterState.widget.showDefaultInfoWindow == true) {
      osmPlatform.visibilityInfoWindow(
          _idMap, _osmFlutterState.widget.showDefaultInfoWindow);
    }

    /// listen to data send from native map

    osmPlatform.onLongPressMapClickListener(_idMap).listen((event) {
      _osmFlutterState.widget.controller.listenerMapLongTapping.value =
          event.value;
    });

    osmPlatform.onSinglePressMapClickListener(_idMap).listen((event) {
      _osmFlutterState.widget.controller.listenerMapSingleTapping.value =
          event.value;
    });

    if (_osmFlutterState.widget.onGeoPointClicked != null) {
      osmPlatform.onGeoPointClickListener(_idMap).listen((event) {
        _osmFlutterState.widget.onGeoPointClicked!(event.value);
      });
    }
    if (_osmFlutterState.widget.onLocationChanged != null) {
      osmPlatform.onUserPositionListener(_idMap).listen((event) {
        _osmFlutterState.widget.onLocationChanged!(event.value);
      });
      /* this._osmController.myLocationListener(widget.onLocationChanged, (err) {
          print(err);
        });*/
    }
    if (Platform.isIOS) {
      await osmPlatform.initIosMap(_idMap);
    }

    /// change default icon  marker
    final defaultIcon = _osmFlutterState.widget.markerOption
            ?.copyWith(defaultMarker: _osmFlutterState.widget.markerIcon) ??
        _osmFlutterState.widget.markerIcon;

    if (defaultIcon != null) {
      await changeDefaultIconMarker(_osmFlutterState.defaultMarkerKey);
    }

    /// change advanced picker icon marker
    if (_osmFlutterState.widget.markerOption?.advancedPickerMarker != null) {
      await changeIconAdvPickerMarker(_osmFlutterState.advancedPickerMarker);
    }

    /// init location in map
    if (initWithUserPosition && !_osmFlutterState.widget.isPicker) {
      initPosition = await myLocation();
    }
    if (initPosition != null) await changeLocation(initPosition);

    /// draw static position
    if (_osmFlutterState.widget.staticPoints.isNotEmpty) {
      _osmFlutterState.widget.staticPoints
          .asMap()
          .forEach((index, points) async {
        if (points.markerIcon != null) {
          await osmPlatform.customMarkerStaticPosition(
            _idMap,
            _osmFlutterState.staticMarkersKeys[points.id],
            points.id,
            colorIcon: points.markerIcon?.icon?.color ?? null,
          );
        }
        if (points.geoPoints != null && points.geoPoints!.isNotEmpty) {
          await osmPlatform.staticPosition(
              _idMap, points.geoPoints!, points.id);
        }
      });
    }

    /// road configuration
    if (_osmFlutterState.widget.road != null) {
      await showDialog(
          context: _osmFlutterState.context,
          barrierDismissible: false,
          builder: (ctx) {
            return JobAlertDialog(
              callback: () async {
                await _initializeRoadInformation();
                Navigator.pop(ctx);
              },
            );
          });
    }

    /// picker config
    if (_osmFlutterState.widget.isPicker) {
      bool granted = await _osmFlutterState.requestPermission();
      if (!granted) {
        throw Exception("you should open gps to get current position");
      }
      await _osmFlutterState.checkService();
      GeoPoint? p = _osmFlutterState.widget.controller.initPosition;
      if (p == null && initWithUserPosition) {
        try {
          p = await osmPlatform.myLocation(_idMap);
        } catch (e) {
          p = (await Location().getLocation()).toGeoPoint();
        }
      }
      await osmPlatform.addPosition(_idMap, p!);
      await osmPlatform.advancedPositionPicker(_idMap);
    }
  }

  Future _initializeRoadInformation() async {
    await osmPlatform.setColorRoad(
      _idMap,
      _osmFlutterState.widget.road!.roadColor,
    );
    await osmPlatform.setMarkersRoad(
      _idMap,
      [
        _osmFlutterState.startIconKey,
        _osmFlutterState.endIconKey,
        _osmFlutterState.middleIconKey
      ],
    );
  }

  ///initialise or change of position
  ///
  /// [p] : (GeoPoint) position that will be added to map
  Future<void> changeLocation(GeoPoint p) async {
    await osmPlatform.addPosition(_idMap, p);
  }

  ///remove marker from map of position
  /// [p] : geoPoint
  Future<void> removeMarker(GeoPoint p) async {
    await osmPlatform.removePosition(_idMap, p);
  }

  ///change Icon Marker
  /// we need to global key to recuperate widget from tree element
  /// [key] : (GlobalKey) key of widget that represent the new marker
  Future changeDefaultIconMarker(GlobalKey? key) async {
    await osmPlatform.customMarker(_idMap, key);
  }

  ///change Icon  of advanced picker Marker
  /// we need to global key to recuperate widget from tree element
  /// [key] : (GlobalKey) key of widget that represent the new marker
  Future changeIconAdvPickerMarker(GlobalKey key) async {
    await osmPlatform.customAdvancedPickerMarker(_idMap, key);
  }

  /// change static position in runtime
  ///  [geoPoints] : list of static geoPoint
  ///  [id] : String of that list of static geoPoint
  Future<void> setStaticPosition(List<GeoPoint> geoPoints, String id) async {
    List<StaticPositionGeoPoint?> staticGeoPosition =
        _osmFlutterState.widget.staticPoints;
    assert(
        staticGeoPosition.firstWhere((p) => p?.id == id, orElse: () => null) !=
            null,
        "no static geo points has been found,you should create it before!");
    await osmPlatform.staticPosition(_idMap, geoPoints, id);
  }

  /// zoom in/out
  ///
  /// [zoom] : (double) positive value:zoomIN or negative value:zoomOut
  Future<void> zoom(double zoom) async {
    assert(zoom != 0, "zoom value should different from zero");
    await osmPlatform.zoom(_idMap, zoom);
  }

  /// zoomIn use defaultZoom
  ///
  /// positive value:zoomIN
  Future<void> zoomIn() async {
    await osmPlatform.zoom(_idMap, 0);
  }

  /// zoomOut use defaultZoom
  ///
  /// negative value:zoomOut
  Future<void> zoomOut() async {
    await osmPlatform.zoom(_idMap, -1);
  }

  /// activate current location position
  Future<void> currentLocation() async {
    bool granted = await _osmFlutterState.requestPermission();
    if (!granted) {
      throw Exception("Location permission not granted");
    }
    bool isEnabled = await _osmFlutterState.checkService();
    if (!isEnabled) {
      throw Exception("turn on GPS service");
    }
    await osmPlatform.currentLocation(_idMap);
  }

  /// recuperation of user current position
  Future<GeoPoint> myLocation() async {
    return await osmPlatform.myLocation(_idMap);
  }

  /// go to specific position without create marker
  ///
  /// [p] : (GeoPoint) desired location
  Future<void> goToPosition(GeoPoint p) async {
    await osmPlatform.goToPosition(_idMap, p);
  }

  /// enabled tracking user location
  Future<void> enableTracking() async {
    /// make in native when is enabled ,nothing is happen
    await _osmFlutterState.requestPermission();
    await osmPlatform.enableTracking(_idMap);
  }

  /// disabled tracking user location
  Future<void> disabledTracking() async {
    await osmPlatform.disableTracking(_idMap);
  }

  /// pick Position in map
  Future<GeoPoint> selectPosition({
    MarkerIcon? icon,
    String imageURL = "",
  }) async {
    if (icon != null) {
      _osmFlutterState.dynamicMarkerWidgetNotifier.value = icon;
      return Future.delayed(
          Duration(
            milliseconds: 200,
          ), () async {
        GeoPoint p = await osmPlatform.pickLocation(
          _idMap,
          key: _osmFlutterState.dynamicMarkerKey,
        );
        return p;
      });
    }
    GeoPoint p = await osmPlatform.pickLocation(
      _idMap,
      imageURL: imageURL,
    );
    return p;
  }

  Future<void> defaultZoom(double zoom) async {
    await osmPlatform.setDefaultZoom(_idMap, zoom);
  }

  /// draw road
  ///  [start] : started point of your Road
  ///  [end] : last point of your road
  ///  [interestPoints] : middle point that you want to be passed by your route
  ///  [roadColor] : (color)  indicate the color that you want to be road colored
  ///  [roadWidth] : (double) indicate the width  of your road
  Future<RoadInfo> drawRoad(
    GeoPoint start,
    GeoPoint end, {
    List<GeoPoint>? interestPoints,
    RoadOption? roadOption,
  }) async {
    assert(start.latitude != end.latitude || start.longitude != end.longitude,
        "you cannot make road with same geoPoint");
    return await osmPlatform.drawRoad(
      _idMap,
      start,
      end,
      interestPoints: interestPoints,
      roadOption: roadOption ?? const RoadOption.empty(),
    );
  }

  /// draw road
  ///  [path] : (list) path of the road
  Future<void> drawRoadManually(
    List<GeoPoint> path,
    Color roadColor,
    double width,
  ) async {
    assert(
        path.first.latitude != path.last.latitude ||
            path.first.longitude != path.last.longitude,
        "you cannot make road with same geoPoint");
    await osmPlatform.drawRoadManually(_idMap, path, roadColor, width);
  }

  ///delete last road draw in the map
  Future<void> removeLastRoad() async {
    return await osmPlatform.removeLastRoad(_idMap);
  }

  Future<bool> checkServiceLocation() async {
    bool isEnabled = await osmPlatform.locationService.serviceEnabled();
    if (!isEnabled) {
      await osmPlatform.locationService.requestService();
      return Future.delayed(Duration(milliseconds: 55), () async {
        isEnabled = await osmPlatform.locationService.serviceEnabled();
        return isEnabled;
      });
    }
    return true;
  }

  /// draw circle shape in the map
  ///
  /// [circleOSM] : (CircleOSM) represent circle in osm map
  Future<void> drawCircle(CircleOSM circleOSM) async {
    return await osmPlatform.drawCircle(_idMap, circleOSM);
  }

  /// remove circle shape from map
  /// [key] : (String) key of the circle
  Future<void> removeCircle(String key) async {
    return await osmPlatform.removeCircle(_idMap, key);
  }

  /// draw rect shape in the map
  /// [regionOSM] : (RegionOSM) represent region in osm map
  Future<void> drawRect(RectOSM rectOSM) async {
    return await osmPlatform.drawRect(_idMap, rectOSM);
  }

  /// remove region shape from map
  /// [key] : (String) key of the region
  Future<void> removeRect(String key) async {
    return await osmPlatform.removeRect(_idMap, key);
  }

  /// remove all rect shape from map
  Future<void> removeAllRect() async {
    return await osmPlatform.removeAllRect(_idMap);
  }

  /// remove all circle shapes from map
  Future<void> removeAllCircle() async {
    return await osmPlatform.removeAllCircle(_idMap);
  }

  /// remove all shapes from map
  Future<void> removeAllShapes() async {
    return await osmPlatform.removeAllShapes(_idMap);
  }

  /// to start assisted selection in the map
  Future<void> advancedPositionPicker() async {
    return await osmPlatform.advancedPositionPicker(_idMap);
  }

  /// to retrieve location desired
  Future<GeoPoint> selectAdvancedPositionPicker() async {
    return await osmPlatform.selectAdvancedPositionPicker(_idMap);
  }

  /// to retrieve current location without finish picker
  Future<GeoPoint> getCurrentPositionAdvancedPositionPicker() async {
    return await osmPlatform.getPositionOnlyAdvancedPositionPicker(_idMap);
  }

  /// to cancel the assisted selection in tge map
  Future<void> cancelAdvancedPositionPicker() async {
    return await osmPlatform.cancelAdvancedPositionPicker(_idMap);
  }

  Future<void> mapOrientation(double? degree) async {
    await osmPlatform.mapRotation(_idMap, degree);
  }
}

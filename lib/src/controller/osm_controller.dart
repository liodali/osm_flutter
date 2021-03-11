import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/src/types/shape_osm.dart';
import 'package:location/location.dart';

import '../interface_osm/osm_interface.dart';
import '../osm_flutter.dart';
import '../types/types.dart';

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

    osmPlatform.setSecureURL(_idMap, _osmFlutterState.widget.useSecureURL);
    if (_osmFlutterState.widget.showDefaultInfoWindow == true)
      osmPlatform.visibilityInfoWindow(
          _idMap, _osmFlutterState.widget.showDefaultInfoWindow);
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
    if (initWithUserPosition && !_osmFlutterState.widget.isPicker) {
      await currentLocation();
    }
    if (_osmFlutterState.widget.markerIcon != null) {
      await changeIconMarker(_osmFlutterState.key);
    }
    if (initPosition != null) {
      await changeLocation(initPosition);
    }

    if (_osmFlutterState.widget.staticPoints.isNotEmpty) {
      _osmFlutterState.widget.staticPoints
          .asMap()
          .forEach((index, points) async {
        if (points.markerIcon != null) {
          await osmPlatform.customMarkerStaticPosition(_idMap,
              _osmFlutterState.staticMarkersKeys[points.id], points.id);
        }
        if (points.geoPoints != null && points.geoPoints!.isNotEmpty) {
          await osmPlatform.staticPosition(
              _idMap, points.geoPoints!, points.id);
        }
      });
    }
    if (_osmFlutterState.widget.road != null) {
      await showDialog(
          context: _osmFlutterState.context,
          barrierDismissible: false,
          builder: (ctx) {
            return JobAlertDialog(
              callback: () async {
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
                Navigator.pop(ctx);
              },
            );
          });
    }
    if (initWithUserPosition && _osmFlutterState.widget.isPicker) {
      GeoPoint p = await osmPlatform.myLocation(_idMap);
      await osmPlatform.addPosition(_idMap, p);
      osmPlatform.advancedPositionPicker(_idMap);
    }
  }

  ///initialise or change of position
  /// [p] : geoPoint
  Future<void> changeLocation(GeoPoint p) async {
    osmPlatform.addPosition(_idMap, p);
  }

  ///remove marker from map of position
  /// [p] : geoPoint
  Future<void> removeMarker(GeoPoint p) async {
    osmPlatform.removePosition(_idMap, p);
  }

  ///change Icon Marker
  /// we need to global key to recuperate widget from tree element
  /// [key] : (GlobalKey) key of widget that represent the new marker
  Future changeIconMarker(GlobalKey? key) async {
    await osmPlatform.customMarker(_idMap, key);
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
    if (granted) await osmPlatform.currentLocation(_idMap);
  }

  /// recuperation of user current position
  Future<GeoPoint> myLocation() async {
    return await osmPlatform.myLocation(_idMap);
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
  Future<GeoPoint> selectPosition() async {
    GeoPoint p = await osmPlatform.pickLocation(_idMap);
    return p;
  }

  Future<void> defaultZoom(double zoom) async {
    await osmPlatform.setDefaultZoom(_idMap, zoom);
  }

  Future<void> enableHttps(bool enable) async {
    await osmPlatform.setSecureURL(_idMap, enable);
  }

  /// draw road
  ///  [start] : started point of your Road
  ///  [end] : last point of your road
  Future<RoadInfo> drawRoad(GeoPoint start, GeoPoint end) async {
    assert(start.latitude != end.latitude || start.longitude != end.longitude,
        "you cannot make road with same geoPoint");
    return await osmPlatform.drawRoad(_idMap, start, end);
  }

  ///delete last road draw in the map
  Future<void> removeLastRoad() async {
    return await osmPlatform.removeLastRoad(_idMap);
  }

  Future<void> checkServiceLocation() async {
    bool isEnabled = await Location().serviceEnabled();
    if (!isEnabled) {
      await showDialog(
        context: _osmFlutterState.context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            title: Text("GPS service is disabled"),
            content: Text(
                "We need to get your current location,you should turn on your gps location "),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(_osmFlutterState.context),
                child: Text(
                  "Cancel",
                  style: TextStyle(color: Colors.black),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(_osmFlutterState.context),
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
    } else {
      currentLocation();
    }
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
}

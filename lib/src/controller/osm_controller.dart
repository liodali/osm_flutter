import 'package:flutter/material.dart';
import 'package:location_permissions/location_permissions.dart';

import '../interface_osm/osm_interface.dart';
import '../osm_flutter.dart';
import '../types/types.dart';

final OSMPlatform osmPlatform = OSMPlatform.instance;

class OSMController {
  int _idMap;
  OSMFlutterState _osmFlutterState;

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
    GeoPoint initPosition,
    bool initWithUserPosition = false,
  }) async {
    osmPlatform.setDefaultZoom(_idMap, _osmFlutterState.widget.defaultZoom);

    await osmPlatform.setSecureURL(_idMap, _osmFlutterState.widget.useSecureURL);
    await osmPlatform.visibilityInfoWindow(_idMap, _osmFlutterState.widget.showDefaultInfoWindow);
    if (_osmFlutterState.widget.onGeoPointClicked != null) {
      osmPlatform.onGeoPointClickListener(_idMap).listen((event) {
        _osmFlutterState.widget.onGeoPointClicked(event.value);
      });
    }
    if (_osmFlutterState.widget.onLocationChanged != null) {
      osmPlatform.onUserPositionListener(_idMap).listen((event) {
        _osmFlutterState.widget.onLocationChanged(event.value);
      });
      /* this._osmController.myLocationListener(widget.onLocationChanged, (err) {
          print(err);
        });*/
    }
    if (initWithUserPosition) {
      await currentLocation();
    }
    if (_osmFlutterState.widget.markerIcon != null) {
      await changeIconMarker(_osmFlutterState.key);
    }
    if (initPosition != null) {
      await changeLocation(initPosition);
    }

    if (_osmFlutterState.widget.staticPoints != null) {
      if (_osmFlutterState.widget.staticPoints.isNotEmpty) {
        _osmFlutterState.widget.staticPoints
            .asMap()
            .forEach((index, points) async {
          if (points.markerIcon != null) {
            await osmPlatform.customMarkerStaticPosition(_idMap,
                _osmFlutterState.staticMarkersKeys[points.id], points.id);
          }
          if (points.geoPoints != null && points.geoPoints.isNotEmpty) {
            await osmPlatform.staticPosition(
                _idMap, points.geoPoints, points.id);
          }
        });
      }
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
                  _osmFlutterState.widget.road.roadColor,
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
  }

  ///initialise or change of position
  /// [p] : geoPoint
  Future<void> changeLocation(GeoPoint p) async {
    if (p != null) osmPlatform.addPosition(_idMap, p);
  }

  ///remove marker from map of position
  /// [p] : geoPoint
  Future<void> removeMarker(GeoPoint p) async {
    if (p != null) osmPlatform.removePosition(_idMap, p);
  }

  ///change Icon Marker
  /// we need to global key to recuperate widget from tree element
  /// [key] : (GlobalKey) key of widget that represent the new marker
  Future changeIconMarker(GlobalKey key) async {
    await osmPlatform.customMarker(_idMap, key);
  }

  /// change static position in runtime
  ///  [geoPoints] : list of static geoPoint
  ///  [id] : String of that list of static geoPoint
  Future<void> setStaticPosition(List<GeoPoint> geoPoints, String id) async {
    assert(
        _osmFlutterState.widget.staticPoints != null &&
            _osmFlutterState.widget.staticPoints
                    .firstWhere((p) => p.id == id) !=
                null,
        "static points null,you should initialize them before you set their positions!");
    await osmPlatform.staticPosition(_idMap, geoPoints, id);
  }

  /// zoom in/out
  /// [zoom] : (double) positive value:zoomIN or negative value:zoomOut
  Future<void> zoom(double zoom) async {
    assert(zoom != 0, "zoom value should different from zero");
    await osmPlatform.zoom(_idMap, zoom);
  }

  /// zoomIn use defaultZoom
  /// positive value:zoomIN
  Future<void> zoomIn() async {
    await osmPlatform.zoom(_idMap, 0);
  }

  /// zoomOut use defaultZoom
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
    assert(
        start != null && end != null, "you cannot make road without 2 point");
    assert(start.latitude != end.latitude || start.longitude != end.longitude,
        "you cannot make road with same geoPoint");
    return await osmPlatform.drawRoad(_idMap, start, end);
  }

  ///delete last road draw in the map
  Future<void> removeLastRoad() async {
    await osmPlatform.removeLastRoad(_idMap);
  }

  Future<void> checkServiceLocation() async {
    ServiceStatus serviceStatus =
        await LocationPermissions().checkServiceStatus();
    if (serviceStatus == ServiceStatus.disabled) {
      await showDialog(
        context: _osmFlutterState.context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            title: Text("GPS service is disabled"),
            content: Text(
                "We need to get your current location,you should turn on your gps location "),
            actions: <Widget>[
              FlatButton(
                onPressed: () => Navigator.pop(_osmFlutterState.context),
                child: Text(
                  "annuler",
                  style: TextStyle(color: Colors.black),
                ),
              ),
              FlatButton(
                onPressed: () => Navigator.pop(_osmFlutterState.context),
                color: Theme.of(_osmFlutterState.context).primaryColor,
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
    } else if (serviceStatus == ServiceStatus.enabled) {
      currentLocation();
    }
  }
}

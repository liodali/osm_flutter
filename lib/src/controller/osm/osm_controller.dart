import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import '../../widgets/mobile_osm_flutter.dart';
import 'package:location/location.dart';



class MobileOSMController extends IBaseOSMController {
  late int _idMap;
  late MobileOsmFlutterState _osmFlutterState;

  static MobileOSMPlatform osmPlatform = OSMPlatform.instance as MobileOSMPlatform;


  late double stepZoom = 1;
  late int minZoomLevel = 2;
  late int maxZoomLevel = 18;

  MobileOSMController();

  MobileOSMController._(this._idMap, this._osmFlutterState) {
    minZoomLevel = this._osmFlutterState.widget.minZoomLevel;
    maxZoomLevel = this._osmFlutterState.widget.maxZoomLevel;
  }

  static Future<MobileOSMController> init(
    int id,
      MobileOsmFlutterState osmState,
  ) async {
    await osmPlatform.init(id);
    return MobileOSMController._(id, osmState);
  }

  /// dispose: close stream in osmPlatform,remove references
  void dispose() {
    osmPlatform.close();
  }

  /// initMap: initialisation of osm map
  /// [initPosition]          : (geoPoint) animate map to initPosition
  /// [initWithUserPosition]  : set map in user position
  /// [box]                   : (BoundingBox) area limit of the map
  Future<void> initMap({
    GeoPoint? initPosition,
    bool initWithUserPosition = false,
    BoundingBox? box,
  }) async {
    if (_osmFlutterState.widget.onMapIsReady != null) {
      _osmFlutterState.widget.onMapIsReady!(false);
    }

    /// load config map scene for iOS
    if (Platform.isIOS) {
      await (osmPlatform as MethodChannelOSM).initIosMap(_idMap);
    }

    _checkBoundingBox(box, initPosition);
    stepZoom = _osmFlutterState.widget.stepZoom;

    await configureZoomMap(
      _osmFlutterState.widget.minZoomLevel,
      _osmFlutterState.widget.maxZoomLevel,
      stepZoom,
      _osmFlutterState.widget.initZoom,
    );

    if (_osmFlutterState.widget.showDefaultInfoWindow == true) {
      osmPlatform.visibilityInfoWindow(
          _idMap, _osmFlutterState.widget.showDefaultInfoWindow);
    }

    /// listen to data send from native map

    osmPlatform.onLongPressMapClickListener(_idMap).listen((event) {
      _osmFlutterState.widget.controller
          .setValueListenerMapLongTapping(event.value);
    });

    osmPlatform.onSinglePressMapClickListener(_idMap).listen((event) {
      _osmFlutterState.widget.controller
          .setValueListenerMapSingleTapping(event.value);
    });
    osmPlatform.onMapIsReady(_idMap).listen((event) async {
      _osmFlutterState.widget.mapIsReadyListener.value = event.value;
      if (_osmFlutterState.widget.onMapIsReady != null) {
        _osmFlutterState.widget.onMapIsReady!(event.value);
      }
      _osmFlutterState.widget.controller
          .setValueListenerMapIsReady(event.value);
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

    /// change default icon  marker
    final defaultIcon = _osmFlutterState.widget.markerOption?.defaultMarker;

    if (defaultIcon != null) {
      await changeDefaultIconMarker(_osmFlutterState.defaultMarkerKey);
    } else {
      if (Platform.isIOS) {
        _osmFlutterState.widget.dynamicMarkerWidgetNotifier.value = Icon(
          Icons.location_on,
          color: Colors.red,
          size: 32,
        );
        await Future.delayed(Duration(milliseconds: 250), () async {
          _osmFlutterState.widget.dynamicMarkerWidgetNotifier.value = null;
          await changeDefaultIconMarker(_osmFlutterState.dynamicMarkerKey);
        });
      }
    }

    /// change advanced picker icon marker
    if (_osmFlutterState.widget.markerOption?.advancedPickerMarker != null) {
      await changeIconAdvPickerMarker(_osmFlutterState.advancedPickerMarker);
    }
    if (Platform.isIOS &&
        _osmFlutterState.widget.markerOption?.advancedPickerMarker == null) {
      _osmFlutterState.widget.dynamicMarkerWidgetNotifier.value = Icon(
        Icons.location_on,
        color: Colors.red,
        size: 32,
      );
      await Future.delayed(Duration(milliseconds: 250), () async {
        _osmFlutterState.widget.dynamicMarkerWidgetNotifier.value = null;
        await changeIconAdvPickerMarker(_osmFlutterState.dynamicMarkerKey);
      });
    }

    /// change user person Icon and arrow Icon
    if (_osmFlutterState.widget.userLocationMarker != null) {
      await osmPlatform.customUserLocationMarker(
        _idMap,
        _osmFlutterState.personIconMarkerKey,
        _osmFlutterState.arrowDirectionMarkerKey,
      );
    }

    /// init location in map
    if (initWithUserPosition && !_osmFlutterState.widget.isPicker) {
      initPosition = await myLocation();
      _checkBoundingBox(box, initPosition);
    }
    if (box != null && !box.isWorld()) {
      await limitAreaMap(box);
    }

    if (initPosition != null) {
      await osmPlatform.initMap(
        _idMap,
        initPosition,
      );
    }

    /// draw static position
    if (_osmFlutterState.widget.staticPoints.isNotEmpty) {
      _osmFlutterState.widget.staticPoints
          .asMap()
          .forEach((index, points) async {
        if (points.markerIcon != null) {
          await osmPlatform.customMarkerStaticPosition(
            _idMap,
            _osmFlutterState.widget.staticIconGlobalKeys[points.id],
            points.id,
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
      Future.microtask(() => _initializeRoadInformation());
    }

    /// picker config
    if (_osmFlutterState.widget.isPicker) {
      GeoPoint? p = _osmFlutterState.widget.controller.initPosition;
      if (p == null && initWithUserPosition) {
        bool granted = await _osmFlutterState.requestPermission();
        if (!granted) {
          throw Exception("you should open gps to get current position");
        }
        await _osmFlutterState.checkService();
        try {
          p = await osmPlatform.myLocation(_idMap);
          await osmPlatform.initMap(_idMap, p);
        } catch (e) {
          p = (await Location().getLocation()).toGeoPoint();
        }
      }
      await osmPlatform.advancedPositionPicker(_idMap);
    }
  }

  void _checkBoundingBox(BoundingBox? box, GeoPoint? initPosition) {
    if (box != null && !box.isWorld() && initPosition != null) {
      if (!box.inBoundingBox(initPosition)) {
        throw Exception(
            "you want to limit the area of the map but your init location is already outside the area!");
      }
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

  Future<void> configureZoomMap(
    int minZoomLevel,
    int maxZoomLevel,
    double stepZoom,
    double initZoom,
  ) async {
    await (osmPlatform as MethodChannelOSM).configureZoomMap(
      _idMap,
      initZoom,
      minZoomLevel,
      maxZoomLevel,
      stepZoom,
    );
  }

  /// set area camera limit of the map
  /// [box] : (BoundingBox) bounding that map cannot exceed from it
  Future<void> limitAreaMap(BoundingBox box) async {
    await osmPlatform.limitArea(
      _idMap,
      box,
    );
  }

  /// remove area camera limit from the map
  Future<void> removeLimitAreaMap() async {
    await osmPlatform.removeLimitArea(
      _idMap,
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

  ///change  Marker of specific static points
  /// we need to global key to recuperate widget from tree element
  /// [id] : (String) id  of the static group geopoint
  /// [markerIcon] : (MarkerIcon) new marker that will set to the static group geopoint
  Future<void> setIconStaticPositions(
    String id,
    MarkerIcon markerIcon,
  ) async {
    if (markerIcon.icon != null) {
      _osmFlutterState.widget.dynamicMarkerWidgetNotifier.value = markerIcon.icon;
    } else if (markerIcon.image != null) {
      _osmFlutterState.widget.dynamicMarkerWidgetNotifier.value = Image(
        image: markerIcon.image!,
      );
    }
    await Future.delayed(Duration(milliseconds: 300), () async {
      await osmPlatform.customMarkerStaticPosition(
        _idMap,
        _osmFlutterState.dynamicMarkerKey,
        id,
      );
    });
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
    // List<StaticPositionGeoPoint?> staticGeoPosition =
    //     _osmFlutterState.widget.staticPoints;
    // assert(
    //     staticGeoPosition.firstWhere((p) => p?.id == id, orElse: () => null) !=
    //         null,
    //     "no static geo points has been found,you should create it before!");
    await osmPlatform.staticPosition(_idMap, geoPoints, id);
  }

  /// zoomIn use stepZoom
  Future<void> zoomIn() async {
    await osmPlatform.setZoom(_idMap, stepZoom: 0);
  }

  /// zoomOut use stepZoom
  Future<void> zoomOut() async {
    await osmPlatform.setZoom(_idMap, stepZoom: -1);
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

  /// create marker int specific position without change map camera
  ///
  /// [p] : (GeoPoint) desired location
  ///
  /// [markerIcon] : (MarkerIcon) set icon of the marker
  Future<void> addMarker(
    GeoPoint p, {
    MarkerIcon? markerIcon,
  }) async {
    if (markerIcon != null &&
        (markerIcon.icon != null || markerIcon.image != null)) {
      if (markerIcon.icon != null) {
        _osmFlutterState.widget.dynamicMarkerWidgetNotifier.value = markerIcon.icon;
      } else if (markerIcon.image != null) {
        _osmFlutterState.widget.dynamicMarkerWidgetNotifier.value = Image(
          image: markerIcon.image!,
        );
      }
      Future.delayed(Duration(milliseconds: 250), () async {
        await osmPlatform.addMarker(_idMap, p,
            globalKeyIcon: _osmFlutterState.dynamicMarkerKey);
      });
    } else {
      await osmPlatform.addMarker(_idMap, p);
    }
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
      _osmFlutterState.widget.dynamicMarkerWidgetNotifier.value = icon;
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

  Future<void> setZoom({double? zoomLevel, double? stepZoom}) async {
    if (zoomLevel != null &&
        (zoomLevel >= maxZoomLevel || zoomLevel <= minZoomLevel)) {
      throw Exception(
          "zoom level should be between $minZoomLevel and $maxZoomLevel");
    }
    await osmPlatform.setZoom(
      _idMap,
      stepZoom: stepZoom,
      zoomLevel: zoomLevel,
    );
  }

  Future<double> getZoom() async {
    return await osmPlatform.getZoom(_idMap);
  }

  /// draw road
  ///  [start] : started point of your Road
  ///
  ///  [end] : last point of your road
  ///
  ///  [interestPoints] : middle point that you want to be passed by your route
  ///
  ///  [roadOption] : (RoadOption) runtime configuration of the road
  Future<RoadInfo> drawRoad(
    GeoPoint start,
    GeoPoint end, {
    RoadType roadType = RoadType.car,
    List<GeoPoint>? interestPoints,
    RoadOption? roadOption,
  }) async {
    assert(start.latitude != end.latitude || start.longitude != end.longitude,
        "you cannot make road with same geoPoint");
    return await osmPlatform.drawRoad(
      _idMap,
      start,
      end,
      roadType: roadType,
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
    bool isEnabled = await (osmPlatform as MethodChannelOSM)
        .locationService
        .serviceEnabled();
    if (!isEnabled) {
      await (osmPlatform as MethodChannelOSM).locationService.requestService();
      return Future.delayed(Duration(milliseconds: 55), () async {
        isEnabled = await (osmPlatform as MethodChannelOSM)
            .locationService
            .serviceEnabled();
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

  Future<void> mapOrientation(double degree) async {
    await osmPlatform.mapRotation(_idMap, degree);
  }



  @override
  Future<void> setMaximumZoomLevel(int maxZoom) async{
    await osmPlatform.setMaximumZoomLevel(_idMap, maxZoom);
  }

  @override
  Future<void> setMinimumZoomLevel(int minZoom) async{
    await osmPlatform.setMaximumZoomLevel(_idMap, minZoom);
  }

  @override
  Future<void> setStepZoom(int stepZoom) async{
    await osmPlatform.setStepZoom(_idMap, stepZoom);
  }

  @override
  Future<void> limitArea(BoundingBox box) async{
    await osmPlatform.limitArea(_idMap, box);

  }

  @override
  Future<void> removeLimitArea() async{
   await osmPlatform.removeLimitArea(_idMap);
  }
}

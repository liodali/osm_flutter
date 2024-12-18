import 'dart:async';
import 'dart:io';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/src/common/utilities.dart';

import 'package:flutter_osm_plugin/src/widgets/mobile_osm_flutter.dart';
import 'package:routing_client_dart/routing_client_dart.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';

MobileOSMController getOSMMap() => MobileOSMController();

final class MobileOSMController extends IBaseOSMController {
  late int _idMap;
  late MobileOsmFlutterState _osmFlutterState;

  static MobileOSMPlatform osmPlatform =
      OSMPlatform.instance as MobileOSMPlatform;
  final duration = const Duration(milliseconds: 300);
  Timer? _timer;
  late final osrmManager = RoutingManager();
  late double stepZoom = 1;
  late double minZoomLevel = 2;
  late double maxZoomLevel = 18;
  PolylineOption defaultRoadOption = const PolylineOption.empty();
  AndroidLifecycleMixin? _androidOSMLifecycle;

  MobileOSMController();

  MobileOSMController._(this._idMap, this._osmFlutterState) {
    minZoomLevel = _osmFlutterState.widget.zoomOption.minZoomLevel;
    maxZoomLevel = _osmFlutterState.widget.zoomOption.maxZoomLevel;
  }

  static Future<MobileOSMController> init(
    int id,
    MobileOsmFlutterState osmState,
  ) async {
    await osmPlatform.init(id);
    return MobileOSMController._(id, osmState);
  }

  void addObserver(AndroidLifecycleMixin androidOSMLifecycle) {
    _androidOSMLifecycle = androidOSMLifecycle;
  }

  /// dispose: close stream in osmPlatform,remove references
  void dispose() {
    if (_timer != null && _timer!.isActive) {
      _timer?.cancel();
    }
    _androidOSMLifecycle = null;
    osmPlatform.close(_idMap);
  }

  /// [initMap]
  ///
  /// inner initialisation of osm map
  ///
  /// [initPosition]          : (geoPoint) animate map to initPosition
  ///
  /// [useExternalTracking]   : (bool) to enable external control of user location only receive user location without control the map
  ///
  /// [userPositionOption]    : set map in user position
  ///
  /// [box]                   : (BoundingBox) area limit of the map

  @override
  Future<void> initPositionMap({
    GeoPoint? initPosition,
    UserTrackingOption? userPositionOption,
    bool useExternalTracking = false,
    BoundingBox? box,
    double? initZoom,
  }) async {
    if (_osmFlutterState.widget.onMapIsReady != null) {
      _osmFlutterState.widget.onMapIsReady!(false);
    }

    /// load config map scene for iOS
    if (Platform.isIOS) {
      osmPlatform.onIosMapInit(_idMap).listen((event) async {
        if (event.value) {
          await initMap(
            initPosition,
            userPositionOption,
            useExternalTracking,
            box,
            initZoom,
          );
        }
      });
      await (osmPlatform as MethodChannelOSM).initIosMap(
        _idMap,
      );
      _osmFlutterState.widget.dynamicMarkerWidgetNotifier.value = null;
    }

    _checkBoundingBox(box, initPosition);
    stepZoom = _osmFlutterState.widget.zoomOption.stepZoom;

    await configureZoomMap(
      _osmFlutterState.widget.zoomOption.minZoomLevel,
      _osmFlutterState.widget.zoomOption.maxZoomLevel,
      stepZoom,
      initZoom ?? _osmFlutterState.widget.zoomOption.initZoom,
    );

    if (Platform.isAndroid) {
      await initMap(
        initPosition,
        userPositionOption,
        useExternalTracking,
        box,
        initZoom,
      );
    }
  }

  /// listen to data send from native map
  void onListenChannel() {
    osmPlatform.onLongPressMapClickListener(_idMap).listen((event) {
      _osmFlutterState.widget.controller
          .setValueListenerMapLongTapping(event.value);
      for (var osmMixin in _osmFlutterState.widget.controller.osMMixins) {
        osmMixin.onLongTap(event.value);
      }
    });
    osmPlatform.onSinglePressMapClickListener(_idMap).listen((event) {
      _osmFlutterState.widget.controller
          .setValueListenerMapSingleTapping(event.value);
      for (var osmMixin in _osmFlutterState.widget.controller.osMMixins) {
        osmMixin.onSingleTap(event.value);
      }
    });

    osmPlatform.onRoadMapClickListener(_idMap).listen((event) {
      _osmFlutterState.widget.controller
          .setValueListenerMapRoadTapping(event.value);
      for (var osmMixin in _osmFlutterState.widget.controller.osMMixins) {
        osmMixin.onRoadTap(event.value);
      }
    });
    osmPlatform.onMapIsReady(_idMap).listen((event) async {
      if (_androidOSMLifecycle != null &&
          _osmFlutterState.widget.mapIsReadyListener.value != event.value) {
        _androidOSMLifecycle!.mapIsReady(event.value);
      }
      _osmFlutterState.widget.mapIsReadyListener.value = event.value;
      if (_osmFlutterState.widget.onMapIsReady != null) {
        _osmFlutterState.widget.onMapIsReady!(event.value);
      }
      if (_osmFlutterState.widget.controller.osMMixins.isNotEmpty) {
        Future.forEach(_osmFlutterState.widget.controller.osMMixins,
            (osmMixin) async {
          osmMixin.mapIsReady(event.value);
        });
      }
      _osmFlutterState.widget.controller
          .setValueListenerMapIsReady(event.value);
    });

    osmPlatform.onRegionIsChangingListener(_idMap).listen((event) {
      if (_osmFlutterState.widget.onMapMoved != null) {
        _osmFlutterState.widget.onMapMoved!(event.value);
      }

      _osmFlutterState.widget.controller
          .setValueListenerRegionIsChanging(event.value);
      for (var osmMixin in _osmFlutterState.widget.controller.osMMixins) {
        osmMixin.onRegionChanged(event.value);
      }
    });

    osmPlatform.onMapRestored(_idMap).listen((event) {
      Future.delayed(duration, () {
        if (!_osmFlutterState.widget.mapIsReadyListener.value) {
          _osmFlutterState.widget.mapIsReadyListener.value = true;
        }
        for (var osmMixin in _osmFlutterState.widget.controller.osMMixins) {
          osmMixin.mapRestored();
        }
      });
    });

    if (_osmFlutterState.widget.onGeoPointClicked != null) {
      osmPlatform.onGeoPointClickListener(_idMap).listen((event) {
        _osmFlutterState.widget.onGeoPointClicked!(event.value);
      });
    }

    osmPlatform.onUserPositionListener(_idMap).listen((event) {
      if (_osmFlutterState.widget.onLocationChanged != null) {
        _osmFlutterState.widget.onLocationChanged!(event.value);
      }
      for (var mixin in _osmFlutterState.widget.controller.osMMixins) {
        mixin.onLocationChanged(event.value);
      }
    });
  }

  void _checkBoundingBox(BoundingBox? box, GeoPoint? initPosition) {
    if (box != null && !box.isWorld() && initPosition != null) {
      if (!box.inBoundingBox(initPosition)) {
        throw Exception(
            "you want to limit the area of the map but your init location is already outside the area!");
      }
    }
  }

  Future<void> initMap(
    GeoPoint? initPosition,
    UserTrackingOption? userPositionOption,
    bool useExternalTracking,
    BoundingBox? box,
    double? initZoom,
  ) async {
    final userTrackOption =
        userPositionOption ?? _osmFlutterState.widget.userTrackingOption;

    /// change user person Icon and arrow Icon
    if (_osmFlutterState.widget.userLocationMarker != null) {
      await osmPlatform.customUserLocationMarker(
        _idMap,
        _osmFlutterState.personIconMarkerKey,
        _osmFlutterState.arrowDirectionMarkerKey,
      );
    }

    /// road configuration
    if (_osmFlutterState.widget.polylineOption != null) {
      defaultRoadOption = _osmFlutterState.widget.polylineOption!;
    }

    /// init location in map
    if (userTrackOption != null && userTrackOption.initWithUserPosition) {
      if (Platform.isAndroid) {
        bool granted = await _osmFlutterState.requestPermission();
        if (!granted) {
          throw Exception(
              "we cannot continue showing the map without grant gps permission");
        }
      }
      initPosition = await myLocation();
      _checkBoundingBox(box, initPosition);
    }
    if (box != null && !box.isWorld()) {
      await limitAreaMap(box);
    }
    if (initPosition != null) {
      await osmPlatform.initPositionMap(
        _idMap,
        initPosition,
      );
      await Future.delayed(const Duration(milliseconds: 250));
    }
    if (userTrackOption != null && userTrackOption.enableTracking) {
      await currentLocation();
      switch (useExternalTracking) {
        case true:
          await startLocationUpdating();
          break;
        case false:
          await enableTracking(
            enableStopFollow: userTrackOption.unFollowUser,
          );
          break;
      }
    }

    await _drawInitStaticPoints();
  }

  Future<void> _drawInitStaticPoints() async {
    /// draw static position
    if (_osmFlutterState.widget.staticPoints.isNotEmpty) {
      await Future.forEach(_osmFlutterState.widget.staticPoints,
          (points) async {
        if (points.markerIcon != null) {
          await osmPlatform.customMarkerStaticPosition(
            _idMap,
            _osmFlutterState.widget.staticIconGlobalKeys[points.id],
            points.id,
          );
        }
        if (points.geoPoints.isNotEmpty) {
          await osmPlatform.staticPosition(
            _idMap,
            points.geoPoints,
            points.id,
          );
        }
      });
    }
  }

  @override
  Future<void> configureZoomMap(
    double minZoomLevel,
    double maxZoomLevel,
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

  @override
  Future<void> changeTileLayer({CustomTile? tileLayer}) =>
      osmPlatform.changeTileLayer(
        _idMap,
        tileLayer,
      );

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

  /// initialise or change of position
  ///
  /// [p] : (GeoPoint) position that will be added to map
  @override
  Future<void> changeLocation(GeoPoint p) async {
    await osmPlatform.addPosition(_idMap, p);
  }

  ///remove marker from map of position
  /// [p] : geoPoint
  @override
  Future<void> removeMarker(GeoPoint p) async {
    await osmPlatform.removePosition(_idMap, p);
  }

  ///change  Marker of specific static points
  /// we need to global key to recuperate widget from tree element
  /// [id] : (String) id  of the static group geopoint
  /// [markerIcon] : (MarkerIcon) new marker that will set to the static group geopoint
  @override
  Future<void> setIconStaticPositions(
    String id,
    MarkerIcon markerIcon, {
    bool refresh = false,
  }) async {
    _osmFlutterState.widget.dynamicMarkerWidgetNotifier.value = markerIcon;
    await osmPlatform.customMarkerStaticPosition(
      _idMap,
      _osmFlutterState.dynamicMarkerKey,
      id,
      refresh: refresh,
    );
    await Future.delayed(duration);
  }

  /// change static position in runtime
  ///  [geoPoints] : list of static geoPoint
  ///  [id] : String of that list of static geoPoint
  @override
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
  @override
  Future<void> zoomIn() async {
    await osmPlatform.setZoom(_idMap, stepZoom: 0);
  }

  /// zoomOut use stepZoom
  @override
  Future<void> zoomOut() async {
    await osmPlatform.setZoom(_idMap, stepZoom: -1);
  }

  /// activate current location position
  @override
  Future<void> currentLocation() async {
    if (Platform.isAndroid) {
      bool granted = await _osmFlutterState.requestPermission();
      if (!granted) {
        throw Exception("Location permission not granted");
      }
    }
    // bool isEnabled = await _osmFlutterState.checkService();
    // if (!isEnabled) {
    //   throw Exception("turn on GPS service");
    // }
    await osmPlatform.currentLocation(_idMap);
  }

  /// recuperation of user current position
  @override
  Future<GeoPoint> myLocation() async {
    return await osmPlatform.myLocation(_idMap);
  }

  /// go to specific position without create marker
  ///
  /// [p] : (GeoPoint) desired location
  @override
  Future<void> goToPosition(GeoPoint p, {bool animate = false}) async {
    await osmPlatform.goToPosition(
      _idMap,
      p,
      animate: animate,
    );
  }

  /// create marker int specific position without change map camera
  ///
  /// [p] : (GeoPoint) desired location
  ///
  /// [markerIcon] : (MarkerIcon) set icon of the marker
  @override
  Future<void> addMarker(
    GeoPoint p, {
    MarkerIcon? markerIcon,
    double? angle,
    IconAnchor? iconAnchor,
  }) async {
    if (markerIcon != null) {
      _osmFlutterState.widget.dynamicMarkerWidgetNotifier.value = markerIcon;
      //int durationSecond = 500;
      await Future.delayed(duration, () async {
        await osmPlatform.addMarker(
          _idMap,
          angle != null && angle != 0
              ? GeoPointWithOrientation(
                  angle: angle,
                  latitude: p.latitude,
                  longitude: p.longitude,
                )
              : p,
          globalKeyIcon: _osmFlutterState.dynamicMarkerKey,
          iconAnchor: iconAnchor,
        );
      });
    } else {
      await osmPlatform.addMarker(
        _idMap,
        p,
        iconAnchor: iconAnchor,
      );
    }
  }

  /// enabled tracking user location
  @override
  Future<void> enableTracking({
    bool enableStopFollow = false,
    bool disableMarkerRotation = false,
    Anchor anchor = Anchor.center,
    bool useDirectionMarker = false,
  }) async {
    /// make in native when is enabled ,nothing is happen
    await _osmFlutterState.requestPermission();
    await osmPlatform.enableTracking(
      _idMap,
      stopFollowInDrag: enableStopFollow,
      disableMarkerRotation: disableMarkerRotation,
      anchor: anchor,
      useDirectionMarker: useDirectionMarker,
    );
  }

  /// disabled tracking user location
  @override
  Future<void> disabledTracking() async {
    await osmPlatform.disableTracking(_idMap);
  }

  @override
  Future<void> setZoom({double? zoomLevel, double? stepZoom}) async {
    if (zoomLevel != null &&
        (zoomLevel < minZoomLevel || zoomLevel > maxZoomLevel)) {
      throw Exception(
          "zoom level should be between $minZoomLevel and $maxZoomLevel");
    }
    await osmPlatform.setZoom(
      _idMap,
      stepZoom: stepZoom,
      zoomLevel: zoomLevel,
    );
  }

  @override
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
  ///  [polylineOption] : ((RoadType, PolylineOption)) runtime configuration of the road
  @override
  Future<RoadInfo> drawRoad(
    GeoPoint start,
    GeoPoint end, {
    List<GeoPoint>? interestPoints,
    (RoadType, PolylineOption)? polylineOption,
    bool zoomInto = true,
  }) async {
    assert(start.latitude != end.latitude || start.longitude != end.longitude,
        "you cannot make road with same geoPoint");
    final waypoints = [start, end];
    if (interestPoints != null && interestPoints.isNotEmpty) {
      waypoints.insertAll(1, interestPoints);
    }
    final polyOption = polylineOption?.$2 ?? defaultRoadOption;
    final roadType = polylineOption?.$1 ?? RoadType.car;
    final route = await osrmManager.getRoute(
      request: OSRMRequest.route(
        waypoints: waypoints.toLngLatList(),
        routingType: roadType != RoadType.mixed
            ? RoutingType.values[roadType.index]
            : RoutingType.car,
      ),
    );
    final roadInfo = RoadInfo(
      distance: route.distance,
      duration: route.duration,
      segments: [
        RoadSegment(
          distance: route.distance,
          duration: route.duration,
          route: route.polyline?.toGeoPointList() ?? [],
          instructions: route.instructions
              .map(
                (instruction) => instruction.toInstruction(),
              )
              .toList(),
        )
      ],
    );
    await osmPlatform.drawRoad(
      _idMap,
      Road(
        id: roadInfo.key,
        polylines: [
          Polyline(
            id: 'seg-id',
            encodedPolyline: route.polylineEncoded ??
                encodePolyline(
                  route.polyline
                          ?.map(
                            (e) => e.toGeoPoint().toListNum(),
                          )
                          .toList() ??
                      <List<num>>[],
                ),
            polylineOption: polyOption,
          )
        ],
      ),
      zoomInto: zoomInto,
    );

    return roadInfo;
  }

  /// draw road
  ///  [path] : (list) path of the road
  @override
  Future<String> drawRoadManually(
    Road road, {
    bool zoomInto = true,
  }) async {
    if (road.polylines.isEmpty) {
      throw Exception("you cannot make road with empty list of  polylines");
    }

    await osmPlatform.drawRoad(
      _idMap,
      road,
      zoomInto: true,
    );
    return road.id;
  }

  ///delete last road draw in the map
  @override
  Future<void> removeLastRoad() async {
    return await osmPlatform.removeLastRoad(_idMap);
  }

  @override
  Future<void> removeRoad({required String roadKey}) async {
    return await osmPlatform.removeRoad(_idMap, roadKey);
  }

  // Future<bool> checkServiceLocation() async {
  //   bool isEnabled = await (osmPlatform as MethodChannelOSM).locationService.serviceEnabled();
  //   if (!isEnabled) {
  //     await (osmPlatform as MethodChannelOSM).locationService.requestService();
  //     return Future.delayed(Duration(milliseconds: 55), () async {
  //       isEnabled = await (osmPlatform as MethodChannelOSM).locationService.serviceEnabled();
  //       return isEnabled;
  //     });
  //   }
  //   return true;
  // }

  /// draw circle shape in the map
  ///
  /// [circleOSM] : (CircleOSM) represent circle in osm map
  @override
  Future<void> drawCircle(CircleOSM circleOSM) async {
    return await osmPlatform.drawCircle(_idMap, circleOSM);
  }

  /// remove circle shape from map
  /// [key] : (String) key of the circle
  @override
  Future<void> removeCircle(String key) async {
    return await osmPlatform.removeCircle(_idMap, key);
  }

  /// draw rect shape in the map
  /// [regionOSM] : (RegionOSM) represent region in osm map
  @override
  Future<void> drawRect(RectOSM rectOSM) async {
    return await osmPlatform.drawRect(_idMap, rectOSM);
  }

  /// remove region shape from map
  /// [key] : (String) key of the region
  @override
  Future<void> removeRect(String key) async {
    return await osmPlatform.removeRect(_idMap, key);
  }

  /// remove all rect shape from map
  @override
  Future<void> removeAllRect() async {
    return await osmPlatform.removeAllRect(_idMap);
  }

  /// remove all circle shapes from map
  @override
  Future<void> removeAllCircle() async {
    return await osmPlatform.removeAllCircle(_idMap);
  }

  /// remove all shapes from map
  @override
  Future<void> removeAllShapes() async {
    return await osmPlatform.removeAllShapes(_idMap);
  }

  @override
  Future<void> mapOrientation(double degree) async {
    var angle = degree;
    await osmPlatform.mapRotation(_idMap, angle);
  }

  @override
  Future<void> setMaximumZoomLevel(double maxZoom) async {
    await osmPlatform.setMaximumZoomLevel(_idMap, maxZoom);
  }

  @override
  Future<void> setMinimumZoomLevel(double minZoom) async {
    await osmPlatform.setMaximumZoomLevel(_idMap, minZoom);
  }

  @override
  Future<void> setStepZoom(int stepZoom) async {
    await osmPlatform.setStepZoom(_idMap, stepZoom);
  }

  @override
  Future<void> limitArea(BoundingBox box) async {
    await osmPlatform.limitArea(_idMap, box);
  }

  @override
  Future<void> removeLimitArea() async {
    await osmPlatform.removeLimitArea(_idMap);
  }

  @override
  Future<GeoPoint> getMapCenter() async {
    return osmPlatform.getMapCenter(_idMap);
  }

  @override
  Future<BoundingBox> getBounds() {
    return osmPlatform.getBounds(_idMap);
  }

  @override
  Future<void> zoomToBoundingBox(
    BoundingBox box, {
    int paddinInPixel = 0,
  }) async {
    await (MobileOSMController.osmPlatform as MethodChannelOSM)
        .zoomToBoundingBox(
      _idMap,
      box,
      paddinInPixel: paddinInPixel,
    );
  }

  @override
  Future<void> setIconMarker(GeoPoint point, MarkerIcon markerIcon) async {
    _osmFlutterState.widget.dynamicMarkerWidgetNotifier.value = markerIcon;
    await Future.delayed(duration, () async {
      await osmPlatform.setIconMarker(
        _idMap,
        point,
        _osmFlutterState.dynamicMarkerKey,
      );
    });
  }

  @override
  Future<void> clearAllRoads() async {
    await osmPlatform.clearAllRoads(_idMap);
  }

  @override
  Future<List<GeoPoint>> geoPoints() async {
    return await osmPlatform.getGeoPointMarkers(_idMap);
  }

  @override
  Future<void> changeMarker({
    required GeoPoint oldLocation,
    required GeoPoint newLocation,
    MarkerIcon? newMarkerIcon,
    double? angle,
    IconAnchor? iconAnchor,
  }) async {
    var durationMilliSecond = 0;
    if (newMarkerIcon != null) {
      durationMilliSecond = 300;
      _osmFlutterState.widget.dynamicMarkerWidgetNotifier.value = newMarkerIcon;
    }
    await Future.delayed(Duration(milliseconds: durationMilliSecond), () async {
      await osmPlatform.changeMarker(
        _idMap,
        oldLocation,
        newLocation,
        globalKeyIcon:
            newMarkerIcon != null ? _osmFlutterState.dynamicMarkerKey : null,
        angle: angle,
        iconAnchor: iconAnchor,
      );
    });
  }

  @override
  Future<void> removeMarkers(List<GeoPoint> markers) async {
    await osmPlatform.removeMarkers(_idMap, markers);
  }

  @override
  Future<void> toggleLayer({required bool toggle}) async {
    await osmPlatform.toggleLayer(_idMap, toggle: toggle);
  }

  @override
  Future<void> startLocationUpdating() async {
    final isGrant = await _osmFlutterState.requestPermission();
    if (isGrant) {
      await osmPlatform.startLocationUpdating(_idMap);
    }
  }

  @override
  Future<void> stopLocationUpdating() =>
      osmPlatform.stopLocationUpdating(_idMap);
}

extension PrivateMethodOSMController on MobileOSMController {
  AndroidLifecycleMixin? get androidMixinObserver => _androidOSMLifecycle;
}

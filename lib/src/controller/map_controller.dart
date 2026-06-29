import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/src/controller/osm/osm_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:routing_client_dart/routing_client_dart.dart' as routing;

/// class [MapController] : map controller that will control map by select position,enable current location,
/// draw road , show static geoPoint,
///
/// [initMapWithUserPosition] : (bool) if is true, map will show your current location
///
/// [initPosition] : (GeoPoint) if it isn't null, the map will be pointed at this position
class MapController extends BaseMapController {
  late final osrmManager = routing.OSRMManager();
  MapController({
    super.initMapWithUserPosition,
    super.initPosition,
    super.areaLimit = const BoundingBox.world(),
    super.useExternalTracking,
  })  : assert(
          (initMapWithUserPosition != null) ^ (initPosition != null),
        ),
        super(
          customTile: null,
        );

  MapController.withPosition({
    required GeoPoint initPosition,
    super.areaLimit = const BoundingBox.world(),
  }) : super(
          initMapWithUserPosition: null,
          initPosition: initPosition,
          customTile: null,
        );

  MapController.withUserPosition({
    super.areaLimit = const BoundingBox.world(),
    super.useExternalTracking = false,
    UserTrackingOption trackUserLocation = const UserTrackingOption(
      enableTracking: false,
      unFollowUser: false,
    ),
  }) : super(
          initMapWithUserPosition: trackUserLocation,
          initPosition: null,
          customTile: null,
        );

  MapController.customLayer({
    super.initMapWithUserPosition,
    super.initPosition,
    super.areaLimit = const BoundingBox.world(),
    required CustomTile customTile,
  })  : assert(
          (initMapWithUserPosition != null) || initPosition != null,
        ),
        super(
          customTile: customTile,
        );

  MapController.cyclOSMLayer({
    super.initMapWithUserPosition,
    super.initPosition,
    super.areaLimit = const BoundingBox.world(),
  })  : assert(
          (initMapWithUserPosition != null) || initPosition != null,
        ),
        super(
          customTile: CustomTile(
            urlsServers: [
              TileURLs(
                url: "https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm/",
                subdomains: [
                  "a",
                  "b",
                  "c",
                ],
              ),
            ],
            tileExtension: ".png",
            sourceName: "cycleMapnik",
            tileSize: 256,
          ),
        );
  MapController.publicTransportationLayer({
    super.initMapWithUserPosition,
    super.initPosition,
    super.areaLimit = const BoundingBox.world(),
  })  : assert(
          (initMapWithUserPosition != null) || initPosition != null,
        ),
        super(
          customTile: CustomTile(
            urlsServers: [
              TileURLs(url: "https://tile.memomaps.de/tilegen/"),
            ],
            tileExtension: ".png",
            sourceName: "memomapsMapnik",
            tileSize: 256,
          ),
        );

  /// [dispose]
  ///
  /// this method used to dispose controller in the map
  @override
  void dispose() {
    if (!kIsWeb) {
      (osmBaseController as MobileOSMController).dispose();
    }
    super.dispose();
  }

  /// [changeTileLayer]
  ///
  /// this method used to change tiles of map.
  /// raster tiles are supported on all platforms; vector tile styles
  /// (via [CustomTile.styleURL]) are supported on web and iOS.
  Future<void> changeTileLayer({
    CustomTile? tileLayer,
  }) async {
    await osmBaseController.changeTileLayer(tileLayer: tileLayer);
  }

  /// [limitAreaMap]
  ///
  /// this method is to set area camera limit of the map
  ///
  /// [boundingBox] : (BoundingBox) bounding that map cannot exceed from it
  Future<void> limitAreaMap(BoundingBox boundingBox) async {
    await osmBaseController.limitArea(boundingBox);
  }

  /// [removeLimitAreaMap]
  ///
  /// remove area camera limit from the map, this support only in android
  Future<void> removeLimitAreaMap() async {
    await osmBaseController.removeLimitArea();
  }

  // [changeLocation]
  ///
  /// initialise or change of position with creating marker in that specific position
  ///
  /// [p] : geoPoint
  @Deprecated("we will remove this method in future release")
  Future<void> changeLocation(GeoPoint position) async {
    await osmBaseController.changeLocation(position);
  }

  /// [goToLocation]
  ///
  /// animate to specific position with out add marker into the map
  ///
  /// [position] : (GeoPoint) position that will be go to map
  @Deprecated("use moveTo")
  Future<void> goToLocation(GeoPoint position) async {
    await osmBaseController.goToPosition(position);
  }

  /// [moveTo]
  ///
  /// move the camera of the map to specific position with animation or without
  /// using [animate] parameter (default: false)
  ///
  /// [position] : (GeoPoint) position that will be go to map
  Future<void> moveTo(GeoPoint position, {bool animate = false}) async {
    await osmBaseController.goToPosition(position, animate: animate);
  }

  /// [removeMarker]
  ///
  /// remove marker from map of position
  ///
  /// [position] : marker position that we want to remove from the map
  Future<void> removeMarker(GeoPoint position) async {
    osmBaseController.removeMarker(position);
  }

  /// [removeMarkers]
  ///
  ///remove markers from map of position
  Future<void> removeMarkers(List<GeoPoint> geoPoints) async {
    osmBaseController.removeMarkers(geoPoints);
  }

  /// setMarkerIcon
  ///
  /// this method allow to change Icon Marker of specific GeoPoint
  /// thr GeoPoint should be exist,or nothing will happen
  ///
  /// [point] : (GeoPoint) geopoint that you want to change icon
  ///
  /// [icon] : (MarkerIcon) widget that represent the new home marker
  Future setMarkerIcon(GeoPoint point, MarkerIcon icon) async {
    await osmBaseController.setIconMarker(point, icon);
  }

  /*///change advanced picker Icon Marker
  /// we need to global key to recuperate widget from tree element
  /// [key] : (GlobalKey) key of widget that represent the new marker
  Future changeAdvPickerIconMarker(GlobalKey key) async {
    await osmBaseController.changeIconAdvPickerMarker(key);
  }*/

  /// [setStaticPosition]
  ///
  /// change static position in runtime
  ///  [geoPoints] : list of static geoPoint
  ///  [id] : String of that list of static geoPoint
  Future<void> setStaticPosition(List<GeoPoint> geoPoints, String id) async {
    await osmBaseController.setStaticPosition(geoPoints, id);
  }

  /// [setMarkerOfStaticPoint]
  ///
  /// change  Marker of specific static points
  /// we need to global key to recuperate widget from tree element
  /// [id] : (String) id  of the static group geopoint
  ///
  /// [markerIcon] : (MarkerIcon) new marker that will set to the static group geopoint
  Future<void> setMarkerOfStaticPoint({
    required String id,
    required MarkerIcon markerIcon,
  }) =>
      osmBaseController.setIconStaticPositions(
        id,
        markerIcon,
        refresh: true,
      );

  /// [getZoom]
  ///
  /// recuperate current zoom level
  Future<double> getZoom() => osmBaseController.getZoom();

  /// [setZoom]
  ///
  /// this method change the zoom level of the map by setting direcly the [zoomLevel] or  [stepZoom]
  ///
  /// if [stepZoom] specified [zoomLevel] will be ignored
  /// if [zoomLevel] negative,the map will zoomOut
  ///
  /// return Future
  ///
  /// Will throw exception if [zoomLevel] > of [maxZoomLevel] or [zoomLevel] < [minZoomLevel]
  ///
  ///
  /// [zoomLevel] : (double) should be between minZoomLevel and maxZoomLevel
  ///
  /// [stepZoom] : (double) step zoom that will be added to current zoom
  Future<void> setZoom({double? zoomLevel, double? stepZoom}) async {
    await osmBaseController.setZoom(
      zoomLevel: zoomLevel,
      stepZoom: stepZoom,
    );
  }

  /// [zoomIn]
  ///
  /// will change the zoom of the map by zoom in using default stepZoom
  /// positive value:zoomIN
  Future<void> zoomIn() async {
    await osmBaseController.zoomIn();
  }

  /// zoomOut
  ///
  ///  will change the zoom of the map by zoom out using default stepZoom
  /// negative value:zoomOut
  Future<void> zoomOut() async {
    await osmBaseController.zoomOut();
  }

  /// [zoomToBoundingBox]
  ///
  /// this method used to change zoom level to show specific region,
  /// get [box] and [paddinInPixel] as parameter
  ///
  /// [box] : (BoundingBox) the region that the map will move to and adjust the zoom level to be visible
  ///
  /// [paddinInPixel] : (int) padding that will be used to show specific region
  Future<void> zoomToBoundingBox(
    BoundingBox box, {
    int paddinInPixel = 0,
  }) async {
    await osmBaseController.zoomToBoundingBox(
      box,
      paddinInPixel: paddinInPixel,
    );
  }

  /// activate current location position
  Future<void> currentLocation() async {
    await osmBaseController.currentLocation();
  }

  /// recuperation of user current position
  Future<GeoPoint> myLocation() async {
    return await osmBaseController.myLocation();
  }

  /// [enableTracking]
  ///
  /// this method will enable tracking the user location,
  /// [enableStopFollow] is false ,the map will return follow the user location when it change
  ///
  /// [enableStopFollow] is true ,the map will not follow the user location when it change if user change the location of the map
  ///
  /// To disable the rotation of user marker,
  /// change [disableUserMarkerRotation] to true (default : false)
  ///
  ///
  Future<void> enableTracking({
    bool enableStopFollow = false,
    bool disableUserMarkerRotation = false,
    Anchor anchor = Anchor.center,
    bool useDirectionMarker = false,
  }) async {
    await osmBaseController.enableTracking(
        enableStopFollow: enableStopFollow,
        disableMarkerRotation: disableUserMarkerRotation,
        anchor: anchor,
        useDirectionMarker: useDirectionMarker);
  }

  /// [startLocationUpdating]
  ///
  /// Starts receiving the user’s current location.
  ///
  /// use this method to start only receiving the user location without
  /// controlling the map which you can do that manually
  Future<void> startLocationUpdating({
    bool enableStopFollow = false,
    bool disableUserMarkerRotation = false,
    Anchor anchor = Anchor.center,
    bool useDirectionMarker = false,
  }) async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS) {
      await osmBaseController.startLocationUpdating();
      return;
    }
    final hasPermission = await _requestLocationPermission();
    if (!hasPermission) {
      return;
    }

    await osmBaseController.startLocationUpdating();
  }

  Future<bool> _requestLocationPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final locationStatus = await Permission.locationWhenInUse.request();
      if (!_isPermissionGranted(locationStatus)) {
        return false;
      }

      final locationAlwaysStatus = await Permission.locationAlways.request();
      return _isPermissionGranted(locationStatus) ||
          _isPermissionGranted(locationAlwaysStatus);
    }

    final locationStatus = await Permission.locationWhenInUse.request();
    return _isPermissionGranted(locationStatus);
  }

  bool _isPermissionGranted(PermissionStatus status) {
    return status.isGranted || status.isLimited;
  }

  ///[stopLocationUpdating]
  ///
  /// Stops receive of location updates.
  ///
  /// use this method to stop receiving the user location events
  Future<void> stopLocationUpdating() async {
    await osmBaseController.stopLocationUpdating();
  }

  /// disabled tracking user location
  Future<void> disabledTracking() async {
    await osmBaseController.disabledTracking();
  }

  ///  draw road
  ///
  ///  this method show route from 2 point and pass throught interesect points in the map,
  ///
  ///  you can configure your road in runtime with [roadOption], and change the road type drawn by modify
  ///  the [routeType].
  ///
  ///  * to delete the road use [RoadInfo.key]
  ///
  ///  return [RoadInfo] that contain road information such as distance,duration, list of geopoints
  ///
  ///  [start] : started point of your Road
  ///
  ///  [end] : last point of your road
  ///
  ///  [intersectPoint] : (List of GeoPoint) middle position that you want you road to pass through it
  ///
  ///  [roadOption] : (RoadOption) runtime configuration of the road
  Future<RoadInfo> drawRoad(
    GeoPoint start,
    GeoPoint end, {
    RoadType roadType = RoadType.car,
    List<GeoPoint>? intersectPoint,
    RoadOption? roadOption,
  }) async {
    final road = await osrmManager.getRoad(
      waypoints: [
        routing.LngLat(lng: start.longitude, lat: start.latitude),
        ...?intersectPoint
            ?.map((e) => routing.LngLat(lng: e.longitude, lat: e.latitude)),
        routing.LngLat(lng: end.longitude, lat: end.latitude),
      ],
      roadType: switch (roadType) {
        RoadType.car => routing.RoadType.car,
        RoadType.bike => routing.RoadType.bike,
        RoadType.foot => routing.RoadType.foot,
      },
    );
    final instructions = await osrmManager.buildInstructions(road);
    final geoPoints = road.polyline
        ?.map((e) => GeoPoint(latitude: e.lat, longitude: e.lng))
        .toList();
    final roadInfo = RoadInfo(
      instructions: instructions
          .map((e) => Instruction(
                geoPoint: GeoPoint(
                  latitude: e.location.lat,
                  longitude: e.location.lng,
                ),
                instruction: e.instruction,
              ))
          .toList(),
      distance: road.distance,
      duration: road.duration,
      route: geoPoints ?? [],
    );
    unawaited(osmBaseController.drawRoadManually(
      roadInfo.key,
      geoPoints ?? [],
      roadOption ?? const RoadOption.empty(),
    ));
    return roadInfo;
    // return await osmBaseController.drawRoad(
    //   start,
    //   end,
    //   roadType: roadType,
    //   interestPoints: intersectPoint,
    //   roadOption: roadOption,
    // );
  }

  /// [drawMultipleRoad]
  ///
  /// will draw list of roads in sametime with making api calls continually
  /// to get list of GeoPoint for each configuration
  /// and you can define common configuration for all roads that share the same
  /// color,width,roadType using [commonRoadOption]
  /// this method return list of [RoadInfo] with the same order for each config
  ///
  /// parameters :
  ///
  ///  [configs]        : (List) list of road configuration
  ///
  /// [commonRoadOption]  : (MultiRoadOption) common road config that can apply to all roads that doesn't define any inner roadOption
  Future<List<RoadInfo>> drawMultipleRoad(
    List<MultiRoadConfiguration> configs, {
    MultiRoadOption commonRoadOption = const MultiRoadOption.empty(),
  }) async {
    return await osmBaseController.drawMultipleRoad(
      configs,
      commonRoadOption: commonRoadOption,
    );
  }

  /// [removeLastRoad]
  ///
  ///delete last road draw in the map
  Future<void> removeLastRoad() async {
    await osmBaseController.removeLastRoad();
  }

  /// [removeRoad]
  ///
  ///delete road draw in the map using [roadKey]
  Future<void> removeRoad({required String roadKey}) async {
    await osmBaseController.removeRoad(roadKey: roadKey);
  }

  /// [clearAllRoads]
  ///this method will delete all roads drawn in the map
  Future<void> clearAllRoads() async {
    await osmBaseController.clearAllRoads();
  }

  /// draw circle into map
  Future<void> drawCircle(CircleOSM circleOSM) async {
    await osmBaseController.drawCircle(circleOSM);
  }

  /// remove specific circle in the map
  Future<void> removeCircle(String keyCircle) async {
    await osmBaseController.removeCircle(keyCircle);
  }

  /// draw rect into map
  Future<void> drawRect(RectOSM rectOSM) async {
    await osmBaseController.drawRect(rectOSM);
  }

  /// remove specific region in the map
  Future<void> removeRect(String keyRect) async {
    await osmBaseController.removeRect(keyRect);
  }

  /// remove all rect shape from map
  Future<void> removeAllRect() async {
    return await osmBaseController.removeAllRect();
  }

  /// clear all circle
  Future<void> removeAllCircle() async {
    await osmBaseController.removeAllCircle();
  }

  /// remove all shape from map
  Future<void> removeAllShapes() async {
    await osmBaseController.removeAllShapes();
  }

  /// [rotateMapCamera]
  ///
  /// rotate camera of osm map
  Future<void> rotateMapCamera(double degree) async {
    return await osmBaseController.mapOrientation(degree);
  }

  ///   [drawRoadManually]
  ///
  ///   if you have you own routing api you can use this method to draw your route
  ///   manually and you can customize the color,width of the route
  ///   zoom into the boundingbox and show POIs of the route
  ///
  ///   return String unique key can be used to delete road
  ///   paramteres :
  ///
  ///  [path] : (list of GeoPoint) path of the road
  ///
  ///  [roadOption] : (RoadOption) define styles of the road
  Future<void> drawRoadManually(
    List<GeoPoint> path,
    RoadOption roadOption,
  ) =>
      osmBaseController.drawRoadManually(
        UniqueKey().toString(),
        path,
        roadOption,
      );

  Future<void> addMarker(
    GeoPoint p, {
    MarkerIcon? markerIcon,
    double? angle,
    IconAnchor? iconAnchor,
  }) async {
    if (angle != null) {
      assert(
          angle >= 0 && angle <= 2 * pi, "angle should be between 0 and 2*pi");
    }
    await osmBaseController.addMarker(
      p,
      markerIcon: markerIcon,
      angle: angle,
      iconAnchor: iconAnchor,
    );
  }

  Future<void> changeLocationMarker({
    required GeoPoint oldLocation,
    required GeoPoint newLocation,
    MarkerIcon? markerIcon,
    double? angle,
    IconAnchor? iconAnchor,
  }) async {
    await osmBaseController.changeMarker(
      oldLocation: oldLocation,
      newLocation: newLocation,
      newMarkerIcon: markerIcon,
      angle: angle,
      iconAnchor: iconAnchor,
    );
  }

  Future<BoundingBox> get bounds async => osmBaseController.getBounds();

  /// centerMap
  ///
  /// this attribute to retrieve center location of the map
  Future<GeoPoint> get centerMap async => osmBaseController.getMapCenter();

  Future<List<GeoPoint>> get geopoints async => osmBaseController.geoPoints();
}

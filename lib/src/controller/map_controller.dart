import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/src/controller/osm/osm_controller.dart';

/// class [MapController] : map controller that will control map by select position,enable current location,
/// draw road , show static geoPoint,
///
/// [initMapWithUserPosition] : (bool) if is true, map will show your current location
///
/// [initPosition] : (GeoPoint) if it isn't null, the map will be pointed at this position
class MapController extends BaseMapController {
  MapController({
    bool initMapWithUserPosition = true,
    GeoPoint? initPosition,
    BoundingBox? areaLimit = const BoundingBox.world(),
  })  : assert(
          initMapWithUserPosition ^ (initPosition != null),
        ),
        super(
          initMapWithUserPosition: initMapWithUserPosition,
          initPosition: initPosition,
          areaLimit: areaLimit,
          customTile: null,
        );

  MapController.withPosition({
    required GeoPoint initPosition,
    BoundingBox? areaLimit = const BoundingBox.world(),
  }) : super(
          initMapWithUserPosition: false,
          initPosition: initPosition,
          areaLimit: areaLimit,
          customTile: null,
        );

  MapController.withUserPosition({
    BoundingBox? areaLimit = const BoundingBox.world(),
  }) : super(
          initMapWithUserPosition: true,
          initPosition: null,
          areaLimit: areaLimit,
          customTile: null,
        );

  MapController.customLayer({
    bool initMapWithUserPosition = true,
    GeoPoint? initPosition,
    BoundingBox? areaLimit = const BoundingBox.world(),
    required CustomTile customTile,
  })  : assert(
          initMapWithUserPosition || initPosition != null,
        ),
        super(
          initMapWithUserPosition: initMapWithUserPosition,
          initPosition: initPosition,
          areaLimit: areaLimit,
          customTile: customTile,
        );

  MapController.cyclOSMLayer({
    bool initMapWithUserPosition = true,
    GeoPoint? initPosition,
    BoundingBox? areaLimit = const BoundingBox.world(),
  })  : assert(
          initMapWithUserPosition || initPosition != null,
        ),
        super(
          initMapWithUserPosition: initMapWithUserPosition,
          initPosition: initPosition,
          areaLimit: areaLimit,
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
    bool initMapWithUserPosition = true,
    GeoPoint? initPosition,
    BoundingBox? areaLimit = const BoundingBox.world(),
  })  : assert(
          initMapWithUserPosition || initPosition != null,
        ),
        super(
          initMapWithUserPosition: initMapWithUserPosition,
          initPosition: initPosition,
          areaLimit: areaLimit,
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
  void dispose() {
    (osmBaseController as MobileOSMController).dispose();
    super.dispose();
  }

  /// [changeTileLayer]
  ///
  ///
  Future<void> changeTileLayer({
    CustomTile? tileLayer,
  }) async {
    await osmBaseController.changeTileLayer(tileLayer: tileLayer);
  }

  /// [limitAreaMap]
  ///
  /// set area camera limit of the map
  /// [box] : (BoundingBox) bounding that map cannot exceed from it
  Future<void> limitAreaMap(BoundingBox box) async {
    await osmBaseController.limitArea(box);
  }

  /// [removeLimitAreaMap]
  ///
  /// remove area camera limit from the map, this support only in android
  Future<void> removeLimitAreaMap() async {
    await osmBaseController.removeLimitArea();
  }

  /// [changeLocation]
  ///
  /// initialise or change of position with creating marker in that specific position
  ///
  /// [p] : geoPoint
  Future<void> changeLocation(GeoPoint p) async {
    await osmBaseController.changeLocation(p);
  }

  /// [goToLocation]
  ///
  ///animate  to specific position with out add marker into the map
  ///
  /// [p] : (GeoPoint) position that will be go to map
  Future<void> goToLocation(GeoPoint p) async {
    await osmBaseController.goToPosition(p);
  }

  /// [removeMarker]
  ///
  ///remove marker from map of position
  /// [p] : geoPoint
  Future<void> removeMarker(GeoPoint p) async {
    osmBaseController.removeMarker(p);
  }

  /// [changeIconMarker]
  ///
  /// this method allow to change Home Icon Marker
  ///
  /// [icon] : (MarkerIcon) widget that represent the new home marker
  Future changeIconMarker(MarkerIcon icon) async {
    await osmBaseController.changeDefaultIconMarker(icon);
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

  /// change static position in runtime
  ///  [geoPoints] : list of static geoPoint
  ///  [id] : String of that list of static geoPoint
  Future<void> setStaticPosition(List<GeoPoint> geoPoints, String id) async {
    await osmBaseController.setStaticPosition(geoPoints, id);
  }

  ///change  Marker of specific static points
  /// we need to global key to recuperate widget from tree element
  /// [id] : (String) id  of the static group geopoint
  ///
  /// [markerIcon] : (MarkerIcon) new marker that will set to the static group geopoint
  Future<void> setMarkerOfStaticPoint({
    required String id,
    required MarkerIcon markerIcon,
  }) async {
    await osmBaseController.setIconStaticPositions(id, markerIcon,
        refresh: true);
  }

  /// recuperate current zoom level
  Future<double> getZoom() async => await osmBaseController.getZoom();

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

  /// enabled tracking user location
  Future<void> enableTracking() async {
    await osmBaseController.enableTracking();
  }

  /// disabled tracking user location
  Future<void> disabledTracking() async {
    await osmBaseController.disabledTracking();
  }

  @Deprecated(
    "this method will be removed in 0.25.0,use callback `listenerMapSingleTapping` or `listenerMapLongTapping` "
    "to listener to click on the map, and use `addMarker` to create marker in that specific location",
  )

  /// pick Position in map
  Future<GeoPoint> selectPosition({
    MarkerIcon? icon,
    String imageURL = "",
  }) async {
    GeoPoint p = await osmBaseController.selectPosition(
      icon: icon,
      imageURL: imageURL,
    );
    return p;
  }

  ///  draw road
  ///
  ///  this method show route from 2 point and pass throught interesect points in the map,
  ///
  ///  you can configure your road in runtime with [roadOption], and change the road type drawn by modify
  ///  the [routeType].
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
    return await osmBaseController.drawRoad(
      start,
      end,
      roadType: roadType,
      interestPoints: intersectPoint,
      roadOption: roadOption,
    );
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
  ///delete last road draw in the map
  Future<void> removeLastRoad() async {
    await osmBaseController.removeLastRoad();
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

  Future<void> advancedPositionPicker() async {
    await osmBaseController.advancedPositionPicker();
  }

  /// select current position and finish advanced picker
  Future<GeoPoint> selectAdvancedPositionPicker() async {
    return await osmBaseController.selectAdvancedPositionPicker();
  }

  /// get current position
  Future<GeoPoint> getCurrentPositionAdvancedPositionPicker() async {
    return await osmBaseController.getCurrentPositionAdvancedPositionPicker();
  }

  /// cancel advanced picker
  Future<void> cancelAdvancedPositionPicker() async {
    return await osmBaseController.cancelAdvancedPositionPicker();
  }

  /// rotate camera of osm map
  Future<void> rotateMapCamera(double degree) async {
    return await osmBaseController.mapOrientation(degree);
  }

  ///   draw road manually
  ///
  ///   if you have you own routing api you can use this method to draw your route
  ///   manually and you can customize the color,width of the route
  ///   zoom into the boundingbox and show POIs of the route
  ///
  ///   paramteres :
  ///
  ///  [path] : (list of GeoPoint) path of the road
  ///
  ///  [roadColor] : (Color) the color that uses to change the  default road color
  ///
  ///  [roadWidth] : (double) uses to change width of the  road
  ///
  ///  [zoomInto] : (bool) uses to zoom out to the boundingbox of the route
  ///
  ///  [deleteOldRoads] : (bool) uses to delete the last road drawn in the map
  ///
  ///  [interestPointIcon] : (MarkerIcon) uses to change marker icon of interestPoints
  ///
  ///  [interestPoints] : (List of GeoPoint) list of interest point that you want to show marker for them
  Future<void> drawRoadManually(
    List<GeoPoint> path, {
    Color roadColor = Colors.green,
    double roadWidth = 5.0,
    bool zoomInto = false,
    bool deleteOldRoads = false,
    MarkerIcon? interestPointIcon,
    List<GeoPoint> interestPoints = const [],
  }) async {
    assert(path.length > 3);
    assert(roadWidth > 0);
    await osmBaseController.drawRoadManually(
      path,
      roadColor: roadColor,
      width: roadWidth,
      zoomInto: zoomInto,
      deleteOldRoads: deleteOldRoads,
      interestPoints: interestPoints,
      interestPointIcon: interestPointIcon,
    );
  }

  Future<void> addMarker(
    GeoPoint p, {
    MarkerIcon? markerIcon,
    double? angle,
  }) async {
    if (angle != null) {
      assert(angle >= -pi && angle <= pi, "angle should be between -pi and pi");
    }
    await osmBaseController.addMarker(p, markerIcon: markerIcon, angle: angle);
  }

  Future<void> changeLocationMarker({
    required GeoPoint oldLocation,
    required GeoPoint newLocation,
    MarkerIcon? markerIcon,
  }) async {
    await osmBaseController.changeMarker(
      oldLocation: oldLocation,
      newLocation: newLocation,
      newMarkerIcon: markerIcon,
    );
  }

  Future<BoundingBox> get bounds async => await osmBaseController.getBounds();

  Future<GeoPoint> get centerMap async =>
      await osmBaseController.getMapCenter();

  Future<List<GeoPoint>> get geopoints async =>
      await osmBaseController.geoPoints();
}

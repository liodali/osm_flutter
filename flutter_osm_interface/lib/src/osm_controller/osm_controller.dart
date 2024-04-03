import 'package:flutter_osm_interface/src/types/types.dart';

abstract class IBaseOSMController {
  Future<void> initPositionMap({
    GeoPoint? initPosition,
    bool useExternalTracking = false,
    UserTrackingOption? userPositionOption,
  });

  /// [changeTileLayer]
  ///
  /// change tile layer of the map en runtime using [tileLayer]
  Future<void> changeTileLayer({
    CustomTile? tileLayer,
  });

  Future<void> configureZoomMap(
    double minZoomLevel,
    double maxZoomLevel,
    double stepZoom,
    double initZoom,
  );

  ///initialise or change of position
  ///
  /// [p] : (GeoPoint) position that will be added to map
  Future<void> changeLocation(GeoPoint p);

  /// [addMarker]
  ///
  /// create marker int specific position without
  /// change map camera,
  /// you can rotate marker using [angle]
  /// and also set marker anchor using [iconAnchor]
  ///
  /// [p] : (GeoPoint) desired location
  ///
  /// [markerIcon] : (MarkerIcon) set icon of the marker
  Future<void> addMarker(
    GeoPoint p, {
    MarkerIcon? markerIcon,
    double? angle,
    IconAnchor? iconAnchor,
  });

  /// [changeMarker]
  Future<void> changeMarker({
    required GeoPoint oldLocation,
    required GeoPoint newLocation,
    MarkerIcon? newMarkerIcon,
    double? angle = null,
    IconAnchor? iconAnchor,
  });

  /// [removeMarker]
  /// remove marker from map of position
  ///
  /// [p] : geoPoint
  Future<void> removeMarker(
    GeoPoint p,
  );

  /// setIconMarker
  /// this method change marker icon , marker should be already exist in the map
  /// or it will throw exception that marker not exist
  ///
  /// [point]      : (geoPoint) geoPoint that want to change Icon
  ///
  /// [markerIcon] : (MarkerIcon) the new icon marker that will replace old icon
  Future<void> setIconMarker(GeoPoint point, MarkerIcon markerIcon);

  ///change  Marker of specific static points
  /// we need to global key to recuperate widget from tree element
  /// [id] : (String) id  of the static group geopoint
  /// [markerIcon] : (MarkerIcon) new marker that will set to the static group geopoint
  Future<void> setIconStaticPositions(
    String id,
    MarkerIcon markerIcon, {
    bool refresh = false,
  });

  /// change static position in runtime
  ///  [geoPoints] : list of static geoPoint
  ///  [id] : String of that list of static geoPoint
  Future<void> setStaticPosition(List<GeoPoint> geoPoints, String id);

  /// getZoom
  /// this method will return current zoom level of the map
  /// the type of the value returned is double,this value should be between minZoomLevel and maxZoomLevel
  Future<double> getZoom();

  Future<void> setZoom({
    double? zoomLevel,
    double? stepZoom,
  });

  /// zoomIn use stepZoom
  Future<void> zoomIn();

  /// zoomOut use stepZoom
  Future<void> zoomOut();

  Future<void> setStepZoom(
    int stepZoom,
  );

  Future<void> setMinimumZoomLevel(
    double minZoom,
  );

  Future<void> setMaximumZoomLevel(
    double maxZoom,
  );

  /// zoomToBoundingBox
  ///this method will change region and adjust the zoom level to the specific region
  ///
  /// [box] : (BoundingBox) the region that will change zoom level to be visible in the mapview
  ///
  ///  [paddinInPixel] : (int) the padding that will be added to region to adjust the zoomLevel
  Future<void> zoomToBoundingBox(
    BoundingBox box, {
    int paddinInPixel = 0,
  });

  Future<GeoPoint> getMapCenter();

  /// activate current location position
  Future<void> currentLocation();

  /// recuperation of user current position
  Future<GeoPoint> myLocation();

  /// goToPosition
  /// this method will to change current camera location
  /// to another specific position without create marker
  /// has attribute which is the desired location
  /// [p] : (GeoPoint) desired location
  /// [animate] : (bool) animate the camera if true (default:false)
  Future<void> goToPosition(GeoPoint p,{bool animate = false});

  /// [enableTracking]
  /// 
  /// to start tracking user location where we will show [personMarker] 
  /// or [directionMarker] depend on heading value but we can configure the marker to be always
  /// [directionMarker] by set [useDirectionMarker] to true (default:false)
  /// 
  /// we can also enable stop following user when the user move the map by set [enableStopFollow] to true
  /// with [disableMarkerRotation] we can disable rotation of the marker
  /// and [anchor] will change the position of the marker compared to center of the marker
  /// 
  Future<void> enableTracking({
    bool enableStopFollow = false,
    bool disableMarkerRotation,
    Anchor anchor,
    bool useDirectionMarker = false,
  });

  /// disabled tracking user location
  Future<void> disabledTracking();

  /// [startLocationUpdating]
  ///
  Future<void> startLocationUpdating();
  /// [stopLocationUpdating]
  ///
  Future<void> stopLocationUpdating();

  /// [drawRoad]
  /// this method will call ORSM api to get list of geopoint and
  /// that will be transformed into polyline to be drawn in the map
  ///
  ///  parameters :
  ///  [start] : (GeoPoint) started point of your Road
  ///
  ///  [end] : (GeoPoint) destination point of your road
  ///
  ///  [interestPoints] : (List of GeoPoint) middle point that you want to be passed by your route
  ///
  ///  [roadType] : (RoadType)  indicate the type of the route  that you want to be road to be used (default :RoadType.car)
  ///
  ///  [roadOption] : (RoadOption) option of the road width, color,zoomInto,etc ...
  Future<RoadInfo> drawRoad(
    GeoPoint start,
    GeoPoint end, {
    RoadType roadType = RoadType.car,
    List<GeoPoint>? interestPoints,
    RoadOption? roadOption,
  });

  /// [drawRoadManually]
  ///
  /// this method allow to draw road manually without using any internal api
  /// the path should be provided from any external api like your own OSRM server or google map api
  /// and you can change color of the road and width also
  ///
  ///  [path]  : (list) list of GeoPoint that represent the path of the road
  ///
  ///  [roadOption] : (RoadOption) contain style of road such as color,width,borderColor,zoomInto
  Future<String> drawRoadManually(
    String Key,
    List<GeoPoint> path,
    RoadOption roadOption,
  );

  /// [drawMultipleRoad]
  /// this method will call draw list of roads in sametime with making  api continually
  /// to get list of GeoPoint for each configuration and you can define common configuration for all roads that share the same
  /// color,width,roadType using [commonRoadOption]
  /// this method return list of [RoadInfo] with the same order for each config
  ///
  ///  parameters :
  ///  [configs]        : (List) list of road configuration
  ///
  /// [commonRoadOption]  : (MultiRoadOption) common road config that can apply to all roads that doesn't define any inner roadOption
  Future<List<RoadInfo>> drawMultipleRoad(
    List<MultiRoadConfiguration> configs, {
    MultiRoadOption commonRoadOption,
  });

  /// [clearAllRoads]
  /// this method will delete all road drawn in the map
  Future<void> clearAllRoads();

  /// [removeLastRoad]
  ///
  /// this method will delete last road draw in the map
  Future<void> removeLastRoad();

  /// [removeRoad]
  ///
  /// this method will delete  road using [roadKey] in the map
  /// it the [roadKey] not exist nothing will happen
  Future<void> removeRoad({required String roadKey});

  /// draw circle shape in the map
  ///
  /// [circleOSM] : (CircleOSM) represent circle in osm map
  Future<void> drawCircle(CircleOSM circleOSM);

  /// remove circle shape from map
  /// [key] : (String) key of the circle
  Future<void> removeCircle(String key);

  /// draw rect shape in the map
  /// [regionOSM] : (RegionOSM) represent region in osm map
  Future<void> drawRect(RectOSM rectOSM);

  /// remove region shape from map
  /// [key] : (String) key of the region
  Future<void> removeRect(String key);

  /// remove all rect shape from map
  Future<void> removeAllRect();

  /// remove all circle shapes from map
  Future<void> removeAllCircle();

  /// remove all shapes from map
  Future<void> removeAllShapes();

  Future<void> mapOrientation(double degree);

  Future<BoundingBox> getBounds();

  Future<void> limitArea(
    BoundingBox box,
  );

  /// removeLimitArea
  ///
  /// this method will remove the region limitation for camera movement
  /// and the user can move freely
  Future<void> removeLimitArea();

  /// [geoPoints]
  ///
  /// this method will get location of existing marker in the mapview
  /// this method will not get static markers.
  ///
  /// return list of geopoint that represent location of the markers
  Future<List<GeoPoint>> geoPoints();

  /// [removeMarkers]
  ///
  /// this method will delete list of markers, even if the markers not exist will be skipped
  Future<void> removeMarkers(
    List<GeoPoint> markers,
  );

  /// [toggleLayer]
  ///
  /// change visibility of all layers of the map
  Future<void> toggleLayer({
    required bool toggle,
  });
}

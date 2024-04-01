// ignore_for_file: avoid_unused_constructor_parameters, non_constant_identifier_names, comment_references

@JS()
library osm_interop;

import 'package:flutter_osm_web/src/interop/models/custom_tile_js.dart';
import 'package:flutter_osm_web/src/interop/models/shape_js.dart';
import 'package:js/js.dart';

import 'models/bounding_box_js.dart';
import 'models/geo_point_js.dart';

@JS('centerMap')
external Map<String, double> centerMap(
  int mapId,
);

@JS('getBounds')
external Map<String, double> getBounds(
  int mapId,
);

@JS('locateMe')
external Map<String, double> locateMe(
  int mapId,
);

@JS('initMapLocation')
external dynamic initMapLocation(int mapId, GeoPointJs point);

@JS('setZoomControl')
external dynamic setZoomControl(int mapId, bool showZoomControl);

@JS('configZoom')
external dynamic configZoom(
  int mapId,
  double stepZoom,
  double initZoom,
  double minZoomLevel,
  double maxZoomLevel,
);

@JS('setZoomStep')
external dynamic setZoomStep(
  int mapId,
  double stepZoom,
);

@JS('zoomIn')
external dynamic zoomIn(
  int mapId,
);

@JS('zoomOut')
external dynamic zoomOut(
  int mapId,
);

@JS('setZoom')
external dynamic setZoom(
  int mapId,
  double zoom,
);

@JS('setZoomStep')
external dynamic setZoomWithStep(
  int mapId,
  double stepZoom,
);

@JS('getZoom')
external dynamic getZoom();

@JS('setMaxZoomLevel')
external dynamic setMaxZoomLevel(
  int mapId,
  double maxZoomLvl,
);

@JS('setMinZoomLevel')
external dynamic setMinZoomLevel(
  int mapId,
  double minZoomLvl,
);

@JS('setDefaultIcon')
external dynamic setDefaultIcon(
  int mapId,
  String base64,
);

@JS('addMarker')
external dynamic addMarker(
  int mapId,
  GeoPointJs p,
  SizeJs size,
  String icon,
  double? angle,
  IconAnchorJS? iconAnchor,
);

@JS('changeMarker')
external dynamic changeMarker(
  int mapId,
  GeoPointJs oldP,
  GeoPointJs newP,
  String? icon,
  SizeJs? iconSize,
  double? angle,
  IconAnchorJS? iconAnchor,
);

@JS('modifyMarker')
external dynamic modifyMarker(
  int mapId,
  GeoPointJs p,
  String icon,
);

@JS('addPosition')
external dynamic addPosition(
  int mapId,
  GeoPointJs p,
  bool showMarker,
  bool animate,
);

@JS('removeMarker')
external dynamic removeMarker(int mapId, GeoPointJs p);

@JS('currentUserLocation')
external dynamic currentUserLocation(
  int mapId,
);

@JS('setStaticGeoPoints')
external dynamic setStaticGeoPoints(
  int mapId,
  String id,
  List<GeoPointJs> points,
);

@JS('setStaticGeoPointsWithOrientation')
external dynamic setStaticGeoPointsWithOrientation(
  int mapId,
  String id,
  List<GeoPointWithOrientationJs> points,
);

@JS('setIconStaticGeoPoints')
external dynamic setIconStaticGeoPoints(
  int mapId,
  String id,
  String icons,
);

@JS('limitArea')
external dynamic limitArea(
  int mapId,
  BoundingBoxJs box,
);

@JS('flyToBounds')
external dynamic flyToBounds(
  int mapId,
  BoundingBoxJs box,
  int padding,
);

@JS('drawRoad')
external dynamic drawRoad(
  int mapId,
  String key,
  List<GeoPointJs> route,
  String color,
  double roadWidth,
  bool zoomInto,
  String roadBorderColor,
  double roadBorderWidth,
  List<GeoPointJs> interestPoints,
  String? iconInterestPoints,
);

@JS('removeLastRoad')
external dynamic removeLastRoad(
  int mapId,
);

@JS("getGeoPoints")
external Map<String, String> getGeoPoints(
  int mapId,
);

@JS("setUserLocationIconMarker")
external dynamic setUserLocationIconMarker(
  int mapId,
  String icon,
  SizeJs size,
);
@JS("setUserLocationDirectionIconMarker")
external dynamic setUserLocationDirectionIconMarker(
  int mapId,
  String icon,
  SizeJs size,
);

@JS("enableTracking")
external dynamic enableTracking(
  int mapId,
  bool enableStopFollow,
  bool useDirectionMarker,
  IconAnchorJS anchorJS,
);

@JS("disableTracking")
external dynamic disableTracking(
  int mapId,
);
@JS("startLocationUpdating")
external dynamic startLocationUpdating(
  int mapId,
);
@JS("stopLocationUpdating")
external dynamic stopLocationUpdating(
  int mapId,
);
@JS('changeTileLayer')
external dynamic changeTileLayer(
  int mapId,
  CustomTileJs? tile,
);

@JS('drawRect')
external dynamic drawRect(
  int mapId,
  RectShapeJS rectShapeJS,
  List<GeoPointJs> bounds,
);

@JS('drawCircle')
external dynamic drawCircle(
  int mapId,
  CircleShapeJS circle,
);

@JS('removePath')
external dynamic removePath(
  int mapId,
  String rectKey,
);
@JS('removeAllCircle')
external dynamic removeAllCircle(int mapId);

@JS('removeAllRect')
external dynamic removeAllRect(int mapId);

@JS('removeAllShapes')
external dynamic removeAllShapes(int mapId);

@JS('clearAllRoads')
external dynamic clearAllRoads(int mapId);

@JS('removeRoad')
external dynamic removeRoad(int mapId, String roadKey);


@JS('toggleAlllayers')
external dynamic toggleAlllayers(int mapId, bool toggle);

@JS('setUpMap')
external dynamic setUpMap(int mapId);

/// Allows assigning a function to be callable from `window.initMapFinish()`
@JS('initMapFinish')
external set initMapFinish(void Function(int,bool) f);

/// Allows assigning a function to be callable from `window.onGeoPointClicked(lat,lon)`
@JS('onStaticGeoPointClicked')
external set onStaticGeoPointClicked(void Function(int,double, double) f);

/// Allows assigning a function to be callable from `window.onMapSingleTapClicked(lat,lon)`
@JS('onMapSingleTapListener')
external set onMapSingleTapListener(void Function(int,double, double) f);

/// Allows assigning a function to be callable from `window.onRegionChangedListener(region)`
@JS('onRegionChangedListener')
external set onRegionChangedListener(
    void Function(int,double, double, double, double, double, double) f);

/// Allows assigning a function to be callable from `window.onRoadListener(road)`
@JS('onRoadListener')
external set onRoadListener(
  void Function(
   int, String,
  ) f,
);

/// Allows assigning a function to be callable from `window.onUserPositionListener(lat,lon)`
@JS('onUserPositionListener')
external set onUserPositionListener(void Function(int,double, double) f);

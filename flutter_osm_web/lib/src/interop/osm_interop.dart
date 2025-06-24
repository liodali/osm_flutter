// ignore_for_file: avoid_unused_constructor_parameters, non_constant_identifier_names, comment_references

@JS()
library osm_interop;

import 'package:flutter_osm_web/src/interop/models/custom_tile_js.dart';
import 'package:flutter_osm_web/src/interop/models/shape_js.dart';
import 'dart:js_interop';

import 'package:flutter_osm_web/src/interop/models/bounding_box_js.dart';
import 'package:flutter_osm_web/src/interop/models/geo_point_js.dart';
import 'package:flutter_osm_web/src/interop/models/road_option_js.dart';

@JS('removeControls')
external JSPromise removeControls(
  JSNumber mapId,
);

@JS('centerMap')
external GeoPointJs centerMap(
  JSNumber mapId,
);

@JS('getBounds')
external BoundingBoxJs getBounds(
  JSNumber mapId,
);

@JS('locateMe')
external JSPromise<JSString> locateMe(
  JSNumber mapId,
);

@JS('initMapLocation')
external JSPromise initMapLocation(JSNumber mapId, GeoPointJs point);

@JS('setZoomControl')
external JSPromise setZoomControl(JSNumber mapId, JSBoolean showZoomControl);

@JS('configZoom')
external JSPromise configZoom(
  JSNumber mapId,
  JSNumber stepZoom,
  JSNumber initZoom,
  JSNumber minZoomLevel,
  JSNumber maxZoomLevel,
);

@JS('setZoomStep')
external JSPromise setZoomStep(
  JSNumber mapId,
  JSNumber stepZoom,
);

@JS('zoomIn')
external JSPromise zoomIn(
  JSNumber mapId,
);

@JS('zoomOut')
external JSPromise zoomOut(
  JSNumber mapId,
);

@JS('setZoom')
external JSPromise setZoom(
  JSNumber mapId,
  JSNumber zoom,
);

@JS('setZoomStep')
external JSPromise setZoomWithStep(
  JSNumber mapId,
  JSNumber stepZoom,
);

@JS('getZoom')
external JSPromise<JSNumber> getZoom(
  JSNumber mapId,
);

@JS('setMaxZoomLevel')
external JSPromise setMaxZoomLevel(
  JSNumber mapId,
  JSNumber maxZoomLvl,
);

@JS('setMinZoomLevel')
external JSPromise setMinZoomLevel(
  JSNumber mapId,
  JSNumber minZoomLvl,
);

@JS('setDefaultIcon')
external JSPromise setDefaultIcon(
  JSNumber mapId,
  JSString base64,
);

@JS('addMarker')
external JSPromise addMarker(
  JSNumber mapId,
  GeoPointJs p,
  SizeJs size,
  JSString icon,
  JSNumber? angle,
  IconAnchorJS? iconAnchor,
);

@JS('changeMarker')
external JSPromise changeMarker(
  JSNumber mapId,
  GeoPointJs currentPoint,
  GeoPointJs? newP,
  JSString? icon,
  SizeJs? iconSize,
  JSNumber? angle,
  IconAnchorJS? iconAnchor,
);

@JS('modifyMarker')
external JSPromise modifyMarker(
  JSNumber mapId,
  GeoPointJs p,
  JSString icon,
);

@JS('addPosition')
external JSPromise addPosition(
  JSNumber mapId,
  GeoPointJs p,
  JSBoolean showMarker,
  JSBoolean animate,
);

@JS('removeMarker')
external JSPromise removeMarker(JSNumber mapId, GeoPointJs p);

@JS('currentUserLocation')
external JSPromise currentUserLocation(
  JSNumber mapId,
);

@JS('setStaticGeoPoints')
external JSPromise setStaticGeoPoints(
  JSNumber mapId,
  JSString id,
  JSArray<GeoPointJs> points,
);

@JS('setStaticGeoPointsWithOrientation')
external JSPromise setStaticGeoPointsWithOrientation(
  JSNumber mapId,
  JSString id,
  JSArray<GeoPointWithOrientationJs> points,
);

@JS('setIconStaticGeoPoints')
external JSPromise setIconStaticGeoPoints(
  JSNumber mapId,
  JSString id,
  JSString icons,
);

@JS('limitArea')
external JSAny limitArea(
  JSNumber mapId,
  BoundingBoxJs box,
);

@JS('flyToBounds')
external JSPromise flyToBounds(
  JSNumber mapId,
  BoundingBoxJs box,
  JSNumber padding,
);

@JS('drawRoad')
external JSNumber drawRoad(
  JSNumber mapId,
  JSString key,
  JSArray<GeoPointJs> route,
  JSArray<GeoPointJs> interestPoints,
  RoadOptionJS roadOptionJS,
  // JSString color,
  // JSNumber roadWidth,
  // JSBoolean zoomInto,
  // JSString roadBorderColor,
  // JSNumber roadBorderWidth,
  // JSString? iconInterestPoints,
);

@JS('removeLastRoad')
external JSPromise removeLastRoad(
  JSNumber mapId,
);

@JS("getGeoPoints")
external JSPromise<JSString> getGeoPoints(
  JSNumber mapId,
);

@JS("setUserLocationIconMarker")
external JSPromise setUserLocationIconMarker(
  JSNumber mapId,
  String icon,
  SizeJs size,
);
@JS("setUserLocationDirectionIconMarker")
external JSPromise setUserLocationDirectionIconMarker(
  JSNumber mapId,
  JSString icon,
  SizeJs size,
);

@JS("enableTracking")
external JSPromise enableTracking(
  JSNumber mapId,
  JSBoolean enableStopFollow,
  JSBoolean useDirectionMarker,
  IconAnchorJS anchorJS,
);

@JS("disableTracking")
external JSPromise disableTracking(
  JSNumber mapId,
);
@JS("startLocationUpdating")
external JSPromise startLocationUpdating(
  JSNumber mapId,
);
@JS("stopLocationUpdating")
external JSPromise stopLocationUpdating(
  JSNumber mapId,
);
@JS('changeTileLayer')
external JSPromise changeTileLayer(
  JSNumber mapId,
  CustomTileJs? tile,
);

@JS('drawRect')
external JSPromise drawRect(
  JSNumber mapId,
  RectShapeJS rectShapeJS,
  JSArray<GeoPointJs> bounds,
);

@JS('drawCircle')
external JSPromise drawCircle(
  JSNumber mapId,
  CircleShapeJS circle,
);

@JS('removePath')
external JSPromise removePath(
  JSNumber mapId,
  JSString rectKey,
);
@JS('removeAllCircle')
external JSPromise removeAllCircle(JSNumber mapId);

@JS('removeAllRect')
external JSPromise removeAllRect(JSNumber mapId);

@JS('removeAllShapes')
external JSPromise removeAllShapes(JSNumber mapId);

@JS('clearAllRoads')
external JSPromise clearAllRoads(JSNumber mapId);

@JS('removeRoad')
external JSPromise removeRoad(JSNumber mapId, JSString roadKey);

@JS('toggleAlllayers')
external JSPromise toggleAlllayers(JSNumber mapId, JSBoolean toggle);

@JS('setUpMap')
external JSNumber setUpMap(JSNumber mapId);

/// Allows assigning a function to be callable from `window.initMapFinish()`
@JS('initMapFinish')
external set initMapFinish(JSFunction f);

/// Allows assigning a function to be callable from `window.onGeoPointClicked(lat,lon)`
// @JS('onStaticGeoPointClicked')
// external set onStaticGeoPointClicked(JSFunction f);

@JS('onGeoPointClicked')
external set onGeoPointClicked(JSFunction f);

@JS('onGeoPointLongPress')
external set onGeoPointLongPress(JSFunction f);

/// Allows assigning a function to be callable from `window.onMapSingleTapClicked(lat,lon)`
@JS('onMapSingleTapListener')
external set onMapSingleTapListener(JSFunction f);

/// Allows assigning a function to be callable from `window.onRegionChangedListener(region)`
@JS('onRegionChangedListener')
external set onRegionChangedListener(JSFunction f);

/// Allows assigning a function to be callable from `window.onRoadListener(road)`
@JS('onRoadListener')
external set onRoadListener(
  JSFunction f,
);

/// Allows assigning a function to be callable from `window.onUserPositionListener(lat,lon)`
@JS('onUserPositionListener')
external set onUserPositionListener(JSFunction f);

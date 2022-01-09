// ignore_for_file: avoid_unused_constructor_parameters, non_constant_identifier_names, comment_references

@JS()
library osm_interop;

import 'package:js/js.dart';

import 'models/bounding_box_js.dart';
import 'models/geo_point_js.dart';

@JS('centerMap')
external Map<String, double> centerMap();

@JS('getBounds')
external Map<String, double> getBounds();

@JS('locateMe')
external Map<String, double> locateMe();

@JS('initMapLocation')
external dynamic initMapLocation(GeoPointJs p);

@JS('setZoomControl')
external dynamic setZoomControl(bool showZoomControl);

@JS('configZoom')
external dynamic configZoom(
    double stepZoom, double initZoom, double minZoomLevel, double maxZoomLevel);

@JS('setZoomStep')
external dynamic setZoomStep(double stepZoom);

@JS('zoomIn')
external dynamic zoomIn();

@JS('zoomOut')
external dynamic zoomOut();

@JS('setZoom')
external dynamic setZoom(double zoom);

@JS('setZoomStep')
external dynamic setZoomWithStep(double stepZoom);

@JS('getZoom')
external dynamic getZoom();

@JS('setMaxZoomLevel')
external dynamic setMaxZoomLevel(double maxZoomLvl);

@JS('setMinZoomLevel')
external dynamic setMinZoomLevel(double mminZoomLvl);

@JS('setDefaultIcon')
external dynamic setDefaultIcon(String base64);

@JS('addPosition')
external dynamic addPosition(GeoPointJs p, bool showMarker, bool animate);

@JS('removeMarker')
external dynamic removeMarker(GeoPointJs p);

@JS('currentUserLocation')
external dynamic currentUserLocation();

@JS('setStaticGeoPoints')
external dynamic setStaticGeoPoints(String id, List<GeoPointJs> points);

@JS('setIconStaticGeoPoints')
external dynamic setIconStaticGeoPoints(String id, String icons);

@JS('limitArea')
external dynamic limitArea(BoundingBoxJs box);

@JS('flyToBounds')
external dynamic flyToBounds(BoundingBoxJs box, int padding);

/// Allows assigning a function to be callable from `window.initMapFinish()`
@JS('initMapFinish')
external set initMapFinish(void Function(bool) f);

/// Allows assigning a function to be callable from `window.onGeoPointClicked(lat,lon)`
@JS('onStaticGeoPointClicked')
external set onStaticGeoPointClicked(void Function(double, double) f);

/// Allows assigning a function to be callable from `window.onMapSingleTapClicked(lat,lon)`
@JS('onMapSingleTapListener')
external set onMapSingleTapListener(void Function(double, double) f);

/// Allows assigning a function to be callable from `window.onRegionChangedListener(region)`
@JS('onRegionChangedListener')
external set onRegionChangedListener(void Function(double, double,double, double,double, double) f);

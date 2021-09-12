// ignore_for_file: avoid_unused_constructor_parameters, non_constant_identifier_names, comment_references

@JS()
library osm_interop;

import 'package:js/js.dart';

import 'models/geo_point_js.dart';

@JS('locateMe')
external Map<String, double> locateMe();

@JS('initMapLocation')
external dynamic initMapLocation(GeoPointJs p);

@JS('setZoomControl')
external dynamic setZoomControl(bool showZoomControl);


@JS('configZoom')
external dynamic configZoom(double stepZoom,double initZoom,int minZoomLevel,int maxZoomLevel);

@JS('setZoomStep')
external dynamic setZoomStep(double stepZoom);

@JS('zoomIn')
external dynamic zoomIn();

@JS('zoomOut')
external dynamic zoomOut();

@JS('setZoom')
external dynamic setZoom(double zoom);


@JS('setDefaultIcon')
external dynamic setDefaultIcon(String base64);

@JS('addPosition')
external dynamic addPosition(GeoPointJs p,bool showMarker,bool animate);


@JS('removeMarker')
external dynamic removeMarker(GeoPointJs p);

@JS('currentUserLocation')
external dynamic currentUserLocation();

@JS('setStaticGeoPoints')
external dynamic setStaticGeoPoints(String id,List<GeoPointJs> points);

@JS('setIconStaticGeoPoints')
external dynamic setIconStaticGeoPoints(String id,String icons);

/// Allows assigning a function to be callable from `window.initMapFinish()`
@JS('initMapFinish')
external set initMapFinish(void Function(bool) f);

/// Allows assigning a function to be callable from `window.initMapFinish()`
@JS('onStaticGeoPointClicked')
external set onStaticGeoPointClicked(void Function(double,double) f);




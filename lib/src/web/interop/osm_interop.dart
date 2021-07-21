// ignore_for_file: avoid_unused_constructor_parameters, non_constant_identifier_names, comment_references

@JS()
library osm_interop;

import 'package:js/js.dart';

import 'models/geo_point_js.dart';

@JS('locateMe')
external Map<String, double> locateMe();

@JS('initMapLocation')
external dynamic initMapLocation(GeoPointJs p);

@JS('addPosition')
external dynamic addPosition(GeoPointJs p);

/// Allows assigning a function to be callable from `window.initMapFinish()`
@JS('initMapFinish')
external set initMapFinish(void Function(bool) f);




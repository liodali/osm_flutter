@JS()
library osm_interop;

import 'package:flutter_osm_web/src/interop/models/geo_point_js.dart';
import 'dart:js_interop';

@JS()
@anonymous
extension type RectShapeJS._(JSObject _) implements JSObject {
  external String key;
  external String color;
  external num strokeWidth;
  external String? borderColor;
  external num opacityFilled;
  // Must have an unnamed factory constructor with named arguments.
  external factory RectShapeJS({
    String key,
    String color,
    num strokeWidth,
    String? borderColor,
    num opacityFilled,
  });
}

@JS()
@anonymous
extension type CircleShapeJS._(JSObject _) implements JSObject {
  external String key;
  external String color;
  external String? borderColor;
  external num opacityFilled;
  external num strokeWidth;
  external GeoPointJs center;
  external num radius;

  // Must have an unnamed factory constructor with named arguments.
  external factory CircleShapeJS({
    String key,
    GeoPointJs center,
    num radius,
    String color,
    String? borderColor,
    num strokeWidth,
    num opacityFilled,
  });
}

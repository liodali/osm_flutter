@JS()
library osm_interop;

import 'package:flutter_osm_web/src/interop/models/geo_point_js.dart';
import 'package:js/js.dart';

@JS()
@anonymous
class RectShapeJS {
  external String get key;
  external String get color;
  external num get strokeWidth;

  // Must have an unnamed factory constructor with named arguments.
  external factory RectShapeJS({
    String key,
    String color,
    num strokeWidth,
  });
}

@JS()
@anonymous
class CircleShapeJS {
  external String get key;
  external String get color;
  external num get strokeWidth;
  external GeoPointJs get center;
  external num get radius;

  // Must have an unnamed factory constructor with named arguments.
  external factory CircleShapeJS({
    String key,
    GeoPointJs center,
    num radius,
    String color,
    num strokeWidth,
  });
}
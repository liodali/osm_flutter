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
  external String? get borderColor;
  external num get opacityFilled;
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
class CircleShapeJS {
  external String get key;
  external String get color;
  external String? get borderColor;
  external num get opacityFilled;
  external num get strokeWidth;
  external GeoPointJs get center;
  external num get radius;

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

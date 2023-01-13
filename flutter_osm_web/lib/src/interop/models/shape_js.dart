@JS()
library osm_interop;

import 'package:flutter_osm_web/src/interop/models/geo_point_js.dart';
import 'package:js/js.dart';

@JS()
@anonymous
class RectShapeJS {
  external String get key;
  external List<GeoPointJs> get rect;
  external String get color;
  external double get strokeWidth;

  // Must have an unnamed factory constructor with named arguments.
  external factory RectShapeJS({
    String key,
    List<GeoPointJs> rect,
    String color,
    double strokeWidth,
  });
}

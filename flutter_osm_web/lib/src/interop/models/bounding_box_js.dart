@JS()
library osm_interop;

import 'package:js/js.dart';

@JS()
@anonymous
class BoundingBoxJs {
  external double get north;

  external double get east;

  external double get south;

  external double get west;

  // Must have an unnamed factory constructor with named arguments.
  external factory BoundingBoxJs({
    double north,
    double east,
    double south,
    double west,
  });
}

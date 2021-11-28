@JS()
library osm_interop;

import 'package:js/js.dart';

@JS()
@anonymous
class GeoPointJs {
  external double get lon;
  external double get lat;

  // Must have an unnamed factory constructor with named arguments.
  external factory GeoPointJs({double lon, double lat});
}

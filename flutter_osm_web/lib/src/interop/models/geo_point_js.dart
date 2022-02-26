@JS()
library osm_interop;

import 'package:js/js.dart';

@JS()
@anonymous
class GeoPointJs {
  external num get lon;
  external num get lat;

  // Must have an unnamed factory constructor with named arguments.
  external factory GeoPointJs({num lon, num lat});
}

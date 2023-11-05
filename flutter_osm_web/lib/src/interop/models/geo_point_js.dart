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
@JS()
@anonymous
class SizeJs {
  external num get width;

  external num get height;

  // Must have an unnamed factory constructor with named arguments.
  external factory SizeJs({num width, num height});
}
@JS()
@anonymous
class GeoPointWithOrientationJs {
  external num get lon;

  external num get lat;

  external num get angle;

  // Must have an unnamed factory constructor with named arguments.
  external factory GeoPointWithOrientationJs({
    num lon,
    num lat,
    num angle,
  });
}

@JS()
@anonymous
class IconAnchorJS {
  external num get x;

  external num get y;

  external IconOffsetAnchorJS? get offset;

  // Must have an unnamed factory constructor with named arguments.
  external factory IconAnchorJS({num x, num y, IconOffsetAnchorJS? offset});
}

@JS()
@anonymous
class IconOffsetAnchorJS {
  external num get x;

  external num get y;

  // Must have an unnamed factory constructor with named arguments.
  external factory IconOffsetAnchorJS({num x, num y});
}

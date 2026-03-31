@JS()
library osm_interop;

import 'dart:js_interop';

@JS()
@staticInterop
@anonymous
extension type GeoPointJs._(JSObject o) implements JSObject {
  external num lon;

  external num lat;

  // Must have an unnamed factory constructor with named arguments.
  external factory GeoPointJs({num lon, num lat});

  Map<String, double> toMap() {
    return {
      'lon': lon.toDouble(),
      'lat': lat.toDouble(),
    };
  }
}

@JS()
@staticInterop
@anonymous
extension type SizeJs._(JSObject o) implements JSObject {
  external num width;

  external num height;

  // Must have an unnamed factory constructor with named arguments.
  external factory SizeJs({num width, num height});
}

@JS()
@staticInterop
@anonymous
extension type GeoPointWithOrientationJs._(JSObject o) implements JSObject {
  external num lon;

  external num lat;

  external num angle;

  // Must have an unnamed factory constructor with named arguments.
  external factory GeoPointWithOrientationJs({
    num lon,
    num lat,
    num angle,
  });
}

@JS()
@staticInterop
@anonymous
extension type IconAnchorJS._(JSObject o) implements JSObject {
  external num x;

  external num y;

  external IconOffsetAnchorJS? get offset;

  // Must have an unnamed factory constructor with named arguments.
  external factory IconAnchorJS({num x, num y, IconOffsetAnchorJS? offset});
}

@JS()
@staticInterop
@anonymous
extension type IconOffsetAnchorJS._(JSObject o) implements JSObject {
  external num x;

  external num y;

  // Must have an unnamed factory constructor with named arguments.
  external factory IconOffsetAnchorJS({num x, num y});
}

@JS()
library osm_interop;

import 'dart:js_interop';

@JS()
@anonymous
extension type BoundingBoxJs._(JSObject _) implements JSObject {
  external double north;

  external double east;

  external double south;

  external double west;

  // Must have an unnamed factory constructor with named arguments.
  external factory BoundingBoxJs({
    double north,
    double east,
    double south,
    double west,
  });
}

extension BoundingBoxJsExt on BoundingBoxJs {
  Map<String, double> toDart() {
    return {
      "north": north,
      "east": east,
      "south": south,
      "west": west,
    };
  }
}

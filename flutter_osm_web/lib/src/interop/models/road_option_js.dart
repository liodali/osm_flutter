@JS()
library osm_interop;

import 'dart:js_interop';

@JS()
@staticInterop
@anonymous
extension type RoadOptionJS._(JSObject _) implements JSObject {
  external String color;
  external double roadWidth;
  external String roadBorderColor;
  external double roadBorderWidth;
  external bool isDotted;
  external String? iconInterestPoints;

  external factory RoadOptionJS({
    required String color,
    double roadWidth = 5.0,
    String? roadBorderColor,
    double roadBorderWidth = 0.0,
    bool isDotted = false,
    String? iconInterestPoints,
  });
}

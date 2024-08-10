@JS()
library osm_interop;

import 'dart:js_interop';

@JS()
@anonymous
extension type RoadOptionJS._(JSObject _) implements JSObject {
  external String roadColor;
  external int roadWidth;
  external bool zoomInto;
  external String? roadBorderColor;
  external double roadBorderWidth;

  external factory RoadOptionJS({
    required String roadColor,
    num roadWidth = 5.0,
    bool zoomInto = true,
    String? roadBorderColor,
    num roadBorderWidth = 0.0,
  });
}

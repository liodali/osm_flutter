@JS()
library osm_interop;

import 'dart:js_interop';

@JS()
@staticInterop
@anonymous
extension type RoadOptionJS._(JSObject _) implements JSObject {
  external String color;
  external double roadWidth;
  external bool zoomInto;
  external String? roadBorderColor;
  external double roadBorderWidth;
  external bool isDotted;
  external String? iconInterestPoints;
  external JSArray<JSString>? gradientColors;

  factory RoadOptionJS({
    required String color,
    double roadWidth = 5.0,
    bool zoomInto = true,
    String? roadBorderColor,
    double roadBorderWidth = 0.0,
    bool isDotted = false,
    String? iconInterestPoints,
    List<String>? gradientColors,
  }) => RoadOptionJS._create(
    color: color,
    roadWidth: roadWidth,
    zoomInto: zoomInto,
    roadBorderColor: roadBorderColor,
    roadBorderWidth: roadBorderWidth,
    isDotted: isDotted,
    iconInterestPoints: iconInterestPoints,
    gradientColors:
        gradientColors?.map((color) => color.toJS).toList().toJS,
  );

  // Dart defaults must be applied before crossing the JS/WASM boundary.
  external factory RoadOptionJS._create({
    required String color,
    required double roadWidth,
    required bool zoomInto,
    String? roadBorderColor,
    required double roadBorderWidth,
    required bool isDotted,
    String? iconInterestPoints,
    required JSArray<JSString>? gradientColors,
  });
}

@JS()
library osm_interop;

import 'package:js/js.dart';

@JS()
@anonymous
class RoadOptionJS {
  external String get roadColor;
  external int get roadWidth;
  external bool get zoomInto;
  external String? get roadBorderColor;
  external double get roadBorderWidth;

  external factory RoadOptionJS({
    required String roadColor,
    num roadWidth = 5.0,
    bool zoomInto = true,
    String? roadBorderColor,
    num roadBorderWidth = 0.0,
  });
}

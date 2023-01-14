@JS()
library osm_interop;

import 'package:js/js.dart';

@JS()
@anonymous
class RectShapeJS {
  external String get key;
  external String get color;
  external num get strokeWidth;

  // Must have an unnamed factory constructor with named arguments.
  external factory RectShapeJS({
    String key,
    String color,
    num strokeWidth,
  });
}

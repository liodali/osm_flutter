@JS()
library osm_interop;

import 'package:js/js.dart';

@JS()
@anonymous
class CustomTileJs {
  external String get url;
  external String get subDomains;
  external String get tileExtension;
  external String get apiKey;
  external num get tileSize;
  external num get maxZoom;
  external num get minZoom;

  // Must have an unnamed factory constructor with named arguments.
  external factory CustomTileJs({
    String url,
    String subDomains,
    String tileExtension,
    String apiKey,
    num tileSize,
    num maxZoom,
    num minZoom,
  });
}

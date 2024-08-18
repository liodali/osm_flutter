@JS()
library osm_interop;

import 'dart:js_interop';

@JS()
@anonymous
extension type CustomTileJs._(JSObject _) implements JSObject {
  external String url;
  external String subDomains;
  external String tileExtension;
  external String apiKey;
  external num tileSize;
  external num maxZoom;
  external num minZoom;

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

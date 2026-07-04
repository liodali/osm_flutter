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
  external String styleURL;
  external num tileSize;
  external num maxZoom;
  external num minZoom;

  external factory CustomTileJs({
    String url,
    String subDomains,
    String tileExtension,
    String apiKey,
    String styleURL,
    num tileSize,
    num maxZoom,
    num minZoom,
  });
}

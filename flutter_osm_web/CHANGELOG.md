# ChangeLog

## 2.0.0:

- **Breaking**: migrate web rendering engine from Leaflet to MapLibre GL JS
- add `useMapLibre` flag to `OsmWebWidget` to toggle between Leaflet and MapLibre
- add `index_maplibre.html` asset (MapLibre GL JS implementation)
- add `styleURL` support to `CustomTileJs` interop and `WebMixin` for vector tiles
- load assets from local package in debug mode instead of GitHub CDN
- prevent marker click event propagation to map
- add tracking state guard to prevent duplicate callbacks
- improve sidebar toggle and road rendering
- change `flutter_osm_interface` dependency to `^1.4.0`

## 1.4.4:

## 1.4.3:

- remove package_info_plus dependency

## 1.4.2:

- fix bug in loading assets where we download them from github cdn

## 1.4.1:

## 1.4.0:

- add `onGeoPointLongPressEvent` to handle long click in web
- fix tracking position information from js to dart

## 1.3.5:

## 1.3.4+1:

## 1.3.4: fix bug

## 1.3.3: fix bug

## 1.3.2: fix bug

- fix mylocation api

## 1.3.1: fix bug

- fix bug in setIconMarker
- improve changeMarker API in JS

## 1.3.0:

## 1.2.0-wasm:

- add wasm support (migrate from package:js to dart:js_interop)

## 1.1.0:

## 1.0.5:

## 1.0.4:

## 1.0.3:

## 1.0.2:

## 1.0.1:

## 1.0.0:

## 1.0.0-rc.4: update dependencies

## 1.0.0-rc.3: update dependencies

## 1.0.0-rc.2: migrate to wasm

## 1.0.0-rc.1: fix bug

- fix bug delete road #500

## 1.0.0-rc:

- improve draw shape in web

## 1.0.0-dev.3

## 1.0.0-dev.2

## 1.0.0-dev.1

## 1.0.0-dev

## 0.6.2

## 0.6.1

## 0.6.0

## 0.5.0

## 0.4.2

## 0.4.1

## 0.4.0

## 0.3.0

## 0.1.0

## 0.0.1

- TODO: Describe initial release.

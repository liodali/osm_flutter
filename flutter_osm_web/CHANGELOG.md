# ChangeLog

## 2.2.0

- Use the canonical OSM raster endpoint, send an explicit browser referrer
  policy and retain visible provider attribution. Normalize legacy OSM
  a/b/c subdomain URLs without changing other providers.
- Serialize tile-layer changes, await replacement styles, keep raster basemaps
  below overlays and restore gradient road metrics after style changes.
  Failed style loads reject their caller and allow a later reset to recover.
- **Breaking**: remove the Leaflet engine; MapLibre GL JS is now the only web
  rendering engine. The `map.html` asset and the `useMapLibre` flag on
  `OsmWebWidget` are removed (the map iframe always loads
  `index_maplibre.html`).
- add gradient road support: `RoadOption.roadGradientColors` (at least 2
  colors) draws the road with a start-to-end color gradient using MapLibre's
  `line-gradient` (road sources now enable `lineMetrics`). Gradient roads
  skip the dotted dash pattern on the main line; borders still apply.

## 2.1.0

- Migrate routing_client_dart to ^1.0.8 (Dart 3.7+): routing goes through
  `RoutingManager.getRoute(request: OSRMRequest.route(...))` and reads
  instructions from `route.instructions` instead of `buildInstructions`.
  Routes explicitly request GeoJSON geometry to preserve coordinate
  precision, and road-type mapping (`RoadType` → `RoutingType`) is preserved.
- Handle a missing/null route geometry without a null assertion: `drawRoad`
  returns an empty route instead of crashing.
- Require Dart 3.7+ / Flutter 3.47+ and update `web` to ^1.1.2.
- Use `widgets.dart` only: bundle a default pin asset and provide a neutral,
  animated loading indicator, so no Material/Cupertino icon fonts are
  required on web.
- Apply `RoadOptionJS` defaults in Dart before crossing the JS/WASM boundary
  (dart2wasm ignores defaults on external JS constructors) and type
  `roadBorderColor` as nullable.
- Move `flutter_test` to `dev_dependencies` and add Chrome JS/WASM regression
  tests for routing, JS defaults, and the loading indicator.

## 2.0.1:

- fix Flutter Web WASM build: load map HTML/JS from Flutter assets instead of Dio/CDN
- inject map scripts with `HTMLScriptElement.text` (WASM `innerHTML` parsed the JS as HTML)
- load the map iframe from a same-origin blob URL instead of `srcdoc` to avoid `about:srcdoc` History.replaceState errors under COOP/COEP

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

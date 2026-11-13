# flutter_osm_web

The endorsed web implementation of `flutter_osm_plugin`, with Leaflet and
MapLibre rendering through `HtmlElementView` and Dart JS interop.

## Getting started

Use `flutter_osm_plugin` in your application; it selects this implementation
on web. JavaScript and WebAssembly builds are supported by the regular package;
the old `1.2.0-wasm` prerelease is no longer needed.

## Routing migration

Version 2.1.0 targets `routing_client_dart: ^1.0.8`, Dart 3.7+ and
Flutter 3.47+. Routing uses `RoutingManager.getRoute(request: OSRMRequest.route(...))`
and reads instructions from `route.instructions` instead of calling
`buildInstructions`.

The plugin's `RoadType` and `RoadInfo` API remain unchanged. Routes explicitly
request GeoJSON to preserve coordinate precision; distances remain in kilometres
and durations in seconds. Missing geometry is handled without a null assertion.

## Design-system-neutral widgets

The web implementation uses `package:flutter/widgets.dart`, without Material
or Cupertino imports. It uses an animated custom loading indicator and a bundled
default pin image rather than a Material icon font. Applications can still
supply their own marker and loading widgets.

`RoadOptionJS` applies defaults in Dart before crossing the JS/WASM boundary,
because defaults on external JS constructors are ignored by dart2wasm.

## Validation

From this package directory:

```sh
flutter analyze lib test
flutter test --platform chrome
flutter test --platform chrome --wasm
```

The browser tests cover route type mapping, waypoint order, coordinate precision,
metadata, route caching, nullable geometry, JS defaults and the loading indicator.

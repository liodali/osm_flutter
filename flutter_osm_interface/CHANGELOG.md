## 1.8.0

- Remove `package:flutter/material.dart` and `package:flutter/cupertino.dart`
  imports in favor of `package:flutter/widgets.dart` (and `foundation.dart` for
  lifecycle annotations), making the platform interface independent from the
  design-system libraries deprecated in Flutter 3.50 — no `material_ui` or
  `cupertino_ui` migration needed.
- `MarkerIcon.icon` is now typed `Widget?` instead of `Icon?`
  (source-compatible widening; any widget works as a marker icon).
- Add `defaultRoadColor` (`Color(0xFF4CAF50)`, same value as the legacy
  `Colors.green`) used by `RoadOption.empty()`, `MultiRoadOption.empty()`, and
  multi-road configuration defaults.
- Guard `BaseMapController.dispose()` so disposing a controller that was never
  attached to a platform map (e.g. in widget tests) no longer touches the
  platform side.
- Raise the Dart floor to 3.7 and the Flutter floor to 3.47.0, matching the
  main plugin and web baseline after the routing_client_dart 1.0.8 migration;
  align dio to ^5.11.1.

## 1.7.0

- Add macOS to the shared Apple serialization paths for colors, tile URLs,
  marker PNG payloads, and default tile resets.
- Preserve Web payload formats in browsers running on iOS or macOS.
- Unregister a map's method-channel handler when it closes, including when
  other maps remain active or a map is recreated.
- Add Apple channel/event isolation and native-versus-Web serialization tests.
- Keep existing platform interfaces and Android transport contracts compatible.

## 1.6.0

- Move the typed Android transport contract and event codec into the platform
  interface so optional JNI and future FFI transports can implement a shared
  boundary.
- fix(ios): strip the `{z}/{x}/{y}` tile template (and any trailing tile
  extension) from tile server urls in `TileURLs.toMapiOS()`. iOS appends the
  template itself, so sending the full template url produced doubled
  `{z}/{x}/{y}` placeholders and broken custom tile urls.

## 1.5.1

- omit absent `roadBorderColor`/`roadBorderWidth` entries from the manual
  road channel payload when the road option leaves them unset (#614)

## 1.5.0:

- add `styleURL` field to `CustomTile` for vector tile support
- add `CustomTile.openFreeMap` constructor (Liberty vector style)
- add `CustomTile.satellite` constructor (ArcGIS World Imagery)
- serialize `isVector` flag in `CustomTile.toMap()` when `styleURL` is set
- pass `isDotted`, `roadBorderColor`, `roadBorderWidth`, `zoomIntoRegion` in `drawRoadManually` method channel

## 1.4.0:

- add `onGeoPointLongPressEvent` to handle long click
- add mixin `onGeoPointLongPressEvent`

## 1.3.2:

## 1.3.1:

## 1.3.0:

## 1.1.0:

## 1.0.3:

## 1.0.2:

## 1.0.1:

## 1.0.0:

## 1.0.0-rc:

- improve shape api and method channel api

## 1.0.0-dev.3

## 1.0.0-dev.2

## 1.0.0-dev.1

## 1.0.0-dev

## 0.7.0 :

## 0.6.1 :

## 0.6.0 :

## 0.5.2 :

## 0.5.1 :

## 0.5.0 :

## 0.4.0 :

## 0.3.0 :

## 0.2.4 :

## 0.2.3 :

## 0.2.2 :

## 0.2.1 :

## 0.1.29 :

- add enableStopFollow to enableTracking

## 0.1.30 :

## 0.1.29 :

- add changeTileLayer in osm_channel,osm_controller

## 0.1.28 :

## 0.1.27 :

## 0.1.26 :

## 0.1.25 :

## 0.1.24 :

## 0.1.23 :

## 0.1.22 :

## 0.1.21 :

## 0.1.20 :

## 0.1.19 :

## 0.1.18 :

## 0.1.17 :

## 0.1.16 :

## 0.1.15 :

## 0.1.14+1 :

## 0.1.14 :

## 0.1.13 :

## 0.1.12+1 :

- fix ==operator in osm types

## 0.1.12 :

- add listenerRegionIsChanging listenable to get bounding box when user navigate with map
- get boundingbox direclty from map

## 0.1.10+2 :

- remove annotation protected from mapRestored in OSMMixin

## 0.1.10+1 :

## 0.1.10 :

## 0.1.9 :

## 0.1.5 :

- add attribute `angle` to method `addMarker`

## 0.1.4 :

- change type of minZoomLevel and maxZoomLevel from int to double

## 0.1.3 :

## 0.1.2 :

## 0.1.1 :

- fix [#157]
- improve osmplatform when no context available

## 0.1.0 :

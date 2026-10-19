# ios/ — frozen CocoaPods legacy snapshot

This directory is a **frozen, never-edit snapshot** kept only for the deprecated
CocoaPods integration. Do not modify anything here; changes will be overwritten
and never shipped.

- The **live** Swift implementation is the SPM package at
  `darwin/flutter_osm_plugin/` (shared iOS/macOS source, selected by
  `sharedDarwinSource: true` in the root `pubspec.yaml`).
- `flutter_osm_plugin.podspec` is frozen: `OSMFlutterFramework` suspended
  CocoaPods distribution with 0.9.0, so this podspec can only ever resolve the
  legacy 0.8.x engine (maps-core 3.7.x era). It receives no maintenance.
- `flutter_osm_plugin/Sources/` mirrors the Swift sources exactly as last
  shipped through the podspec (2.1.0+1) so existing CocoaPods-based apps keep
  building. It intentionally contains **no `Package.swift`** — Swift Package
  Manager is never routed here.
- `Assets/en.json` is referenced by the podspec's resource rule only.

Note for Flutter apps: with `sharedDarwinSource: true`, Flutter's podhelper
resolves plugins from `darwin/`, so this snapshot is invisible to
Flutter-managed CocoaPods builds. It only serves apps that hand-wire the
podspec path.

# OSM Flutter — Agent Guide

## Overview

Flutter plugin for OpenStreetMap supporting **Android**, **iOS**, and **Web**. Uses a **federated plugin architecture** with 3 packages.

| Package | Role | Current Version |
|---|---|---|
| `flutter_osm_plugin` | Main plugin, re-exports interface + platform-specific implementations | 1.4.5 |
| `flutter_osm_interface` | Platform interface (abstract classes, types, channel definitions) | 1.4.0 |
| `flutter_osm_web` | Web platform implementation (HTML/JS interop) | 1.4.4 |

## Architecture

### Federated Plugin Pattern

```
flutter_osm_plugin (main)
  ├── depends on flutter_osm_interface  ^1.4.0
  ├── depends on flutter_osm_web      ^1.4.4
  ├── android/    → native Android (Kotlin)
  ├── ios/        → native iOS (Swift)
  └── lib/        → shared Dart + widget layer

flutter_osm_interface
  └── lib/src/    → OSMPlatform abstract, types, events, method channel

flutter_osm_web
  └── depends on flutter_osm_interface ^1.4.0
  └── lib/src/    → Web implementation via HtmlElementView + JS interop
```

### Key Abstractions

- `OSMPlatform` (`flutter_osm_interface`) — base platform interface using `plugin_platform_interface`
- `MobileOSMPlatform` extends `OSMPlatform` — adds mobile-only methods (markers, roads, tracking, shapes)
- `MethodChannelOSM` — default Android/iOS implementation via `MethodChannel`
- `WebOsmController` / `OsmWebPlatform` — web implementation via JS interop

## Directory Structure

```
osm_flutter/
├── android/                  # Native Android (Kotlin)
│   └── src/main/kotlin/...   # FlutterOsmPlugin, OSM views, lifecycle
├── ios/                      # Native iOS (Swift)
│   └── flutter_osm_plugin/   # Swift plugin, map views
├── lib/
│   ├── flutter_osm_plugin.dart           # Library exports
│   └── src/
│       ├── controller/
│       │   ├── map_controller.dart         # Main MapController (mobile)
│       │   ├── picker_map_controller.dart
│       │   ├── simple_map_controller.dart
│       │   └── osm/                       # OSMController state holder
│       ├── widgets/
│       │   ├── mobile_osm_flutter.dart     # Mobile map widget
│       │   ├── picker_location.dart
│       │   ├── custom_picker_location.dart
│       │   ├── static_osm.dart
│       │   ├── copyright_osm_widget.dart
│       │   ├── stub.dart                   # Web/mobile stubs
│       │   └── platform/                 # Platform-specific widget shims
│       ├── common/                       # Utilities, exceptions
│       └── osm_flutter.dart              # Main OSMFlutter widget
├── flutter_osm_interface/
│   └── lib/src/
│       ├── osm_interface.dart            # OSMPlatform + MobileOSMPlatform
│       ├── channel/
│       │   └── osm_method_channel.dart   # MethodChannelOSM
│       ├── types/                        # GeoPoint, RoadInfo, BoundingBox, etc.
│       ├── common/                       # OSMEvent, utilities, exceptions
│       ├── map_controller/               # BaseMapController, IBaseMapController
│       ├── osm_controller/               # Abstract OSMController
│       └── mixin/                        # Android lifecycle, OSM mixins
├── flutter_osm_web/
│   └── lib/src/
│       ├── web_platform.dart             # OsmWebPlatform registration
│       ├── osm_web.dart                  # OsmWebWidget (HtmlElementView)
│       ├── controller/
│       │   └── web_osm_controller.dart   # WebOsmController
│       ├── channel/
│       │   └── method_channel_web.dart   # Web method channel
│       ├── interop/                      # JS interop bindings
│       ├── asset/                        # map.html, map.js, osm_interop.js
│       └── mixin_web.dart                # Web-specific controller mixin
└── example/                  # Demo app
    ├── android/
    │   └── app/build.gradle.kts    # compileSdk 36, minSdk 32
    ├── ios/
    └── lib/                        # Example UI
```

## Native Implementation Notes

### Android
- **Language**: Kotlin
- **Map Engine**: Native OSM views (osmdroid or similar)
- **Compile SDK**: 36
- **Min SDK**: 32
- **Key Classes**: `FlutterOsmPlugin`, `OsmFactory`, lifecycle management
- **Build**: Kotlin Gradle Plugin (KGP), Java 17

### iOS
- **Language**: Swift
- **Map Engine**: Native iOS map views
- **Min iOS**: 13
- **Package Manager**: SPM (Swift Package Manager) support added in v1.4.4
- **Key Classes**: Swift plugin, map view controllers

### Web
- **Rendering**: `HtmlElementView` embedding an HTML/JS map
- **Interop**: `dart:js_interop` / `package:web` for JS bridge
- **Assets**: `map.html`, `map.js`, `osm_interop.js` loaded from package assets
- **Removed**: `package_info_plus` dependency (v1.4.4)

## Key Technical Rules

1. **Never use `dart:io`** for platform checks. Use `defaultTargetPlatform` from `package:flutter/foundation.dart` instead (Android/iOS/web-safe).
2. **Web compatibility**: Any widget using `Platform.isAndroid` or `Platform.isIOS` will crash on web. Always guard with `defaultTargetPlatform` or `kIsWeb`.
3. **Federated plugin changes**: When modifying platform APIs, update `flutter_osm_interface` first, then `flutter_osm_web`, then the main plugin.
4. **Path vs published deps**: During development, packages use `path:` dependencies. For release, switch to caret (`^`) constraints.
5. **Asset loading**: Web assets (JS/HTML) are loaded from `packages/flutter_osm_web/src/asset/` via Flutter asset system.

## Release Scripts

| Script | Purpose |
|---|---|
| `update_versions.py` | Update dependency versions in pubspecs (no publish) |
| `check_pubspec_release.py` | Check pub.dev versions, optionally publish inner packages, then update root deps |
| `pre_release.py` | Git tag-based release trigger (uses tags like `flutter_osm_interface-v1.4.0`) |

### update_versions.py usage

```bash
python3 update_versions.py --mode all          # update web + root pubspecs
python3 update_versions.py --mode osm          # update only root pubspec
python3 update_versions.py --mode web          # update only web pubspec
python3 update_versions.py --mode all --version-type upperbound   # use >=min <max
```

Modes:
- `web` — updates `flutter_osm_web`'s dependency on `flutter_osm_interface`
- `osm` — updates root `pubspec.yaml` dependencies (smart: skips if up-to-date, converts path to version)
- `all` — both

Version types:
- `caret` (default) — `^1.4.0`
- `upperbound` — `">=1.4.0 <1.5.0"`

### check_pubspec_release.py usage

```bash
python3 check_pubspec_release.py              # check versions, fail if missing
python3 check_pubspec_release.py --publish    # publish missing packages, then update deps
```

## GitHub Actions Workflows

| Workflow | Trigger | Purpose |
|---|---|---|
| `publish.yaml` | `vX.Y.Z` tag | Publish main plugin to pub.dev |
| `build_packages.yaml` | `flutter_osm_interface-vX.Y.Z` / `flutter_osm_web-vX.Y.Z` tags | Publish inner packages |
| `base_publish_pcks.yaml` | Reusable | OIDC-based pub.dev publishing |
| `deploy_example_android.yaml` | `app-vX.Y.Z` tag or manual | Build AAB + deploy to Google Play |

### Deploy Example Android
- **Trigger**: `git tag app-v1.2.3 && git push origin app-v1.2.3` → auto-deploys to **internal** track
- **Manual**: Any track (`internal`, `alpha`, `beta`, `production`)
- **Secrets required**: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

## Example App

- **Package**: `hamza.dali.flutter_osm_plugin_example`
- **Compile SDK**: 36
- **Min SDK**: 32
- **NDK**: 28.2.13676358
- **Signing**: Reads `android/key.properties` for release signing
- **Build**: `flutter build appbundle --release` (in `example/`)

## Common Tasks

### Adding a new platform method
1. Add method signature to `OSMPlatform` or `MobileOSMPlatform` in `flutter_osm_interface`
2. Implement in `MethodChannelOSM` (Android/iOS)
3. Implement in `WebOsmController` / `OsmWebPlatform` (web)
4. Expose via `MapController` in main plugin

### Updating versions for release
```bash
# 1. Update inner package versions in their pubspec.yaml files manually
# 2. Run version updater
python3 update_versions.py --mode all

# 3. Check & publish
python3 check_pubspec_release.py --publish

# 4. Update main plugin version, then publish
flutter pub publish -f
```

### Building example release
```bash
cd example
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

## Dependencies

### Main Plugin
- `flutter_osm_interface: ^1.4.0`
- `flutter_osm_web: ^1.4.4`
- `dio: ^5.9.2`, `routing_client_dart: ^0.5.5`, `google_polyline_algorithm: ^3.1.0`
- `permission_manager: ^2.0.9`, `url_launcher: ^6.3.2`

### Interface
- `plugin_platform_interface: ^2.1.8`
- `stream_transform: ^2.1.0`
- `google_polyline_algorithm: ^3.1.0`
- `dio: ^5.8.0+1`

### Web
- `web: ^1.1.1`
- `stream_transform: ^2.1.0`
- `routing_client_dart: ^0.5.5`
- `dio: ^5.9.0`
- `flutter_osm_interface: ^1.4.0`

# flutter_osm_android_jni

Optional **JNI command transport** for [`flutter_osm_plugin`][plugin] on Android.

It routes typed map commands (markers, shapes, roads, camera, tiles) through a
generated JNI binding into the Kotlin `OsmAndroidBridge` façade owned by the
endorsed [`flutter_osm_android`][host] host package, while MethodChannel keeps
responsibility for events, acknowledgements, location, permissions, and
lifecycle.

[plugin]: https://pub.dev/packages/flutter_osm_plugin
[host]: https://pub.dev/packages/flutter_osm_android

## When to use it

- You want lower-latency command dispatch than MethodChannel JSON encoding.
- You are comfortable shipping checked-in `jnigen` bindings that target a
  specific Kotlin façade.
- You do **not** need JNI on iOS or web (this package is Android-only).

If you only need the default MethodChannel transport, you do not need this
package — `flutter_osm_android` already provides it.

## Architecture

```
flutter_osm_plugin (app-facing)
  └── endorses flutter_osm_android (host: platform view + Kotlin bridge)
                          ▲
                          │ path dependency
                          │
flutter_osm_android_jni ──┘
  ├── lib/src/android_jni/        → jnigen probe + generated bindings
  ├── lib/src/android_transport/  → JniAndroidMapTransport + factory
  └── tool/generate_jni.dart      → binding regeneration
```

The JNI transport implements the `AndroidMapTransport` contract from
`flutter_osm_interface`. Backend selection happens once during `attach`; after
that, state-changing commands are never replayed across transports.

## Setup

Add the package alongside the main plugin:

```yaml
dependencies:
  flutter_osm_plugin: ^2.0.1
  flutter_osm_android_jni: ^0.1.0
```

During local development of the federated workspace, use `path:` dependencies:

```yaml
dependencies:
  flutter_osm_plugin:
    path: ../
  flutter_osm_android_jni:
    path: ../flutter_osm_android_jni/
```

## Usage

Opt in by injecting the JNI transport factory into `AndroidMapController`:

```dart
import 'package:flutter_osm_android_jni/flutter_osm_android_jni.dart';
import 'package:flutter_osm_plugin/android.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

final controller = AndroidMapController.withPosition(
  initPosition: GeoPoint(latitude: 48.8566, longitude: 2.3522),
  backend: AndroidMapBackend.auto,
  transportFactory: createAndroidJniTransportFactory(
    fallback: createDefaultAndroidMapTransport,
  ),
);
```

`createAndroidJniTransportFactory` wraps an existing factory. When the resolved
backend is `jni`, it returns a `JniAndroidMapTransport`; when it is
`methodChannel`, it delegates to the supplied `fallback`. Resolve `auto` before
calling the factory — it throws `ArgumentError` if passed `AndroidMapBackend.auto`
directly.

### Fallback semantics

JNI fallback is **attach-only**. Once initialization starts on a backend,
commands are not replayed through another backend. This keeps map state
consistent and avoids duplicate mutations.

## Exported API

| Symbol | Purpose |
|---|---|
| `createAndroidJniTransportFactory` | Composes a JNI transport over a fallback factory |
| `JniAndroidMapTransport` | `AndroidMapTransport` implementation using JNI commands + MethodChannel events |
| `AndroidJniProbeResult`, `runAndroidJniProbe` | Phase-0 smoke test for the JNI bridge (Android-only) |

## Regenerate bindings

The checked-in bindings in `lib/src/android_jni/generated.dart` target
`hamza.dali.flutter_osm_plugin.jni.OsmAndroidBridge`, which is supplied by the
host Android package. Regenerate them after changing that Kotlin façade:

```bash
cd flutter_osm_android_jni
dart run tool/generate_jni.dart
```

The generator resolves Gradle dependencies through the repository `example/`
app, so make sure `example/android/` builds before running it.

## Testing

```bash
cd flutter_osm_android_jni
flutter test
```

Unit tests cover the transport factory composition. JNI runtime behavior is
validated on-device through the example app and parity tests against the
MethodChannel transport.

## Platform support

| Platform | Supported |
|---|---|
| Android | Yes |
| iOS | No (use MethodChannel) |
| Web | No (use `flutter_osm_web`) |

Calling `runAndroidJniProbe()` or constructing `JniAndroidMapTransport` on a
non-Android platform will fail at runtime.

## Versioning and release

This package is released independently of the main plugin. Until dedicated
GitHub Actions workflows are wired, publish it manually:

```bash
cd flutter_osm_android_jni
flutter pub publish -f
```

See the root `AGENTS.md` for the full release pipeline and version-update
scripts.

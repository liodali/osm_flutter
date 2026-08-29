# flutter_osm_android_jni

Optional JNI command transport for `flutter_osm_plugin` on Android.

The main plugin owns the platform view and Kotlin map session. This package
contains the Dart JNI runtime integration and generated bindings. Events,
acknowledgements, location, permissions, and lifecycle continue to use the
host plugin's MethodChannel plane.

## Development setup

```yaml
dependencies:
  flutter_osm_plugin:
    path: ../
  flutter_osm_android_jni:
    path: ../flutter_osm_android_jni/
```

Opt in when constructing the typed Android controller:

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

JNI fallback is attach-only. Once initialization starts, commands are not
replayed through MethodChannel.

## Regenerate bindings

Resolve the repository example dependencies, then run:

```bash
cd flutter_osm_android_jni
dart run tool/generate_jni.dart
```

The generated binding targets
`hamza.dali.flutter_osm_plugin.jni.OsmAndroidBridge`, which is supplied by the
host Android plugin.

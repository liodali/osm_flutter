## 0.2.0

- Target flutter_osm_android 0.2.0 (mapscore 4.0.0), matching
  flutter_osm_plugin 3.0.0.
- Require flutter_osm_interface ^1.7.0 for the shared platform contracts.
- Keep the existing JNI transport API and generated bindings; MethodChannel
  continues to carry acknowledgements, events, location, and lifecycle handling.

## 0.1.0

- Extract the optional Dart JNI transport and generated bindings from
  `flutter_osm_plugin`.
- Preserve MethodChannel acknowledgements, events, location, permissions, and
  lifecycle handling.
- Add explicit JNI transport-factory composition for attach-only fallback.

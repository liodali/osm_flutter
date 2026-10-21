# flutter_osm_android

Endorsed Android implementation for `flutter_osm_plugin`.

Applications should depend on `flutter_osm_plugin`; Flutter includes this package automatically as its default Android implementation. The optional `flutter_osm_android_jni` package can be added separately for JNI command transport.

## Requirements

Flutter 3.44+ / Dart 3.12+ is required for built-in Kotlin compatibility. With
AGP 9+, Kotlin is supplied by AGP. When built-in Kotlin is disabled, Flutter
applies the Kotlin Gradle Plugin from the consuming app's classpath; keep the
Kotlin version declaration in the app's settings. The host uses
`kotlin.compilerOptions` with JVM target 17 in either mode.

The native map engine is [openmobilemaps maps-core](https://github.com/openmobilemaps/maps-core) (`io.openmobilemaps:mapscore`), consumed directly by this package. Version 0.3.0 retains mapscore 4.0.0 and updates the build requirements. Consuming Android apps must use:

- `compileSdk` 37 or newer (also required by the main plugin's permission_handler 13)
- Kotlin `2.3.0` or newer (mapscore ships Kotlin 2.4.0 metadata)
- AGP 9.1.1+ for Android SDK 37, Gradle 9.3.1+, and JDK 17+ (JDK 21 recommended)
- `minSdk` 26 or higher when the mapscore engine is used (mapscore itself has required minSdk 26 since 3.7.1)

mapscore 4.0.0 also puts AndroidX Compose runtime libraries on the runtime classpath; apps already using Compose will simply align versions via Gradle resolution.

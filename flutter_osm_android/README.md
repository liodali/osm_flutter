# flutter_osm_android

Endorsed Android implementation for `flutter_osm_plugin`.

Applications should depend on `flutter_osm_plugin`; Flutter includes this package automatically as its default Android implementation. The optional `flutter_osm_android_jni` package can be added separately for JNI command transport.

## Requirements

The native map engine is [openmobilemaps maps-core](https://github.com/openmobilemaps/maps-core) (`io.openmobilemaps:mapscore`), consumed directly by this package. Since the 0.2.0 update (mapscore 4.0.0), consuming Android apps must use:

- `compileSdk` 36 or newer
- Kotlin `2.3.0` or newer (mapscore ships Kotlin 2.4.0 metadata)
- An AGP version whose D8/R8 supports Java 21 class files (AGP 8.4+, 8.13+ recommended) and Gradle running on JDK 17+ (JDK 21 recommended)
- `minSdk` 26 or higher when the mapscore engine is used (mapscore itself has required minSdk 26 since 3.7.1)

mapscore 4.0.0 also puts AndroidX Compose runtime libraries on the runtime classpath; apps already using Compose will simply align versions via Gradle resolution.

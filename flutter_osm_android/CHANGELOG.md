## 0.3.0

- Compile with Android SDK 37, matching permission_handler 13 in the main plugin.
- Require AGP 9.1.1+ / Gradle 9.3.1+ for SDK 37 support.
- Migrate to built-in Kotlin and `kotlin.compilerOptions`, removing explicit
  KGP application and the legacy `android.kotlinOptions` block.
- Require Flutter 3.44+ / Dart 3.12+ for Flutter's KGP compatibility handling.

## 0.2.0

- Update `io.openmobilemaps:mapscore` from 3.7.1 to 4.0.0 (GPU tessellation, rotated icons in `IconLayer`, animated dashed lines, CRS support in vector layer styles, circles for point features).
- Align explicitly-pinned mapscore transitive dependencies with its 4.0.0 POM: `androidx.activity:activity-ktx` 1.10.1, `androidx.lifecycle:lifecycle-runtime-ktx` 2.10.0, `com.squareup.okhttp3:okhttp` 5.1.0.
- **Breaking for consuming apps** (required by mapscore 4.0.0): Kotlin 2.3+ toolchain, AGP with Java 21 class-file support (8.4+), `compileSdk` 36+. See the README requirements section.

## 0.1.0

- Extract the Android host implementation and MethodChannel transport from `flutter_osm_plugin`.

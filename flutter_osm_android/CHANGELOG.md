## Unreleased

- Generated (Pigeon) bridges for the typed route families — camera, markers,
  layers, shapes, roads, location, location updates, tracking, user-location
  icons and the six event families — advertised through the attach-time
  capability probe (`map#bootstrap#protocol`). Every family stays available
  on the legacy `MethodChannel`: an attachment uses a generated route only
  after the plugin negotiates it, a switched host stops emitting that
  family's legacy message, and the `MapEventCoalescer` rate state is shared
  by both routes.
- Activity restoration is emitted on the typed lifecycle route and buffered
  across the recreation/route-selection race; the legacy event plane is
  unchanged for attachments that do not negotiate.


- Align `flutter_osm_interface` dependency with the 1.9.0 release
  (`RoadOption.roadGradientColors`, ignored by this Android host).
  No code changes.

## 0.4.0

- **Breaking for consuming apps**: the host declares API 26 (Android 8.0) as
  its minimum. mapscore is an unconditional dependency and requires API 26;
  the previous advertised API 21 minimum was never actually usable. Do not
  use `tools:overrideLibrary` to bypass this.
- Upgrade the host AGP buildscript to 9.3.1 and the wrapper configuration to
  Gradle 9.5.0. Consuming applications must also use AGP 9.3.1+ / Gradle
  9.5.0+; the plugin's wrapper does not control application builds.
- Use the public AGP DSL for SDK configuration (`namespace =`, `compileSdk =`,
  `minSdk =`) and native library packaging (`packaging.jniLibs.pickFirsts`);
  remove the empty legacy `lintOptions` block and the redundant multidex
  setting.

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

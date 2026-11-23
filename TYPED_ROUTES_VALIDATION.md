# Typed routes — device validation plan

Status: **pending device testing** (prepared at the `events.region` phase).
Every typed (generated Pigeon) route is implemented on Android, iOS and
macOS and covered by unit tests; this document is the runbook for the
on-device validation that gates the default flip. Nothing here changes
defaults: all `useTyped*` flags stay opt-in until the results table below is
filled for all three platforms and any parity finding is fixed.

Family inventory and wire-level notes: [the legacy command & event audit](flutter_osm_interface/pigeons/LEGACY_COMMAND_AUDIT.md).

## What is being validated

One attachment with **every typed family enabled together**: ten command
families (probe → freeze per family) and six event families (probe → Dart
registers handlers → pre-initialization route selection → host switches
delivery; exactly one route per family). The example's home page map
(`MainPageExample`) uses this configuration. Every other example page
(`simple`, `old-home`, `hook`, `configuration`, `search`, `picker-result`)
opts into nothing and stays on the legacy plane, so the same build offers a
side-by-side parity baseline.

The automated harness is `example/integration_test/typed_routes_parity_test.dart`
(cross-platform `integration_test`):

- **Default run** — attachment without uncertain-route aborts, readiness via
  the typed lifecycle route, typed camera commands, region-event payload
  parity against the typed camera queries, two-map isolation, disposal and
  recreation. No host setup needed.
- **`--dart-define=TYPED_ROUTES_LOCATION=true`** — user-location fixes via
  the typed location route; asserts fix parity with `myLocation()` and
  records inter-fix spacing for the rate check. Needs permission and a fix.
- **`--dart-define=TYPED_ROUTES_GESTURES=true`** — synthetic map taps via the
  typed interaction route, asserting per-map isolation. Only the Android
  harness forwards synthetic pointer events to platform views; Apple maps
  take touches from UIKit/AppKit directly, so taps are a manual check there.

Lines prefixed `TYPED_ROUTES:` in the log are the recorded observations; the
run ends with a `TYPED_ROUTES_SUMMARY` block to paste into the results table.

## Checks

| # | Check | How | Expected |
|---|---|---|---|
| 1 | **Attachment** | Default run; also launch the example and open the home page | Both maps ready; no `RouteSelectionUncertainException`; no "Message corrupted"/handler errors in logcat/Xcode console |
| 2 | **Payload parity** | Default run compares the last region event with `centerMap`/`bounds` (typed event vs typed query). Manually: compare the same action on the home page (typed) and `old-home` (legacy) — marker tap position, road tap key/distance, location heading, region bounds | Identical public values within 1e-4 (float noise); tap coordinates equal the marker position to full precision on both |
| 3 | **Two maps** | Default run moves map A and asserts B receives nothing; home page + `old-home` pushed together on Android/iOS (two attachments, one typed one legacy) | No cross-delivery; B's center unchanged; closing one map leaves the other fully usable |
| 4 | **Recreation** | Default run re-attaches a third map after disposal. Android: enable "Don't keep activities", background/return the home page (typed lifecycle restoration); macOS: the `manual_macos_checks.dart` lifecycle command (three disposal/recreation cycles) | New attachment ready; region event delivered; Android restoration arrives once via the typed route |
| 5 | **Permissions** | Android: `adb install -g` + `emu geo fix`, then `adb shell pm revoke hamza.dali.flutter_osm_plugin_example android.permission.ACCESS_FINE_LOCATION` and call `myLocation()` → `GeoPointException`. Apple: first-launch prompt allow → fixes flow; deny → `GeoPointException`; `tccutil reset Location <bundle-id>` to re-prompt. macOS needs the Runner activated (foreground) before the prompt | Typed routes change nothing here: permission ownership stays in Dart (`permission_handler`) on Android, native checks on Apple; errors map to the same public exceptions |
| 6 | **Disposal** | Default run removes both maps and checks for exceptions. Manually: pop the home page and push it again repeatedly; on macOS `flutter run -d macos -t lib/manual_macos_checks.dart` and its `lifecycle` command | No exceptions, no zombie subscriptions, native session count returns to zero (macOS acceptance screen `snapshot`) |
| 7 | **Event rates** | Location step records spacing. Region: drag/zoom the home page (typed) and `old-home` (legacy) while logging `listenerRegionIsChanging` timestamps | Android: location ≥ ~1000 ms spacing, region ≥ ~100 ms with first-immediate and trailing newest — **same on typed and legacy pages**. Apple: every callback forwarded on both pages, no Dart-side spacing floor |
| 8 | **Older-host compatibility** | Scratch copy of `example/` with `dependency_overrides: flutter_osm_android: <last published>` (a host without the event capabilities). Launch the home page (all flags on) and run the default integration test | Every missing capability falls back to legacy before initialization: maps ready, events on the legacy plane, no selection sent for absent capabilities (Dart unit tests already cover camera-only bootstrap for every family) |

## Commands

Android (device or emulator; grant permission and supply a fix first —
`adb install -g`, then `adb emu geo fix <lon> <lat>` on an emulator, a real
fix on a device; the maintainer's local `ANDROID_TESTING.md` notes have the
full instrumentation setup):

```sh
cd example
flutter test integration_test/typed_routes_parity_test.dart -d <device>
flutter test integration_test/typed_routes_parity_test.dart -d <device> \
  --dart-define=TYPED_ROUTES_LOCATION=true --dart-define=TYPED_ROUTES_GESTURES=true
adb -s <device> logcat | grep -E "TYPED_ROUTES|osm"
```

iOS (simulator or device; set a simulated location in the simulator's
Features menu):

```sh
cd example
flutter test integration_test/typed_routes_parity_test.dart -d <ios-target>
flutter test integration_test/typed_routes_parity_test.dart -d <ios-target> \
  --dart-define=TYPED_ROUTES_LOCATION=true
```

macOS (run sequentially with other Xcode builds sharing the derived-data
directory; the maintainer's local `APPLE_TESTING.md` notes have the build
sequence):

```sh
cd example
flutter test integration_test/typed_routes_parity_test.dart -d macos
flutter test integration_test/typed_routes_parity_test.dart -d macos \
  --dart-define=TYPED_ROUTES_LOCATION=true
flutter run -d macos -t lib/manual_macos_checks.dart   # lifecycle/disposal acceptance screen
```

## Results

Record per platform: device/OS, Flutter, commit, and the `TYPED_ROUTES_SUMMARY`
observations (events count, spacing, fix parity). Findings become issues
against the family before the default flip.

### Harness verification (not the formal validation)

The default run was executed once on macOS (this machine) to prove the
harness itself: **passed**. Observed `TYPED_ROUTES` lines: both maps ready
through the typed lifecycle route; typed camera center exact and
`zoom=10.0`; typed region events delivered (center equals `centerMap`);
isolation `A events=1, B events=0`; disposal and recreation clean; typed
and legacy attachments at the same position reported **field-exact
identical** region bounds and bounds queries. The Android and iOS runs
(including the opt-in location/gesture steps) are pending.

### Finding A — Apple host bounds are wrong on both routes (pre-existing)

`OSMFlutterFramework` 0.9.1 `MCRectCoord.toBoundingBox()`
(`models/extensions.swift`) assigns `north: topLeft.longitude`,
`west: topLeft.latitude`, `east: bottomRight.latitude`,
`south: bottomRight.longitude` — latitude and longitude are swapped — and
the visible rect it is handed for `onVisibleBoundsChanged` is zero-area at
the camera center. Consequences on iOS and macOS, identically on the legacy
and typed routes (verified with a legacy-only probe):

- `Region.boundingBox` in `onRegionIsChangingListener` degenerates to the
  center coordinate (`north == south == center.longitude`,
  `east == west == center.latitude`); `Region.center` is correct.
- `controller.bounds` / typed `getBounds` answer a field-permuted world box
  (`north: -180, east: -85.05…, south: 180, west: 85.05…`).

This is **not a typed-route regression**: typed↔legacy parity is exact. It
is a host correctness defect owned by the framework; the fix belongs in
`toBoundingBox()` (and the zero-area visible rect) in the next framework
release, followed by a pin bump in `darwin/flutter_osm_plugin/Package.swift`.
The plugin must not swap fields itself — it would double-correct once the
framework is fixed. Until then the harness asserts absolute bounds
correctness on Android only and typed/legacy parity everywhere. The
example only reads `region.center`, which is why this went unnoticed.

| Check | Android | iOS | macOS |
|---|---|---|---|
| 1 Attachment | pending | pending | harness run passed |
| 2 Payload parity | pending | pending | harness run passed (Finding A applies to bounds on both routes) |
| 3 Two maps | pending | pending | harness run passed |
| 4 Recreation | pending | pending | harness run passed (typed); restoration is Android-only |
| 5 Permissions | pending | pending | pending |
| 6 Disposal | pending | pending | harness run passed |
| 7 Event rates | pending | pending | pending |
| 8 Older-host compatibility | pending | n/a (host ships with the main package; covered by Dart fallback tests) | n/a (same) |

## After validation

0. Finding A is fixed in `OSMFlutterFramework` (bounds lat/lon swap and the
   zero-area visible rect) and the Darwin package pin is bumped; the plugin
   side needs no change. Until then, Apple bounds stay as they are today on
   both routes.
1. Fix any parity finding in the owning family (interface first, then
   hosts), with a regression test in the family's `*_route_test.dart` and
   the matching host test.
2. Flip the `useTyped*` defaults on `OSMOption` (and the mobile/web widget
   shims) to `true`; keep the example's legacy pages explicitly opted out so
   the parity baseline stays available.
3. Finish the compatibility documentation: README section for the typed
   routes (what negotiates, what stays legacy, the uncertain-outcome
   abort), CHANGELOG, and move the audit's status line to "default".

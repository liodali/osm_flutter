# Typed routes — device validation plan and record

Status: **typed routes are the default** (branch `method-pigeon`). Every
typed (generated Pigeon) route is implemented on Android, iOS and macOS,
covered by unit tests, and the combined configuration below **passed the
runtime harness on an Android emulator, the iOS simulator and macOS** against
framework 0.9.2, including the older-host fallback. Every command family
and every event family has also run end to end, and the negotiated route of
each family is **observed** per attachment (not inferred) on every platform.
Tap events (marker, marker long-press, map, road) were validated with real
touches on the iOS simulator and an Android emulator, typed against legacy.
What remains before a release is the physical-device pass listed under
[Remaining device checks](#remaining-device-checks).

Family inventory and wire-level notes: [the legacy command & event audit](flutter_osm_interface/pigeons/LEGACY_COMMAND_AUDIT.md).

## What is being validated

One attachment with **every typed family enabled together**: ten command
families (probe → freeze per family) and six event families (probe → Dart
registers handlers → pre-initialization route selection → host switches
delivery; exactly one route per family). Since the default flip this is what
an application gets from `OSMFlutter` without any flag; the example's home
page map (`MainPageExample`) states the same flags explicitly as the
reference configuration. The `old-home`, `simple` and `hook` pages opt out
explicitly (`legacyOsmOption` in `example/lib/src/common/legacy_routes.dart`)
and stay on the legacy plane, so the same build offers a side-by-side parity
baseline; the remaining pages build their options inside plugin widgets and
follow the defaults.

The automated harness is `example/integration_test/typed_routes_parity_test.dart`
(cross-platform `integration_test`). It runs on the **shipped defaults**: a
guard fails if the `useTyped*` defaults stop being the combined typed
configuration, and every legacy baseline opts out explicitly.

- **Default run** — attachment without uncertain-route aborts, readiness,
  camera commands, region-event payload parity against the camera queries,
  absolute bounds correctness (finite, containing the center, shrinking after
  zooming in), two-map isolation, disposal and recreation, and field-exact
  typed/legacy parity of the region event and bounds query against an
  explicitly legacy attachment at the same position and viewport size. No
  host setup needed. Against a host without the capability probe the same
  run is the older-host check.
- **`--dart-define=TYPED_ROUTES_LOCATION=true`** — a real location flow
  (`currentLocation` + `startLocationUpdating`) on the default attachment
  **and on an explicitly legacy attachment at the same time**, against the
  same location source. Asserts the typed fix event equals `myLocation()`,
  the platform cadence floor (Android ≥ ~1 s on both planes) and that both
  planes deliver the same number of callbacks over the same span (no drops,
  no duplicates); records both spacing lists. **Both planes must deliver at
  least four fresh fixes after their first one, or the step fails**: two
  providers that fall silent would otherwise compare as equal. Needs
  location permission and a *moving* fix — see the per-platform notes.
- **`--dart-define=TYPED_ROUTES_GESTURES=true`** — synthetic map taps through
  the typed interaction route on Android, asserting per-map isolation. Only
  the Android harness can forward synthetic pointer events to platform views.
- **`--dart-define=TYPED_ROUTES_FAMILIES=true`** — the command families the
  other steps leave untouched, on one full-screen default attachment:
  markers (add, move, static group, remove — verified through the public
  `geoPoints()` query), layers (custom → default tile source), shapes
  (circle and rectangle draw, remove, remove all), roads (manual draw,
  `removeLastRoad`, `clearAllRoads`, and a real `drawRoad` over the network),
  user-location icons (configured at initialization) and, with the location
  step, tracking (`enableTracking` delivering fixes, `disabledTracking`).

Which route each family took is verified, not inferred from the flags. The
run first **classifies the host** with two signals the routing decision
cannot influence, both on the first platform view: the legacy-channel
capability probe (`map#bootstrap#protocol`), which a current host answers
and an older host leaves not implemented, and the presence of a generated
channel handler (`clearRoads` with a dummy session is rejected with
`stale_session` by a current host before any mutation, and finds no handler
on an older one). The two must agree, or the run fails. A **current** host
must then hold a generated client for **every** family on every default
attachment — the default maps, the families map and the recreated map —
and an **older** host must hold none; the explicitly legacy baselines must
hold nothing on either; and nothing may linger once a map is removed. A
silent legacy fallback on a current host therefore fails the run instead of
passing on the legacy plane. `host:`, `routes:`, `recreation: … typed=` and
`legacy typed=[]` in the log are those observations.

Lines prefixed `TYPED_ROUTES:` in the log are the recorded observations; the
run ends with a `TYPED_ROUTES_SUMMARY` block.

### Tap events: the plain-app probe

Taps cannot be validated through `flutter test`: Apple maps take their
touches from UIKit/AppKit and the live test binding cannot deliver native
touches to the platform view (even with `shouldPropagateDevicePointerEvents`),
and on Android a Flutter-synthesized tap reaches the map but not the engine's
marker-click confirmation. `example/lib/typed_routes_tap_probe.dart` is a
plain app (no test framework) that runs the marker tap, marker long-press,
map tap and road tap phases — starting from a clean map — on the shipped
defaults and then on an explicitly legacy attachment, and meanwhile draws and
removes shapes, roads and tile layers with labelled screenshots (roads,
shapes and layers have no query API). `example/tool/typed_routes_tap_injector.py`
watches the run log, taps each armed point with real input (AXe on the
simulator, `adb shell input` on Android) and takes the screenshots; the
images are then compared against each pass's base frame.

## Checks

| # | Check | How | Expected |
|---|---|---|---|
| 1 | **Attachment** | Default run on every platform and against the older host; also launch the example and open the home page | Maps ready; no `RouteSelectionUncertainException`; no "Message corrupted"/handler errors in logcat/Xcode console |
| 2 | **Payload parity** | Default run compares the last region event with the camera queries and with the legacy attachment; location run compares the typed fix with `myLocation()`. Manually: the same action on the home page (typed) and `old-home` (legacy) — marker tap position, road tap key/distance, location heading, region bounds | Identical public values within 1e-4 (float noise); tap coordinates equal the marker position to full precision on both |
| 3 | **Two maps** | Default run moves map A and asserts B receives nothing; home page + `old-home` pushed together on Android/iOS (two attachments, one typed one legacy) | No cross-delivery; B's center unchanged; closing one map leaves the other fully usable |
| 4 | **Recreation** | Default run re-attaches a map after disposal. Android: enable "Don't keep activities", background/return the home page (typed lifecycle restoration); macOS: the `manual_macos_checks.dart` lifecycle command (three disposal/recreation cycles) | New attachment ready; region event delivered; Android restoration arrives once via the typed route |
| 5 | **Permissions** | Android: grant + fix, then `pm revoke … ACCESS_FINE_LOCATION` and call `myLocation()` → `GeoPointException`. Apple: first-launch prompt allow → fixes flow; deny → `GeoPointException`; `tccutil reset Location <bundle-id>` to re-prompt. macOS needs the Runner activated before the prompt | Typed routes change nothing here: permission ownership stays in Dart (`permission_handler`) on Android, native checks on Apple; errors map to the same public exceptions |
| 6 | **Disposal** | Default run removes both maps and checks for exceptions. Manually: pop the home page and push it again repeatedly; on macOS `flutter run -d macos -t lib/manual_macos_checks.dart` and its `lifecycle` command | No exceptions, no zombie subscriptions, native session count returns to zero (macOS acceptance screen `snapshot`) |
| 7 | **Event rates** | Location run records spacing on both planes in one window. Region: drag/zoom the home page (typed) and `old-home` (legacy) while logging `listenerRegionIsChanging` timestamps | Android: location ≥ ~1000 ms spacing, region ≥ ~100 ms with first-immediate and trailing newest — **same on typed and legacy planes**. Apple: every callback forwarded on both planes, no Dart-side spacing floor |
| 8 | **Older-host compatibility** | Scratch copy of `example/` with `dependency_overrides: flutter_osm_android: 0.4.1` (the last published host, which predates the probe). Run the default harness | Every missing capability falls back to legacy before initialization: maps ready, events on the legacy plane, no selection sent for absent capabilities, no negotiation noise in logcat (Dart unit tests cover camera-only bootstrap for every family) |

## Commands

Android (device or emulator). Grant location permission and supply a fix
first. `flutter test` reinstalls a fresh copy of the app at the start of
each run and uninstalls it afterwards, so grant **after** the package
appears and before the location step starts (~20 s in), and stream fixes
while the app is listening:

```sh
cd example
flutter test integration_test/typed_routes_parity_test.dart -d <device>
# location + gestures:
( while ! adb -s <device> shell pm list packages | grep -q flutter_osm_plugin_example; do sleep 0.5; done
  adb -s <device> shell pm grant hamza.dali.flutter_osm_plugin_example android.permission.ACCESS_FINE_LOCATION
  adb -s <device> shell pm grant hamza.dali.flutter_osm_plugin_example android.permission.ACCESS_COARSE_LOCATION ) &
( for i in $(seq 1 330); do   # emulator: keep the fix moving so each update is new
    adb -s <device> emu geo fix \
      "$(printf "%.6f" "$(echo "2.3522 + $i*0.00001" | bc -l)")" \
      "$(printf "%.6f" "$(echo "48.8566 + $i*0.00001" | bc -l)")"
    sleep 1; done ) &
flutter test integration_test/typed_routes_parity_test.dart -d <device> \
  --dart-define=TYPED_ROUTES_LOCATION=true --dart-define=TYPED_ROUTES_GESTURES=true
adb -s <device> logcat | grep -E "TYPED_ROUTES|osm"
```

iOS (simulator or device). Same grant-after-install rule with
`xcrun simctl privacy <udid> grant location hamza.dali.flutterOsmPluginExample`
once `xcrun simctl get_app_container <udid> hamza.dali.flutterOsmPluginExample app`
succeeds, and a simulated location that keeps moving
(`xcrun simctl location <udid> set <lat>,<lon>` in a loop, or the simulator's
Features menu). A grant issued before the app is installed does not stick and
the test then waits on the permission prompt.

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
caffeinate -d -i flutter test integration_test/typed_routes_parity_test.dart -d macos
caffeinate -d -i flutter test integration_test/typed_routes_parity_test.dart -d macos \
  --dart-define=TYPED_ROUTES_LOCATION=true    # needs the Runner's location permission
flutter run -d macos -t lib/manual_macos_checks.dart   # lifecycle/disposal acceptance screen
```

`caffeinate -d -i` keeps the display awake while the command runs; without
it the screen goes dark from idle mid-run and the locked session stops
rendering the map window. macOS:

```sh
cd example
caffeinate -d -i flutter run -d macos -t lib/typed_routes_tap_probe.dart > /tmp/probe.log 2>&1 &
python3 tool/typed_routes_tap_injector.py --macos flutter_osm_plugin_example \
  --log /tmp/probe.log --shots /tmp/typed_routes_shots_macos
```

Tap probe (iOS simulator; Android: `--adb <serial> --scale <density>`):

```sh
cd example
flutter run -d <udid> -t lib/typed_routes_tap_probe.dart > /tmp/probe.log 2>&1 &
python3 tool/typed_routes_tap_injector.py --udid <udid> --log /tmp/probe.log \
  --shots /tmp/typed_routes_shots            # `PROBE done` ends both
```

`--dart-define=PROBE_PASSES=typed` or `=legacy` runs a single pass.

Older host: copy `example/` (`lib/`, `asset/`, `android/`, `pubspec.yaml`,
`analysis_options.yaml`, the harness) outside the checkout, point
`flutter_osm_plugin` / `flutter_osm_interface` / `flutter_osm_web` at the
checkout by absolute path, drop the unused JNI add-on, and override
`flutter_osm_android: 0.4.1`; confirm with
`flutter pub deps` that the host resolves from the pub cache, then run the
default harness.

## Results

Environment: Flutter 3.50.0 / Dart 3.14.0, Xcode 26.5, branch `method-pigeon`
at `36b90832` plus the working tree described in the root `CHANGELOG.md`
(4.2.0), `OSMFlutterFramework` 0.9.2, run on 2026-11-25.

### iOS — iPhone 17 simulator, iOS 26.5

- Default run **passed**: both maps ready; camera center exact, zoom 10;
  region event == camera queries; bounds N=48.96667927685769
  E=2.5133043467116543 S=48.73304818997366 W=2.1866956532883455, valid,
  containing the center and shrinking after zooming in; isolation
  `A events=1, B events=0`; disposal and recreation clean; typed and legacy
  attachments field-exact identical for the region event and the bounds query.
- Location run **passed** (earlier step revision, fixed 12 s window; kept
  because it shows the triplet cadence): typed 30
  fixes, legacy 30 fixes, spacing nearly element-for-element identical
  (`[394, 99, 236, 851, 98, 232, 872, …]` vs `[391, 101, 234, 853, 98, 232,
  871, …]`: three callbacks per update, no floor on either plane); the typed
  fix event equals `myLocation()`.

This is the first time the harness ran on iOS at all — see Finding B.
- Latest harness revision (host classification, fresh-fix requirement),
  location + families run **passed**: `host: generated protocol available`
  (both signals agree, every family capability advertised); A, B, the
  families map and the recreated map each hold all fifteen generated
  clients; 5 / 5 fresh fixes with identical spacing.
- Location + families run **passed**: A, B, the families map and the
  recreated map each hold all fifteen typed families while live; the legacy
  location baseline holds none and nothing lingers after removal; markers,
  layers, shapes, roads (manual, `removeLastRoad`, `clearAllRoads`, and a
  2.09 km `drawRoad`), location icons and tracking all completed; location
  typed 10 / legacy 10 fixes in the window.
- Tap probe (typed pass, then legacy pass, real touches via AXe), identical
  on both planes to the reported precision:

  | Step | typed | legacy |
  |---|---|---|
  | marker tap | delivered, `48.8566000,2.3522000` (exact marker position) | delivered, identical |
  | map tap | delivered, `48.8566000,2.3522000` | delivered, identical |
  | road tap (manual road) | delivered, `distance=null routePoints=0` | delivered, identical |
  | marker long press | not delivered (Finding F) | not delivered |
  | marker standing on a road | the road tap wins | the road tap wins |
  | shapes drawn → removed (pixels vs base) | 64.23% → 0.00% | 64.23% → 0.00% |
  | manual road → `removeLastRoad()` → `clearAllRoads()` | 0.23% → 0.00% → 0.00% | 0.23% → 0.00% → 0.00% |
  | computed route → `removeLastRoad()` → `removeRoad(key)` | 0.14% → 0.00% → 0.00% | 0.14% → 0.00% → 0.00% |
  | topo tiles → default tiles | 30.2% → 2.7% | 30.2% → 2.8% |

### Android — Pixel 6 AVD, API 37 (android-37.1, arm64, 16K page image), Android 17

- Default run **passed**: both maps ready; camera center exact, zoom 10;
  region event == camera queries; bounds N=48.96697136387368
  E=2.510170574599917 S=48.73275473516651 W=2.189829425400083, valid,
  containing the center and shrinking after zooming in; isolation
  `A events=1, B events=0`; disposal and recreation clean; typed/legacy
  parity field-exact.
- Location + gestures run **passed**: a tap on map A reported A's center
  (48.86, 2.36) with B silent, a tap on B was delivered to B only; the typed
  fix event equals `myLocation()`; earlier step revision, fixed 12 s
  window — typed 2 / legacy 2 fixes
  (spacing `[1116, 2606]` vs `[1070, 2356]`, both on the host's 1 s cadence;
  the emulator's GPS delivers sparsely). An earlier sequential form of the
  same step measured `[1007, 2937]` vs `[1160, 2640]`.

The bounds line up with iOS on a comparable half-window (lat span 0.2342° vs
0.2336°), so the zoom-to-scale calibration is consistent across both engines.
- Location + families run: A, B, the families map and the recreated map all
  hold the fifteen typed families while live; markers, layers, shapes, roads
  (manual, `removeLastRoad`, `clearAllRoads`, 2.09 km `drawRoad`), icons and
  tracking completed; the gesture step delivered isolated interaction taps.
  An earlier revision of the step accepted an empty window and recorded
  `typed 0 / legacy 0` as a pass (Finding I); that run proved nothing about
  cadence.
- Latest harness revision, location + families + gestures run **passed**:
  `host: generated protocol available`; every default attachment all-typed;
  **4 / 4 fresh fixes**, spacing `[2861, 15017, 15078]` vs
  `[2795, 15018, 15079]` ms — the engine's ~15 s request interval on this
  emulator, above the 1 s floor and identical on both planes. The emulator
  needs simulated movement of roughly walking speed or more: with ~1 m of
  jitter per fix the provider's distance filter delivers only the first
  fixes and the step fails for lack of fresh fixes (as it should).
- Tap probe with `adb shell input` (typed pass, then legacy pass), identical
  on both planes: marker tap delivered with the exact marker position, map
  tap delivered and exact, road tap delivered (`distance=0.0 routePoints=0`
  for a manual road on Android), marker long press **not delivered**
  (Finding F), road wins under a marker. The emulator ran with a software
  GPU, on which `screencap` does not capture the map surface, so the
  draw/remove screenshots are blank there: on Android the removal of roads
  and shapes was not verified visually.

### macOS

Default run **passed** again on the final tree: bounds
N=48.96166042361 E=2.803007685737138 S=48.73809000957792
W=1.896992314262862 at 48.85/2.35 zoom 10 (same values as the earlier
0.9.2 run), typed/legacy parity exact, isolation, disposal and recreation
clean. **The latest harness revision passed on macOS** (default + families,
display on): `host: generated protocol available`, all fifteen generated
clients on A, B, the families map and the recreated map, the same bounds as
above, every command family completed. Two attempts the evening before had
failed the zoom-in viewport check because the display was off and the
session locked (power log `Display is turned off`; `CGSSessionScreenIsLocked:
1`): AppKit then does not render the map window, its viewport is not updated
after a camera change, and bounds read stale. **The macOS run needs the
display on and the session unlocked.** All **84** macOS host XCTest cases
passed against 0.9.2 (the previous 82 plus the two regressions of Findings
D and E).

- Tap probe on macOS (`tool/typed_routes_tap_injector.py` posts real CGEvent
  clicks at the view's screen position; typed pass, then legacy pass),
  identical on both planes to the reported precision:

  | Step | typed | legacy |
  |---|---|---|
  | marker tap | delivered, `48.8566000,2.3522000` (exact marker position) | delivered, identical |
  | map tap | delivered, `48.8566000,2.3522000` | delivered, identical |
  | road tap (manual road) | delivered, `distance=null routePoints=0` | delivered, identical |
  | marker long press (1.2 s hold) | no long-press event; the press is reported as a plain **marker tap** (Finding F) | identical |
  | marker standing on a road | the road tap wins | the road tap wins |
  | shapes drawn → removed (pixels vs base) | 33.83% → 0.00% | 33.83% → 0.00% |
  | manual road → `removeLastRoad()` → `clearAllRoads()` | 0.50% → 0.00% → 0.00% | 0.50% → 0.00% → 0.00% |
  | computed route → `removeLastRoad()` → `removeRoad(key)` | 0.26% → 0.00% → 0.00% | 0.26% → 0.00% → 0.00% |
  | topo tiles → default tiles | 58.28% → 2.86% | 58.28% → 2.86% |

- Location events: with the example app's permission prompt allowed, each
  plane delivered **one** fix within 60 s (`typed=1, legacy=1`, identical)
  and nothing more — a stationary Mac yields no further updates for this
  request. There is no cadence to compare, so the step fails its fresh-fix
  requirement by design; the macOS location **rate** stays pending until a
  moving location source is available.

**Keeping the Mac rendering.** These runs need the display on and the
session unlocked, and the screen goes dark from idle in the middle of a
run. Wrap every macOS harness or probe run in `caffeinate -d -i` (for
example `caffeinate -d -i flutter test …`), which keeps the display from
sleeping for the duration of the command; a lock you trigger yourself
cannot be prevented. The **test window must also stay frontmost and
unobstructed**: the harness's `pumpWidget` waits for a real frame, and
macOS delivers no frames to a window that is covered or behind another
one. A run launched in the background then stalls silently — the app sits
idle at 0% CPU with every engine thread waiting, and nothing times out
because the wait is the frame itself. Observed twice; both runs resumed
the instant the window was activated. For an unattended run keep it in
front:

```sh
( for i in $(seq 1 300); do osascript -e 'tell application "System Events" to \
    set frontmost of process "flutter_osm_plugin_example" to true' >/dev/null 2>&1; \
    sleep 1; done ) &
```

### Older host — published `flutter_osm_android` 0.4.1

Scratch copy as described above (`flutter pub deps`: host 0.4.1 from the pub
cache, which contains no Pigeon/bootstrap code). With the shipped defaults —
all fifteen flags effectively on — the default harness **passed** five
times out of six on earlier revisions (maps ready on the legacy `map#init`
plane, camera and region events identical to the current-host values,
isolation, disposal, recreation and parity). One run lost the tool↔device
channel four seconds in (`did not complete [E]`) while the app itself ran on
and finished without a logged error; it did not recur in the following runs
with identical artifacts and is recorded as an unexplained tooling one-off,
not a plugin finding.

Latest harness revision: the harness **classifies this host as older**
(`host: no generated protocol (older host)` — no capability answer and no
generated handler), **asserts that no attachment holds a generated client**
(A, B, the families map, the recreated map), and both the default run and
the families run **passed**: every command family completed on the legacy
plane of 0.4.1 as well (markers through `geoPoints()`, layers, shapes,
roads including a 2.09 km `drawRoad`). Logcat for the app shows no
negotiation noise (no handler errors, "Message corrupted", route-selection
failures).

| Check | Android (emulator) | iOS (simulator) | macOS |
|---|---|---|---|
| 1 Attachment | harness passed | harness passed | harness passed |
| 2 Payload parity | region, location, marker/map/road taps passed (probe, real input); shapes/roads visuals pending (software GPU) | region, location, marker/map/road taps passed (probe); shapes/roads visuals passed | region, marker/map/road taps passed (probe); shapes/roads visuals passed |
| 3 Two maps | harness passed; typed + legacy maps live together passed (probe and location step) | harness passed; typed + legacy maps live together passed | harness passed; both planes live together in the probe |
| 4 Recreation | attachment recreation passed; activity restoration pending | attachment recreation passed | harness passed (typed); `manual_macos_checks` lifecycle pending |
| 5 Permissions | granted path passed; deny/`GeoPointException` pending | granted path passed; prompt allow/deny pending | allow prompt exercised once (a fix was delivered); deny pending |
| 6 Disposal | harness passed; no typed route lingers after removal | harness passed; no typed route lingers after removal | harness passed; no typed route lingers after removal |
| 7 Event rates | location: 4 / 4 fresh fixes, ~15 s cadence identical on both planes, ≥ ~1 s on both; region drag pending | location: 5 / 5 and 10 / 10 fresh fixes, identical cadence, every callback; region drag pending | pending (no location feed on a stationary Mac; permission not yet granted to the example app) |
| 8 Older-host compatibility | harness passed against 0.4.1 (7 of 8 runs; the latest revision classifies the host as older, asserts no generated client, and passes the default and families runs) | n/a (host ships with the main package; Dart fallback tests) | n/a (same) |

## Findings

### Finding A — Apple bounds defect (fixed in framework 0.9.2)

`OSMFlutterFramework` 0.9.1 `MCRectCoord.toBoundingBox()`
(`models/extensions.swift`) assigned `north: topLeft.longitude`,
`west: topLeft.latitude`, `east: bottomRight.latitude`,
`south: bottomRight.longitude` — latitude and longitude swapped — and the
visible rect it was handed for `onVisibleBoundsChanged` was zero-area at the
camera center. Consequences on iOS and macOS, identically on the legacy and
typed routes (verified with a legacy-only probe): `Region.boundingBox`
degenerated to the center, and `controller.bounds` / typed `getBounds`
answered a field-permuted world box.

This was **not a typed-route regression**: typed↔legacy parity was exact. The
framework fixes are released in **0.9.2**, commit
`0494aa313b65f28eedc5562ff904ce115db52eea`, and the shared Darwin package
pins that exact version: corrected axis assignment, `getVisibleRect()` as the
visible region, viewport synchronization during initialization/layout, and
startup zoom applied without an animation that could overwrite an immediate
explicit zoom. The plugin applies no coordinate compensation. The harness
now asserts absolute bounds on every platform (see Checks 2) and pumps
native-view layout after readiness, because readiness alone can precede
Flutter submitting platform-view geometry (a genuinely zero-size viewport).

### Finding B — the example showed a black screen on iOS (fixed)

`example/ios/Runner/SceneDelegate.swift` existed on disk but was never a
member of the Runner target in `Runner.xcodeproj/project.pbxproj`, while
`Info.plist`'s scene manifest named `Runner.SceneDelegate`. The class was
therefore never compiled, `NSClassFromString("Runner.SceneDelegate")`
answered `nil` at runtime, UIKit connected the scene with **no delegate and
no window**, and no `FlutterViewController`/engine was ever created: a black
screen, on `flutter test` and on a plain launch alike. Present since the
UIScene manifest landed (2026-05-22 / 2026-06-04); macOS has no scene
delegate, which is why only iOS was affected and why the iOS harness had
never actually run. Fix: add the file to the target (file reference, group,
Sources phase). The published package archive excludes the example's iOS
project, so pub.dev users were not affected.

### Finding C — harness gaps (fixed)

- The location step wired an `onLocationChanged` callback but never started a
  flow, so no host could ever deliver a fix. It now calls `currentLocation()`
  and `startLocationUpdating()` on both planes.
- The step compared cadence against an assumed rate, then against a median of
  inter-fix gaps — meaningless on Apple, where a location update arrives as
  a burst of callbacks. It now runs the typed and a legacy attachment
  **simultaneously** and compares callback counts over one window.
- Readiness was recorded as "(typed lifecycle route)" although against an
  older host it legitimately arrives on the legacy plane; labels are neutral
  now.
- The step's permission prerequisite is timing-dependent: `flutter test`
  installs a fresh copy per run, so a grant made before the run is discarded.
  The commands above grant right after the install lands.
- After the default flip the harness's "legacy" baselines would silently have
  become typed; they opt out explicitly and a guard pins the defaults.

### Finding D — two legacy commands never answered on Apple (fixed)

`clear#shapes` and `toggle#Alllayer` in the shared Darwin
`MapMethodHandler.swift` applied their effect but never called `result`, so
on iOS/macOS the legacy-plane `removeAllShapes()` and `toggleLayer()` futures
never completed (Android replies; the typed shapes and layers routes reply).
Pre-existing and plane-independent (an opt-out hung the same way); the typed
probe found it because its legacy pass stalled at `removeAllShapes()`. Fix:
both reply `200`; an undecodable manual road now answers with an error
instead of silence; a scan of all 42 legacy cases shows a reply on every
path. Regression test: `testLegacyShapeAndOverlayCommandsAlwaysReply`.

### Finding E — `removeLastRoad()` removed nothing on Apple (fixed)

On the Darwin host only the legacy *fetched-route* handler recorded
`lastRoadKey`; manual roads (typed or legacy) never did, and since route
calculation moved to Dart (4.0.0) `MapController.drawRoad` draws manually.
`removeLastRoad()` had therefore been a no-op for every road an application
draws, on both planes (Android's legacy `delete#road` without a key removes
*all* roads — a separate, long-standing platform difference left as is).
Fix: every add path records the most recently drawn road and `delete#road`
without a key consumes it exactly once. Regression test:
`testLegacyDeleteLastRoadRemovesTheMostRecentlyDrawnRoad`. Runtime: the
probe shows the manual road and the computed route gone after
`removeLastRoad()` on both planes (table above).

### Finding F — marker long press is not reported (open, framework-side)

A long press on a marker delivers neither `onGeoPointLongPress` nor a map
long tap, on iOS (AXe, 1.2 s and 2.5 s holds) and on Android (`input swipe`
1.2 s hold), identically on the typed and legacy planes — while a long press
on the empty map is reported. The plugin wires `onMarkerLongPress` through
the delegate proxy and the framework's icon layer implements `onLongPress`;
the detection lives in MapCore, which offers no opt-in. Not a typed-route
regression; worth a manual confirmation on a device and an issue against
`OSMFlutterFramework`.

### Finding G — a road under a marker wins the tap (informational)

Tapping a marker that stands on a road reports the road tap, not the marker
click, identically on both planes and platforms: framework hit priority.

### Finding H — `flutter test` cannot deliver native touches (test setup)

The live test binding drops device pointer events unless
`shouldPropagateDevicePointerEvents` is set, and even then a UIKit/AppKit
platform view never receives them; on Android the Flutter-synthesized tap
reaches the map (interaction event) but not the marker-click confirmation.
Tap events are therefore validated by the plain-app probe with real input.
Two early versions of the route observation in the harness were also wrong
(platform-view ids predicted by counting creations; route checks evaluated
after the maps were already disposed) — both fixed by discovering ids from
live typed routes and checking while the maps are live. No defect was
involved in either.

### Finding I — the harness could pass without proving what it claimed (fixed)

A review of the harness found two verification gaps. (1) The location step
compared the number of fixes two planes delivered inside a fixed window,
but never required any: a provider that fell silent after the first fix
left `0 / 0`, which compares as equal — one Android run passed that way.
The step now requires at least four fresh fixes on each plane after the
first one, or it fails. (2) The route check verified that the *flags* were
`true` and that each attachment was either all-typed or not typed at all;
a current host that silently fell back to legacy on every family satisfied
both. The run now classifies the host from two independent signals
(legacy-channel capability probe, presence of a generated channel handler)
and requires generated clients for every family on a current host and none
on an older one. Both paths are demonstrated above: iOS simulator and
Android emulator report `generated protocol available` and hold all fifteen
clients; the published 0.4.1 host reports `no generated protocol` and holds
none. Two implementation details were learned the hard way: the generated
codec reports a missing handler as `PlatformException('channel-error')`,
not `MissingPluginException`, and the Dart route clients guard the session
before sending, so the classification talks to the client wrapper's
`StaleMapSessionException`, the host's own answer.

### Finding J — the example's Search page was an error screen (fixed)

With the display unlocked the example app itself was opened on macOS: the
home page renders, but **Search Example was a full-screen widget error**
(`No Material widget found` for its search `TextField`) — red in a debug
build, a blank dark surface in profile/release builds. Present on every
platform since 4.0.0, when the picker stopped providing a Material scaffold
and this page was not updated to host it. Unrelated to the typed routes (a
Dart widget-tree assertion before any map exists). Fix: the page wraps the
picker in a `Scaffold`; verified on macOS — the page, its map (typed through
the defaults) and its search field render with no exception.

### Finding K — the static map lost its home marker on macOS (fixed)

`OSMViewer` with `SimpleMapController.markerHome` rendered on macOS but
without the home marker, and threw `Error to draw you custom icon` — on the
typed **and** the legacy plane. The static controller adds the marker one
second after attach; on macOS the map is still initializing then, no frame
has mounted the icon widget, and the capture failed at once. The same call
made later succeeded. Fix in the interface, shared by both routes: the
capture waits (frame by frame, bounded) until the icon widget is mounted and
painted. Verified on macOS with a throwaway static-map probe: no error and
the home marker visible on both planes. (`flutter_osm_interface`:
`icon_mount_test.dart`.)

The macOS runs in this round were made under `caffeinate -d -i`; the display
assertion was confirmed held during a full harness run, and the harness
passed on the final code on both iOS and macOS afterwards.

### Finding L — a background macOS run stalls when its window is covered (environment)

Two harness runs stalled on macOS at a `pumpWidget` (after "isolation" and
after "recreation"), each for 10+ minutes: the app idle at 0% CPU, every
engine thread in its run loop, nothing in the system log. A live test
binding's `pumpWidget` waits for a real frame, and macOS delivers none to
an occluded window; both runs continued the moment the window was
activated. Not a plugin defect, and it explains why a run that passes when
watched can hang when launched in the background. The mitigation is in
"Keeping the Mac rendering" above.

No typed-route defect was found on any platform: every difference the
probe measured between the planes was identical to the reported precision.

## Remaining device checks

Run the harness and the probe on physical devices, then record device/OS,
Flutter, commit and the `TYPED_ROUTES_SUMMARY` / `PROBE` lines here:

1. **Permissions** — first-launch prompt allow → fixes flow on the typed
   route; deny → `GeoPointException`; Android `pm revoke` → `GeoPointException`.
2. **Android activity recreation** — "Don't keep activities", background and
   return the home page: restoration arrives once through the typed lifecycle
   route (`onMapRestored`). Apple has no restoration.
3. **Event rates by hand** — region-change spacing while dragging on both
   pages (Android ≥ ~100 ms, first immediate, trailing newest; Apple every
   callback), and location fix spacing with a real GPS (Android ≥ ~1 s).
4. **Tracking UX** — `enableTracking` / `disabledTracking` with
   `unFollowUser` and a custom anchor on a real fix stream.
5. **Visual confirmation on Android** — shapes and roads removed, on a
   device or a hardware-GPU emulator (the software-GPU emulator cannot
   screenshot the map surface).
6. **Marker long press** — confirm Finding F by hand (both example pages).
7. **macOS location rate** — needs a moving location source; a stationary
   Mac delivers a single fix. Also the permission **deny** path.

## Release checklist

- Flip the `useTyped*` defaults — **done** (`OSMOption` and the widget
  shims); the example's legacy pages opt out explicitly; README and
  CHANGELOG describe the compatibility contract.
- Bump and publish the typed-capable inner releases (`flutter_osm_interface`,
  `flutter_osm_android`; the web and JNI packages only need constraint
  alignment), then point the root's **hosted** constraints at them with
  `update_versions.py`. Until then the root resolves the typed-capable
  packages only through the development `pubspec_overrides.yaml`; the
  published 4.1.0 constraints (`^1.9.0`, `^0.4.0`) are not sufficient for
  this source and must not be published as they are.
- Re-run this harness once on each platform at the release commit.

# Legacy command & event audit — Pigeon channel profile

Status: **default** (4.2.0). Every command family and every native-to-Dart
event family scheduled by the plan has a typed (generated Pigeon) route, and
each is the default — capability-negotiated at attachment, with an opt-out
flag per family. The remaining legacy traffic is listed below as
**intentional exceptions**. The combined configuration passed the runtime
harness on an Android emulator, the iOS simulator and macOS, including the
older-host fallback; the physical-device pass is the remaining pre-release
gate ([TYPED_ROUTES_VALIDATION.md](../../TYPED_ROUTES_VALIDATION.md)).

Sources audited:

- Dart: `flutter_osm_interface/lib/src/channel/osm_method_channel.dart`
- Android: `flutter_osm_android/.../mapscore/LegacyMethodChannelAdapter.kt`
  (`LegacyMapCommand`, `TypedMapCommand`), `MapscoreMapSession.kt`,
  `MapEventCoalescer.kt`
- Apple: `darwin/.../Shared/MapMethodHandler.swift`, `MapSession.swift`

## Families routed through Pigeon (default, capability-negotiated)

### Command families (Dart → host)

Each family probes the host once at attachment (`map#bootstrap#protocol`)
and freezes its own decision: generated route only when the application did
not opt out (`useTyped*` defaults to `true`) **and** the host advertises the
capability. The legacy route is never removed.

| Family | Capability | Public API served | Legacy route kept for |
|---|---|---|---|
| Camera (zoom/move/rotation/position) | `camera` | `MapController` camera ops | older hosts, opt-out, JNI default |
| Camera config (bounds, limits, zoom config) | `camera.config` | bounds queries, limits, zoom config | older hosts, opt-out |
| Markers + static groups | `markers` | marker add/move/remove, static groups | older hosts, opt-out, JNI default |
| Layers (tile source, overlay visibility) | `layers` | tile source, overlay toggles | older hosts, opt-out |
| Shapes (circles, rectangles) | `shapes` | shape add/remove/clear | older hosts, opt-out |
| Roads (manual draw, remove, clear) | `roads` | manual roads | older hosts, opt-out |
| Location (my-location layer, one-shot fix) | `location` | `currentLocation`, `myLocation` | older hosts, opt-out |
| Continuous updates | `location.updates` | `startLocationUpdating` / `stopLocationUpdating` | older hosts, opt-out |
| Follow-me tracking | `location.tracking` (+`.anchor`) | `enableTracking` / `disableTracking` | older hosts, opt-out |
| User-location icons | `location.icons` | person/direction icon replacement | older hosts, opt-out |

### Native-to-Dart event families (host → Dart)

Each event family additionally **negotiates its delivery route before
initialization** (`map#events#<family>#route`, identity-validated) so that
exactly one route delivers per attachment. The public stream is unchanged
on either route, and the host's own rate/coalescing is preserved on either
route — the typed route only changes *where* events travel.

| Family | Capability | Route selection | Legacy message(s) replaced | Public stream (unchanged) | Rate / coalescing (identical on both routes) | Legacy route kept for |
|---|---|---|---|---|---|---|
| Lifecycle: readiness, restoration | `events.lifecycle` | `map#events#lifecycle#route` | `map#init`, `map#restored` | `onMapIsReady`, `onMapRestored` | one delivery per readiness transition (repeats coalesced); replay before first subscription; Android restoration buffered across the recreation/selection race | older hosts, opt-out, JNI attachments |
| Map interactions: single/long press | `events.interaction` | `map#events#interaction#route` | `receiveSinglePress`, `receiveLongPress` | `onSinglePressMapClickListener`, `onLongPressMapClickListener` | discrete: every press delivered once, repeats never coalesced | older hosts, opt-out, JNI attachments |
| Marker interactions: single/long press | `events.markers` | `map#events#markers#route` | `receiveGeoPoint`, `receiveGeoPointLongPress` | `onGeoPointClickListener`, `onGeoPointLongPressListener` | discrete | older hosts, opt-out, JNI attachments |
| Road taps | `events.roads` | `map#events#roads#route` | `receiveRoad` | `onRoadMapClickListener` | discrete; typed payload mirrors the legacy map field for field | older hosts, opt-out, JNI attachments |
| User location: continuous fixes | `events.location` | `map#events#location#route` | `receiveUserLocation` | `onUserPositionListener` | Android: `MapEventCoalescer` 1 s (first immediate, newest wins); Apple: every location callback | older hosts, opt-out, JNI attachments |
| Visible region: center, bounds, zoom | `events.region` | `map#events#region#route` | `receiveRegionIsChanging` | `onRegionIsChangingListener` | Android: `MapEventCoalescer` 100 ms (first immediate, newest wins); Apple: every map-move callback | older hosts, opt-out, JNI attachments |

Host payload notes (public events are identical on either route and either
host; these are the wire-level differences the forwarders absorb):

- **Road taps.** Android never decoded its legacy `roadPoints` list, so the
  typed payload leaves `routePoints` null (public route stays empty, as
  before); Apple carries the encoded polyline and instructions.
- **User location.** The heading crosses as the raw double the legacy map
  carried and decodes through the same `UserLocation.fromMap` path (no unit
  conversion).
- **Visible region.** The typed callback carries the zoom in the camera
  family's `getZoom` units. The public `Region` never had a zoom field
  (Android's legacy payload had none; Apple's legacy `zoomLevel` was never
  read), so the typed zoom is not surfaced either.
- **Visible region without a center** (Android camera not ready): the legacy
  payload historically carried a null `center`; the typed contract cannot
  express it and drops that change on the typed route only.
- **Apple bounds (fixed in framework 0.9.2).** Through 0.9.1 the pinned
  framework's `MCRectCoord.toBoundingBox()` swapped latitude/longitude and
  was handed a zero-area visible rect, so on iOS/macOS `Region.boundingBox`
  degenerated to the center and `controller.bounds` answered a permuted world
  box — identically on the legacy and typed routes (parity was exact;
  `Region.center` was correct). The plugin applies no compensation; the
  shared Darwin package pins 0.9.2 and the harness asserts absolute bounds
  on every platform (Finding A in
  [TYPED_ROUTES_VALIDATION.md](../../TYPED_ROUTES_VALIDATION.md)).

## Acceptance matrix

Automated coverage per family and host. "Runtime" is end-to-end evidence on
real hosts without physical hardware — the harness
(`example/integration_test/typed_routes_parity_test.dart`: default run,
location step, families step) and, for tap events, the plain-app probe
(`example/lib/typed_routes_tap_probe.dart` with real injected touches) — on
an Android emulator, the iOS simulator and macOS. **pending** means there is
no end-to-end evidence for that family on that target; it is never inferred
from unit tests or from another family's result. Details, numbers and the
physical-device pass are tracked in
[TYPED_ROUTES_VALIDATION.md](../../TYPED_ROUTES_VALIDATION.md). Every runtime
row below is for the combined configuration (all typed families together) on
the shipped defaults.

| Family | Dart routing tests (`flutter_osm_interface/test`) | Android host tests (Kotlin) | Apple host | Example / integration | Runtime (emulator / simulator) |
|---|---|---|---|---|---|
| Camera, camera config | `camera_route_test.dart` | `PigeonNativeCameraBridgeTest` | builds; `RunnerTests` typed marker/camera coverage | harness default run; `android_controller_attach_test` (JNI) | iOS simulator passed (latest harness); Android emulator passed (latest harness); macOS passed (latest harness); device pending |
| Markers, layers, shapes, roads (commands) | `markers_route_test`, `layers_route_test`, `shapes_route_test`, `roads_route_test` | `PigeonNative{Markers,Layers,Shapes,Roads}BridgeTest` | builds; `RunnerTests` | harness families step; `android_controller_attach_test` (JNI) | families step passed on iOS simulator and Android emulator (current host, all generated clients asserted) and against the published 0.4.1 host (legacy plane); macOS passed (latest harness). Markers verified through `geoPoints()`; shape and road removal verified by screenshot on iOS and macOS (typed = legacy) — **visual removal on Android pending**; device pending |
| Location, updates, tracking, icons (commands) | `location_route_test`, `location_updates_route_test`, `tracking_route_test`, `user_location_icons_route_test` | `PigeonNative{Location,LocationUpdates,Tracking,UserLocationIcons}BridgeTest` | builds; `RunnerTests` permission/result paths | harness location step (updates) and families step (icons at init, tracking); `android_controller_attach_test` (location events) | passed on iOS simulator and Android emulator; icons have no observable result beyond completing; macOS: `currentLocation`/`startLocationUpdating` delivered one fix on each plane — **tracking and icons not run on macOS**; device pending |
| Lifecycle events | `lifecycle_events_route_test` | `LegacyLifecycleRouteSelectionTest`, `LifecycleEventRouteTest`, `PigeonNativeLifecycleEventsBridgeTest` | builds | harness default run (readiness, recreated attachment); `android_phase5_lifecycle_test` (legacy plane) | readiness and attachment recreation passed on iOS simulator (latest harness) and Android emulator (latest); macOS passed (latest harness); **Android activity restoration through the typed route pending**; device pending |
| Interaction events | `interaction_events_route_test` | `LegacyInteractionRouteSelectionTest`, `PigeonNativeInteractionEventsBridgeTest` | builds | harness gesture step (Android); probe map tap | map tap passed on iOS simulator, Android emulator and macOS (typed = legacy); device pending |
| Marker events | `marker_events_route_test` | `LegacyMarkerRoadRouteSelectionTest`, `PigeonNativeMarkerEventsBridgeTest` | builds | probe marker tap / long press | marker tap passed on iOS simulator, Android emulator and macOS (typed = legacy, exact position); **marker long press never reported: nothing on iOS/Android, a plain marker tap on macOS — open, Finding F**; device pending |
| Road events | `road_events_route_test` | `LegacyMarkerRoadRouteSelectionTest`, `PigeonNativeRoadEventsBridgeTest` | builds | probe road tap | road tap passed on iOS simulator, Android emulator and macOS (typed = legacy); device pending |
| Location events | `location_events_route_test` | `LegacyLocationRouteSelectionTest`, `PigeonNativeLocationEventsBridgeTest`, `CoalescedEventRouteTest` | builds | harness location step (typed and legacy maps live together) | iOS simulator: 5 / 5 and 10 / 10 fresh fixes, equal cadence; Android emulator: 4 / 4 fresh fixes at ~15 s cadence on both planes; macOS: 1 / 1 fix, no cadence on a stationary Mac — **rate pending**; device pending |
| Region events | `region_events_route_test` | `LegacyRegionRouteSelectionTest`, `PigeonNativeRegionEventsBridgeTest`, `CoalescedEventRouteTest` | builds | harness default run | passed on iOS simulator (latest harness) and Android emulator (latest); macOS passed (latest harness); device pending |
| Older-host fallback (every family) | each `*_route_test`: camera-only bootstrap → legacy without negotiation | adapters reject unknown selections with `invalid_route` | — | scratch copy pinned to the published `flutter_osm_android` 0.4.1 (validation doc) | Android emulator: the harness classifies the host as older from two independent signals, asserts that no attachment holds a generated client, and passes the default and families runs on the legacy plane; iOS/macOS n/a (host ships with the main package) |

Every Dart suite also covers exactly-one-route delivery (legacy messages
dropped while the generated route is frozen), stale session callbacks,
disposal, two-map isolation, attachment-scoped stream completion and
recreation; the route-selection suites cover freeze-once, definite
rejection (legacy kept) and the uncertain-outcome abort.

## Event routing rules (all event families)

- Negotiation happens during attachment, **before initialization**: probe
  (family capability) → Dart registers the per-view FlutterApi handlers →
  Dart sends `map#events#<family>#route` with the session identity → host
  validates and switches delivery. A **definite** rejection (stale session,
  unknown route, missing endpoint) keeps the legacy route; the decision is
  frozen for the attachment and never re-negotiated.
- A selection **timeout** is an uncertain outcome: the host may already have
  switched to the generated route while the reply was lost. Dart confirms a
  rollback to `legacy` on the same ordered channel before allowing the
  legacy fallback; if the rollback cannot be confirmed it aborts attachment
  (`RouteSelectionUncertainException` subtypes: lifecycle, interaction,
  marker, road, location, region) rather than unregistering handlers while
  the host might still emit on Pigeon. No decision is frozen on abort, so a
  retry re-negotiates cleanly.
- A failed negotiation for a disposed/replaced attachment never writes a
  decision: the epoch guard discards it so it cannot overwrite the
  replacement's frozen route.
- Exactly one delivery route per attachment and family: a switched host
  never emits that family's legacy message, and the Dart channel drops
  legacy messages for maps whose generated route is active. Families are
  independent: an attachment may mix typed and legacy families, and the
  command routes (e.g. typed tracking) are independent of the event routes
  (e.g. legacy location events) — both combinations are tested.
- Every typed callback carries `sessionToken` + `generation`; mismatched
  (stale) callbacks are dropped. Disposal unregisters the handlers; a
  replacement attachment decides freshly against the new session identity,
  and a stale client's late teardown never unregisters the replacement.
- **Rates are the host's.** The Dart forwarder owns no rate: it forwards
  every validated callback once, in order, never buffers or coalesces. On
  Android, location and region changes pass through the session's
  `MapEventCoalescer` *before* the frozen route decides where the flushed
  payload goes, so the generated callbacks and the legacy messages share one
  rate state and interval. On Apple, every location and map-move callback is
  forwarded on both routes.
- Readiness is a transition signal: repeated identical values are coalesced
  by the Dart client, so one initialization yields exactly one delivery.
  All other event families are discrete or host-rated and are never
  coalesced in Dart.
- Public streams are unchanged; both routes feed the same event broadcast.
  Lifecycle events emitted during attachment (e.g. Android flushing a
  buffered restoration while answering the selection) arrive before the
  controller subscribes, so they are buffered per map and replayed to the
  first listener instead of being dropped by the broadcast stream. Every
  other event stream is served through an attachment-scoped view: a
  subscription that is still active when its map is disposed completes
  instead of receiving a replacement attachment's events, and disposal
  clears any unreplayed lifecycle buffer.

## Intentional exceptions — stay legacy by design

1. **Permissions.** Location permission requests stay in Dart
   (`permission_handler`, `lib/src/common/location_permission.dart` and the
   Android controller's injected requester); native hosts only perform
   authorization *checks* and report `permission_denied` /
   `location_service_disabled`. No typed permission API will be added — a
   second permission surface would duplicate ownership and prompt UX.
   The legacy `currentLocation` settings round trip (provider off → system
   settings) is a location-service flow, not a permission API, and is
   mirrored by the typed `location` family.
2. **Attach-time negotiation itself**: the bootstrap probe
   (`map#bootstrap#protocol`) and the six event route selections
   (`map#events#{lifecycle,interaction,markers,roads,location,region}#route`).
   Negotiation must run on a channel that exists before any generated route
   is decided; moving it would be circular.
3. **The JNI event plane.** JNI command attachments complete through the
   session's MethodChannel event sink and never negotiate typed event
   routes, so `map#init`, `receiveSinglePress`, `receiveLongPress`,
   `receiveGeoPoint`, `receiveGeoPointLongPress`, `receiveRoad`,
   `receiveUserLocation` and `receiveRegionIsChanging` remain decoded
   legacy event names (`decodeAndroidMapEvent`) and the only delivery plane
   for JNI. For MethodChannel attachments these same messages are the
   legacy plane that the typed event families replace once negotiated;
   hosts emit each family on exactly one route per attachment.
4. **Apple initialization sequencing** (`init#ios#map` → `map#init#ios`).
   The shared Darwin host answers the config probe with one event that
   triggers Dart-side initialization exactly once. It is control flow, not
   a map mutation; it stays legacy.
5. **Relative zoom / zoom UI helpers**: `change#stepZoom`, `set#minZoom`,
   `set#maxZoom`, `showZoomController`, `zoomToRegion` (legacy alias).
   The typed `configureZoom` covers absolute configuration; the relative
   step and the native zoom-controller overlay keep their legacy semantics
   (documented in the camera schema). Candidates for a later camera phase,
   not blockers.
6. **Info-window visibility** (`use#visiblityInfoWindow`). Android-only
   overlay behavior with no typed counterpart yet; intentional exception
   until the info-window family is designed.
7. **Road calculation** (`road`, `draw#multi#road`). Route fetching stays
   asynchronous in Dart/native network code; only drawing of computed
   polylines crossed to the typed `roads` family. The multi-road
   orchestration keeps its legacy request/response shape.
8. **Queries with typed equivalents but legacy public payloads**:
   `map#center`, `map#bounds`, `get#Zoom`, `get#geopoints`. The typed camera
   route serves bounds/position when negotiated; `get#geopoints` returns
   the legacy coordinate list shape the public API exposes. Candidate for
   the markers query phase.
9. **Deprecated no-ops**: `changePosition` (Apple answers 200 without
   effect), `marker#icon` legacy alias. Kept for byte parity; never
   migrated.
10. **Restoration on the legacy plane.** `map#restored` remains a decoded
    legacy event name for compatibility, but hosts do not newly emit it:
    restoration emission is introduced **only** on the typed
    `events.lifecycle` route (Android activity recreation). Apple hosts
    have no restoration concept and never emit `onMapRestored`. This keeps
    the legacy event plane byte-for-byte unchanged for opted-out users and
    older hosts.
    On Android the session is registered as the activity
    `OnSaveInstanceStateListener`; restoration arriving before route
    negotiation (or before any selection for JNI/opt-out attachments) is
    buffered and flushed once the route resolves, so it is never lost to
    the recreation/selection race.

## Rollout status

The rollout gate — payload parity against the legacy plane, two live maps,
recreation, permissions, disposal, event rates and older-host compatibility
in the combined configuration — was met for everything runnable without
physical hardware: the harness passed on an Android emulator, the iOS
simulator and macOS, location callbacks were compared typed against legacy
over one window on both mobile platforms, and the published pre-Pigeon
Android host (0.4.1) fell back cleanly under the shipped defaults. The
defaults therefore changed to `true` in 4.2.0 (`OSMOption` and the mobile/web
widget shims), the example's legacy pages opt out explicitly to keep the
parity baseline, and the compatibility documentation is in the README and
CHANGELOG. Before publishing: finish the physical-device pass and the
version/constraint steps listed in
[TYPED_ROUTES_VALIDATION.md](../../TYPED_ROUTES_VALIDATION.md).

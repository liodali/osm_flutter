# Legacy command & event audit — Pigeon channel profile

Status at the `events.lifecycle` phase (typed native-to-Dart readiness and
restoration callbacks). This audit records every command/event family that
still travels on the legacy per-view MethodChannel
(`plugins.dali.hamza/osmview_<id>`) and, for each, whether it is a migration
candidate or an **intentional exception** that stays legacy by design.

Sources audited:

- Dart: `flutter_osm_interface/lib/src/channel/osm_method_channel.dart`
- Android: `flutter_osm_android/.../mapscore/LegacyMethodChannelAdapter.kt`
  (`LegacyMapCommand`, `TypedMapCommand`) and `MapscoreMapSession.kt`
- Apple: `darwin/.../Shared/MapMethodHandler.swift`

## Families already routed through Pigeon (opt-in, capability-negotiated)

| Family | Capability | Legacy route kept for |
|---|---|---|
| Camera (zoom/move/rotation/position) | `camera` | older hosts, non-opt-in |
| Camera config (bounds, limits, zoom config) | `camera.config` | older hosts, non-opt-in |
| Markers + static groups | `markers` | older hosts, non-opt-in, JNI default |
| Layers (tile source, overlay visibility) | `layers` | older hosts, non-opt-in |
| Shapes (circles, rectangles) | `shapes` | older hosts, non-opt-in |
| Roads (manual draw, remove, clear) | `roads` | older hosts, non-opt-in |
| Location (my-location layer, one-shot fix) | `location` | older hosts, non-opt-in |
| Continuous updates | `location.updates` | older hosts, non-opt-in |
| Follow-me tracking | `location.tracking` (+`.anchor`) | older hosts, non-opt-in |
| User-location icons | `location.icons` | older hosts, non-opt-in |
| Lifecycle events (readiness, restoration) | `events.lifecycle` | older hosts, non-opt-in, JNI attachments |

Legacy routes are never removed: they are the compatibility plane for older
hosts and the delivery plane for attachments that do not opt in.

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
2. **The bootstrap probe itself** (`map#bootstrap#protocol`) and the
   **lifecycle route selection** (`map#events#lifecycle#route`). Attach-time
   negotiation must run on a channel that exists before any generated route
   is decided; moving them would be circular.
3. **The non-lifecycle event plane.** `receiveSinglePress`,
   `receiveLongPress`, `receiveGeoPoint`, `receiveGeoPointLongPress`,
   `receiveRoad`, `receiveUserLocation`, `receiveRegionIsChanging` stay on
   the legacy MethodChannel. This is also the **JNI event plane**: JNI
   command attachments complete through the session's MethodChannel event
   sink and never negotiate `events.lifecycle`, so their readiness keeps
   flowing as `map#init`. Typed callbacks for these events are a later
   phase; location streams are coalesced natively (`MapEventCoalescer`).
4. **Apple initialization sequencing** (`init#ios#map` → `map#init#ios`).
   The shared Darwin host answers the config probe with one event that
   triggers Dart-side initialization exactly once. It is control flow, not
   a map mutation; migration is deferred until the event plane moves.
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
    the legacy event plane byte-for-byte unchanged for non-opt-in users.
    On Android the session is registered as the activity
    `OnSaveInstanceStateListener`; restoration arriving before route
    negotiation (or before any selection for JNI/opt-out attachments) is
    buffered and flushed once the route resolves, so it is never lost to
    the recreation/selection race.

## Lifecycle event routing rules (this phase)

- Negotiation happens during attachment, **before initialization**: probe
  (`events.lifecycle` capability) → Dart registers the per-view FlutterApi
  handlers → Dart sends `map#events#lifecycle#route` with the session
  identity → host validates and switches delivery. A **definite** rejection
  (stale session, unknown route, missing endpoint) keeps the legacy route;
  the decision is frozen for the attachment.
- A selection **timeout** is an uncertain outcome: the host may already
  have switched to the generated route while the reply was lost. Dart
  confirms a rollback to `legacy` on the same ordered channel before
  allowing the legacy fallback; if the rollback cannot be confirmed it
  aborts attachment (`LifecycleRouteUncertainException`) rather than
  unregistering handlers while the host might still emit on Pigeon. No
  decision is frozen on abort, so a retry re-negotiates cleanly.
- A failed negotiation for a disposed/replaced attachment never writes a
  decision: the epoch guard discards it so it cannot overwrite the
  replacement's frozen route.
- Exactly one delivery route per attachment: a switched host never emits
  `map#init`/`map#restored` on the legacy plane, and the Dart channel drops
  legacy lifecycle messages for maps whose generated route is active.
- Every typed callback carries `sessionToken` + `generation`; mismatched
  (stale) callbacks are dropped. Disposal unregisters the handlers; a
  replacement attachment decides freshly against the new session identity.
- Readiness is a transition signal: repeated identical values are coalesced
  by the Dart client, so one initialization yields exactly one delivery.
- Public streams (`onMapIsReady`, `onMapRestored`) are unchanged; both
  routes feed the same event broadcast.

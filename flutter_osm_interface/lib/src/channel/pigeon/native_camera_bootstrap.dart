// Read-only attach-time protocol contract for the Pigeon channel routes.
//
// The bootstrap probe runs on the EXISTING legacy method channel with its
// primitive codec, before any map mutation, so routing can be frozen during
// attachment. It must stay in sync with the native payloads:
// - Android: `PigeonNativeCameraBridge.bootstrapPayload` (flutter_osm_android)
// - iOS/macOS: `PigeonCameraBridge.bootstrapPayload` (darwin shared source)
//
// This module is private to the platform interface; applications never touch
// generated or bootstrap types.
import 'package:flutter/foundation.dart';

/// Legacy-channel method name of the read-only probe. Additive: hosts that
/// predate it reply not-implemented, which maps to legacy routing.
const String kNativeBootstrapMethod = 'map#bootstrap#protocol';

/// Wire revision answered by hosts that speak this contract.
const int kNativeProtocolRevision = 1;

/// Schema identifier prefix answered by hosts of this plan's contracts.
const String kNativeCameraSchemaId = 'flutter_osm.native.camera.v1';

/// Capability family carried by the camera schema.
const String kCameraCapability = 'camera';

/// Capability for the expanded camera surface: bounds queries,
/// zoom-to-bounds, camera limits/reset and zoom configuration. Original
/// camera hosts advertise only [kCameraCapability]; these commands route to
/// legacy unless the host negotiated this capability at attach time.
const String kCameraConfigCapability = 'camera.config';

/// Capability family carried by the layers schema: tile-source selection
/// and overlay visibility. Hosts without this capability keep those
/// commands on their legacy routes.
const String kLayersCapability = 'layers';

/// Capability family carried by the shapes schema: circles and rectangles
/// (add/replace, removal by id, kind clears, full clear). Hosts without
/// this capability keep those commands on their legacy routes.
const String kShapesCapability = 'shapes';

/// Capability family carried by the roads schema: manual road drawing,
/// removal by id and clearing. Hosts without this capability keep those
/// commands on their legacy routes.
const String kRoadsCapability = 'roads';

/// Capability family carried by the location schema: the my-location
/// layer and single-shot fixes. Hosts without this capability keep those
/// commands on their legacy routes.
const String kLocationCapability = 'location';

/// Capability family carried by the continuous-updates schema. Hosts
/// without this capability keep those commands on their legacy routes.
const String kLocationUpdatesCapability = 'location.updates';

/// Capability family carried by the follow-me tracking schema. Hosts
/// without this capability keep `trackMe`/`deactivateTrackMe` on their
/// legacy routes.
const String kTrackingCapability = 'location.tracking';

/// Capability family carried by the user-location icon schema (person and
/// direction marker replacement). Hosts without this capability keep icon
/// replacement on their legacy `user#locationMarkers` route.
const String kLocationIconsCapability = 'location.icons';

/// Capability for optional tracking anchors. Hosts that advertise it accept
/// a null tracking anchor (keep the pivots the icon configuration already
/// has) on both the generated tracking route and the legacy `trackMe`
/// payload. Older hosts require a non-null anchor there — a null list slot
/// crashes their legacy decode and a null generated anchor fails their wire
/// decode — so clients fall back to the centered payload for them.
const String kTrackingOptionalAnchorCapability = 'location.tracking.anchor';

/// Capability family carried by the markers schema.
const String kMarkersCapability = 'markers';

/// Capability family carried by the native-to-Dart lifecycle event schema
/// (map readiness and restoration callbacks). Hosts without this capability
/// keep lifecycle events on the legacy `map#init` / `map#restored` method
/// channel messages. Attachments that never negotiate this route — older
/// hosts, non-opt-in applications and the JNI command plane — keep the
/// legacy event plane untouched.
const String kLifecycleEventsCapability = 'events.lifecycle';

/// Legacy-channel method name of the lifecycle event route selection.
///
/// Sent by the client during attachment, before initialization, only after
/// the bootstrap probe advertised [kLifecycleEventsCapability]. The payload
/// is `{sessionToken, generation, route}` with `route` one of
/// [kLifecycleEventsRoutePigeon] / [kLifecycleEventsRouteLegacy]; hosts
/// validate the session identity and answer `true`, or fail with
/// `stale_session` / `invalid_route`. Hosts default to the legacy route, so
/// exactly one delivery route is active per attachment.
const String kNativeLifecycleEventsRouteMethod = 'map#events#lifecycle#route';

/// Route value selecting the generated Pigeon lifecycle callbacks.
const String kLifecycleEventsRoutePigeon = 'pigeon';

/// Route value selecting the legacy method-channel lifecycle events.
const String kLifecycleEventsRouteLegacy = 'legacy';

/// Capability family carried by the native-to-Dart map-interaction event
/// schema (single-press and long-press callbacks). Hosts without this
/// capability keep interaction events on the legacy `receiveSinglePress` /
/// `receiveLongPress` method-channel messages. Attachments that never
/// negotiate this route — older hosts, non-opt-in applications and the JNI
/// command plane — keep the legacy event plane untouched.
const String kInteractionEventsCapability = 'events.interaction';

/// Legacy-channel method name of the interaction event route selection.
///
/// Same contract as [kNativeLifecycleEventsRouteMethod], scoped to the
/// `events.interaction` family: sent during attachment, before
/// initialization, only after the bootstrap probe advertised
/// [kInteractionEventsCapability]. The payload is
/// `{sessionToken, generation, route}` with `route` one of
/// [kInteractionEventsRoutePigeon] / [kInteractionEventsRouteLegacy].
const String kNativeInteractionEventsRouteMethod = 'map#events#interaction#route';

/// Route value selecting the generated Pigeon interaction callbacks.
const String kInteractionEventsRoutePigeon = 'pigeon';

/// Route value selecting the legacy method-channel interaction events.
const String kInteractionEventsRouteLegacy = 'legacy';

/// Capability family carried by the native-to-Dart marker interaction
/// event schema (marker single-press and long-press callbacks). Hosts
/// without this capability keep marker interactions on the legacy
/// `receiveGeoPoint` / `receiveGeoPointLongPress` method-channel messages.
/// Attachments that never negotiate this route — older hosts, non-opt-in
/// applications and the JNI command plane — keep the legacy event plane
/// untouched.
const String kMarkerEventsCapability = 'events.markers';

/// Legacy-channel method name of the marker interaction route selection.
///
/// Same contract as [kNativeLifecycleEventsRouteMethod], scoped to the
/// `events.markers` family.
const String kNativeMarkerEventsRouteMethod = 'map#events#markers#route';

/// Route value selecting the generated Pigeon marker callbacks.
const String kMarkerEventsRoutePigeon = 'pigeon';

/// Route value selecting the legacy method-channel marker events.
const String kMarkerEventsRouteLegacy = 'legacy';

/// Capability family carried by the native-to-Dart road tap event schema.
/// Hosts without this capability keep road taps on the legacy `receiveRoad`
/// method-channel message. Attachments that never negotiate this route —
/// older hosts, non-opt-in applications and the JNI command plane — keep
/// the legacy event plane untouched.
const String kRoadEventsCapability = 'events.roads';

/// Legacy-channel method name of the road tap route selection.
///
/// Same contract as [kNativeLifecycleEventsRouteMethod], scoped to the
/// `events.roads` family.
const String kNativeRoadEventsRouteMethod = 'map#events#roads#route';

/// Route value selecting the generated Pigeon road tap callback.
const String kRoadEventsRoutePigeon = 'pigeon';

/// Route value selecting the legacy method-channel road tap event.
const String kRoadEventsRouteLegacy = 'legacy';

/// Capability family carried by the native-to-Dart user-location event
/// schema (continuous location fixes with heading). Hosts without this
/// capability keep fixes on the legacy `receiveUserLocation` method-channel
/// message. Attachments that never negotiate this route — older hosts,
/// non-opt-in applications and the JNI command plane — keep the legacy
/// event plane untouched. The callback inherits the host's location rate
/// and coalescing; it only changes where fixes travel.
const String kLocationEventsCapability = 'events.location';

/// Legacy-channel method name of the user-location event route selection.
///
/// Same contract as [kNativeLifecycleEventsRouteMethod], scoped to the
/// `events.location` family.
const String kNativeLocationEventsRouteMethod = 'map#events#location#route';

/// Route value selecting the generated Pigeon user-location callback.
const String kLocationEventsRoutePigeon = 'pigeon';

/// Route value selecting the legacy method-channel user-location events.
const String kLocationEventsRouteLegacy = 'legacy';

/// Capability family carried by the native-to-Dart visible-region event
/// schema (center, bounding box and zoom of the visible region). Hosts
/// without this capability keep region changes on the legacy
/// `receiveRegionIsChanging` method-channel message. Attachments that never
/// negotiate this route — older hosts, non-opt-in applications and the JNI
/// command plane — keep the legacy event plane untouched. The callback
/// inherits the host's region-event rate and coalescing; it only changes
/// where changes travel.
const String kRegionEventsCapability = 'events.region';

/// Legacy-channel method name of the visible-region event route selection.
///
/// Same contract as [kNativeLifecycleEventsRouteMethod], scoped to the
/// `events.region` family.
const String kNativeRegionEventsRouteMethod = 'map#events#region#route';

/// Route value selecting the generated Pigeon visible-region callback.
const String kRegionEventsRoutePigeon = 'pigeon';

/// Route value selecting the legacy method-channel visible-region events.
const String kRegionEventsRouteLegacy = 'legacy';

/// Base of the event-route selection failures whose outcome is uncertain:
/// the selection timed out and a rollback to the legacy route could not be
/// confirmed, so the host's active delivery route is unknown. Freezing
/// either route could silently lose events, so attachment is aborted
/// instead; the caller may retry, which re-negotiates from a clean state.
abstract class RouteSelectionUncertainException implements Exception {
  const RouteSelectionUncertainException();
}

/// Per-map message-channel suffix for generated Pigeon routes.
///
/// Generated channel names become
/// `dev.flutter.pigeon.flutter_osm_interface.<Api>.<method>.view_<id>`,
/// keeping two live maps fully isolated.
String nativeChannelSuffix(int viewId) => 'view_$viewId';

/// Validated bootstrap payload for one map attachment.
@immutable
class NativeProtocolBootstrap {
  final int revision;
  final String schemaId;
  final List<String> capabilities;
  final String sessionToken;
  final int generation;

  const NativeProtocolBootstrap({
    required this.revision,
    required this.schemaId,
    required this.capabilities,
    required this.sessionToken,
    required this.generation,
  });

  /// Strict validation: malformed or mismatched payloads produce
  /// [NativeProtocolInvalid], never a silent fallback to legacy routing.
  static NativeProtocolProbeResult parse(Object? payload) {
    if (payload is! Map) {
      return NativeProtocolInvalid(reason: 'bootstrap payload is not a map');
    }
    final revision = payload['revision'];
    final schemaId = payload['schemaId'];
    final capabilities = payload['capabilities'];
    final sessionToken = payload['sessionToken'];
    final generation = payload['generation'];
    if (revision is! int) {
      return const NativeProtocolInvalid(reason: 'missing integer revision');
    }
    if (schemaId is! String || !schemaId.startsWith('flutter_osm.native.')) {
      return NativeProtocolInvalid(reason: 'unknown schemaId: $schemaId');
    }
    if (capabilities is! List || capabilities.any((c) => c is! String)) {
      return const NativeProtocolInvalid(reason: 'capabilities must be strings');
    }
    if (sessionToken is! String || sessionToken.isEmpty) {
      return const NativeProtocolInvalid(reason: 'missing sessionToken');
    }
    if (generation is! int) {
      return const NativeProtocolInvalid(reason: 'missing integer generation');
    }
    return NativeProtocolSupported(
      bootstrap: NativeProtocolBootstrap(
        revision: revision,
        schemaId: schemaId,
        capabilities: List<String>.unmodifiable(
          capabilities.cast<String>(),
        ),
        sessionToken: sessionToken,
        generation: generation,
      ),
    );
  }

  /// True when the advertised revision exactly matches this client.
  bool get isSupportedRevision => revision == kNativeProtocolRevision;

  bool advertises(String capability) => capabilities.contains(capability);

  @override
  String toString() => 'NativeProtocolBootstrap(revision: $revision, '
      'schemaId: $schemaId, capabilities: $capabilities)';
}

/// Outcome of the attach-time probe.
sealed class NativeProtocolProbeResult {
  const NativeProtocolProbeResult();
}

/// Host answered with a well-formed bootstrap payload.
class NativeProtocolSupported extends NativeProtocolProbeResult {
  final NativeProtocolBootstrap bootstrap;

  const NativeProtocolSupported({required this.bootstrap});
}

/// Host predates the probe (missing/not implemented): a supported legacy
/// selection, decided before any generated mutation is attempted.
class NativeProtocolLegacyHost extends NativeProtocolProbeResult {
  const NativeProtocolLegacyHost();
}

/// Host answered but the payload is malformed or from an unknown schema.
/// Never silently treated as an old-host compatibility case.
class NativeProtocolInvalid extends NativeProtocolProbeResult {
  final String reason;

  const NativeProtocolInvalid({required this.reason});

  @override
  String toString() => 'NativeProtocolInvalid($reason)';
}

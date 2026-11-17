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

/// Capability family carried by the markers schema.
const String kMarkersCapability = 'markers';

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

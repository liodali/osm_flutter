// Handwritten support facade over the generated native-to-Dart
// user-location event channel (continuous location fixes with heading).
//
// Mirrors the interaction family facade: applications never touch generated
// types. The route is selected once per map during attachment (see
// `attachLocationEventsRoute`), before initialization, and only exists when
// the host negotiated the `events.location` capability and accepted the
// `map#events#location#route` selection. Exactly one delivery route is
// active per attachment: while this client is registered, the host emits
// location fixes only through this callback and the platform channel drops
// legacy `receiveUserLocation` messages for the map.
//
// Delivery contract (carried from the schema): every callback carries the
// session identity and the fix as raw doubles — position in degrees and
// heading in degrees clockwise from true north, exactly the legacy payload's
// values with the host's full precision; callbacks whose token/generation
// does not match this attachment are stale (replaced or disposed view) and
// are dropped. The host owns the rate: the callback inherits the platform's
// location rate and coalescing unchanged, so this facade forwards every
// validated callback once and never buffers, throttles or coalesces itself.
import 'package:flutter/services.dart';

import 'native_map_camera.g.dart' as generated;

import 'native_camera_bootstrap.dart';

/// Thrown when the user-location event route negotiation ends in an
/// uncertain state: the selection timed out and a rollback to the legacy
/// route could not be confirmed. The host may already have switched to the
/// generated route, so silently falling back to legacy would unregister the
/// callback and lose every location fix. Attachment is aborted instead; the
/// caller may retry, which re-negotiates from a clean state.
class LocationRouteUncertainException
    extends RouteSelectionUncertainException {
  const LocationRouteUncertainException();

  @override
  String toString() => 'LocationRouteUncertainException: '
      'the user-location event route could not be negotiated safely; '
      'attachment was aborted rather than risking lost location fixes';
}

/// Selected generated user-location event route for one map attachment.
///
/// Registers the generated FlutterApi handler for the map's per-view channel
/// suffix and forwards validated callbacks through [onLocationChanged] with
/// the host's full precision. [dispose] removes the handler; late messages
/// then find no handler and are discarded by the engine.
class PigeonLocationEventsClient
    implements generated.NativeMapLocationEventsApi {
  /// Currently registered client per channel suffix. A stale client whose
  /// attachment was replaced must not unregister the replacement's handler
  /// when its late teardown runs, so disposal is identity-checked.
  static final Map<String, PigeonLocationEventsClient> _registered = {};

  final NativeProtocolBootstrap _bootstrap;
  final BinaryMessenger? _binaryMessenger;
  final String _channelSuffix;
  final void Function(double latitude, double longitude, double heading)
      _onLocationChanged;

  bool _disposed = false;

  PigeonLocationEventsClient({
    BinaryMessenger? binaryMessenger,
    required int viewId,
    required NativeProtocolBootstrap bootstrap,
    required void Function(double latitude, double longitude, double heading)
        onLocationChanged,
  })  : _bootstrap = bootstrap,
        _binaryMessenger = binaryMessenger,
        _channelSuffix = nativeChannelSuffix(viewId),
        _onLocationChanged = onLocationChanged {
    generated.NativeMapLocationEventsApi.setUp(
      this,
      binaryMessenger: binaryMessenger,
      messageChannelSuffix: _channelSuffix,
    );
    _registered[_channelSuffix] = this;
  }

  NativeProtocolBootstrap get bootstrap => _bootstrap;

  /// True while this client's handler is registered for the attachment.
  bool get isActive => !_disposed;

  @override
  void onLocationChanged(
    generated.NativeCameraSession session,
    double latitude,
    double longitude,
    double heading,
  ) {
    if (_disposed || !_matchesSession(session)) return;
    _onLocationChanged(latitude, longitude, heading);
  }

  bool _matchesSession(generated.NativeCameraSession session) =>
      session.sessionToken == _bootstrap.sessionToken &&
      session.generation == _bootstrap.generation;

  /// Removes this attachment's handler. Must run before a replacement
  /// attachment registers its own client on the same per-view channel;
  /// when a replacement already registered, this only marks the stale
  /// client inactive and leaves the live handler untouched.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (identical(_registered[_channelSuffix], this)) {
      _registered.remove(_channelSuffix);
      generated.NativeMapLocationEventsApi.setUp(
        null,
        binaryMessenger: _binaryMessenger,
        messageChannelSuffix: _channelSuffix,
      );
    }
  }
}

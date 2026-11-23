// Handwritten support facade over the generated native-to-Dart
// map-interaction event channel (single presses and long presses).
//
// Mirrors the lifecycle family facade: applications never touch generated
// types. The route is selected once per map during attachment (see
// `attachInteractionEventsRoute`), before initialization, and only exists
// when the host negotiated the `events.interaction` capability and accepted
// the `map#events#interaction#route` selection. Exactly one delivery route
// is active per attachment: while this client is registered, the host emits
// interaction events only through these callbacks and the platform channel
// drops legacy `receiveSinglePress` / `receiveLongPress` messages for the
// map.
//
// Delivery contract (carried from the schema): every callback carries the
// session identity; callbacks whose token/generation does not match this
// attachment are stale (replaced or disposed view) and are dropped.
// Interactions are discrete events: each occurrence is forwarded once and
// repeats are never coalesced. Coordinates cross the wire as doubles, so
// the host's full precision reaches the public streams without a map
// round-trip.
import 'package:flutter/services.dart';

import 'native_map_camera.g.dart' as generated;

import 'native_camera_bootstrap.dart';

/// Thrown when the interaction route negotiation ends in an uncertain
/// state: the selection timed out and a rollback to the legacy route could
/// not be confirmed. The host may already have switched to the generated
/// route, so silently falling back to legacy would unregister the callbacks
/// and lose every interaction event. Attachment is aborted instead; the
/// caller may retry, which re-negotiates from a clean state.
class InteractionRouteUncertainException
    extends RouteSelectionUncertainException {
  const InteractionRouteUncertainException();

  @override
  String toString() => 'InteractionRouteUncertainException: '
      'the interaction event route could not be negotiated safely; '
      'attachment was aborted rather than risking lost press events';
}

/// Selected generated interaction-event route for one map attachment.
///
/// Registers the generated FlutterApi handlers for the map's per-view
/// channel suffix and forwards validated callbacks through [onSinglePress]
/// / [onLongPress] with the host's full coordinate precision. [dispose]
/// removes the handlers; late messages then find no handler and are
/// discarded by the engine.
class PigeonInteractionEventsClient
    implements generated.NativeMapInteractionEventsApi {
  /// Currently registered client per channel suffix. A stale client whose
  /// attachment was replaced must not unregister the replacement's handlers
  /// when its late teardown runs, so disposal is identity-checked.
  static final Map<String, PigeonInteractionEventsClient> _registered = {};

  final NativeProtocolBootstrap _bootstrap;
  final BinaryMessenger? _binaryMessenger;
  final String _channelSuffix;
  final void Function(double latitude, double longitude) _onSinglePress;
  final void Function(double latitude, double longitude) _onLongPress;

  bool _disposed = false;

  PigeonInteractionEventsClient({
    BinaryMessenger? binaryMessenger,
    required int viewId,
    required NativeProtocolBootstrap bootstrap,
    required void Function(double latitude, double longitude) onSinglePress,
    required void Function(double latitude, double longitude) onLongPress,
  })  : _bootstrap = bootstrap,
        _binaryMessenger = binaryMessenger,
        _channelSuffix = nativeChannelSuffix(viewId),
        _onSinglePress = onSinglePress,
        _onLongPress = onLongPress {
    generated.NativeMapInteractionEventsApi.setUp(
      this,
      binaryMessenger: binaryMessenger,
      messageChannelSuffix: _channelSuffix,
    );
    _registered[_channelSuffix] = this;
  }

  NativeProtocolBootstrap get bootstrap => _bootstrap;

  /// True while this client's handlers are registered for the attachment.
  bool get isActive => !_disposed;

  @override
  void onSinglePress(
    generated.NativeCameraSession session,
    double latitude,
    double longitude,
  ) {
    if (_disposed || !_matchesSession(session)) return;
    _onSinglePress(latitude, longitude);
  }

  @override
  void onLongPress(
    generated.NativeCameraSession session,
    double latitude,
    double longitude,
  ) {
    if (_disposed || !_matchesSession(session)) return;
    _onLongPress(latitude, longitude);
  }

  bool _matchesSession(generated.NativeCameraSession session) =>
      session.sessionToken == _bootstrap.sessionToken &&
      session.generation == _bootstrap.generation;

  /// Removes this attachment's handlers. Must run before a replacement
  /// attachment registers its own client on the same per-view channels;
  /// when a replacement already registered, this only marks the stale
  /// client inactive and leaves the live handlers untouched.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (identical(_registered[_channelSuffix], this)) {
      _registered.remove(_channelSuffix);
      generated.NativeMapInteractionEventsApi.setUp(
        null,
        binaryMessenger: _binaryMessenger,
        messageChannelSuffix: _channelSuffix,
      );
    }
  }
}

// Handwritten support facade over the generated native-to-Dart lifecycle
// event channel (map readiness and restoration).
//
// Mirrors the other family facades: applications never touch generated
// types. The route is selected once per map during attachment (see
// `attachLifecycleEventsRoute`), before initialization, and only exists
// when the host negotiated the `events.lifecycle` capability and accepted
// the `map#events#lifecycle#route` selection. Exactly one delivery route is
// active per attachment: while this client is registered, the host emits
// lifecycle events only through these callbacks and the platform channel
// drops legacy `map#init` / `map#restored` messages for the map.
//
// Delivery contract (carried from the schema): every callback carries the
// session identity; callbacks whose token/generation does not match this
// attachment are stale (replaced or disposed view) and are dropped.
// Readiness reports state transitions: repeated identical values from the
// host are coalesced, so one initialization produces exactly one readiness
// delivery. Restoration is a discrete event and is always forwarded.
import 'package:flutter/services.dart';

import 'native_map_camera.g.dart' as generated;

import 'native_camera_bootstrap.dart';

/// Thrown when the lifecycle route negotiation ends in an uncertain state:
/// the selection timed out and a rollback to the legacy route could not be
/// confirmed. The host may already have switched to the generated route, so
/// silently falling back to legacy would unregister the callbacks and lose
/// every readiness/restoration event. Attachment is aborted instead; the
/// caller may retry, which re-negotiates from a clean state.
class LifecycleRouteUncertainException implements Exception {
  const LifecycleRouteUncertainException();

  @override
  String toString() => 'LifecycleRouteUncertainException: '
      'the lifecycle event route could not be negotiated safely; '
      'attachment was aborted rather than risking lost readiness events';
}

/// Selected generated lifecycle-event route for one map attachment.
///
/// Registers the generated FlutterApi handlers for the map's per-view
/// channel suffix and forwards validated callbacks through [onReady] /
/// [onRestored]. [dispose] removes the handlers; late messages then find no
/// handler and are discarded by the engine.
class PigeonLifecycleEventsClient
    implements generated.NativeMapLifecycleEventsApi {
  /// Currently registered client per channel suffix. A stale client whose
  /// attachment was replaced must not unregister the replacement's handlers
  /// when its late teardown runs, so disposal is identity-checked.
  static final Map<String, PigeonLifecycleEventsClient> _registered = {};

  final NativeProtocolBootstrap _bootstrap;
  final BinaryMessenger? _binaryMessenger;
  final String _channelSuffix;
  final void Function(bool isReady) _onReady;
  final void Function() _onRestored;

  bool _disposed = false;
  bool? _lastReady;

  PigeonLifecycleEventsClient({
    BinaryMessenger? binaryMessenger,
    required int viewId,
    required NativeProtocolBootstrap bootstrap,
    required void Function(bool isReady) onReady,
    required void Function() onRestored,
  })  : _bootstrap = bootstrap,
        _binaryMessenger = binaryMessenger,
        _channelSuffix = nativeChannelSuffix(viewId),
        _onReady = onReady,
        _onRestored = onRestored {
    generated.NativeMapLifecycleEventsApi.setUp(
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
  void onMapReady(generated.NativeCameraSession session, bool isReady) {
    if (_disposed || !_matchesSession(session)) return;
    // Exactly-once readiness per transition: hosts emit once per
    // initialization outcome, and a repeated identical value (e.g. a late
    // duplicate from a recomposed native view) never re-delivers.
    if (_lastReady == isReady) return;
    _lastReady = isReady;
    _onReady(isReady);
  }

  @override
  void onMapRestored(generated.NativeCameraSession session) {
    if (_disposed || !_matchesSession(session)) return;
    _onRestored();
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
      generated.NativeMapLifecycleEventsApi.setUp(
        null,
        binaryMessenger: _binaryMessenger,
        messageChannelSuffix: _channelSuffix,
      );
    }
  }
}

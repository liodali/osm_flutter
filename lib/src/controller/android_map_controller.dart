import 'dart:async';

import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/src/android_transport/android_map_transport.dart';
import 'package:flutter_osm_plugin/src/android_transport/android_transport_factory.dart';

/// Opt-in Android controller introduced alongside the legacy map controller.
///
/// JNI mutations are queued onto Android's main thread and complete from
/// MethodChannel acknowledgements. Backend fallback remains attach-only.
final class AndroidMapController extends BaseMapController
    implements AndroidMapPlatform {
  AndroidMapController.withPosition({
    required GeoPoint initPosition,
    this.backend = AndroidMapBackend.auto,
    BoundingBox areaLimit = const BoundingBox.world(),
    super.customTile,
    AndroidMapTransportFactory? transportFactory,
  })  : _transportFactory = transportFactory ?? createAndroidMapTransport,
        super(
          initMapWithUserPosition: null,
          initPosition: initPosition,
          areaLimit: areaLimit,
        ) {
    camera = AndroidMapCamera._(this);
    markers = AndroidMapMarkers._(this);
    // Prevent a disposal/attach failure from becoming an unhandled async error
    // when callers only await attach. Awaiting [ready] still receives it.
    _readyCompleter.future.ignore();
  }

  final AndroidMapTransportFactory _transportFactory;
  final Completer<void> _readyCompleter = Completer<void>();
  final StreamController<AndroidMapEvent> _events =
      StreamController<AndroidMapEvent>.broadcast(sync: true);

  AndroidMapTransport? _transport;
  StreamSubscription<AndroidMapEvent>? _transportEvents;
  Future<void>? _disposeFuture;
  int? _viewId;
  bool _attaching = false;
  bool _attachStarted = false;
  int _markerSequence = 0;

  late final AndroidMapCamera camera;
  late final AndroidMapMarkers markers;

  @override
  final AndroidMapBackend backend;

  @override
  AndroidMapBackend? get activeBackend => _transport?.backend;

  int? get viewId => _viewId;

  @override
  Future<void> get ready => _readyCompleter.future;

  @override
  Stream<AndroidMapEvent> get events => _events.stream;

  @override
  void init() {
    // Initialization is performed atomically by [attachAndroidMap]. The legacy
    // BaseMapController timer must not run without an IBaseOSMController.
  }

  @override
  Future<void> attachAndroidMap(int viewId) async {
    if (_disposeFuture != null) {
      throw AndroidMapException(
        operation: 'attach',
        code: 'controller_disposed',
        viewId: viewId,
      );
    }
    if (_attachStarted || _attaching || _viewId != null) {
      throw AndroidMapException(
        operation: 'attach',
        code: 'already_attached',
        viewId: _viewId ?? viewId,
      );
    }

    _attachStarted = true;
    _attaching = true;
    try {
      final candidates = backend == AndroidMapBackend.auto
          ? const [
              AndroidMapBackend.jni,
              AndroidMapBackend.methodChannel,
            ]
          : [backend];

      for (final candidateBackend in candidates) {
        AndroidMapTransport? candidate;
        try {
          candidate = _transportFactory(candidateBackend);
          await candidate.attach(viewId);
          if (_disposeFuture != null) {
            throw AndroidMapException(
              operation: 'attach',
              code: 'controller_disposed',
              viewId: viewId,
            );
          }
        } catch (error, stackTrace) {
          await candidate?.close();
          final exception = _asException(
            error,
            operation: 'attach',
            viewId: viewId,
          );
          final mayFallback = _disposeFuture == null &&
              backend == AndroidMapBackend.auto &&
              candidateBackend == AndroidMapBackend.jni;
          if (mayFallback) {
            continue;
          }
          _completeReadyError(exception, stackTrace);
          throw exception;
        }

        _transport = candidate;
        _viewId = viewId;
        _transportEvents = candidate.events.listen(
          _onTransportEvent,
          onError: _onTransportError,
        );

        try {
          await candidate.initialize(initialPosition: initPosition!);
          return;
        } catch (error, stackTrace) {
          // Initialization is the first state-changing command. Never replay
          // it through another backend after it has been attempted.
          final exception = _asException(
            error,
            operation: 'initialize',
            viewId: viewId,
          );
          await _releaseTransport();
          _completeReadyError(exception, stackTrace);
          throw exception;
        }
      }

      final exception = AndroidMapException(
        operation: 'attach',
        code: 'no_backend_available',
        viewId: viewId,
      );
      _completeReadyError(exception, StackTrace.current);
      throw exception;
    } finally {
      _attaching = false;
    }
  }

  void _onTransportEvent(AndroidMapEvent event) {
    if (event.viewId != _viewId || _disposeFuture != null) {
      return;
    }
    _events.add(event);
    switch (event) {
      case AndroidMapReady(:final isReady):
        if (isReady && !_readyCompleter.isCompleted) {
          _readyCompleter.complete();
        }
        break;
      case AndroidMapError(:final error):
        _completeReadyError(error, StackTrace.current);
        break;
      default:
        break;
    }
  }

  void _onTransportError(Object error, StackTrace stackTrace) {
    final viewId = _viewId;
    if (viewId == null || _disposeFuture != null) return;
    final exception = _asException(
      error,
      operation: 'event',
      viewId: viewId,
    );
    _onTransportEvent(AndroidMapError(viewId: viewId, error: exception));
    _completeReadyError(exception, stackTrace);
  }

  AndroidMapException _asException(
    Object error, {
    required String operation,
    required int viewId,
  }) {
    if (error is AndroidMapException) return error;
    return AndroidMapException(
      operation: operation,
      code: 'transport_error',
      viewId: viewId,
      cause: error,
    );
  }

  void _completeReadyError(Object error, StackTrace stackTrace) {
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.completeError(error, stackTrace);
    }
  }

  Future<AndroidMapTransport> _readyTransport() async {
    await ready;
    final transport = _transport;
    if (transport == null || _disposeFuture != null) {
      throw AndroidMapException(
        operation: 'command',
        code: 'controller_disposed',
        viewId: _viewId,
      );
    }
    return transport;
  }

  MarkerId _nextMarkerId() =>
      MarkerId('android-${_viewId ?? 'pending'}-${_markerSequence++}');

  Future<void> _releaseTransport() async {
    await _transportEvents?.cancel();
    _transportEvents = null;
    await _transport?.close();
    _transport = null;
    _viewId = null;
  }

  Future<void> close() => dispose();

  @override
  Future<void> dispose() {
    final existing = _disposeFuture;
    if (existing != null) return existing;
    super.dispose();
    return _disposeFuture = _dispose();
  }

  Future<void> _dispose() async {
    _completeReadyError(
      AndroidMapException(
        operation: 'dispose',
        code: 'controller_disposed',
        viewId: _viewId,
      ),
      StackTrace.current,
    );
    await _releaseTransport();
    await _events.close();
  }
}

/// Typed camera capability for [AndroidMapController].
final class AndroidMapCamera {
  AndroidMapCamera._(this._controller);

  final AndroidMapController _controller;

  Future<void> moveTo(GeoPoint position, {bool animated = false}) async {
    final transport = await _controller._readyTransport();
    await transport.moveTo(position, animated: animated);
  }

  Future<void> setZoom(double zoom) async {
    final transport = await _controller._readyTransport();
    await transport.setZoom(zoom);
  }

  Future<double> getZoom() async {
    final transport = await _controller._readyTransport();
    return transport.getZoom();
  }

  Future<void> setRotation(double angle, {bool animated = true}) async {
    final transport = await _controller._readyTransport();
    await transport.setRotation(angle, animated: animated);
  }
}

/// Stable-ID marker capability for [AndroidMapController].
final class AndroidMapMarkers {
  AndroidMapMarkers._(this._controller);

  final AndroidMapController _controller;
  final Set<MarkerId> _issuedIds = {};

  Future<MarkerId> add(GeoPoint position, {MarkerId? markerId}) async {
    final id = markerId ?? _controller._nextMarkerId();
    if (!_issuedIds.add(id)) {
      throw AndroidMapException(
        operation: 'addMarker',
        code: 'duplicate_marker_id',
        viewId: _controller.viewId,
        message: 'Marker ID ${id.value} was already issued by this controller.',
      );
    }
    try {
      final transport = await _controller._readyTransport();
      await transport.addMarker(id, position);
      return id;
    } catch (_) {
      _issuedIds.remove(id);
      rethrow;
    }
  }

  Future<void> remove(MarkerId markerId) async {
    final transport = await _controller._readyTransport();
    await transport.removeMarker(markerId);
    _issuedIds.remove(markerId);
  }
}

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/src/android_jni/generated.dart';
import 'package:flutter_osm_plugin/src/android_transport/android_event_decoder.dart';
import 'package:flutter_osm_plugin/src/android_transport/android_map_transport.dart';
import 'package:jni/jni.dart';

/// JNI command transport with MethodChannel acknowledgements and events.
///
/// Backend selection is completed by [attach]. Every mutation is then queued
/// once through JNI and acknowledged after it executes on Android's main thread;
/// failed commands are never replayed through MethodChannel.
final class JniAndroidMapTransport implements AndroidMapTransport {
  static const _commandTimeout = Duration(seconds: 15);

  final StreamController<AndroidMapEvent> _events =
      StreamController<AndroidMapEvent>.broadcast(sync: true);
  final Map<String, Completer<void>> _pending = {};

  OsmAndroidBridge? _bridge;
  MethodChannel? _eventChannel;
  int? _viewId;
  int _requestSequence = 0;
  bool _closed = false;

  @override
  AndroidMapBackend get backend => AndroidMapBackend.jni;

  @override
  Stream<AndroidMapEvent> get events => _events.stream;

  @override
  Future<void> attach(int viewId) async {
    if (_closed) {
      throw AndroidMapException(
        operation: 'attach',
        code: 'transport_closed',
        viewId: viewId,
      );
    }
    if (_bridge != null) {
      throw AndroidMapException(
        operation: 'attach',
        code: 'already_attached',
        viewId: _viewId,
      );
    }

    OsmAndroidBridge? bridge;
    try {
      bridge = OsmAndroidBridge();
      final ping = bridge.ping().toDartString(releaseOriginal: true);
      if (ping != 'osm-jni-ok') {
        throw StateError('Unexpected JNI bridge response: $ping');
      }

      final eventChannel = MethodChannel('plugins.dali.hamza/osmview_$viewId');
      eventChannel.setMethodCallHandler(_handleMethodCall);
      if (!bridge.attach(viewId)) {
        eventChannel.setMethodCallHandler(null);
        throw StateError('Native map session $viewId is unavailable');
      }

      _bridge = bridge;
      _eventChannel = eventChannel;
      _viewId = viewId;
    } catch (error) {
      bridge?.release();
      throw _exception(
        error,
        operation: 'attach',
        code: 'jni_attach_failed',
        viewId: viewId,
      );
    }
  }

  @override
  Future<void> initialize({required GeoPoint initialPosition}) =>
      _enqueue('initialize', (bridge, viewId, requestId) {
        return bridge.initialize(
          viewId,
          initialPosition.latitude,
          initialPosition.longitude,
          requestId,
        );
      });

  @override
  Future<void> moveTo(GeoPoint position, {required bool animated}) =>
      _enqueue('moveTo', (bridge, viewId, requestId) {
        return bridge.moveTo(
          viewId,
          position.latitude,
          position.longitude,
          animated,
          requestId,
        );
      });

  @override
  Future<void> setZoom(double zoom) =>
      _enqueue('setZoom', (bridge, viewId, requestId) {
        return bridge.setZoom(viewId, zoom, requestId);
      });

  @override
  Future<double> getZoom() async {
    final (bridge, viewId) = _requireAttached('getZoom');
    try {
      final zoom = bridge.getZoom(viewId);
      if (zoom.isNaN) {
        throw const FormatException('Native camera snapshot is unavailable');
      }
      return zoom;
    } catch (error) {
      throw _exception(
        error,
        operation: 'getZoom',
        code: 'jni_query_failed',
        viewId: viewId,
      );
    }
  }

  @override
  Future<void> setRotation(double angle, {required bool animated}) =>
      _enqueue('setRotation', (bridge, viewId, requestId) {
        return bridge.setRotation(viewId, angle, animated, requestId);
      });

  @override
  Future<void> addMarker(MarkerId markerId, GeoPoint position) =>
      _enqueue('addMarker', (bridge, viewId, requestId) {
        final nativeMarkerId = markerId.value.toJString();
        try {
          return bridge.addMarker(
            viewId,
            nativeMarkerId,
            position.latitude,
            position.longitude,
            requestId,
          );
        } finally {
          nativeMarkerId.release();
        }
      });

  @override
  Future<void> removeMarker(MarkerId markerId) =>
      _enqueue('removeMarker', (bridge, viewId, requestId) {
        final nativeMarkerId = markerId.value.toJString();
        try {
          return bridge.removeMarker(viewId, nativeMarkerId, requestId);
        } finally {
          nativeMarkerId.release();
        }
      });

  Future<void> _enqueue(
    String operation,
    bool Function(OsmAndroidBridge bridge, int viewId, JString requestId)
        command,
  ) async {
    final (bridge, viewId) = _requireAttached(operation);
    final requestId = '$viewId-${_requestSequence++}';
    final completer = Completer<void>();
    _pending[requestId] = completer;
    final nativeRequestId = requestId.toJString();
    try {
      final accepted = command(bridge, viewId, nativeRequestId);
      if (!accepted) {
        throw StateError('Native map session rejected the command queue');
      }
    } catch (error, stackTrace) {
      _pending.remove(requestId);
      final exception = _exception(
        error,
        operation: operation,
        code: 'jni_command_rejected',
        viewId: viewId,
      );
      completer.completeError(exception, stackTrace);
    } finally {
      nativeRequestId.release();
    }
    return completer.future.timeout(
      _commandTimeout,
      onTimeout: () {
        _pending.remove(requestId);
        throw AndroidMapException(
          operation: operation,
          code: 'command_timeout',
          viewId: viewId,
          message: 'Native command acknowledgement was not received.',
        );
      },
    );
  }

  Future<bool> _handleMethodCall(MethodCall call) async {
    final viewId = _viewId;
    if (viewId == null || _closed) return false;
    final event = decodeAndroidMapEvent(viewId, call);
    if (event == null) return false;

    switch (event) {
      case AndroidMapAcknowledgement(:final requestId):
        _pending.remove(requestId)?.complete();
        break;
      case AndroidMapError(:final requestId, :final error):
        if (requestId != null) {
          _pending.remove(requestId)?.completeError(error, StackTrace.current);
        }
        break;
      default:
        break;
    }
    _events.add(event);
    return true;
  }

  (OsmAndroidBridge, int) _requireAttached(String operation) {
    final bridge = _bridge;
    final viewId = _viewId;
    if (_closed || bridge == null || viewId == null) {
      throw AndroidMapException(
        operation: operation,
        code: 'not_attached',
        viewId: viewId,
      );
    }
    return (bridge, viewId);
  }

  AndroidMapException _exception(
    Object error, {
    required String operation,
    required String code,
    required int viewId,
  }) {
    if (error is AndroidMapException) return error;
    return AndroidMapException(
      operation: operation,
      code: code,
      viewId: viewId,
      message: error.toString(),
      cause: error,
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final bridge = _bridge;
    final viewId = _viewId;
    _bridge = null;
    _viewId = null;

    _eventChannel?.setMethodCallHandler(null);
    _eventChannel = null;

    final error = AndroidMapException(
      operation: 'close',
      code: 'transport_closed',
      viewId: viewId,
    );
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pending.clear();

    if (bridge != null) {
      try {
        if (viewId != null) bridge.close(viewId);
      } finally {
        bridge.release();
      }
    }
    await _events.close();
  }
}

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
  final Map<int, void Function(AndroidMapException)>
      _pendingChannelInvocations = {};

  OsmAndroidBridge? _bridge;
  MethodChannel? _eventChannel;
  int? _viewId;
  int _requestSequence = 0;
  int _channelInvocationSequence = 0;
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
  Future<void> addMarker(
    MarkerId markerId,
    GeoPoint position, {
    Uint8List? iconBytes,
  }) =>
      _enqueue('addMarker', (bridge, viewId, requestId) {
        final nativeMarkerId = markerId.value.toJString();
        final nativeIcon = iconBytes == null ? null : _byteArray(iconBytes);
        try {
          return bridge.addMarker(
            viewId,
            nativeMarkerId,
            position.latitude,
            position.longitude,
            nativeIcon,
            requestId,
          );
        } finally {
          nativeMarkerId.release();
          nativeIcon?.release();
        }
      });

  @override
  Future<void> addMarkers(Map<MarkerId, GeoPoint> markers) =>
      _enqueue('addMarkers', (bridge, viewId, requestId) {
        final nativeIds = _stringArray(
          markers.keys.map((markerId) => markerId.value),
        );
        final coordinates = JDoubleArray.of([
          for (final point in markers.values) ...[
            point.latitude,
            point.longitude,
          ],
        ]);
        try {
          return bridge.addMarkers(
            viewId,
            nativeIds.array,
            coordinates,
            requestId,
          );
        } finally {
          nativeIds.release();
          coordinates.release();
        }
      });

  @override
  Future<void> updateMarkerIcon(
    MarkerId markerId,
    Uint8List iconBytes,
  ) =>
      _enqueue('updateMarkerIcon', (bridge, viewId, requestId) {
        final nativeMarkerId = markerId.value.toJString();
        final nativeIcon = _byteArray(iconBytes);
        try {
          return bridge.updateMarkerIcon(
            viewId,
            nativeMarkerId,
            nativeIcon,
            requestId,
          );
        } finally {
          nativeMarkerId.release();
          nativeIcon.release();
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

  @override
  Future<void> removeMarkers(Iterable<MarkerId> markerIds) =>
      _enqueue('removeMarkers', (bridge, viewId, requestId) {
        final nativeIds = _stringArray(
          markerIds.map((markerId) => markerId.value),
        );
        try {
          return bridge.removeMarkers(viewId, nativeIds.array, requestId);
        } finally {
          nativeIds.release();
        }
      });

  @override
  Future<void> addCircle({
    required ShapeId shapeId,
    required GeoPoint center,
    required double radius,
    required int fillColor,
    required int borderColor,
    required double strokeWidth,
  }) =>
      _enqueue('addCircle', (bridge, viewId, requestId) {
        final nativeShapeId = shapeId.value.toJString();
        try {
          return bridge.addCircle(
            viewId,
            nativeShapeId,
            center.latitude,
            center.longitude,
            radius,
            fillColor,
            borderColor,
            strokeWidth,
            requestId,
          );
        } finally {
          nativeShapeId.release();
        }
      });

  @override
  Future<void> addRectangle({
    required ShapeId shapeId,
    required GeoPoint center,
    required double distance,
    required int fillColor,
    required int borderColor,
    required double strokeWidth,
  }) =>
      _enqueue('addRectangle', (bridge, viewId, requestId) {
        final nativeShapeId = shapeId.value.toJString();
        try {
          return bridge.addRectangle(
            viewId,
            nativeShapeId,
            center.latitude,
            center.longitude,
            distance,
            fillColor,
            borderColor,
            strokeWidth,
            requestId,
          );
        } finally {
          nativeShapeId.release();
        }
      });

  @override
  Future<void> removeShape(ShapeId shapeId) =>
      _enqueue('removeShape', (bridge, viewId, requestId) {
        final nativeShapeId = shapeId.value.toJString();
        try {
          return bridge.removeShape(viewId, nativeShapeId, requestId);
        } finally {
          nativeShapeId.release();
        }
      });

  @override
  Future<void> clearShapes() =>
      _enqueue('clearShapes', (bridge, viewId, requestId) {
        return bridge.clearShapes(viewId, requestId);
      });

  @override
  Future<void> setStaticPositions(
    StaticPositionId groupId,
    List<GeoPoint> positions, {
    Uint8List? iconBytes,
  }) =>
      _enqueue('setStaticPositions', (bridge, viewId, requestId) {
        final nativeGroupId = groupId.value.toJString();
        final coordinates = JDoubleArray.of([
          for (final point in positions) ...[
            point.latitude,
            point.longitude,
            point is GeoPointWithOrientation ? point.angle : 0.0,
          ],
        ]);
        final nativeIcon = iconBytes == null ? null : _byteArray(iconBytes);
        try {
          return bridge.setStaticPositions(
            viewId,
            nativeGroupId,
            coordinates,
            nativeIcon,
            requestId,
          );
        } finally {
          nativeGroupId.release();
          coordinates.release();
          nativeIcon?.release();
        }
      });

  @override
  Future<void> removeStaticPositions(StaticPositionId groupId) =>
      _enqueue('removeStaticPositions', (bridge, viewId, requestId) {
        final nativeGroupId = groupId.value.toJString();
        try {
          return bridge.removeStaticPositions(
            viewId,
            nativeGroupId,
            requestId,
          );
        } finally {
          nativeGroupId.release();
        }
      });

  @override
  Future<void> drawRoad(
    RoadId roadId,
    List<GeoPoint> geometry,
    RoadOption option,
  ) =>
      _enqueue('drawRoad', (bridge, viewId, requestId) {
        final nativeRoadId = roadId.value.toJString();
        final coordinates = JDoubleArray.of([
          for (final point in geometry) ...[
            point.latitude,
            point.longitude,
          ],
        ]);
        try {
          return bridge.drawRoad(
            viewId,
            nativeRoadId,
            coordinates,
            _signedArgb(option.roadColor.toARGB32()),
            option.roadWidth,
            _signedArgb(
              (option.roadBorderColor ?? option.roadColor).toARGB32(),
            ),
            option.roadBorderWidth ?? 0.0,
            option.zoomInto,
            option.isDotted,
            requestId,
          );
        } finally {
          nativeRoadId.release();
          coordinates.release();
        }
      });

  @override
  Future<void> removeRoad(RoadId roadId) =>
      _enqueue('removeRoad', (bridge, viewId, requestId) {
        final nativeRoadId = roadId.value.toJString();
        try {
          return bridge.removeRoad(viewId, nativeRoadId, requestId);
        } finally {
          nativeRoadId.release();
        }
      });

  @override
  Future<void> clearRoads() =>
      _enqueue('clearRoads', (bridge, viewId, requestId) {
        return bridge.clearRoads(viewId, requestId);
      });

  @override
  Future<void> setTile(CustomTile? tile) =>
      _enqueue('setTile', (bridge, viewId, requestId) {
        if (tile == null) return bridge.resetTile(viewId, requestId);
        final styleUrl = tile.styleURL;
        if (styleUrl != null) {
          final nativeStyleUrl = styleUrl.toJString();
          final nativeSourceName = tile.sourceName.toJString();
          try {
            return bridge.setVectorTile(
              viewId,
              nativeStyleUrl,
              nativeSourceName,
              tile.minZoomLevel,
              tile.maxZoomLevel,
              requestId,
            );
          } finally {
            nativeStyleUrl.release();
            nativeSourceName.release();
          }
        }

        final url = tile.urlsServers.first.toMapAndroid().first.toJString();
        final sourceName = tile.sourceName.toJString();
        final extension = tile.tileExtension.toJString();
        final apiKey = (tile.keyApi?.key ?? '').toJString();
        final apiValue = (tile.keyApi?.value ?? '').toJString();
        try {
          return bridge.setRasterTile(
            viewId,
            url,
            sourceName,
            extension,
            tile.minZoomLevel,
            tile.maxZoomLevel,
            apiKey,
            apiValue,
            requestId,
          );
        } finally {
          url.release();
          sourceName.release();
          extension.release();
          apiKey.release();
          apiValue.release();
        }
      });

  @override
  Future<void> setOverlaysVisible(bool visible) =>
      _enqueue('setOverlaysVisible', (bridge, viewId, requestId) {
        return bridge.setOverlaysVisible(viewId, visible, requestId);
      });

  @override
  Future<void> showCurrentLocation() => _invokeChannelVoid(
        'showCurrentLocation',
        'android#location#show',
      );

  @override
  Future<GeoPoint> getCurrentLocation() async {
    final value = await _invokeChannelValue<Map>(
      'getCurrentLocation',
      'android#location#get',
    );
    return GeoPoint.fromMap(value);
  }

  @override
  Future<void> startLocationUpdates() => _invokeChannelVoid(
        'startLocationUpdates',
        'android#location#updates#start',
      );

  @override
  Future<void> stopLocationUpdates() => _invokeChannelVoid(
        'stopLocationUpdates',
        'android#location#updates#stop',
      );

  @override
  Future<void> startLocationTracking({
    required bool stopFollowOnDrag,
    required bool disableMarkerRotation,
    required bool useDirectionMarker,
    required Anchor anchor,
  }) =>
      _invokeChannelVoid(
        'startLocationTracking',
        'android#location#tracking#start',
        {
          'stopFollowOnDrag': stopFollowOnDrag,
          'disableMarkerRotation': disableMarkerRotation,
          'useDirectionMarker': useDirectionMarker,
          'anchor': anchor.toMap(),
        },
      );

  @override
  Future<void> stopLocationTracking() => _invokeChannelVoid(
        'stopLocationTracking',
        'android#location#tracking#stop',
      );

  Future<void> _invokeChannelVoid(
    String operation,
    String method, [
    Object? arguments,
  ]) =>
      _trackChannelInvocation(operation, () async {
        final channel = _requireEventChannel(operation);
        try {
          await channel.invokeMethod<void>(method, arguments);
        } on PlatformException catch (error) {
          throw _channelException(operation, error);
        } on MissingPluginException catch (error) {
          throw AndroidMapException(
            operation: operation,
            code: 'missing_plugin',
            viewId: _viewId,
            message: error.message,
            cause: error,
          );
        }
      });

  Future<T> _invokeChannelValue<T>(
    String operation,
    String method, [
    Object? arguments,
  ]) =>
      _trackChannelInvocation(operation, () async {
        final channel = _requireEventChannel(operation);
        try {
          final value = await channel.invokeMethod<T>(method, arguments);
          if (value == null) {
            throw AndroidMapException(
              operation: operation,
              code: 'null_result',
              viewId: _viewId,
            );
          }
          return value;
        } on PlatformException catch (error) {
          throw _channelException(operation, error);
        } on MissingPluginException catch (error) {
          throw AndroidMapException(
            operation: operation,
            code: 'missing_plugin',
            viewId: _viewId,
            message: error.message,
            cause: error,
          );
        }
      });

  Future<T> _trackChannelInvocation<T>(
    String operation,
    Future<T> Function() invoke,
  ) {
    final invocationId = _channelInvocationSequence++;
    final completer = Completer<T>();
    _pendingChannelInvocations[invocationId] = (error) {
      if (!completer.isCompleted) {
        completer.completeError(
          AndroidMapException(
            operation: operation,
            code: error.code,
            viewId: error.viewId,
            message: error.message,
            cause: error,
          ),
        );
      }
    };
    Future<T>.sync(invoke).then(
      (value) {
        _pendingChannelInvocations.remove(invocationId);
        if (!completer.isCompleted) completer.complete(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        _pendingChannelInvocations.remove(invocationId);
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      },
    );
    return completer.future;
  }

  MethodChannel _requireEventChannel(String operation) {
    final channel = _eventChannel;
    if (_closed || channel == null || _viewId == null) {
      throw AndroidMapException(
        operation: operation,
        code: 'not_attached',
        viewId: _viewId,
      );
    }
    return channel;
  }

  AndroidMapException _channelException(
    String operation,
    PlatformException error,
  ) =>
      AndroidMapException(
        operation: operation,
        code: error.code,
        viewId: _viewId,
        message: error.message,
        cause: error,
      );

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
    final channelCancellations =
        _pendingChannelInvocations.values.toList(growable: false);
    _pendingChannelInvocations.clear();
    for (final cancel in channelCancellations) {
      cancel(error);
    }

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

final class _NativeStringArray {
  _NativeStringArray(this.array, this._values);

  final JArray<JString> array;
  final List<JString> _values;

  void release() {
    try {
      array.release();
    } finally {
      for (final value in _values) {
        value.release();
      }
    }
  }
}

_NativeStringArray _stringArray(Iterable<String> values) {
  final nativeValues = values.map((value) => value.toJString()).toList();
  try {
    return _NativeStringArray(
      JArray.of(JString.type, nativeValues),
      nativeValues,
    );
  } catch (_) {
    for (final value in nativeValues) {
      value.release();
    }
    rethrow;
  }
}

JByteArray _byteArray(Uint8List bytes) =>
    JByteArray.of(bytes.map((value) => value > 127 ? value - 256 : value));

int _signedArgb(int value) => value > 0x7fffffff ? value - 0x100000000 : value;

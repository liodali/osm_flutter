import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';

/// Typed compatibility transport over the existing per-view channel.
final class MethodChannelAndroidMapTransport implements AndroidMapTransport {
  final StreamController<AndroidMapEvent> _events =
      StreamController<AndroidMapEvent>.broadcast(sync: true);

  MethodChannel? _channel;
  int? _viewId;
  int _invocationSequence = 0;
  final Map<int, void Function(AndroidMapException)> _pendingInvocations = {};
  bool _closed = false;

  @override
  AndroidMapBackend get backend => AndroidMapBackend.methodChannel;

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
    if (_channel != null) {
      throw AndroidMapException(
        operation: 'attach',
        code: 'already_attached',
        viewId: _viewId,
      );
    }

    _viewId = viewId;
    _channel = MethodChannel('plugins.dali.hamza/osmview_$viewId');
    _channel!.setMethodCallHandler(_handleMethodCall);
  }

  @override
  Future<void> initialize({required GeoPoint initialPosition}) =>
      _invokeVoid('initialize', 'initMap', initialPosition.toMap());

  @override
  Future<void> moveTo(GeoPoint position, {required bool animated}) =>
      _invokeVoid('moveTo', 'moveTo#position', {
        ...position.toMap(),
        'animate': animated,
      });

  @override
  Future<void> setZoom(double zoom) =>
      _invokeVoid('setZoom', 'android#camera#zoom', zoom);

  @override
  Future<double> getZoom() async {
    final value = await _invokeValue<num>('getZoom', 'get#Zoom');
    return value.toDouble();
  }

  @override
  Future<void> setRotation(double angle, {required bool animated}) =>
      _invokeVoid('setRotation', 'android#camera#rotation', {
        'angle': angle,
        'animated': animated,
      });

  @override
  Future<void> addMarker(
    MarkerId markerId,
    GeoPoint position, {
    Uint8List? iconBytes,
  }) =>
      _invokeVoid('addMarker', 'android#marker#add', {
        'markerId': markerId.value,
        'lat': position.latitude,
        'lon': position.longitude,
        if (iconBytes != null) 'icon': iconBytes,
      });

  @override
  Future<void> addMarkers(Map<MarkerId, GeoPoint> markers) =>
      _invokeVoid('addMarkers', 'android#marker#addAll', {
        'markerIds': markers.keys.map((id) => id.value).toList(),
        'coordinates': [
          for (final point in markers.values) ...[
            point.latitude,
            point.longitude,
          ],
        ],
      });

  @override
  Future<void> updateMarkerIcon(
    MarkerId markerId,
    Uint8List iconBytes,
  ) =>
      _invokeVoid('updateMarkerIcon', 'android#marker#icon', {
        'markerId': markerId.value,
        'icon': iconBytes,
      });

  @override
  Future<void> removeMarker(MarkerId markerId) =>
      _invokeVoid('removeMarker', 'android#marker#remove', markerId.value);

  @override
  Future<void> removeMarkers(Iterable<MarkerId> markerIds) => _invokeVoid(
        'removeMarkers',
        'android#marker#removeAll',
        markerIds.map((id) => id.value).toList(),
      );

  @override
  Future<void> addCircle({
    required ShapeId shapeId,
    required GeoPoint center,
    required double radius,
    required int fillColor,
    required int borderColor,
    required double strokeWidth,
  }) =>
      _invokeVoid('addCircle', 'android#shape#circle', {
        'shapeId': shapeId.value,
        'lat': center.latitude,
        'lon': center.longitude,
        'size': radius,
        'fillColor': fillColor,
        'borderColor': borderColor,
        'strokeWidth': strokeWidth,
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
      _invokeVoid('addRectangle', 'android#shape#rectangle', {
        'shapeId': shapeId.value,
        'lat': center.latitude,
        'lon': center.longitude,
        'size': distance,
        'fillColor': fillColor,
        'borderColor': borderColor,
        'strokeWidth': strokeWidth,
      });

  @override
  Future<void> removeShape(ShapeId shapeId) =>
      _invokeVoid('removeShape', 'android#shape#remove', shapeId.value);

  @override
  Future<void> clearShapes() =>
      _invokeVoid('clearShapes', 'android#shape#clear');

  @override
  Future<void> setStaticPositions(
    StaticPositionId groupId,
    List<GeoPoint> positions, {
    Uint8List? iconBytes,
  }) =>
      _invokeVoid('setStaticPositions', 'android#static#set', {
        'groupId': groupId.value,
        'coordinates': [
          for (final point in positions) ...[
            point.latitude,
            point.longitude,
            point is GeoPointWithOrientation ? point.angle : 0.0,
          ],
        ],
        if (iconBytes != null) 'icon': iconBytes,
      });

  @override
  Future<void> removeStaticPositions(StaticPositionId groupId) => _invokeVoid(
        'removeStaticPositions',
        'android#static#remove',
        groupId.value,
      );

  @override
  Future<void> drawRoad(
    RoadId roadId,
    List<GeoPoint> geometry,
    RoadOption option,
  ) =>
      _invokeVoid('drawRoad', 'android#road#draw', {
        'roadId': roadId.value,
        'coordinates': [
          for (final point in geometry) ...[
            point.latitude,
            point.longitude,
          ],
        ],
        'roadColor': _signedArgb(option.roadColor.toARGB32()),
        'roadWidth': option.roadWidth,
        'borderColor': _signedArgb(
          (option.roadBorderColor ?? option.roadColor).toARGB32(),
        ),
        'borderWidth': option.roadBorderWidth ?? 0.0,
        'zoomInto': option.zoomInto,
        'dotted': option.isDotted,
      });

  @override
  Future<void> removeRoad(RoadId roadId) =>
      _invokeVoid('removeRoad', 'android#road#remove', roadId.value);

  @override
  Future<void> clearRoads() => _invokeVoid('clearRoads', 'android#road#clear');

  @override
  Future<void> setTile(CustomTile? tile) =>
      _invokeVoid('setTile', 'android#tile#set', tile?.toMap());

  @override
  Future<void> setOverlaysVisible(bool visible) =>
      _invokeVoid('setOverlaysVisible', 'android#layer#visibility', visible);

  @override
  Future<void> showCurrentLocation() => _invokeVoid(
        'showCurrentLocation',
        'android#location#show',
      );

  @override
  Future<GeoPoint> getCurrentLocation() async {
    final value = await _invokeValue<Map>(
      'getCurrentLocation',
      'android#location#get',
    );
    return GeoPoint.fromMap(value);
  }

  @override
  Future<void> startLocationUpdates() => _invokeVoid(
        'startLocationUpdates',
        'android#location#updates#start',
      );

  @override
  Future<void> stopLocationUpdates() => _invokeVoid(
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
      _invokeVoid('startLocationTracking', 'android#location#tracking#start', {
        'stopFollowOnDrag': stopFollowOnDrag,
        'disableMarkerRotation': disableMarkerRotation,
        'useDirectionMarker': useDirectionMarker,
        'anchor': anchor.toMap(),
      });

  @override
  Future<void> stopLocationTracking() => _invokeVoid(
        'stopLocationTracking',
        'android#location#tracking#stop',
      );

  Future<bool> _handleMethodCall(MethodCall call) async {
    final viewId = _viewId;
    if (viewId == null || _closed) return false;
    final event = decodeAndroidMapEvent(viewId, call);
    if (event != null) _events.add(event);
    return event != null;
  }

  Future<void> _invokeVoid(
    String operation,
    String method, [
    Object? arguments,
  ]) =>
      _trackInvocation(operation, () async {
        final channel = _requireChannel(operation);
        try {
          await channel.invokeMethod<void>(method, arguments);
        } on PlatformException catch (error) {
          throw _platformException(operation, error);
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

  Future<T> _invokeValue<T>(
    String operation,
    String method, [
    Object? arguments,
  ]) =>
      _trackInvocation(operation, () async {
        final channel = _requireChannel(operation);
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
          throw _platformException(operation, error);
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

  Future<T> _trackInvocation<T>(
    String operation,
    Future<T> Function() invoke,
  ) {
    final invocationId = _invocationSequence++;
    final completer = Completer<T>();
    _pendingInvocations[invocationId] = (error) {
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
        _pendingInvocations.remove(invocationId);
        if (!completer.isCompleted) completer.complete(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        _pendingInvocations.remove(invocationId);
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      },
    );
    return completer.future;
  }

  AndroidMapException _platformException(
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

  MethodChannel _requireChannel(String operation) {
    final channel = _channel;
    if (channel == null || _closed) {
      throw AndroidMapException(
        operation: operation,
        code: 'not_attached',
        viewId: _viewId,
      );
    }
    return channel;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final viewId = _viewId;
    final error = AndroidMapException(
      operation: 'close',
      code: 'transport_closed',
      viewId: viewId,
    );
    final cancellations = _pendingInvocations.values.toList(growable: false);
    _pendingInvocations.clear();
    for (final cancel in cancellations) {
      cancel(error);
    }
    _channel?.setMethodCallHandler(null);
    _channel = null;
    _viewId = null;
    await _events.close();
  }
}

int _signedArgb(int value) => value > 0x7fffffff ? value - 0x100000000 : value;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/src/android_transport/android_event_decoder.dart';
import 'package:flutter_osm_plugin/src/android_transport/android_map_transport.dart';

/// Typed compatibility transport over the existing per-view channel.
final class MethodChannelAndroidMapTransport implements AndroidMapTransport {
  final StreamController<AndroidMapEvent> _events =
      StreamController<AndroidMapEvent>.broadcast(sync: true);

  MethodChannel? _channel;
  int? _viewId;
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
  Future<void> setZoom(double zoom) => _invokeVoid('setZoom', 'Zoom', {
        'zoomLevel': zoom,
      });

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
  Future<void> addMarker(MarkerId markerId, GeoPoint position) =>
      _invokeVoid('addMarker', 'android#marker#add', {
        'markerId': markerId.value,
        'lat': position.latitude,
        'lon': position.longitude,
      });

  @override
  Future<void> removeMarker(MarkerId markerId) =>
      _invokeVoid('removeMarker', 'android#marker#remove', markerId.value);

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
  ]) async {
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
  }

  Future<T> _invokeValue<T>(
    String operation,
    String method, [
    Object? arguments,
  ]) async {
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
    _channel?.setMethodCallHandler(null);
    _channel = null;
    _viewId = null;
    await _events.close();
  }
}

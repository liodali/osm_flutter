import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/src/android_transport/android_map_transport.dart';

/// Phase 2 compatibility transport over the existing per-view channel.
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
  Future<void> initialize({required GeoPoint initialPosition}) async {
    final channel = _requireChannel('initialize');
    try {
      await channel.invokeMethod<void>('initMap', initialPosition.toMap());
    } on PlatformException catch (error) {
      throw AndroidMapException(
        operation: 'initialize',
        code: error.code,
        viewId: _viewId,
        message: error.message,
        cause: error,
      );
    }
  }

  Future<bool> _handleMethodCall(MethodCall call) async {
    final viewId = _viewId;
    if (viewId == null || _closed) {
      return false;
    }

    switch (call.method) {
      case 'map#init':
        _events.add(
          AndroidMapReady(
            viewId: viewId,
            isReady: call.arguments as bool,
          ),
        );
        break;
      case 'receiveLongPress':
        _events.add(
          AndroidMapTap(
            viewId: viewId,
            position: GeoPoint.fromMap(call.arguments),
            kind: AndroidMapTapKind.long,
          ),
        );
        break;
      case 'receiveSinglePress':
        _events.add(
          AndroidMapTap(
            viewId: viewId,
            position: GeoPoint.fromMap(call.arguments),
            kind: AndroidMapTapKind.single,
          ),
        );
        break;
      case 'receiveRegionIsChanging':
        _events.add(
          AndroidRegionChanged(
            viewId: viewId,
            region: Region.fromMap(call.arguments),
          ),
        );
        break;
    }
    return true;
  }

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

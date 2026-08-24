import 'dart:async';

import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/src/android_jni/probe.dart';
import 'package:flutter_osm_plugin/src/android_transport/android_map_transport.dart';

/// JNI transport capability gate for Phase 2.
///
/// JNI host calls are proven, but map-session attach is intentionally deferred
/// to Phase 3. Failing here allows `auto` to select MethodChannel before any
/// state-changing command is sent.
final class JniAndroidMapTransport implements AndroidMapTransport {
  @override
  AndroidMapBackend get backend => AndroidMapBackend.jni;

  @override
  Stream<AndroidMapEvent> get events => const Stream<AndroidMapEvent>.empty();

  @override
  Future<void> attach(int viewId) async {
    try {
      final probe = runAndroidJniProbe();
      if (probe.ping != 'osm-jni-ok') {
        throw AndroidMapException(
          operation: 'attach',
          code: 'jni_capability_mismatch',
          viewId: viewId,
          message: 'Unexpected JNI bridge response: ${probe.ping}',
        );
      }
    } on AndroidMapException {
      rethrow;
    } catch (error) {
      throw AndroidMapException(
        operation: 'attach',
        code: 'jni_unavailable',
        viewId: viewId,
        cause: error,
      );
    }

    throw AndroidMapException(
      operation: 'attach',
      code: 'jni_map_sessions_unavailable',
      viewId: viewId,
      message: 'JNI map-session commands are introduced in Phase 3.',
    );
  }

  @override
  Future<void> initialize({required GeoPoint initialPosition}) async {
    throw const AndroidMapException(
      operation: 'initialize',
      code: 'jni_map_sessions_unavailable',
    );
  }

  @override
  Future<void> close() async {}
}

import 'dart:async';

import 'package:flutter_osm_plugin/android.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AndroidMapController', () {
    test('attaches, initializes, and completes ready from the selected map',
        () async {
      final transport = FakeAndroidMapTransport(
        backend: AndroidMapBackend.methodChannel,
      );
      final controller = AndroidMapController.withPosition(
        initPosition: GeoPoint(latitude: 48.85, longitude: 2.35),
        backend: AndroidMapBackend.methodChannel,
        transportFactory: (_) => transport,
      );
      final observed = <AndroidMapEvent>[];
      final subscription = controller.events.listen(observed.add);

      await controller.attachAndroidMap(42);
      var isReady = false;
      controller.ready.then((_) => isReady = true);
      transport.emit(const AndroidMapReady(viewId: 42, isReady: false));
      await Future<void>.delayed(Duration.zero);
      expect(isReady, isFalse);
      transport.emit(const AndroidMapReady(viewId: 42, isReady: true));
      await controller.ready;

      expect(transport.attachedViewId, 42);
      expect(transport.initialPosition?.latitude, 48.85);
      expect(controller.activeBackend, AndroidMapBackend.methodChannel);
      expect(observed, hasLength(2));

      await subscription.cancel();
      await controller.dispose();
      expect(transport.closeCount, 1);
    });

    test('auto falls back only when JNI attach fails', () async {
      final jni = FakeAndroidMapTransport(
        backend: AndroidMapBackend.jni,
        attachError: StateError('JNI map sessions unavailable'),
      );
      final methodChannel = FakeAndroidMapTransport(
        backend: AndroidMapBackend.methodChannel,
      );
      final controller = AndroidMapController.withPosition(
        initPosition: GeoPoint(latitude: 1, longitude: 2),
        transportFactory: (backend) => switch (backend) {
          AndroidMapBackend.jni => jni,
          AndroidMapBackend.methodChannel => methodChannel,
          AndroidMapBackend.auto => throw StateError('unresolved auto'),
        },
      );

      await controller.attachAndroidMap(8);

      expect(jni.attachCount, 1);
      expect(jni.closeCount, 1);
      expect(methodChannel.attachCount, 1);
      expect(methodChannel.initializeCount, 1);
      expect(controller.activeBackend, AndroidMapBackend.methodChannel);

      methodChannel.emit(const AndroidMapReady(viewId: 8, isReady: true));
      await controller.ready;
      await controller.dispose();
    });

    test('does not replay initialization through fallback', () async {
      final jni = FakeAndroidMapTransport(
        backend: AndroidMapBackend.jni,
        initializeError: StateError('initialization failed'),
      );
      final methodChannel = FakeAndroidMapTransport(
        backend: AndroidMapBackend.methodChannel,
      );
      final controller = AndroidMapController.withPosition(
        initPosition: GeoPoint(latitude: 1, longitude: 2),
        transportFactory: (backend) => switch (backend) {
          AndroidMapBackend.jni => jni,
          AndroidMapBackend.methodChannel => methodChannel,
          AndroidMapBackend.auto => throw StateError('unresolved auto'),
        },
      );

      await expectLater(
        controller.attachAndroidMap(9),
        throwsA(isA<AndroidMapException>()),
      );

      expect(jni.initializeCount, 1);
      expect(methodChannel.attachCount, 0);
      await expectLater(controller.ready, throwsA(isA<AndroidMapException>()));
      await controller.dispose();
    });

    test('does not allow reattach after attach failure', () async {
      final failedTransport = FakeAndroidMapTransport(
        backend: AndroidMapBackend.methodChannel,
        attachError: StateError('attach failed'),
      );
      var factoryCalls = 0;
      final controller = AndroidMapController.withPosition(
        initPosition: GeoPoint(latitude: 1, longitude: 2),
        backend: AndroidMapBackend.methodChannel,
        transportFactory: (_) {
          factoryCalls += 1;
          return failedTransport;
        },
      );

      await expectLater(
        controller.attachAndroidMap(10),
        throwsA(isA<AndroidMapException>()),
      );
      await expectLater(
        controller.attachAndroidMap(11),
        throwsA(isA<AndroidMapException>()),
      );

      expect(factoryCalls, 1);
      expect(failedTransport.attachCount, 1);
      await controller.dispose();
    });

    test('filters events belonging to another platform view', () async {
      final transport = FakeAndroidMapTransport(
        backend: AndroidMapBackend.methodChannel,
      );
      final controller = AndroidMapController.withPosition(
        initPosition: GeoPoint(latitude: 1, longitude: 2),
        backend: AndroidMapBackend.methodChannel,
        transportFactory: (_) => transport,
      );
      final observed = <AndroidMapEvent>[];
      final subscription = controller.events.listen(observed.add);
      await controller.attachAndroidMap(11);

      transport.emit(const AndroidMapReady(viewId: 12, isReady: true));
      transport.emit(const AndroidMapReady(viewId: 11, isReady: true));
      await controller.ready;

      expect(observed, hasLength(1));
      expect(observed.single, isA<AndroidMapReady>());

      await subscription.cancel();
      await controller.dispose();
    });

    test('dispose during attach prevents fallback and initialization',
        () async {
      final attachGate = Completer<void>();
      final jni = FakeAndroidMapTransport(
        backend: AndroidMapBackend.jni,
        attachGate: attachGate,
      );
      final methodChannel = FakeAndroidMapTransport(
        backend: AndroidMapBackend.methodChannel,
      );
      final controller = AndroidMapController.withPosition(
        initPosition: GeoPoint(latitude: 1, longitude: 2),
        transportFactory: (backend) => switch (backend) {
          AndroidMapBackend.jni => jni,
          AndroidMapBackend.methodChannel => methodChannel,
          AndroidMapBackend.auto => throw StateError('unresolved auto'),
        },
      );

      final attaching = controller.attachAndroidMap(13);
      await Future<void>.delayed(Duration.zero);
      final disposing = controller.dispose();
      attachGate.complete();

      await expectLater(attaching, throwsA(isA<AndroidMapException>()));
      await disposing;
      expect(jni.initializeCount, 0);
      expect(methodChannel.attachCount, 0);
    });

    test('dispose fails pending readiness and closes once', () async {
      final transport = FakeAndroidMapTransport(
        backend: AndroidMapBackend.methodChannel,
      );
      final controller = AndroidMapController.withPosition(
        initPosition: GeoPoint(latitude: 1, longitude: 2),
        backend: AndroidMapBackend.methodChannel,
        transportFactory: (_) => transport,
      );
      await controller.attachAndroidMap(13);

      final ready = expectLater(
        controller.ready,
        throwsA(isA<AndroidMapException>()),
      );
      await controller.dispose();
      await ready;
      await controller.dispose();

      expect(transport.closeCount, 1);
    });
  });
}

final class FakeAndroidMapTransport implements AndroidMapTransport {
  FakeAndroidMapTransport({
    required this.backend,
    this.attachError,
    this.initializeError,
    this.attachGate,
  });

  @override
  final AndroidMapBackend backend;
  final Object? attachError;
  final Object? initializeError;
  final Completer<void>? attachGate;
  final StreamController<AndroidMapEvent> _events =
      StreamController<AndroidMapEvent>.broadcast(sync: true);

  int attachCount = 0;
  int initializeCount = 0;
  int closeCount = 0;
  int? attachedViewId;
  GeoPoint? initialPosition;
  bool _closed = false;

  @override
  Stream<AndroidMapEvent> get events => _events.stream;

  @override
  Future<void> attach(int viewId) async {
    attachCount += 1;
    final error = attachError;
    if (error != null) throw error;
    await attachGate?.future;
    attachedViewId = viewId;
  }

  @override
  Future<void> initialize({required GeoPoint initialPosition}) async {
    initializeCount += 1;
    final error = initializeError;
    if (error != null) throw error;
    this.initialPosition = initialPosition;
  }

  void emit(AndroidMapEvent event) {
    _events.add(event);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    closeCount += 1;
    await _events.close();
  }
}

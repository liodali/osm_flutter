import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/android.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('runs the Phase 3 JNI camera and marker command slice', (
    tester,
  ) async {
    var readyCallbackCount = 0;
    final events = <AndroidMapEvent>[];
    final observer = _ReadyObserver();
    final controller = AndroidMapController.withPosition(
      initPosition: GeoPoint(latitude: 48.8566, longitude: 2.3522),
    );
    controller.addObserver(observer);
    final subscription = controller.events.listen(events.add);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OSMFlutter(
            controller: controller,
            osmOption: const OSMOption(),
            onMapIsReady: (ready) {
              if (ready) readyCallbackCount += 1;
            },
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 5));
    await controller.ready.timeout(const Duration(seconds: 10));
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.activeBackend, AndroidMapBackend.jni);
    expect(readyCallbackCount, 1);
    expect(observer.trueReadyCount, 1);
    expect(events.whereType<AndroidMapReady>(), isNotEmpty);

    await controller.camera.moveTo(
      GeoPoint(latitude: 48.8606, longitude: 2.3376),
      animated: false,
    );
    await controller.camera.setZoom(14);
    expect(await controller.camera.getZoom(), closeTo(14, 0.01));
    await controller.camera.setRotation(0.25, animated: false);
    const markerId = MarkerId('phase-3-marker');
    expect(
      await controller.markers.add(
        GeoPoint(latitude: 48.8606, longitude: 2.3376),
        markerId: markerId,
      ),
      markerId,
    );
    await controller.markers.remove(markerId);
    expect(
      events.whereType<AndroidMapAcknowledgement>().map(
        (event) => event.operation,
      ),
      containsAll(<String>[
        'initialize',
        'moveTo',
        'setZoom',
        'setRotation',
        'addMarker',
        'removeMarker',
      ]),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    await subscription.cancel();
    await controller.dispose();
  });

  testWidgets('isolates JNI commands for two platform-view IDs', (
    tester,
  ) async {
    final first = AndroidMapController.withPosition(
      initPosition: GeoPoint(latitude: 48.8566, longitude: 2.3522),
      backend: AndroidMapBackend.jni,
    );
    final second = AndroidMapController.withPosition(
      initPosition: GeoPoint(latitude: 51.5072, longitude: -0.1276),
      backend: AndroidMapBackend.jni,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: OSMFlutter(
                  controller: first,
                  osmOption: const OSMOption(),
                ),
              ),
              Expanded(
                child: OSMFlutter(
                  controller: second,
                  osmOption: const OSMOption(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    await Future.wait([
      first.ready.timeout(const Duration(seconds: 10)),
      second.ready.timeout(const Duration(seconds: 10)),
    ]);

    await first.camera.setZoom(11);
    await second.camera.setZoom(15);
    expect(await first.camera.getZoom(), closeTo(11, 0.01));
    expect(await second.camera.getZoom(), closeTo(15, 0.01));
    const sharedId = MarkerId('same-id-isolated-by-view');
    await first.markers.add(
      GeoPoint(latitude: 48.8566, longitude: 2.3522),
      markerId: sharedId,
    );
    await second.markers.add(
      GeoPoint(latitude: 51.5072, longitude: -0.1276),
      markerId: sharedId,
    );
    await first.markers.remove(sharedId);
    await second.markers.remove(sharedId);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    await first.dispose();
    await second.dispose();
  });

  testWidgets('keeps the typed command slice available through fallback', (
    tester,
  ) async {
    final controller = AndroidMapController.withPosition(
      initPosition: GeoPoint(latitude: 48.8566, longitude: 2.3522),
      backend: AndroidMapBackend.methodChannel,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OSMFlutter(
            controller: controller,
            osmOption: const OSMOption(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    await controller.ready.timeout(const Duration(seconds: 10));

    expect(controller.activeBackend, AndroidMapBackend.methodChannel);
    await controller.camera.moveTo(
      GeoPoint(latitude: 48.8606, longitude: 2.3376),
      animated: false,
    );
    await controller.camera.setZoom(13);
    expect(await controller.camera.getZoom(), closeTo(13, 0.01));
    const markerId = MarkerId('phase-3-fallback-marker');
    await controller.markers.add(
      GeoPoint(latitude: 48.8606, longitude: 2.3376),
      markerId: markerId,
    );
    await controller.markers.remove(markerId);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    await controller.dispose();
  });
}

final class _ReadyObserver with OSMMixinObserver {
  int trueReadyCount = 0;

  @override
  Future<void> mapIsReady(bool isReady) async {
    if (isReady) trueReadyCount += 1;
  }
}

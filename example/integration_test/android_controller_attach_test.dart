import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/android.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('attaches AndroidMapController with pre-command fallback', (
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

    expect(controller.activeBackend, AndroidMapBackend.methodChannel);
    expect(readyCallbackCount, 1);
    expect(observer.trueReadyCount, 1);
    expect(events.whereType<AndroidMapReady>(), isNotEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    await subscription.cancel();
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

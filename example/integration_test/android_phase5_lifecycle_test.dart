import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/android.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('keeps requested location updates across pause and resume', (
    tester,
  ) async {
    final controller = AndroidMapController.withPosition(
      initPosition: GeoPoint(latitude: 48.8566, longitude: 2.3522),
      backend: AndroidMapBackend.jni,
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
    await controller.location.startUpdates();

    // The device runner backgrounds and resumes the Activity during this
    // window, then confirms the native LocationManager registration stops and
    // returns. The command below verifies that the map session remains usable.
    debugPrint('PHASE5_LIFECYCLE_READY');
    await Future<void>.delayed(const Duration(seconds: 10));

    await controller.camera.setZoom(12);
    expect(await controller.camera.getZoom(), closeTo(12, 0.01));
    await controller.location.stopUpdates();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    await controller.dispose();
  });
}

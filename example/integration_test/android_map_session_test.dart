import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('supports two independent Android map sessions', (
    tester,
  ) async {
    var firstReady = false;
    var secondReady = false;
    final firstController = MapController.withPosition(
      initPosition: GeoPoint(latitude: 48.8566, longitude: 2.3522),
    );
    final secondController = MapController.withPosition(
      initPosition: GeoPoint(latitude: 51.5072, longitude: -0.1276),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: OSMFlutter(
                  controller: firstController,
                  osmOption: const OSMOption(),
                  onMapIsReady: (ready) => firstReady = ready,
                ),
              ),
              Expanded(
                child: OSMFlutter(
                  controller: secondController,
                  osmOption: const OSMOption(),
                  onMapIsReady: (ready) => secondReady = ready,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 5));
    expect(firstReady, isTrue);
    expect(secondReady, isTrue);

    // Exercise both PlatformView.dispose paths and the registry cleanup.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });
}

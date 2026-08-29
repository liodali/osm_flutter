import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_android_jni/flutter_osm_android_jni.dart';
import 'package:flutter_osm_plugin/android.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

final _jniTransportFactory = createAndroidJniTransportFactory(
  fallback: createDefaultAndroidMapTransport,
);

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
      backend: AndroidMapBackend.auto,
      transportFactory: _jniTransportFactory,
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

  testWidgets('runs Phase 4 JNI overlays, icon bytes, and bulk commands', (
    tester,
  ) async {
    final events = <AndroidMapEvent>[];
    final controller = AndroidMapController.withPosition(
      initPosition: GeoPoint(latitude: 48.8566, longitude: 2.3522),
      backend: AndroidMapBackend.jni,
      transportFactory: _jniTransportFactory,
    );
    final subscription = controller.events.listen(events.add);

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

    final icon = await _loadMarkerIcon();
    final marker = await controller.markers.add(
      GeoPoint(latitude: 48.857, longitude: 2.353),
      iconBytes: icon,
    );
    await controller.markers.updateIcon(marker, icon);

    final geometry = List.generate(
      25,
      (index) => GeoPoint(
        latitude: 48.857 + index * 0.0001,
        longitude: 2.353 + index * 0.0001,
      ),
    );
    final bulkWatch = Stopwatch()..start();
    final bulkMarkers = await controller.markers.addAll(geometry);
    bulkWatch.stop();
    debugPrint(
      'Phase 4 JNI bulk add: ${geometry.length} markers in '
      '${bulkWatch.elapsedMicroseconds}µs, '
      'payload doubles=${geometry.length * 2}',
    );

    final circle = await controller.shapes.addCircle(
      center: geometry.first,
      radius: 25,
      color: Colors.blue.withValues(alpha: 0.4),
      borderColor: Colors.blue,
    );
    final rectangle = await controller.shapes.addRectangle(
      center: geometry.last,
      distance: 30,
      color: Colors.green.withValues(alpha: 0.4),
    );
    final staticGroup = await controller.staticPositions.set(
      geometry.take(3).toList(),
      iconBytes: icon,
    );
    final road = await controller.roads.draw(
      geometry.take(5).toList(),
      option: const RoadOption(
        roadColor: Colors.deepPurple,
        roadWidth: 6,
        roadBorderColor: Colors.white,
        roadBorderWidth: 2,
        zoomInto: false,
      ),
    );
    await controller.layers.setOverlaysVisible(false);
    await controller.layers.setOverlaysVisible(true);
    await controller.layers.setTile(CustomTile.satellite());
    await controller.layers.setTile(null);

    await controller.markers.removeAll(bulkMarkers);
    await controller.markers.remove(marker);
    await controller.shapes.remove(circle);
    await controller.shapes.remove(rectangle);
    await controller.staticPositions.remove(staticGroup);
    await controller.roads.remove(road);

    expect(
      events.whereType<AndroidMapAcknowledgement>().map(
        (event) => event.operation,
      ),
      containsAll(<String>[
        'addMarker',
        'updateMarkerIcon',
        'addMarkers',
        'addCircle',
        'addRectangle',
        'setStaticPositions',
        'drawRoad',
        'setOverlaysVisible',
        'setTile',
        'removeMarkers',
        'removeShape',
        'removeStaticPositions',
        'removeRoad',
      ]),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    await subscription.cancel();
    await controller.dispose();
  });

  testWidgets('runs Phase 5 location commands on the channel event plane', (
    tester,
  ) async {
    final controller = AndroidMapController.withPosition(
      initPosition: GeoPoint(latitude: 48.8566, longitude: 2.3522),
      backend: AndroidMapBackend.jni,
      transportFactory: _jniTransportFactory,
    );
    final locationEvents = <AndroidUserLocationChanged>[];
    final subscription = controller.events.listen((event) {
      if (event is AndroidUserLocationChanged) locationEvents.add(event);
    });

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

    await controller.location.showCurrentLocation();
    await controller.location.startUpdates();
    final current = await controller.location.getCurrentLocation().timeout(
      const Duration(seconds: 20),
    );
    expect(current.latitude, inInclusiveRange(-90, 90));
    expect(current.longitude, inInclusiveRange(-180, 180));
    await controller.location.stopUpdates();
    await controller.location.startTracking(
      stopFollowOnDrag: true,
      disableMarkerRotation: false,
      useDirectionMarker: false,
    );
    await tester.pump(const Duration(seconds: 2));
    await controller.location.stopTracking();

    expect(controller.activeBackend, AndroidMapBackend.jni);
    expect(locationEvents, isNotEmpty);

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
      transportFactory: _jniTransportFactory,
    );
    final second = AndroidMapController.withPosition(
      initPosition: GeoPoint(latitude: 51.5072, longitude: -0.1276),
      backend: AndroidMapBackend.jni,
      transportFactory: _jniTransportFactory,
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

    const sharedShapeId = ShapeId('same-shape-id-isolated-by-view');
    await first.shapes.addCircle(
      center: GeoPoint(latitude: 48.8566, longitude: 2.3522),
      radius: 20,
      color: Colors.blue,
      shapeId: sharedShapeId,
    );
    await second.shapes.addCircle(
      center: GeoPoint(latitude: 51.5072, longitude: -0.1276),
      radius: 20,
      color: Colors.green,
      shapeId: sharedShapeId,
    );
    await first.shapes.remove(sharedShapeId);
    await second.shapes.remove(sharedShapeId);

    const sharedStaticId = StaticPositionId(
      'same-static-id-isolated-by-view',
    );
    await first.staticPositions.set(
      [GeoPoint(latitude: 48.8566, longitude: 2.3522)],
      groupId: sharedStaticId,
    );
    await second.staticPositions.set(
      [GeoPoint(latitude: 51.5072, longitude: -0.1276)],
      groupId: sharedStaticId,
    );
    await first.staticPositions.remove(sharedStaticId);
    await second.staticPositions.remove(sharedStaticId);

    const sharedRoadId = RoadId('same-road-id-isolated-by-view');
    await first.roads.draw(
      [
        GeoPoint(latitude: 48.8566, longitude: 2.3522),
        GeoPoint(latitude: 48.8576, longitude: 2.3532),
      ],
      roadId: sharedRoadId,
    );
    await second.roads.draw(
      [
        GeoPoint(latitude: 51.5072, longitude: -0.1276),
        GeoPoint(latitude: 51.5082, longitude: -0.1266),
      ],
      roadId: sharedRoadId,
    );
    await first.roads.remove(sharedRoadId);
    await second.roads.remove(sharedRoadId);

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
    final bulkMarkers = await controller.markers.addAll([
      GeoPoint(latitude: 48.861, longitude: 2.338),
      GeoPoint(latitude: 48.862, longitude: 2.339),
    ]);
    final shape = await controller.shapes.addCircle(
      center: GeoPoint(latitude: 48.861, longitude: 2.338),
      radius: 20,
      color: Colors.blue,
    );
    final staticGroup = await controller.staticPositions.set([
      GeoPoint(latitude: 48.861, longitude: 2.338),
    ]);
    final road = await controller.roads.draw([
      GeoPoint(latitude: 48.861, longitude: 2.338),
      GeoPoint(latitude: 48.862, longitude: 2.339),
    ]);
    await controller.layers.setOverlaysVisible(false);
    await controller.layers.setOverlaysVisible(true);
    await controller.location.showCurrentLocation();
    await controller.location.startUpdates();
    final current = await controller.location.getCurrentLocation().timeout(
      const Duration(seconds: 20),
    );
    expect(current.latitude, inInclusiveRange(-90, 90));
    expect(current.longitude, inInclusiveRange(-180, 180));
    await controller.location.stopUpdates();
    await controller.location.startTracking(
      stopFollowOnDrag: true,
      disableMarkerRotation: false,
      useDirectionMarker: false,
    );
    await controller.location.stopTracking();
    await controller.markers.removeAll(bulkMarkers);
    await controller.markers.remove(markerId);
    await controller.shapes.remove(shape);
    await controller.staticPositions.remove(staticGroup);
    await controller.roads.remove(road);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    await controller.dispose();
  });
}

Future<Uint8List> _loadMarkerIcon() async {
  final data = await rootBundle.load(
    'packages/flutter_osm_plugin/assets/default_pin.png',
  );
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

final class _ReadyObserver with OSMMixinObserver {
  int trueReadyCount = 0;

  @override
  Future<void> mapIsReady(bool isReady) async {
    if (isReady) trueReadyCount += 1;
  }
}

import 'dart:convert';

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

  testWidgets('benchmarks Phase 4 JNI against MethodChannel', (tester) async {
    final jni = AndroidMapController.withPosition(
      initPosition: GeoPoint(latitude: 48.8566, longitude: 2.3522),
      backend: AndroidMapBackend.jni,
      transportFactory: _jniTransportFactory,
    );
    final methodChannel = AndroidMapController.withPosition(
      initPosition: GeoPoint(latitude: 48.8566, longitude: 2.3522),
      backend: AndroidMapBackend.methodChannel,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: OSMFlutter(
                  controller: jni,
                  osmOption: const OSMOption(),
                ),
              ),
              Expanded(
                child: OSMFlutter(
                  controller: methodChannel,
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
      jni.ready.timeout(const Duration(seconds: 10)),
      methodChannel.ready.timeout(const Duration(seconds: 10)),
    ]);

    final icon = await _loadMarkerIcon();
    final markerPositions = List.generate(
      25,
      (index) => GeoPoint(
        latitude: 48.8566 + index * 0.0001,
        longitude: 2.3522 + index * 0.0001,
      ),
    );
    final geometry = List.generate(
      250,
      (index) => GeoPoint(
        latitude: 48.8566 + index * 0.00001,
        longitude: 2.3522 + index * 0.00001,
      ),
    );

    await _warmUpController(
      jni,
      markerPositions: markerPositions,
      geometry: geometry,
      icon: icon,
    );
    await _warmUpController(
      methodChannel,
      markerPositions: markerPositions,
      geometry: geometry,
      icon: icon,
    );

    final jniSamples = _BenchmarkSamples();
    final methodChannelSamples = _BenchmarkSamples();
    for (var round = 0; round < 5; round += 1) {
      final orderedRuns = round.isEven
          ? [(jni, jniSamples), (methodChannel, methodChannelSamples)]
          : [(methodChannel, methodChannelSamples), (jni, jniSamples)];
      for (final (controller, samples) in orderedRuns) {
        samples.add(
          await _benchmarkRound(
            controller,
            markerPositions: markerPositions,
            geometry: geometry,
            icon: icon,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    final jniResult = jniSamples.result;
    final methodChannelResult = methodChannelSamples.result;

    final report = <String, Object>{
      'mode': 'profile',
      'rounds': 5,
      'markerCount': markerPositions.length,
      'geometryPointCount': geometry.length,
      'coordinatePayloadBytes': geometry.length * 2 * 8,
      'iconPayloadBytes': icon.length,
      'jni': jniResult.toJson(),
      'methodChannel': methodChannelResult.toJson(),
      'jniToMethodChannelRatio': {
        'sequentialMarkers':
            jniResult.sequentialMarkersUs /
            methodChannelResult.sequentialMarkersUs,
        'bulkMarkers':
            jniResult.bulkMarkersUs / methodChannelResult.bulkMarkersUs,
        'roadGeometry':
            jniResult.roadGeometryUs / methodChannelResult.roadGeometryUs,
        'staticGeometry':
            jniResult.staticGeometryUs / methodChannelResult.staticGeometryUs,
        'iconUpdate': jniResult.iconUpdateUs / methodChannelResult.iconUpdateUs,
      },
    };
    debugPrint('PHASE4_BENCHMARK ${jsonEncode(report)}');

    expect(jniResult.values, everyElement(greaterThan(0)));
    expect(methodChannelResult.values, everyElement(greaterThan(0)));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    await jni.dispose();
    await methodChannel.dispose();
  });
}

Future<void> _warmUpController(
  AndroidMapController controller, {
  required List<GeoPoint> markerPositions,
  required List<GeoPoint> geometry,
  required Uint8List icon,
}) async {
  final marker = await controller.markers.add(markerPositions.first);
  await controller.markers.updateIcon(marker, icon);
  await controller.markers.remove(marker);

  final bulkMarkers = await controller.markers.addAll(markerPositions.take(3));
  await controller.markers.removeAll(bulkMarkers);

  final road = await controller.roads.draw(
    geometry.take(10).toList(),
    option: const RoadOption(
      roadColor: Colors.deepPurple,
      roadWidth: 6,
      roadBorderColor: Colors.white,
      roadBorderWidth: 2,
      zoomInto: false,
    ),
  );
  await controller.roads.remove(road);

  final staticPositions = await controller.staticPositions.set(
    geometry.take(10).toList(),
  );
  await controller.staticPositions.remove(staticPositions);
}

Future<_BenchmarkResult> _benchmarkRound(
  AndroidMapController controller, {
  required List<GeoPoint> markerPositions,
  required List<GeoPoint> geometry,
  required Uint8List icon,
}) async {
  final sequentialIds = <MarkerId>[];
  final sequentialWatch = Stopwatch()..start();
  for (final position in markerPositions) {
    sequentialIds.add(await controller.markers.add(position));
  }
  sequentialWatch.stop();
  await controller.markers.removeAll(sequentialIds);

  final bulkWatch = Stopwatch()..start();
  final bulkIds = await controller.markers.addAll(markerPositions);
  bulkWatch.stop();
  await controller.markers.removeAll(bulkIds);

  final roadWatch = Stopwatch()..start();
  final roadId = await controller.roads.draw(
    geometry,
    option: const RoadOption(
      roadColor: Colors.deepPurple,
      roadWidth: 6,
      roadBorderColor: Colors.white,
      roadBorderWidth: 2,
      zoomInto: false,
    ),
  );
  roadWatch.stop();
  await controller.roads.remove(roadId);

  final staticWatch = Stopwatch()..start();
  final staticId = await controller.staticPositions.set(geometry);
  staticWatch.stop();
  await controller.staticPositions.remove(staticId);

  final iconMarker = await controller.markers.add(markerPositions.first);
  final iconWatch = Stopwatch()..start();
  await controller.markers.updateIcon(iconMarker, icon);
  iconWatch.stop();
  await controller.markers.remove(iconMarker);

  return _BenchmarkResult(
    sequentialMarkersUs: sequentialWatch.elapsedMicroseconds,
    bulkMarkersUs: bulkWatch.elapsedMicroseconds,
    roadGeometryUs: roadWatch.elapsedMicroseconds,
    staticGeometryUs: staticWatch.elapsedMicroseconds,
    iconUpdateUs: iconWatch.elapsedMicroseconds,
  );
}

Future<Uint8List> _loadMarkerIcon() async {
  final data = await rootBundle.load(
    'packages/flutter_osm_plugin/assets/default_pin.png',
  );
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

int _median(List<int> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}

final class _BenchmarkSamples {
  final List<int> _sequentialMarkers = [];
  final List<int> _bulkMarkers = [];
  final List<int> _roadGeometry = [];
  final List<int> _staticGeometry = [];
  final List<int> _iconUpdate = [];

  void add(_BenchmarkResult result) {
    _sequentialMarkers.add(result.sequentialMarkersUs);
    _bulkMarkers.add(result.bulkMarkersUs);
    _roadGeometry.add(result.roadGeometryUs);
    _staticGeometry.add(result.staticGeometryUs);
    _iconUpdate.add(result.iconUpdateUs);
  }

  _BenchmarkResult get result => _BenchmarkResult(
    sequentialMarkersUs: _median(_sequentialMarkers),
    bulkMarkersUs: _median(_bulkMarkers),
    roadGeometryUs: _median(_roadGeometry),
    staticGeometryUs: _median(_staticGeometry),
    iconUpdateUs: _median(_iconUpdate),
  );
}

final class _BenchmarkResult {
  const _BenchmarkResult({
    required this.sequentialMarkersUs,
    required this.bulkMarkersUs,
    required this.roadGeometryUs,
    required this.staticGeometryUs,
    required this.iconUpdateUs,
  });

  final int sequentialMarkersUs;
  final int bulkMarkersUs;
  final int roadGeometryUs;
  final int staticGeometryUs;
  final int iconUpdateUs;

  List<int> get values => [
    sequentialMarkersUs,
    bulkMarkersUs,
    roadGeometryUs,
    staticGeometryUs,
    iconUpdateUs,
  ];

  Map<String, int> toJson() => {
    'sequentialMarkersUs': sequentialMarkersUs,
    'bulkMarkersUs': bulkMarkersUs,
    'roadGeometryUs': roadGeometryUs,
    'staticGeometryUs': staticGeometryUs,
    'iconUpdateUs': iconUpdateUs,
  };
}

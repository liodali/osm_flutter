// Run: flutter run -d macos -t lib/manual_macos_checks.dart
// Uses real platform views and debug-only native probes.
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode || kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) {
    throw UnsupportedError(
      'The acceptance screen requires a debug macOS build.',
    );
  }
  runApp(const MaterialApp(home: MacOSAcceptanceScreen()));
}

class _MapCase {
  _MapCase(this.id, this.position)
    : controller = MapController.withPosition(initPosition: position);
  final int id;
  final GeoPoint position;
  final MapController controller;
  final ready = Completer<void>();
  int locationEvents = 0;
}

class MacOSAcceptanceScreen extends StatefulWidget {
  const MacOSAcceptanceScreen({super.key});
  @override
  State<MacOSAcceptanceScreen> createState() => _MacOSAcceptanceScreenState();
}

class _MacOSAcceptanceScreenState extends State<MacOSAcceptanceScreen> {
  static const _native = MethodChannel('osm_example/manual_checks');
  final _cases = <_MapCase>[];
  final _results = <String>[];
  int _nextId = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    developer.registerExtension('ext.osm.manual', (_, args) async {
      try {
        final result = await _command(args['action'] ?? 'state');
        return developer.ServiceExtensionResponse.result(jsonEncode(result));
      } catch (error) {
        return developer.ServiceExtensionResponse.result(
          jsonEncode({'error': '$error'}),
        );
      }
    });
    _cases.add(_newCase());
  }

  _MapCase _newCase() {
    final id = _nextId++;
    return _MapCase(
      id,
      GeoPoint(
        latitude: 47.376912345 + id * 0.001,
        longitude: 8.541712345 + id * 0.001,
      ),
    );
  }

  void _record(String message) {
    if (mounted) setState(() => _results.add(message));
    debugPrint('OSM_ACCEPTANCE: $message');
  }

  String _describe(Object error) => error is GeoPointException
      ? error.errorMessage() ?? 'Location error'
      : error.toString();

  Future<Map<String, dynamic>> _snapshot() async => Map<String, dynamic>.from(
    await _native.invokeMapMethod<String, dynamic>('snapshot') ?? {},
  );

  Future<Map<String, dynamic>> _waitForNative(int expected) async {
    for (var i = 0; i < 30; i++) {
      final state = await _snapshot();
      if (state['hosts'] == expected && state['liveSessions'] == expected) {
        return state;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    throw StateError('Native release/count mismatch: ${await _snapshot()}');
  }

  Future<void> _replaceMaps(int count) async {
    setState(() {
      _cases.clear();
      _cases.addAll(List.generate(count, (_) => _newCase()));
    });
    await Future.wait(
      _cases.map((map) => map.ready.future),
    ).timeout(const Duration(seconds: 25));
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  void _require(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  Future<Map<String, dynamic>> _command(String action) async {
    if (action == 'state') return _snapshot();
    if (action == 'centers') {
      return {
        'centers': [
          for (final map in _cases) (await map.controller.centerMap).toMap(),
        ],
      };
    }
    if (_busy) return {'error': 'Another check is running'};
    setState(() => _busy = true);
    try {
      if (action == 'inspect') {
        final state = await _snapshot();
        _record(jsonEncode(state));
        return state;
      }
      if (action == 'lifecycle') return await _lifecycle();
      if (action == 'location') {
        final map = _cases.first;
        await map.ready.future;
        await _native.invokeMethod<void>('activate');
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final before = await _snapshot();
        _require(
          before['active'] == true,
          'Bring the acceptance window to the foreground and retry location',
        );
        try {
          await map.controller.myLocation().timeout(
            const Duration(seconds: 60),
          );
          _record(
            'Location completed successfully; coordinates are not recorded.',
          );
          return {
            'location': 'success',
            'before': before,
            'after': await _snapshot(),
          };
        } catch (error) {
          _record(
            'Location completed with ${error.runtimeType}: ${_describe(error)}',
          );
          return {
            'location': 'error',
            'errorType': '${error.runtimeType}',
            'error': _describe(error),
            'before': before,
            'after': await _snapshot(),
          };
        }
      }
      if (action == 'tracking') {
        final map = _cases.first;
        await map.ready.future;
        final eventsAtStart = map.locationEvents;
        await map.controller.enableTracking(anchor: Anchor.bottom);
        final report = <String, dynamic>{};
        try {
          await Future<void>.delayed(const Duration(seconds: 3));
          final before = await _snapshot();
          await _native.invokeMethod<void>('refreshBacking');
          final after = await _snapshot();
          List<Map> anchored(Map<String, dynamic> state) =>
              (state['maps'] as List)
                  .map((map) => map['userIcon'] as Map)
                  .where(
                    (icon) => listEquals(icon['anchor'] as List?, [0.5, 0.0]),
                  )
                  .toList();
          final beforeIcons = anchored(before);
          final afterIcons = anchored(after);
          _require(
            beforeIcons.length == 1 &&
                afterIcons.length == 1 &&
                listEquals(
                  beforeIcons.single['size'] as List?,
                  afterIcons.single['size'] as List?,
                ),
            'Tracking icon/anchor changed: before=$before after=$after',
          );
          report.addAll({
            'before': before,
            'after': after,
            'updatesObserved': map.locationEvents - eventsAtStart,
          });
        } finally {
          await map.controller.disabledTracking();
          await Future<void>.delayed(const Duration(milliseconds: 500));
          final stoppedCount = map.locationEvents;
          await Future<void>.delayed(const Duration(seconds: 1));
          report['updatesAfterStop'] = map.locationEvents - stoppedCount;
        }
        _record(
          'Tracking commands and anchor preservation completed; updates=${report['updatesObserved']}, after stop=${report['updatesAfterStop']}.',
        );
        return report;
      }
      if (action == 'clear') {
        await _replaceMaps(0);
        final state = await _waitForNative(0);
        _record('All maps removed; zero live native sessions.');
        return state;
      }
      if (action == 'removeFirst') {
        _require(_cases.length == 2, 'Create two maps first');
        setState(() => _cases.removeAt(0));
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final state = await _waitForNative(1);
        await _cases.single.controller.zoomIn();
        _record('First map released; remaining map accepts zoom commands.');
        return state;
      }
      if (action == 'create') {
        await _replaceMaps(2);
        return await _waitForNative(2);
      }
      throw ArgumentError('Unknown action: $action');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>> _lifecycle() async {
    await _replaceMaps(2);
    await _waitForNative(2);
    final a = _cases[0];
    final b = _cases[1];
    for (final map in _cases) {
      await map.controller.addMarker(
        map.position,
        markerIcon: const MarkerIcon(icon: Icon(Icons.place, size: 32)),
      );
    }
    final centerBefore = await b.controller.centerMap;
    await a.controller.moveTo(
      GeoPoint(latitude: 48.8566, longitude: 2.3522),
    );
    final moved = await a.controller.centerMap;
    _require(
      (moved.latitude - 48.8566).abs() < 1e-5 &&
          (moved.longitude - 2.3522).abs() < 1e-5,
      'Map A did not move',
    );
    final centerAfter = await b.controller.centerMap;
    _require(
      (centerBefore.latitude - centerAfter.latitude).abs() < 1e-6 &&
          (centerBefore.longitude - centerAfter.longitude).abs() < 1e-6,
      'Moving A moved B',
    );
    _record('Two real maps initialized; camera commands are isolated.');

    final before = await _snapshot();
    await _native.invokeMethod<void>('refreshBacking');
    for (final map in _cases) {
      final points = await map.controller.geopoints;
      _require(
        points.any(
          (p) =>
              p.latitude == map.position.latitude &&
              p.longitude == map.position.longitude,
        ),
        'Backing refresh changed marker coordinates',
      );
      await map.controller.setStaticPosition([map.position], 'poi');
    }
    final after = await _snapshot();
    for (final nativeMap in after['maps'] as List) {
      final scale = (nativeMap['scale'] as num).toDouble();
      _require(
        (nativeMap['markers'] as List).isNotEmpty,
        'No regular marker to inspect',
      );
      _require(
        (nativeMap['pois'] as List).isNotEmpty,
        'No static POI to inspect',
      );
      for (final marker in nativeMap['markers'] as List) {
        _require(
          (marker['size'] as List).length == 2 &&
              (marker['size'] as List).every((value) => value == 32 * scale),
          'Regular marker scale mismatch: $marker',
        );
      }
      for (final poi in nativeMap['pois'] as List) {
        _require(
          (poi['size'] as List).length == 2 &&
              (poi['size'] as List).every((value) => value == 24 * scale),
          'Static POI scale mismatch: $poi',
        );
      }
    }
    _record(
      'Same-display backing refresh preserves exact coordinates and icon sizes, including POI replacement.',
    );
    await _native.invokeMethod<void>('resize', {
      'width': 1100.0,
      'height': 760.0,
    });
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final resized = await _snapshot();
    _require(
      (resized['maps'] as List).every(
        (m) => (m['width'] as num) > 0 && (m['height'] as num) > 0,
      ),
      'Native layout has zero bounds',
    );
    setState(() => _cases.removeAt(0));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _waitForNative(1);
    await b.controller.addMarker(GeoPoint(latitude: 47.38, longitude: 8.55));
    _record(
      'Removing A released its native session; B still accepts commands.',
    );
    for (var cycle = 0; cycle < 3; cycle++) {
      await _replaceMaps(0);
      await _waitForNative(0);
      await _replaceMaps(2);
      await _waitForNative(2);
    }
    _record(
      'Three remove/recreate cycles passed with zero retained native sessions between cycles.',
    );
    for (final map in _cases) {
      await map.controller.addMarker(
        map.position,
        markerIcon: const MarkerIcon(icon: Icon(Icons.place, size: 32)),
      );
    }
    return {
      'result': 'passed',
      'scaleBefore': before,
      'scaleAfter': after,
      'resized': resized,
      'final': await _snapshot(),
    };
  }

  Future<void> _run(String action) async {
    try {
      await _command(action);
    } catch (error) {
      _record('FAILED: $error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('macOS native acceptance checks')),
    body: Column(
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final entry in {
              'lifecycle': 'Run lifecycle / multi-map',
              'location': 'Request location',
              'tracking': 'Start / stop tracking',
              'clear': 'Remove maps',
              'create': 'Create two maps',
              'removeFirst': 'Remove first map',
              'inspect': 'Inspect native state',
            }.entries)
              ElevatedButton(
                onPressed: _busy ? null : () => _run(entry.key),
                child: Text(entry.value),
              ),
          ],
        ),
        const Text(
          'Location uses the actual macOS permission. Cross-display movement requires two displays.',
        ),
        Expanded(
          child: Row(
            children: [
              for (final map in _cases)
                Expanded(
                  key: ValueKey(map.id),
                  child: OSMFlutter(
                    controller: map.controller,
                    onLocationChanged: (_) => map.locationEvents++,
                    onMapIsReady: (ready) {
                      if (ready && !map.ready.isCompleted) map.ready.complete();
                    },
                    osmOption: OSMOption(
                      zoomOption: const ZoomOption(initZoom: 14),
                      userLocationMarker: UserLocationMaker(
                        personMarker: const MarkerIcon(
                          icon: Icon(Icons.person, size: 32),
                        ),
                        directionArrowMarker: const MarkerIcon(
                          icon: Icon(Icons.navigation, size: 32),
                        ),
                      ),
                      staticPoints: [
                        StaticPositionGeoPoint(
                          'poi',
                          const MarkerIcon(icon: Icon(Icons.home, size: 24)),
                          [map.position],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView(
            children: [
              for (final message in _results.reversed) Text(message),
            ],
          ),
        ),
      ],
    ),
  );
}

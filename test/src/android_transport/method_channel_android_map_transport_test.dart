import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/src/android_transport/method_channel_android_map_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.dali.hamza/osmview_41');
  late MethodChannelAndroidMapTransport transport;
  late List<MethodCall> calls;

  setUp(() async {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    transport = MethodChannelAndroidMapTransport();
    await transport.attach(41);
  });

  tearDown(() async {
    await transport.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('uses the deterministic typed zoom command', () async {
    await transport.setZoom(14);

    expect(calls.single.method, 'android#camera#zoom');
    expect(calls.single.arguments, 14.0);
  });

  test('serializes marker IDs, coordinates, and icon bytes', () async {
    final icon = Uint8List.fromList([0, 127, 128, 255]);
    const firstId = MarkerId('first');
    const secondId = MarkerId('second');
    final first = GeoPoint(latitude: 48.85, longitude: 2.35);
    final second = GeoPoint(latitude: 48.86, longitude: 2.36);

    await transport.addMarker(firstId, first, iconBytes: icon);
    await transport.addMarkers({firstId: first, secondId: second});
    await transport.updateMarkerIcon(firstId, icon);
    await transport.removeMarkers(const [firstId, secondId]);

    expect(calls.map((call) => call.method), [
      'android#marker#add',
      'android#marker#addAll',
      'android#marker#icon',
      'android#marker#removeAll',
    ]);
    expect((calls[0].arguments as Map)['icon'], icon);
    expect((calls[1].arguments as Map)['markerIds'], ['first', 'second']);
    expect(
      (calls[1].arguments as Map)['coordinates'],
      [48.85, 2.35, 48.86, 2.36],
    );
  });

  test('serializes overlays, geometry, and tile configuration', () async {
    final center = GeoPoint(latitude: 48.85, longitude: 2.35);
    final next = GeoPoint(latitude: 48.86, longitude: 2.36);

    await transport.addCircle(
      shapeId: const ShapeId('circle'),
      center: center,
      radius: 25,
      fillColor: -16776961,
      borderColor: -1,
      strokeWidth: 2,
    );
    await transport.setStaticPositions(
      const StaticPositionId('static'),
      [center, next],
    );
    await transport.drawRoad(
      const RoadId('road'),
      [center, next],
      const RoadOption(
        roadColor: Colors.blue,
        roadBorderColor: Colors.white,
        roadBorderWidth: 2,
        zoomInto: false,
      ),
    );
    await transport.setTile(CustomTile.satellite());
    await transport.setOverlaysVisible(false);

    expect(calls.map((call) => call.method), [
      'android#shape#circle',
      'android#static#set',
      'android#road#draw',
      'android#tile#set',
      'android#layer#visibility',
    ]);
    expect(
      (calls[1].arguments as Map)['coordinates'],
      [48.85, 2.35, 0.0, 48.86, 2.36, 0.0],
    );
    expect(
      (calls[2].arguments as Map)['coordinates'],
      [48.85, 2.35, 48.86, 2.36],
    );
    expect(calls[3].arguments, isA<Map>());
    expect(calls[4].arguments, isFalse);
  });
}

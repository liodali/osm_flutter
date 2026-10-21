import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = StandardMethodCodec();
  String name(int id) => 'plugins.dali.hamza/osmview_$id';
  Future<void> emit(int id, String method, dynamic arguments) async {
    final done = Completer<void>();
    await messenger.handlePlatformMessage(
        name(id), codec.encodeMethodCall(MethodCall(method, arguments)),
        (reply) {
      try {
        if (reply != null) codec.decodeEnvelope(reply);
        done.complete();
      } catch (error, stack) {
        done.completeError(error, stack);
      }
    });
    await done.future;
    await Future<void>.delayed(Duration.zero);
  }

  for (final target in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    group('$target Apple channel', () {
      late MethodChannelOSM platform;
      final calls = <MethodCall>[];
      setUp(() async {
        debugDefaultTargetPlatformOverride = target;
        platform = MethodChannelOSM();
        calls.clear();
        messenger.setMockMethodCallHandler(MethodChannel(name(41)),
            (call) async {
          calls.add(call);
          if (call.method == 'user#position') {
            throw PlatformException(
                code: 'permission',
                message: 'location permission was not granted');
          }
          return null;
        });
        await platform.init(41);
      });
      tearDown(() {
        platform.close(41);
        platform.close(42);
        messenger.setMockMethodCallHandler(MethodChannel(name(41)), null);
        debugDefaultTargetPlatformOverride = null;
      });

      test('default tile reset sends an Apple tile dictionary', () async {
        await platform.changeTileLayer(41, null);
        expect(calls.single.method, 'change#tile');
        expect(calls.single.arguments['urls'], [
          {
            'url': 'https://{s}.tile.openstreetmap.org/',
            'subdomains': ['a', 'b', 'c']
          },
        ]);
      });

      test('init is idempotent and readiness events stay on their map',
          () async {
        await platform.init(41);
        await platform.init(42);
        final first = <bool>[];
        final second = <bool>[];
        final init = <bool>[];
        final subscriptions = [
          platform.onMapIsReady(41).listen((e) => first.add(e.value)),
          platform.onMapIsReady(42).listen((e) => second.add(e.value)),
          platform.onIosMapInit(41).listen((e) => init.add(e.value)),
        ];
        await platform.initIosMap(41);
        await emit(41, 'map#init#ios', true);
        await emit(41, 'map#init', false);
        await emit(42, 'map#init', true);
        expect(calls.single.method, 'init#ios#map');
        expect(init, [true]);
        expect(first, [false]);
        expect(second, [true]);
        for (final sub in subscriptions) {
          await sub.cancel();
        }
      });

      test(
          'decodes marker, region and location callbacks without losing precision',
          () async {
        const point = {'lat': 47.376912345, 'lon': 8.541712345};
        final marker = platform.onGeoPointLongPressListener(41).first;
        final region = platform.onRegionIsChangingListener(41).first;
        final location = platform.onUserPositionListener(41).first;
        await emit(41, 'receiveGeoPointLongPress', point);
        await emit(41, 'receiveRegionIsChanging', {
          'center': point,
          'bounding': {'north': 48.0, 'east': 9.0, 'south': 47.0, 'west': 8.0},
        });
        await emit(41, 'receiveUserLocation', {...point, 'heading': 1.25});
        expect((await marker).value, GeoPoint.fromMap(point));
        expect((await region).value.center, GeoPoint.fromMap(point));
        expect((await location).value.angle, 1.25);
      });

      test('tracking preserves options and permission errors reach the caller',
          () async {
        await platform.enableTracking(41,
            stopFollowInDrag: true,
            disableMarkerRotation: true,
            anchor: Anchor.bottom,
            useDirectionMarker: true);
        expect(calls.single.method, 'trackMe');
        expect(
            calls.single.arguments, [true, true, true, Anchor.bottom.toMap()]);
        await expectLater(
            platform.myLocation(41), throwsA(isA<GeoPointException>()));
        await platform.disableTracking(41);
        expect(calls.last.method, 'deactivateTrackMe');
      });

      test('closing one map removes its handler while the other stays usable',
          () async {
        await platform.init(42);
        final remaining = platform.onMapIsReady(42).first;
        platform.close(41);
        // A closed map must not write to a stale event stream.
        await emit(41, 'map#init', true);
        await emit(42, 'map#init', true);
        expect((await remaining).value, isTrue);
        platform.close(42);
        await emit(42, 'map#init', true);
        await platform.init(41);
        final recreated = platform.onMapIsReady(41).first;
        await emit(41, 'map#init', true);
        expect((await recreated).value, isTrue);
      });
    });
  }
}

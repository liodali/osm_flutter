// User-location icon routing tests: the frozen routing decision (opt-in x
// host capability), the prepared payload (PNG bytes, logical size, anchors),
// legacy compatibility of `user#locationMarkers`, map isolation, disposal and
// recreation, and the reset-to-defaults route.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_map_camera.g.dart'
    as generated;
import 'package:flutter_osm_interface/src/channel/pigeon/native_user_location_icons_client.dart';

const legacyChannelName = 'plugins.dali.hamza/osmview_7';

String pigeonIconsChannel(String method) =>
    'dev.flutter.pigeon.flutter_osm_interface.NativeMapUserLocationIconsApi.'
    '$method.view_7';

const bootstrapMethod = 'map#bootstrap#protocol';

Map<Object?, Object?> bootstrapWith(List<String> capabilities) => {
      'revision': 1,
      'schemaId': 'flutter_osm.native.camera.v1',
      'capabilities': capabilities,
      'sessionToken': 'token-7',
      'generation': 0,
    };

/// Host advertising the user-location icon capability.
final Map<Object?, Object?> iconBootstrap =
    bootstrapWith(['camera', 'location.icons']);

/// Original hosts without the icon capability: icon replacement stays legacy.
final Map<Object?, Object?> legacyBootstrap = bootstrapWith(['camera']);

ByteData? pigeonReply(Object? value) =>
    const StandardMessageCodec().encodeMessage(<Object?>[value]);

ByteData? pigeonError(String code, [String? message]) =>
    const StandardMessageCodec()
        .encodeMessage(<Object?>[code, message ?? 'message', null]);

/// Test replica of the generated private codec: session envelope (129),
/// marker anchor (131), marker size (132), user-location icon (141) and the
/// icon pair (142).
class _TestPigeonCodec extends StandardMessageCodec {
  const _TestPigeonCodec();

  @override
  Object? readValueOfType(int type, ReadBuffer buffer) {
    switch (type) {
      case 129:
        return generated.NativeCameraSession.decode(readValue(buffer)!);
      case 131:
        return generated.NativeMarkerAnchor.decode(readValue(buffer)!);
      case 132:
        return generated.NativeMarkerSize.decode(readValue(buffer)!);
      case 141:
        return generated.NativeUserLocationIcon.decode(readValue(buffer)!);
      case 142:
        return generated.NativeUserLocationIcons.decode(readValue(buffer)!);
    }
    return super.readValueOfType(type, buffer);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final invocations = <String>[];

  Future<void> mockLegacy(
    Future<Object?> Function(MethodCall call) handler,
  ) async {
    TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(legacyChannelName),
      (call) async => handler(call),
    );
  }

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> mockPigeon(
    String method,
    ByteData? Function(ByteData? message) respond,
  ) async {
    messenger.setMockMessageHandler(
      pigeonIconsChannel(method),
      (ByteData? message) async => respond(message),
    );
  }

  tearDown(() {
    invocations.clear();
    messenger.setMockMethodCallHandler(
      const MethodChannel(legacyChannelName),
      null,
    );
    for (final method in ['setUserLocationIcons']) {
      messenger.setMockMessageHandler(pigeonIconsChannel(method), null);
    }
  });

  /// Pumps the two icon widgets the plugin captures and returns their keys.
  Future<(GlobalKey, GlobalKey)> pumpIcons(WidgetTester tester) async {
    final personKey = GlobalKey();
    final directionKey = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            RepaintBoundary(
              key: personKey,
              child: const ColoredBox(
                color: Color(0xFF00FF00),
                child: SizedBox(width: 12, height: 20),
              ),
            ),
            RepaintBoundary(
              key: directionKey,
              child: const ColoredBox(
                color: Color(0xFF0000FF),
                child: SizedBox(width: 8, height: 14),
              ),
            ),
          ],
        ),
      ),
    );
    return (personKey, directionKey);
  }

  group('attachUserLocationIconsRoute routing table', () {
    test('no opt-in keeps the legacy route without probing', () async {
      await mockLegacy(
        (call) async => throw Exception(
          'probe must not run when the application did not opt in',
        ),
      );
      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection =
          await osm.attachUserLocationIconsRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
      expect(osm.userLocationIconsClientFor(7), isNull);
    });

    test('icon host + opt-in activates the generated route', () async {
      await mockLegacy((call) async => iconBootstrap);
      await mockPigeon('setUserLocationIcons', (_) {
        invocations.add('pigeon:setUserLocationIcons');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachUserLocationIconsRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.generated);
      expect(
        osm.userLocationIconsClientFor(7),
        isA<PigeonUserLocationIconsClient>(),
      );
    });

    test('host without the capability keeps icon replacement legacy',
        () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        if (call.method == bootstrapMethod) return legacyBootstrap;
        return null;
      });
      await mockPigeon('setUserLocationIcons', (_) {
        invocations.add('pigeon:setUserLocationIcons');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      final selection = await osm.attachUserLocationIconsRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.legacy);
      expect(osm.userLocationIconsClientFor(7), isNull);
    });

    test('disposal unfreezes the decision for a replacement attachment',
        () async {
      await mockLegacy((call) async => iconBootstrap);
      await mockPigeon('setUserLocationIcons', (_) => pigeonReply(null));

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachUserLocationIconsRoute(7, optIn: true);
      expect(osm.userLocationIconsClientFor(7), isNotNull);

      osm.close(7);
      expect(osm.userLocationIconsClientFor(7), isNull);

      await osm.init(7);
      final selection =
          await osm.attachUserLocationIconsRoute(7, optIn: false);
      expect(selection, CameraRouteSelection.legacy);
      expect(osm.userLocationIconsClientFor(7), isNull);
    });
  });

  group('prepared icon payload', () {
    testWidgets('replacement sends PNG bytes, logical sizes and anchors',
        (tester) async {
      await mockLegacy((call) async => iconBootstrap);
      generated.NativeUserLocationIcons? received;
      await mockPigeon('setUserLocationIcons', (message) {
        final args =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        received = args[1] as generated.NativeUserLocationIcons?;
        invocations.add('pigeon:setUserLocationIcons');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachUserLocationIconsRoute(7, optIn: true);

      final (personKey, directionKey) = await pumpIcons(tester);
      await tester.runAsync(() async {
        await osm.customUserLocationMarker(
          7,
          personKey,
          directionKey,
          personAnchor: IconAnchor(anchor: Anchor.bottom),
          directionAnchor: IconAnchor(anchor: Anchor.center),
        );
      });

      // Widget rendering stays asynchronous in Dart: no legacy call happens.
      expect(invocations, ['pigeon:setUserLocationIcons']);
      final icons = received!;
      // Encoded PNG signatures, not widget objects or base64 strings.
      expect(
        icons.person.iconBytes.sublist(0, 8),
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
      );
      expect(
        icons.direction.iconBytes.sublist(0, 8),
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
      );
      // Logical (pre-scale) widget dimensions, not raw pixels.
      expect(icons.person.logicalSize!.width, 12);
      expect(icons.person.logicalSize!.height, 20);
      expect(icons.direction.logicalSize!.width, 8);
      expect(icons.direction.logicalSize!.height, 14);
      // Per-icon anchors in normalized units (legacy `Anchor.bottom`
      // encodes (0.5, 0), `Anchor.top` encodes (0.5, 1)).
      expect(icons.person.anchor!.x, 0.5);
      expect(icons.person.anchor!.y, 0.0);
      expect(icons.direction.anchor!.x, 0.5);
      expect(icons.direction.anchor!.y, 0.5);
    });

    testWidgets('omitted anchors stay null so hosts preserve the live anchor',
        (tester) async {
      await mockLegacy((call) async => iconBootstrap);
      generated.NativeUserLocationIcons? received;
      await mockPigeon('setUserLocationIcons', (message) {
        final args =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        received = args[1] as generated.NativeUserLocationIcons?;
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachUserLocationIconsRoute(7, optIn: true);

      final (personKey, directionKey) = await pumpIcons(tester);
      await tester.runAsync(() async {
        await osm.customUserLocationMarker(7, personKey, directionKey);
      });

      expect(received!.person.anchor, isNull);
      expect(received!.direction.anchor, isNull);
    });

    testWidgets('a second replacement re-sends both icons', (tester) async {
      await mockLegacy((call) async => iconBootstrap);
      final received = <generated.NativeUserLocationIcons?>[];
      await mockPigeon('setUserLocationIcons', (message) {
        final args =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        received.add(args[1] as generated.NativeUserLocationIcons?);
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachUserLocationIconsRoute(7, optIn: true);

      final (personKey, directionKey) = await pumpIcons(tester);
      await tester.runAsync(() async {
        await osm.customUserLocationMarker(7, personKey, directionKey);
        await osm.customUserLocationMarker(
          7,
          personKey,
          directionKey,
          personAnchor: IconAnchor(anchor: Anchor.top),
        );
      });

      expect(received, hasLength(2));
      expect(received[0]!.person.anchor, isNull);
      expect(received[1]!.person.anchor!.y, 1.0);
    });

    test('reset to defaults sends a null configuration', () async {
      await mockLegacy((call) async => iconBootstrap);
      final payloads = <Object?>[];
      await mockPigeon('setUserLocationIcons', (message) {
        final args =
            const _TestPigeonCodec().decodeMessage(message)! as List<Object?>;
        payloads.add(args[1]);
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachUserLocationIconsRoute(7, optIn: true);
      await osm.userLocationIconsClientFor(7)!.setUserLocationIcons(null);

      expect(payloads, [null]);
    });

    test('an unattached map keeps the platform default icons', () async {
      await mockLegacy((call) async {
        invocations.add('legacy:${call.method}');
        return null;
      });
      final osm = MethodChannelOSM();
      await osm.init(7);
      // No attach: the icon route was never selected, so nothing is sent.
      expect(osm.userLocationIconsClientFor(7), isNull);
      expect(invocations, isEmpty);
    });
  });

  group('legacy compatibility', () {
    testWidgets('legacy route keeps the base64 + size payload shape',
        (tester) async {
      Map<Object?, Object?>? args;
      await mockLegacy((call) async {
        if (call.method == 'user#locationMarkers') {
          args = call.arguments as Map<Object?, Object?>;
          invocations.add('legacy:${call.method}');
        }
        return null;
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachUserLocationIconsRoute(7, optIn: false);

      final (personKey, directionKey) = await pumpIcons(tester);
      await tester.runAsync(() async {
        await osm.customUserLocationMarker(7, personKey, directionKey);
      });

      expect(invocations, ['legacy:user#locationMarkers']);
      // Apple keeps the base64 + logical size envelope on the legacy route;
      // on Android the same capture is raw bytes. Either way the keys are
      // unchanged, so old hosts keep working.
      expect(args!.containsKey('personIcon'), isTrue);
      expect(args!.containsKey('arrowDirectionIcon'), isTrue);
    });

    test('stale sessions map through the public exception', () async {
      await mockLegacy((call) async => iconBootstrap);
      await mockPigeon(
        'setUserLocationIcons',
        (_) => pigeonError('stale_session'),
      );

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachUserLocationIconsRoute(7, optIn: true);

      await expectLater(
        osm.userLocationIconsClientFor(7)!.setUserLocationIcons(
              generated.NativeUserLocationIcons(
                person: generated.NativeUserLocationIcon(
                  iconBytes: Uint8List.fromList([1, 2, 3]),
                ),
                direction: generated.NativeUserLocationIcon(
                  iconBytes: Uint8List.fromList([4, 5, 6]),
                ),
              ),
            ),
        throwsA(isA<StaleMapSessionException>()),
      );
    });
  });

  group('map isolation', () {
    test('attachments decide per map id and keep icon routes separate',
        () async {
      final calls7 = <String>[];
      final calls8 = <String>[];
      await mockLegacy((call) async => iconBootstrap);
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.dali.hamza/osmview_8'),
        (call) async {
          invocations.add('legacy8:${call.method}');
          return call.method == bootstrapMethod ? legacyBootstrap : null;
        },
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(
          const MethodChannel('plugins.dali.hamza/osmview_8'),
          null,
        );
      });
      await mockPigeon('setUserLocationIcons', (_) {
        calls7.add('map7');
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.init(8);
      await osm.attachUserLocationIconsRoute(7, optIn: true);
      await osm.attachUserLocationIconsRoute(8, optIn: true);

      expect(osm.userLocationIconsClientFor(7), isNotNull);
      expect(osm.userLocationIconsClientFor(8), isNull);

      await osm.userLocationIconsClientFor(7)!.setUserLocationIcons(null);
      expect(calls7, ['map7']);
      expect(calls8, isEmpty);
    });
  });

  group('recreation', () {
    testWidgets('a recreated map re-attaches and sends new icons',
        (tester) async {
      await mockLegacy((call) async => iconBootstrap);
      var calls = 0;
      await mockPigeon('setUserLocationIcons', (_) {
        calls++;
        return pigeonReply(null);
      });

      final osm = MethodChannelOSM();
      await osm.init(7);
      await osm.attachUserLocationIconsRoute(7, optIn: true);
      final (personKey, directionKey) = await pumpIcons(tester);
      await tester.runAsync(() async {
        await osm.customUserLocationMarker(7, personKey, directionKey);
      });
      expect(calls, 1);

      // Dispose and recreate: the new attachment probes again and the
      // regenerated client still carries prepared icon data.
      osm.close(7);
      await osm.init(7);
      final selection = await osm.attachUserLocationIconsRoute(7, optIn: true);
      expect(selection, CameraRouteSelection.generated);
      await tester.runAsync(() async {
        await osm.customUserLocationMarker(7, personKey, directionKey);
      });
      expect(calls, 2);

      osm.close(7);
    });
  });
}

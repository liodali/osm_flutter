import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) => WidgetsApp(
  color: const Color(0xFFFFFFFF),
  pageRouteBuilder:
      <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, _, __) => builder(context),
      ),
  home: home,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'attribution and default picker pin work without a design system',
    (tester) async {
      await tester.pumpWidget(
        _app(
          const Stack(
            children: [
              AnimatedCenterMarker(),
              Align(
                alignment: Alignment.bottomCenter,
                child: CopyrightOSMWidget(),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(tester.getSize(find.byType(Image)), const Size.square(32));
      expect(
        find.textContaining('OpenStreetMap', findRichText: true),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('web default pin loads through its public package asset key', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Center(
          child: Image.asset(
            'packages/flutter_osm_web/src/asset/default_pin.png',
            width: 32,
            height: 32,
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('packages/flutter_osm_web/src/asset/default_pin.png'),
        tester.element(find.byType(Image)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final image = tester.widget<RawImage>(find.byType(RawImage));
    expect(image.image, isNotNull);
  });

  for (final dismissible in [false, true]) {
    testWidgets('neutral picker cancellation and barrier policy ($dismissible)', (
      tester,
    ) async {
      final channels = <MethodChannel>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final channel = MethodChannel(
            'plugins.dali.hamza/osmview_${call.arguments['id']}',
          );
          channels.add(channel);
          messenger.setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'map#center') return {'lat': 48.0, 'lon': 9.0};
            return null;
          });
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });
      late BuildContext context;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (ctx) {
              context = ctx;
              return const Text('Host');
            },
          ),
        ),
      );
      var closed = false;
      final result = showSimplePickerLocation(
        context: context,
        initPosition: GeoPoint(latitude: 47, longitude: 8),
        title: 'Pick a location',
        textCancelPicker: 'Annuler',
        textConfirmPicker: 'Choisir',
        isDismissible: dismissible,
      ).then((value) {
        closed = true;
        return value;
      });
      await tester.pumpAndSettle();
      expect(find.text('Pick a location'), findsOneWidget);
      expect(find.text('Choisir'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(closed, dismissible);
      if (!dismissible) {
        // WidgetsApp provides activation shortcuts; the button also participates
        // in keyboard focus traversal without Material button infrastructure.
        final button = find.ancestor(
          of: find.text('Annuler'),
          matching: find.byType(FocusableActionDetector),
        );
        Focus.of(tester.element(find.text('Annuler'))).requestFocus();
        await tester.pump();
        expect(button, findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(closed, isTrue);
      }
      expect(await result, isNull);
      if (!dismissible) {
        final confirmed = showSimplePickerLocation(
          context: context,
          initPosition: GeoPoint(latitude: 47, longitude: 8),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        final point = await confirmed;
        expect(point!.latitude, 48);
        expect(point.longitude, 9);

        await tester.pumpWidget(
          _app(
            CustomPickerLocation(
              controller: PickerMapController(
                initPosition: GeoPoint(latitude: 47, longitude: 8),
              ),
              appBarPicker: const PreferredSize(
                preferredSize: Size.fromHeight(40),
                child: Text('Neutral toolbar'),
              ),
              topWidgetPicker: const Text('Search overlay'),
              showDefaultMarkerPickWidget: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Neutral toolbar'), findsOneWidget);
        expect(find.text('Search overlay'), findsOneWidget);
        expect(find.byType(AnimatedCenterMarker), findsOneWidget);
        expect(tester.getTopLeft(find.byType(OSMFlutter)).dy, 40);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));
  }
}

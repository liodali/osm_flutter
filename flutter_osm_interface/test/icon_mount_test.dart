// Regression: an icon widget that is mounted only after the capture was
// requested — as happens for the static map's home marker while a map is
// still initializing on macOS — must still be captured, and a widget that
// never mounts must still fail, after a bounded wait.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _icon(GlobalKey key) => Directionality(
  textDirection: TextDirection.ltr,
  child: RepaintBoundary(
    key: key,
    child: const SizedBox(
      width: 12,
      height: 20,
      child: ColoredBox(color: Color(0xFF00FF00)),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an icon mounted a few frames late is captured', (tester) async {
    final key = GlobalKey();
    var frames = 0;
    final boundary = await MethodChannelOSM.awaitPaintedIcon(
      key,
      timeout: const Duration(seconds: 10),
      waitForFrame: () async {
        frames++;
        // The host app mounts the icon on the second frame.
        await tester.pumpWidget(
          frames < 2 ? const SizedBox.shrink() : _icon(key),
        );
      },
      now: tester.binding.clock.now,
    );
    expect(boundary, isA<RenderRepaintBoundary>());
    expect(boundary.debugNeedsPaint, isFalse);
    expect(frames, 2);
  });

  testWidgets('an icon that never mounts fails after the bounded wait', (
    tester,
  ) async {
    final key = GlobalKey();
    var frames = 0;
    Object? failure;
    try {
      await MethodChannelOSM.awaitPaintedIcon(
        key,
        timeout: const Duration(seconds: 3),
        waitForFrame: () async {
          frames++;
          await tester.pump(const Duration(seconds: 1));
        },
        now: tester.binding.clock.now,
      );
    } catch (error) {
      failure = error;
    }
    expect(failure.toString(), contains('Error to draw you custom icon'));
    expect(frames, 3);
  });

  test('the production wait is generous for a slow map initialization', () {
    expect(
      MethodChannelOSM.iconMountTimeout,
      greaterThanOrEqualTo(const Duration(seconds: 5)),
    );
  });
}

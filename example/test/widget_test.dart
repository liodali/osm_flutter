// Smoke test: verifies the app shell (forui theme + auto_route router) builds
// under the current forui/material_ui versions. The home route embeds a real
// OSM platform view, which plain widget tests cannot render, so assertions are
// kept to the overlay shell that MyApp provides.

import 'package:flutter_osm_plugin_example/src/common/router_config.dart';
import 'package:flutter_osm_plugin_example/src/widgets/themed_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_osm_plugin_example/main.dart';

void main() {
  testWidgets('app shell renders forui theme + router', (tester) async {
    await tester.pumpWidget(MyApp(router: AppRouter()));
    // A few frames so the router resolves the initial route and the
    // FToaster overlay attaches. Avoid pumpAndSettle: the map page runs
    // continuous animations/timers in the background.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(FToaster), findsOneWidget);
    // MyApp's root theme above FToaster + each route's ThemedWidget.
    expect(find.byType(FTheme), findsAtLeast(1));
  });

  testWidgets(
    'toast mounts below the route-level FTheme and aligns to bottom center',
    (tester) async {
      // Regression: FToaster is mounted in MyApp's MaterialApp.builder, above
      // the per-route FTheme widgets. ToasterStack's didChangeDependencies
      // reads the FAccessibilityScope (provided by FTheme) when a toast
      // mounts; without an ancestor theme this threw "Unexpected null value".
      //
      // Toasts capture their style from the calling context's theme (the
      // route-level appTheme), so this also pins the toast alignment that
      // lives in appTheme: bottom center.
      await tester.pumpWidget(
        // Mirrors MyApp's structure: theme + toaster above the routed content.
        MaterialApp(
          builder: (context, child) => FTheme(
            data: appTheme,
            child: FToaster(child: child!),
          ),
          home: FTheme(
            data: appTheme,
            child: Builder(
              builder: (context) => FButton(
                onPress: () => showFToast(
                  context: context,
                  title: const Text('regression'),
                ),
                child: const Text('show toast'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('show toast'));
      // The stack mounts + animates in on these frames; it crashed here before
      // the root FTheme was added in MyApp.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('regression'), findsOneWidget);

      // The ToasterStack's Align must resolve to the bottom center of the
      // surface, matching appTheme's toasterStyle.toastAlignment.
      final aligns = tester.widgetList<Align>(
        find.ancestor(of: find.text('regression'), matching: find.byType(Align)),
      );
      expect(
        aligns.map((a) => a.alignment.resolve(TextDirection.ltr)),
        contains(Alignment.bottomCenter),
      );
    },
  );
}

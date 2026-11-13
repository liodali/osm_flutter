import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_osm_plugin_example/src/common/router_config.dart';
import 'package:flutter_osm_plugin_example/src/common/url_strategy/url_strategy.dart'
    show usePathUrlStrategy;
import 'package:flutter_osm_plugin_example/src/services/location_storage.dart';
import 'package:flutter_osm_plugin_example/src/widgets/themed_widget.dart'
    show appTheme;
import 'package:forui/forui.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

void main() async {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  await Hive.initFlutter();
  await LocationStorage.init();
  await RouteHistoryStorage.init();
  usePathUrlStrategy();
  runApp(
    MyApp(
      router: AppRouter(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.router});
  final AppRouter router;
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router.config(),
      localizationsDelegates: const [
        ...FLocalizations.localizationsDelegates,
      ],
      builder: (context, child) => FTheme(
        // FToaster lives above the per-route FTheme widgets (ThemedWidget), so it
        // needs a theme + FAccessibilityScope of its own. Without it, ToasterStack's
        // didChangeDependencies hits a null FAccessibilityScope when a toast mounts.
        // Toasts capture their style from the calling context's theme (the
        // route-level appTheme), so this root theme shares it for consistency.
        data: appTheme,
        child: PointerInterceptor(
          child: FToaster(
            child: child!,
          ),
        ),
      ),
    );
  }
}

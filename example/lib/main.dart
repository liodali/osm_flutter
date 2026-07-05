import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin_example/src/common/router_config.dart';
import 'package:flutter_osm_plugin_example/src/common/url_strategy/url_strategy.dart'
    show usePathUrlStrategy;
import 'package:flutter_osm_plugin_example/src/services/location_storage.dart';
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
      builder: (context, child) => PointerInterceptor(
        child: FToaster(
          child: child!,
        ),
      ),
    );
  }
}

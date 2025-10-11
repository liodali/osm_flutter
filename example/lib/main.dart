import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin_example/src/common/router_config.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart'
    show usePathUrlStrategy;
import 'package:forui/forui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  runApp(MyApp(router: AppRouter()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.router});
  final AppRouter router;
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router.config(),
      theme: FThemes.zinc.dark.toApproximateMaterialTheme(),
      localizationsDelegates: const [
        ...FLocalizations.localizationsDelegates,
      ],
    );
  }
}

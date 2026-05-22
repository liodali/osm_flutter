import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin_example/src/common/router_config.dart';
import 'package:flutter_osm_plugin_example/src/common/url_strategy/url_strategy.dart'
    show usePathUrlStrategy;
import 'package:forui/forui.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

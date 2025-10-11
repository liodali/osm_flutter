import 'package:auto_route/auto_route.dart';
import 'package:flutter_osm_plugin_example/src/pages/configuration_map_widget.dart';
import 'package:flutter_osm_plugin_example/src/pages/home/home_example.dart';
import 'package:flutter_osm_plugin_example/src/pages/home/main_example.dart';
import 'package:flutter_osm_plugin_example/src/pages/simple_example_hook.dart';
import 'package:flutter_osm_plugin_example/src/pages/simple_osm.dart';

class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    NamedRouteDef(
      name: '/home',
      initial: true,
      builder: (context, _) => const MainPageExample(),
    ),
    NamedRouteDef(
      name: '/simple',
      builder: (context, _) => const SimpleOSM(),
    ),
    NamedRouteDef(
      name: '/old-home',
      builder: (context, _) => const OldMainExample(),
    ),
    NamedRouteDef(
      name: '/hook',
      builder: (context, _) => const SimpleHookExample(),
    ),
    NamedRouteDef(
      name: '/configuration',
      builder: (context, _) => const ConfigurationMapWidget(),
    ),
  ];
}

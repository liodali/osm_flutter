import 'package:auto_route/auto_route.dart';
import 'package:flutter_osm_plugin_example/src/pages/configuration_map_widget.dart';
import 'package:flutter_osm_plugin_example/src/pages/home/home_example.dart';
import 'package:flutter_osm_plugin_example/src/pages/home/main_example.dart';
import 'package:flutter_osm_plugin_example/src/pages/search_example.dart';
import 'package:flutter_osm_plugin_example/src/pages/settings_page.dart';
import 'package:flutter_osm_plugin_example/src/pages/simple_example_hook.dart';
import 'package:flutter_osm_plugin_example/src/pages/simple_osm.dart';
import 'package:flutter_osm_plugin_example/src/widgets/themed_widget.dart';

class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    NamedRouteDef(
      name: 'home',
      path: '/',
      initial: true,
      builder: (context, _) => const ThemedWidget(child: MainPageExample()),
    ),
    NamedRouteDef(
      name: 'simple',
      path: '/simple',
      builder: (context, _) => const SimpleOSM(),
    ),
    NamedRouteDef(
      name: 'old-home',
      path: '/old-home',
      builder: (context, _) => const OldMainExample(),
    ),
    NamedRouteDef(
      name: 'hook',
      path: '/hook',
      builder: (context, _) => const SimpleHookExample(),
    ),
    NamedRouteDef(
      name: 'configuration',
      path: '/configuration',
      builder: (context, _) => const ConfigurationMapWidget(),
    ),
    NamedRouteDef(
      name: 'picker-result',
      path: '/picker-result',
      builder: (context, _) => const LocationAppExample(),
    ),
    NamedRouteDef(
      name: 'search',
      path: '/search',
      builder: (context, _) => const SearchPage(),
    ),
    NamedRouteDef(
      name: 'settings',
      path: '/settings',
      builder: (context, _) => const SettingsPage(),
    ),
  ];
}

extension AppRouterExtension on StackRouter {
  Future<dynamic> pushHome() => pushPath('/home');
  Future<dynamic> pushSimple() => pushPath('/simple');
  Future<dynamic> pushOldHome() => pushPath('/old-home');
  Future<dynamic> pushSearch() => pushPath('/search');
  Future<dynamic> pushHook() => pushPath('/hook');
  Future<dynamic> pushConfiguration() => pushPath('/configuration');
  Future<dynamic> pushPickerResult() => pushPath('/picker-result');
  Future<dynamic> pushSettings() => pushPath('/settings');
}

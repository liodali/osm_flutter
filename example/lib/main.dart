import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin_example/src/pages/configuration_map_widget.dart';
import 'package:flutter_osm_plugin_example/src/pages/home/main_example.dart';
import 'package:flutter_osm_plugin_example/src/pages/search_example.dart';
import 'package:flutter_osm_plugin_example/src/pages/simple_example_hook.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart'
    show usePathUrlStrategy;
import 'package:forui/forui.dart';

import 'src/pages/home/home_example.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      //theme: ThemeData.light(useMaterial3: true),
      initialRoute: "/home",
      routes: {
        "/home": (context) => const MainPageExample(),
        "/simple": (context) => Scaffold(
          appBar: AppBar(title: const Text('simple')),
          body: OSMViewer(
            controller: SimpleMapController(
              initPosition: GeoPoint(
                latitude: 47.4358055,
                longitude: 8.4737324,
              ),
              markerHome: const MarkerIcon(icon: Icon(Icons.home)),
            ),
            zoomOption: const ZoomOption(initZoom: 16, minZoomLevel: 11),
          ),
        ),
        "/old-home": (context) => const OldMainExample(),
        "/hook": (context) => const SimpleHookExample(),
        "/configuration": (context) => const ConfigurationMapWidget(),

        //"/adv-home": (ctx) => AdvandedMainExample(),
        // "/nav": (ctx) => MyHomeNavigationPage(
        //       map: Container(),
        // ),
        "/picker-result": (context) => const LocationAppExample(),
        "/search": (context) => const SearchPage(),
      },
      theme: FThemes.zinc.dark.toApproximateMaterialTheme(),
      localizationsDelegates: const [
        ...FLocalizations.localizationsDelegates,
      ],
    );
  }
}

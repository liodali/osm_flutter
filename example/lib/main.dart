import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin_example/src/home/main_example.dart';
import 'package:flutter_osm_plugin_example/src/search_example.dart';
import 'package:flutter_osm_plugin_example/src/simple_example_hook.dart';

//import 'src/adv_home/home_example.dart';
import 'src/home/home_example.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // if (kIsWeb) {
  //   runApp(WebApp());
  // } else {
  //   await dotenv.load(fileName: ".env");
  //    runApp(MyApp());
  // }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      initialRoute: "/simple",
      routes: {
        "/home": (context) => const MainPageExample(),
        "/simple": (context) => Scaffold(
              appBar: AppBar(
                title: const Text('simple'),
              ),
              body: OSMViewer(
                controller: SimpleMapController(
                  initPosition: GeoPoint(
                    latitude: 47.4358055,
                    longitude: 8.4737324,
                  ),
                  markerHome: const MarkerIcon(
                    icon: Icon(Icons.home),
                  ),
                ),
                zoomOption: const ZoomOption(
                  initZoom: 16,
                  minZoomLevel: 11,
                ),
              ),
            ),
        "/old-home": (context) => const OldMainExample(),
        "/hook": (context) => const SimpleHookExample(),
        //"/adv-home": (ctx) => AdvandedMainExample(),
        // "/nav": (ctx) => MyHomeNavigationPage(
        //       map: Container(),
        // ),
        "/second": (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, "/old-home");
                  },
                  child: const Text("another page"),
                ),
              ),
            ),
        "/picker-result": (context) => const LocationAppExample(),
        "/search": (context) => const SearchPage(),
      },
    );
  }
}

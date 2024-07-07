import 'package:flutter/material.dart';
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
      initialRoute: "/home",
      routes: {
        "/home": (context) => const MainPageExample(),
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

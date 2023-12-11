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
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      initialRoute: "/home",
      routes: {
        "/home": (context) => MainPageExample(),
        "/old-home": (context) => OldMainExample(),
        "/hook": (context) => SimpleHookExample(),
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
                  child: Text("another page"),
                ),
              ),
            ),
        "/picker-result": (context) => LocationAppExample(),
        "/search": (context) => SearchPage(),
      },
    );
  }
}

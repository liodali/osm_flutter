import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin_example/src/search_example.dart';
import 'package:flutter_osm_plugin_example/src/simple_example_hook.dart';

//import 'src/adv_home/home_example.dart';
import 'src/home/home_example.dart';

void main() async {
  //await dotenv.load(fileName: ".env");
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: "/home",
      routes: {
        "/home": (ctx) => MainExample(),
        "/simple": (ctx) => SimpleExample(),
        //"/adv-home": (ctx) => AdvandedMainExample(),
        // "/nav": (ctx) => MyHomeNavigationPage(
        //       map: Container(),
        // ),
        "/second": (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.popAndPushNamed(ctx, "/home");
                  },
                  child: Text("another page"),
                ),
              ),
            ),
        "/picker-result": (ctx) => LocationAppExample(),
        "/search": (ctx) => SearchPage(),
      },
    );
  }
}

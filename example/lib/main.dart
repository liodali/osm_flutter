import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin_example/src/search_example.dart';

import 'src/adv_home/home_example.dart';
import 'src/home/home_example.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: "/home",
      routes: {
        "/home": (ctx) => MainExample(),
        "/adv-home": (ctx) => AdvandedMainExample(),
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

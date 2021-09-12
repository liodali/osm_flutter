import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'src/home/home_example.dart';
import 'src/search_example.dart';
import 'web_test_osm.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    runApp(WebTestOsm());
  } else {
    runApp(MyApp());
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: "/home",
      routes: {
        "/home": (ctx) => MainExample(),
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

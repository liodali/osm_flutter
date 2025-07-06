import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

class SimpleExample extends StatefulWidget {
  const SimpleExample({super.key});

  @override
  State<SimpleExample> createState() => _SimpleExampleState();
}

class _SimpleExampleState extends State<SimpleExample> {
  late PageController controller;
  late int indexPage;

  @override
  void initState() {
    super.initState();
    controller = PageController(initialPage: 1);
    indexPage = controller.initialPage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("osm"),
      ),
      body: PageView(
        controller: controller,
        onPageChanged: (p) {
          setState(() {
            indexPage = p;
          });
        },
        children: const <Widget>[
          Center(
            child: Text("page n1"),
          ),
          SimpleOSM(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: indexPage,
        onTap: (p) {
          controller.animateToPage(p,
              duration: const Duration(milliseconds: 500),
              curve: Curves.linear);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.info),
            label: "information",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts),
            label: "contact",
          ),
        ],
      ),
    );
  }
}

class SimpleOSM extends StatefulWidget {
  const SimpleOSM({super.key});

  @override
  State<StatefulWidget> createState() => SimpleOSMState();
}

class SimpleOSMState extends State<SimpleOSM>
    with AutomaticKeepAliveClientMixin {
  late MapController controller;

  @override
  void initState() {
    super.initState();
    controller = MapController(
      initMapWithUserPosition: const UserTrackingOption(),
    );
  }

  @override
  @mustCallSuper
  Widget build(BuildContext context) {
    super.build(context);
    return OSMFlutter(
      controller: controller,
      osmOption: const OSMOption(),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

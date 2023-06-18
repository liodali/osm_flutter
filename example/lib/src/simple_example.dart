import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

class SimpleExample extends StatefulWidget {
  SimpleExample({Key? key}) : super(key: key);

  @override
  _SimpleExampleState createState() => _SimpleExampleState();
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
        title: Text("osm"),
      ),
      body: PageView(
        children: <Widget>[
          Center(
            child: Text("page n1"),
          ),
          SimpleOSM(),
        ],
        controller: controller,
        onPageChanged: (p) {
          setState(() {
            indexPage = p;
          });
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: indexPage,
        onTap: (p) {
          controller.animateToPage(p,
              duration: Duration(milliseconds: 500), curve: Curves.linear);
        },
        items: [
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
      initMapWithUserPosition: UserTrackingOption(),
    );
  }

  @override
  @mustCallSuper
  Widget build(BuildContext context) {
    super.build(context);
    return OSMFlutter(
      controller: controller,
      osmOption: OSMOption(
        markerOption: MarkerOption(
          defaultMarker: MarkerIcon(
            icon: Icon(
              Icons.person_pin_circle,
              color: Colors.blue,
              size: 56,
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

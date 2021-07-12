part of osm_flutter;

class OsmWebWidget extends StatefulWidget {
  final MapController controller;

  OsmWebWidget({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  _OsmWebWidgetState createState() => _OsmWebWidgetState();
}

class _OsmWebWidgetState extends State<OsmWebWidget> {
  late WebOsmController controller;

  @override
  void initState() {
    super.initState();
    controller = WebOsmController();
    widget.controller._init(osmWebController: controller);
  }

  @override
  Widget build(BuildContext context) {
    return OsmWebPlatform.instance.buildMap(
      OsmWebPlatform.idOsmWeb,
      onPlatformViewCreated,
      controller,
    );
  }

  Future<void> onPlatformViewCreated(int id) async {
    print(id);
    // final WebTestController controller = await WebTestController.init(
    //   id,
    // );
  }
}

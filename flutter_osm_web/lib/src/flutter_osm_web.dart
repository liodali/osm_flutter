
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_web/flutter_osm_web.dart';

import 'controller/web_osm_controller.dart';



class OsmWebWidget extends StatefulWidget {
  final IBaseMapController controller;
  final OnGeoPointClicked? onGeoPointClicked;
  final OnLocationChanged? onLocationChanged;
  final ValueNotifier<bool> mapIsReadyListener;
  final Widget? mapIsLoading;
  final List<GlobalKey> globalKeys;
  final Map<String, GlobalKey> staticIconGlobalKeys;

  OsmWebWidget({
    Key? key,
    required this.controller,
    this.onGeoPointClicked,
    this.onLocationChanged,
    required this.mapIsReadyListener,
    this.mapIsLoading,
    required this.globalKeys,
    this.staticIconGlobalKeys = const {},
  }) : super(key: key);

  @override
  OsmWebWidgetState createState() => OsmWebWidgetState();
}

class OsmWebWidgetState extends State<OsmWebWidget> {
  late WebOsmController controller;

  @override
  void initState() {
    super.initState();
    controller = WebOsmController.init(this);
    if (widget.mapIsLoading == null) {
      widget.mapIsReadyListener.value = true;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: Colors.white,
          child: (OSMPlatform.instance as FlutterOsmPluginWeb).buildMap(
            OsmWebPlatform.idOsmWeb,
            onPlatformViewCreated,
            controller,
          ),
        ),
        if (widget.mapIsLoading != null)
          Positioned.fill(
            child: ValueListenableBuilder<bool>(
              valueListenable: widget.mapIsReadyListener,
              builder: (ctx, isReady, child) {
                return Visibility(
                  visible: !isReady,
                  child: child!,
                );
              },
              child: Container(
                color: Colors.white,
                child: widget.mapIsLoading!,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> onPlatformViewCreated(int id) async {
    print(id);
    widget.controller.init(controller);
    // final WebTestController controller = await WebTestController.init(
    //   id,
    // );
  }
}


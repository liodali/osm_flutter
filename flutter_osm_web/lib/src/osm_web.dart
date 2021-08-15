import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_web/flutter_osm_web.dart';

import 'controller/web_osm_controller.dart';

class OsmWebWidget extends StatefulWidget {
  final IBaseMapController controller;
  final List<StaticPositionGeoPoint> staticPoints;
  final OnGeoPointClicked? onGeoPointClicked;
  final OnLocationChanged? onLocationChanged;
  final ValueNotifier<bool> mapIsReadyListener;
  final Widget? mapIsLoading;
  final List<GlobalKey> globalKeys;
  final Map<String, GlobalKey> staticIconGlobalKeys;
  final MarkerOption? markerOption;
  final Road? road;
  final double defaultZoom;
  final bool showDefaultInfoWindow;
  final bool isPicker;
  final bool trackMyPosition;
  final ValueNotifier<Widget?> dynamicMarkerWidgetNotifier;

  OsmWebWidget({
    Key? key,
    required this.controller,
    this.onGeoPointClicked,
    this.onLocationChanged,
    required this.mapIsReadyListener,
    this.mapIsLoading,
    required this.globalKeys,
    this.staticIconGlobalKeys = const {},
    this.trackMyPosition = false,
    this.markerOption,
    this.road,
    this.defaultZoom = 1.0,
    this.showDefaultInfoWindow = false,
    this.isPicker = false,
    required this.dynamicMarkerWidgetNotifier,
    this.staticPoints = const [],
  }) : super(key: key);

  @override
  OsmWebWidgetState createState() => OsmWebWidgetState();
}

class OsmWebWidgetState extends State<OsmWebWidget> {
  late WebOsmController controller;

  GlobalKey? get defaultMarkerKey => widget.globalKeys[0];

  GlobalKey? get advancedPickerMarker => widget.globalKeys[1];

  GlobalKey? get startIconKey => widget.globalKeys[2];

  GlobalKey? get endIconKey => widget.globalKeys[3];

  GlobalKey? get middleIconKey => widget.globalKeys[4];

  GlobalKey? get dynamicMarkerKey => widget.globalKeys[5];

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
    (widget.controller as BaseMapController).setBaseOSMController(controller);
    widget.controller.init();
  }
}

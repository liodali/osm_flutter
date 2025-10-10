import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_web/flutter_osm_web.dart';
import 'package:flutter_osm_web/src/controller/web_osm_controller.dart';

class OsmWebWidget extends StatefulWidget {
  final BaseMapController controller;

  final UserTrackingOption? userTrackingOption;
  final List<StaticPositionGeoPoint> staticPoints;
  final OnGeoPointClicked? onGeoPointClicked;
  final OnGeoPointClicked? onGeoPointLongPress;
  final OnLocationChanged? onLocationChanged;
  final OnMapMoved? onMapMoved;
  final ValueNotifier<bool> mapIsReadyListener;
  final Widget? mapIsLoading;
  final List<GlobalKey> globalKeys;
  final Map<String, GlobalKey> staticIconGlobalKeys;
  final RoadOption? roadConfiguration;
  final bool showDefaultInfoWindow;
  final bool isPicker;
  final ValueNotifier<Widget?> dynamicMarkerWidgetNotifier;
  final double stepZoom;
  final double initZoom;
  final double minZoomLevel;
  final double maxZoomLevel;
  final Function(bool)? onMapIsReady;
  final UserLocationMaker? userLocationMarker;
  final bool isStatic;
  const OsmWebWidget({
    super.key,
    required this.controller,
    this.userTrackingOption,
    this.onGeoPointClicked,
    this.onGeoPointLongPress,
    this.onLocationChanged,
    this.onMapMoved,
    required this.mapIsReadyListener,
    this.mapIsLoading,
    required this.globalKeys,
    this.staticIconGlobalKeys = const {},
    this.roadConfiguration,
    this.showDefaultInfoWindow = false,
    this.isPicker = false,
    required this.dynamicMarkerWidgetNotifier,
    this.staticPoints = const [],
    this.stepZoom = 1.0,
    this.initZoom = 2,
    this.minZoomLevel = 2,
    this.maxZoomLevel = 18,
    this.onMapIsReady,
    this.userLocationMarker,
    this.isStatic = false,
  });

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

  GlobalKey get personIconMarkerKey => widget.globalKeys[6];

  GlobalKey get arrowDirectionMarkerKey => widget.globalKeys[7];
  final keyWidget = GlobalKey();
  late Future<void> _future;
  ValueNotifier<({String mapScript, String osmInterop, String html})?>
      dataScripts = ValueNotifier(null);
  @override
  void initState() {
    super.initState();
    _future = initController();
    if (widget.mapIsLoading == null) {
      widget.mapIsReadyListener.value = false;
    }
  }

  Future<void> initController() async {
    const versionCDN = 'refs/tags/flutter_osm_web-v1.4.2';
    //kReleaseMode ? 'refs/tags/flutter_osm_web-v1.4.1' : 'refs/heads/main';
    final dio = Dio(BaseOptions(
      baseUrl:
          'https://raw.githubusercontent.com/liodali/osm_flutter/$versionCDN/flutter_osm_web/lib/src/asset/',
    ));
    final mapScript = await dio.get<String>(
      'map.js',
    );
    final osmInterop = await dio.get<String>(
      'osm_interop.js',
    );
    final html = await dio.get<String>('map.html');
    dataScripts.value = (
      mapScript: mapScript.data!,
      osmInterop: osmInterop.data!,
      html: html.data!,
    );
    controller = WebOsmController(dataScripts.value!.html);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return HtmlElementView(
            key: keyWidget,
            viewType: FlutterOsmPluginWeb.getViewType(mapId),
            onPlatformViewCreated: onPlatformViewCreated,
          );
        }
        return const Center(child: CircularProgressIndicator.adaptive());
      },
    );
  }

  Future<void> onPlatformViewCreated(int id) async {
    controller.init(this, id);
    controller.onListenToNativeChannel();
    controller.createHtml(
      dataScripts.value!.mapScript,
      dataScripts.value!.osmInterop,
    );
    //controller.addObserver(this);
    (OSMPlatform.instance as FlutterOsmPluginWeb).setWebMapController(
      mapId,
      controller,
    );
    widget.controller.setBaseOSMController(controller);
    widget.controller.init();
  }
}

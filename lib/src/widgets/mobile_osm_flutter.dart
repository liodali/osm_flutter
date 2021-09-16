import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:location/location.dart';

import '../controller/osm/osm_controller.dart';

class MobileOsmFlutter extends StatefulWidget {
  final BaseMapController controller;
  final OnGeoPointClicked? onGeoPointClicked;
  final OnLocationChanged? onLocationChanged;
  final ValueNotifier<bool> mapIsReadyListener;
  final Widget? mapIsLoading;
  final bool trackMyPosition;
  final List<StaticPositionGeoPoint> staticPoints;
  final List<GlobalKey> globalKeys;
  final Map<String, GlobalKey> staticIconGlobalKeys;
  final MarkerOption? markerOption;
  final Road? road;
  final bool showDefaultInfoWindow;
  final bool isPicker;
  final bool showContributorBadgeForOSM;
  final bool showZoomController;
  final ValueNotifier<Widget?> dynamicMarkerWidgetNotifier;
  final double stepZoom;
  final double initZoom;
  final int minZoomLevel;
  final int maxZoomLevel;
  final Function(bool)? onMapIsReady;
  final UserLocationMaker? userLocationMarker;

  MobileOsmFlutter({
    Key? key,
    required this.controller,
    this.trackMyPosition = false,
    this.onGeoPointClicked,
    this.onLocationChanged,
    required this.mapIsReadyListener,
    required this.dynamicMarkerWidgetNotifier,
    this.staticPoints = const [],
    this.mapIsLoading,
    required this.globalKeys,
    required this.staticIconGlobalKeys,
    this.markerOption,
    this.road,
    this.showZoomController = false,
    this.showDefaultInfoWindow = false,
    this.isPicker = false,
    this.showContributorBadgeForOSM = false,
    this.stepZoom = 1.0,
    this.initZoom = 2,
    this.minZoomLevel = 2,
    this.maxZoomLevel = 18,
    this.onMapIsReady,
    this.userLocationMarker,
  }) : super(key: key);

  @override
  MobileOsmFlutterState createState() => MobileOsmFlutterState();
}

class MobileOsmFlutterState extends State<MobileOsmFlutter> {
  MobileOSMController? _osmController;
  final mobileKey = GlobalKey();

//permission status
  PermissionStatus? _permission;

  GlobalKey get defaultMarkerKey => widget.globalKeys[0];

  GlobalKey get advancedPickerMarker => widget.globalKeys[1];

  GlobalKey get startIconKey => widget.globalKeys[2];

  GlobalKey get endIconKey => widget.globalKeys[3];

  GlobalKey get middleIconKey => widget.globalKeys[4];

  GlobalKey get dynamicMarkerKey => widget.globalKeys[5];

  GlobalKey get personIconMarkerKey => widget.globalKeys[6];

  GlobalKey get arrowDirectionMarkerKey => widget.globalKeys[7];
  late Widget widgetMap;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      //check location permission
      if (((widget.controller).initMapWithUserPosition ||
          widget.trackMyPosition)) {
        await requestPermission();
        if (widget.controller.initMapWithUserPosition) {
          bool isEnabled = await _osmController!.checkServiceLocation();
          Future.delayed(Duration(seconds: 1), () async {
            if (isEnabled) {
              return;
            }
            //await _osmController!.currentLocation();
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    widgetMap = AndroidView(
      key: GlobalKey(),
      viewType: 'plugins.dali.hamza/osmview',
      onPlatformViewCreated: _onPlatformViewCreated,
      //creationParamsCodec:  StandardMessageCodec(),
    );
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      widgetMap = UiKitView(
        key: mobileKey,
        viewType: 'plugins.dali.hamza/osmview',
        onPlatformViewCreated: _onPlatformViewCreated,
        //creationParamsCodec:  StandardMessageCodec(),
      );
    }
    return widgetMap;
  }

  /// requestPermission callback to request location in your phone
  Future<bool> requestPermission() async {
    Location location = new Location();

    _permission = await location.hasPermission();
    if (_permission == PermissionStatus.denied) {
      //request location permission
      _permission = await location.requestPermission();
      if (_permission == PermissionStatus.granted) {
        return true;
      }
      return false;
    } else if (_permission == PermissionStatus.granted) {
      return true;
      //  if (widget.currentLocation) await _checkServiceLocation();
    }
    return false;
  }

  Future<bool> checkService() async {
    return await _osmController!.checkServiceLocation();
  }

  void _onPlatformViewCreated(int id) async {
    this._osmController = await MobileOSMController.init(id, this);
    widget.controller.setBaseOSMController(this._osmController!);
    widget.controller.init();
  }
}

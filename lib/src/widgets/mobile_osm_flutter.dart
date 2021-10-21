import 'dart:io';

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
  final double minZoomLevel;
  final double maxZoomLevel;
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

class MobileOsmFlutterState extends State<MobileOsmFlutter>
    with WidgetsBindingObserver, AndroidLifecycleMixin {
  MobileOSMController? _osmController;
  var mobileKey = GlobalKey();
  GlobalKey androidKey = GlobalKey();

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
  late ValueNotifier<Orientation> orientation;
  bool setCache = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addObserver(this);
    Future.delayed(Duration.zero, () async {
      orientation = ValueNotifier(
          Orientation.values[MediaQuery.of(context).orientation.index]);
      orientation.addListener(changeOrientationDetected);

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

  void changeOrientationDetected() async {
    if (Platform.isAndroid) {
      configChanded();
    }
  }

  @override
  void dispose() {
    orientation.removeListener(changeOrientationDetected);
    WidgetsBinding.instance?.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance?.addPostFrameCallback((timeStamp) async {
      final nIndex = MediaQuery.of(context).orientation.index;
      orientation.value = Orientation.values[nIndex];
    });
  }

  @override
  bool get mounted => super.mounted;

  @override
  void didUpdateWidget(covariant MobileOsmFlutter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (this.widget != oldWidget && Platform.isAndroid) {
      setState(() {
        androidKey = GlobalKey();
      });
    }
  }

  @override
  void configChanded() async {
    await _osmController!.saveCacheMap();
    setState(() {
      mobileKey = GlobalKey();
      setCache = true;
    });
  }

  @override
  void mapIsReady(bool isReady) async {
    await widget.controller.osMMixin?.mapIsReady(isReady);
    if (setCache) {
      await _osmController!.setCacheMap();
      setState(() {
        setCache = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlatformView(
      mobileKey: mobileKey,
      androidKey: androidKey,
      onPlatformCreatedView: _onPlatformViewCreated,
    );
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
    _osmController!.addObserver(this);
    widget.controller.setBaseOSMController(this._osmController!);
    widget.controller.init();
  }
}

class PlatformView extends StatelessWidget {
  final Function(int) onPlatformCreatedView;
  final Key? mobileKey;
  final Key? androidKey;

  const PlatformView({
    this.mobileKey,
    this.androidKey,
    required this.onPlatformCreatedView,
  }) : super(key: mobileKey);

  @override
  Widget build(BuildContext context) {
    Widget widgetMap = AndroidView(
      key: androidKey,
      viewType: 'plugins.dali.hamza/osmview',
      onPlatformViewCreated: onPlatformCreatedView,
      //creationParamsCodec:  StandardMessageCodec(),
    );
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      widgetMap = UiKitView(
        //  key: mobileKey,
        viewType: 'plugins.dali.hamza/osmview',
        onPlatformViewCreated: onPlatformCreatedView,
        //creationParamsCodec:  StandardMessageCodec(),
      );
    }
    return widgetMap;
  }
}

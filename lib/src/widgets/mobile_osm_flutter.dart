import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

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
  final RoadConfiguration? roadConfig;
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
  final bool androidHotReloadSupport;

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
    this.roadConfig,
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
    this.androidHotReloadSupport = false,
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
  late String keyUUID;
  late Widget widgetMap;
  late ValueNotifier<Orientation> orientation;
  late ValueNotifier<Size> sizeNotifier;
  ValueNotifier<bool> setCache = ValueNotifier(false);
  ValueNotifier<bool> isFirstLaunched = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    keyUUID = Uuid().v4();
    WidgetsBinding.instance?.addObserver(this);
    Future.delayed(Duration.zero, () async {
      orientation = ValueNotifier(Orientation.values[MediaQuery.of(context).orientation.index]);
      orientation.addListener(changeOrientationDetected);

      sizeNotifier = ValueNotifier(MediaQuery.of(context).size);
      sizeNotifier.addListener(changeOrientationDetected);

      //check location permission
      if (((widget.controller).initMapWithUserPosition || widget.trackMyPosition)) {
        await requestPermission();
        // if (widget.controller.initMapWithUserPosition) {
        //   bool isEnabled = await _osmController!.checkServiceLocation();
        //   Future.delayed(Duration(seconds: 1), () async {
        //     if (isEnabled) {
        //       return;
        //     }
        //     //await _osmController!.currentLocation();
        //   });
        // }
      }
    });
  }

  void changeOrientationDetected() async {
    if (Platform.isAndroid) {
      configChanged();
    }
  }

  void changeSizeDetected() async {
    if (Platform.isAndroid) {
      configChanged();
    }
  }

  @override
  void dispose() {
    Future.microtask(() async => await _osmController?.removeCacheMap());
    orientation.removeListener(changeOrientationDetected);
    WidgetsBinding.instance?.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (Platform.isAndroid && isFirstLaunched.value) {
      WidgetsBinding.instance?.addPostFrameCallback((timeStamp) async {
        if (isFirstLaunched.value) {
          final nIndex = MediaQuery.of(context).orientation.index;
          if (orientation.value != Orientation.values[nIndex]) {
            setCache.value = true;
            orientation.value = Orientation.values[nIndex];
          } else {
            if (sizeNotifier.value != MediaQuery.of(context).size) {
              sizeNotifier.value = MediaQuery.of(context).size;
            }
          }
        }
      });
    }
  }

  @override
  bool get mounted => super.mounted;

  @override
  void didUpdateWidget(covariant MobileOsmFlutter oldWidget) {
    if (Platform.isAndroid && isFirstLaunched.value) {
      if (!setCache.value) {
        setCache.value = true;
        Future.microtask(() async => await _osmController?.saveCacheMap());
      }
    }
    super.didUpdateWidget(oldWidget);
    if (this.widget != oldWidget &&
        Platform.isAndroid &&
        widget.androidHotReloadSupport &&
        kDebugMode) {
      setState(() {
        androidKey = GlobalKey();
      });
    }
  }

  @override
  void configChanged() async {
    setState(() {
      mobileKey = GlobalKey();
      androidKey = GlobalKey();
    });
  }

  @override
  void mapIsReady(bool isReady) async {
    if (!setCache.value) {
      Future.delayed(Duration(milliseconds: 300), () async {
        await widget.controller.osMMixin?.mapIsReady(isReady);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlatformView(
      mobileKey: mobileKey,
      androidKey: androidKey,
      onPlatformCreatedView: _onPlatformViewCreated,
      uuidMapCache: keyUUID,
    );
  }

  /// requestPermission
  /// this callback has role to request location permission in your phone in android Side
  /// for iOS it's done manually
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final locationStatus = await Permission.location.request();
      if (locationStatus.isGranted) {
        return true;
      } else if (locationStatus.isDenied) {
        return false;
      }
    }
    // _permission = await location.hasPermission();
    // if (_permission == PermissionStatus.denied) {
    //   //request location permission
    //   _permission = await location.requestPermission();
    //   if (_permission == PermissionStatus.granted) {
    //     return true;
    //   }
    //   return false;
    // } else if (_permission == PermissionStatus.granted) {
    //   return true;
    //   //  if (widget.currentLocation) await _checkServiceLocation();
    // }
    return false;
  }

  // Future<bool> checkService() async {
  //   return await _osmController!.checkServiceLocation();
  // }

  void _onPlatformViewCreated(int id) async {
    this._osmController = await MobileOSMController.init(id, this);
    _osmController!.addObserver(this);
    widget.controller.setBaseOSMController(this._osmController!);
    widget.controller.init();
    if (!isFirstLaunched.value) {
      isFirstLaunched.value = true;
    }
  }
}

class PlatformView extends StatelessWidget {
  final Function(int) onPlatformCreatedView;
  final Key? mobileKey;
  final Key? androidKey;
  final String uuidMapCache;

  const PlatformView({
    this.mobileKey,
    this.androidKey,
    required this.onPlatformCreatedView,
    required this.uuidMapCache,
  }) : super(key: mobileKey);

  @override
  Widget build(BuildContext context) {
    Widget widgetMap = AndroidView(
      key: androidKey,
      viewType: 'plugins.dali.hamza/osmview',
      onPlatformViewCreated: onPlatformCreatedView,
      creationParams: uuidMapCache,
      //creationParamsCodec: null,
      creationParamsCodec: StandardMethodCodec().messageCodec,
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

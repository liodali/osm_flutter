import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/src/common/osm_option.dart';
import 'package:flutter_osm_plugin/src/controller/simple_map_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_osm_plugin/src/controller/osm/osm_controller.dart';

typedef MobileInitConfiguration = ({
  CustomTile? customTile,
  List<double>? bounds,
  bool enableRotationGesture,
  GeoPoint? initlocation,
  bool userlocation,
  ZoomOption zoomOption,
  bool isStaticMap,
});

class MobileOsmFlutter extends StatefulWidget {
  final BaseMapController controller;
  final UserTrackingOption? userTrackingOption;
  final OnGeoPointClicked? onGeoPointClicked;
  final OnGeoPointClicked? onGeoPointLongPress;
  final OnLocationChanged? onLocationChanged;
  final OnMapMoved? onMapMoved;
  final ValueNotifier<bool> mapIsReadyListener;
  final Widget? mapIsLoading;
  final List<StaticPositionGeoPoint> staticPoints;
  final List<GlobalKey> globalKeys;
  final Map<String, GlobalKey> staticIconGlobalKeys;
  final RoadOption? roadConfig;
  final bool showDefaultInfoWindow;
  final bool isPicker;
  final bool showContributorBadgeForOSM;
  final bool showZoomController;
  final ValueNotifier<Widget?> dynamicMarkerWidgetNotifier;
  final Function(bool)? onMapIsReady;
  final UserLocationMaker? userLocationMarker;
  final bool enableRotationByGesture;
  final ZoomOption zoomOption;
  const MobileOsmFlutter({
    super.key,
    required this.controller,
    this.userTrackingOption,
    this.onGeoPointClicked,
    this.onGeoPointLongPress,
    this.onLocationChanged,
    this.onMapMoved,
    required this.mapIsReadyListener,
    required this.dynamicMarkerWidgetNotifier,
    this.staticPoints = const [],
    this.mapIsLoading,
    required this.globalKeys,
    required this.staticIconGlobalKeys,
    this.roadConfig,
    this.showZoomController = false,
    this.showDefaultInfoWindow = false,
    this.isPicker = false,
    this.showContributorBadgeForOSM = false,
    this.zoomOption = const ZoomOption(),
    this.onMapIsReady,
    this.userLocationMarker,
    this.enableRotationByGesture = false,
  });

  @override
  MobileOsmFlutterState createState() => MobileOsmFlutterState();
}

class MobileOsmFlutterState extends State<MobileOsmFlutter>
    with WidgetsBindingObserver, AndroidLifecycleMixin {
  MobileOSMController? _osmController;

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
  late ValueNotifier<Size> sizeNotifier;
  late ValueNotifier<bool> isFirstLaunched;

  @override
  void initState() {
    super.initState();
    keyUUID = const Uuid().v4();
    isFirstLaunched = ValueNotifier(false);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void mapIsReady(bool isReady) async {
    Future.delayed(const Duration(milliseconds: 300), () async {
      Future.forEach(widget.controller.osMMixins, (osmMixin) async {
        await osmMixin.mapIsReady(isReady);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return PlatformView(
      onPlatformCreatedView: _onPlatformViewCreated,
      uuidMapCache: keyUUID,
      configuration: (
        customTile: widget.controller.customTile,
        bounds: widget.controller.areaLimit?.toIOSList(),
        zoomOption: widget.zoomOption,
        enableRotationGesture: widget.enableRotationByGesture,
        initlocation: widget.controller.initPosition,
        userlocation: widget.userTrackingOption?.initWithUserPosition ?? false,
        isStaticMap: widget.controller is SimpleMapController,
      ),
    );
  }

  /// [requestPermission]
  ///
  /// this callback has role to request location permission in your phone in android Side
  /// for iOS it's done manually
  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final locationStatus = await Permission.location.request();
      if (locationStatus.isGranted) {
        return true;
      } else if (locationStatus.isDenied) {
        return false;
      }
    }
    return true;
  }

  // Future<bool> checkService() async {
  //   return await _osmController!.checkServiceLocation();
  // }

  void _onPlatformViewCreated(int id) async {
    _osmController = await MobileOSMController.init(id, this);
    _osmController!.addObserver(this);
    widget.controller.setBaseOSMController(_osmController!);
    if ((widget.controller).initMapWithUserPosition != null) {
      await requestPermission();
    }
    widget.controller.init();
    _osmController!.onListenChannel();
    if (!isFirstLaunched.value) {
      isFirstLaunched.value = true;
    }
  }
}

class PlatformView extends StatelessWidget {
  final Function(int) onPlatformCreatedView;
  final String uuidMapCache;
  final MobileInitConfiguration configuration;
  const PlatformView({
    super.key,
    required this.onPlatformCreatedView,
    required this.uuidMapCache,
    required this.configuration,
  }); //: super(key: mobileKey);

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: 'plugins.dali.hamza/osmview',
        onPlatformViewCreated: onPlatformCreatedView,
        creationParams: getParams(
          configuration.customTile,
          bounds: configuration.bounds,
          enableRotationGesture: configuration.enableRotationGesture,
          initlocation: configuration.initlocation,
          userlocation: configuration.userlocation,
          zoomOption: configuration.zoomOption,
          isStaticMap: configuration.isStaticMap,
        ),
        creationParamsCodec: const StandardMethodCodec().messageCodec,
      );
    }
    return AndroidView(
      //key: androidKey,
      viewType: 'plugins.dali.hamza/osmview',
      onPlatformViewCreated: onPlatformCreatedView,
      creationParams: getParams(
        configuration.customTile,
        bounds: configuration.bounds,
        enableRotationGesture: configuration.enableRotationGesture,
        initlocation: configuration.initlocation,
        userlocation: configuration.userlocation,
        zoomOption: configuration.zoomOption,
        isStaticMap: configuration.isStaticMap,
      ),
      //creationParamsCodec: null,
      creationParamsCodec: const StandardMethodCodec().messageCodec,
    );
  }

  Map getParams(
    CustomTile? customTile, {
    List<double>? bounds,
    bool isStaticMap = false,
    bool enableRotationGesture = false,
    GeoPoint? initlocation,
    bool userlocation = false,
    ZoomOption zoomOption = const ZoomOption(),
  }) {
    final Map<String, dynamic> params = {
      "uuid": uuidMapCache,
    };
    if (customTile != null) {
      params.putIfAbsent("customTile", () => customTile.toMap());
    }

    if (bounds != null) {
      params.putIfAbsent("bounds", () => bounds);
    }
    params.putIfAbsent("enableRotationGesture", () => enableRotationGesture);
    if (initlocation != null) {
      params.putIfAbsent("location", () => initlocation.toMap());
    }
    if (userlocation) {
      params.putIfAbsent("userlocation", () => userlocation);
    }
    params.putIfAbsent("zoomOption", () => zoomOption.toMap);

    params.putIfAbsent("isStaticMap", () => isStaticMap);

    return params;
  }
}

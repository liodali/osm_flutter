part of osm_flutter;

typedef OnGeoPointClicked = void Function(GeoPoint);
typedef OnLocationChanged = void Function(GeoPoint);

/// Principal widget to show OSMMap using osm api
/// you can track you current location,show static points like position of your stores
/// show road between 2 points
/// [isPicker] : (bool) if is true, map will behave as picker and will start advanced picker
///
/// [trackMyPosition] : (bool) if is true, map will track your location
///
/// [mapIsLoading]   :(Widget) show custom  widget when the map finish initialization
///
/// [showZoomController] : (bool) if us true, you can zoomIn zoomOut directly in the map
///
/// [staticPoints] : (List<StaticPositionGeoPoint>) if you have static point that  you want to show,like static of taxi or location of your stores
///
/// [onGeoPointClicked] : (callback) is trigger when you clicked on marker,return current  geoPoint of the Marker
///
/// [onLocationChanged] : (callback) it's hire when you activate tracking and  user position has been changed
///
/// [markerOption] :  contain marker of geoPoint and customisation of advanced picker marker
///
/// [userLocationMarker] : change user marker or direction marker icon in tracking location
///
/// [road] : set color and icons marker of road
///
/// [defaultZoom] : set default zoom value (default = 1)
///
/// [showDefaultInfoWindow] : (bool) enable/disable default infoWindow of marker (default = false)
///
/// [showContributorBadgeForOSM] : (bool) for copyright of osm, we need to add badge in bottom of the map (default false)
class OSMFlutter extends StatefulWidget {
  final BaseMapController controller;
  final bool trackMyPosition;
  final bool showZoomController;
  final Widget? mapIsLoading;
  final List<StaticPositionGeoPoint> staticPoints;
  final OnGeoPointClicked? onGeoPointClicked;
  final OnLocationChanged? onLocationChanged;
  final MarkerOption? markerOption;
  final UserLocationMaker? userLocationMarker;
  final Road? road;
  final double defaultZoom;
  final bool showDefaultInfoWindow;
  final bool isPicker;
  final bool showContributorBadgeForOSM;

  OSMFlutter({
    Key? key,
    required this.controller,
    this.mapIsLoading,
    this.trackMyPosition = false,
    this.showZoomController = false,
    this.staticPoints = const [],
    this.markerOption,
    this.userLocationMarker,
    this.onGeoPointClicked,
    this.onLocationChanged,
    this.road,
    this.defaultZoom = 1.0,
    this.showDefaultInfoWindow = false,
    this.isPicker = false,
    this.showContributorBadgeForOSM = false,
  }) : super(key: key);

  @override
  OSMFlutterState createState() => OSMFlutterState();
}

class OSMFlutterState extends State<OSMFlutter> {
  GlobalKey androidViewKey = GlobalKey();
  OSMController? _osmController;
  ValueNotifier<Widget?> dynamicMarkerWidgetNotifier = ValueNotifier(null);
  ValueNotifier<bool> mapIsReadyListener = ValueNotifier(false);

  //permission status
  PermissionStatus? _permission;

  //_OsmCreatedCallback _osmCreatedCallback;
  late GlobalKey defaultMarkerKey,
      advancedPickerMarker,
      startIconKey,
      endIconKey,
      middleIconKey,
      dynamicMarkerKey,
      personIconMarkerKey,
      arrowDirectionMarkerKey;
  late Map<String, GlobalKey> staticMarkersKeys;

  @override
  void initState() {
    super.initState();
    if (widget.staticPoints.isNotEmpty && widget.staticPoints.length > 1) {
      List<String> ids = [];
      for (int i = 0; i < widget.staticPoints.length; i++) {
        ids.add(widget.staticPoints[i].id);
      }

      ids.asMap().forEach((i, id) {
        var count = ids.where((_id) => id == _id).length;
        if (count > 1) {
          assert(false, "you have duplicated ids for static points");
        }
      });
    }
    dynamicMarkerKey = GlobalKey();
    defaultMarkerKey = GlobalKey();
    advancedPickerMarker = GlobalKey();
    startIconKey = GlobalKey();
    endIconKey = GlobalKey();
    middleIconKey = GlobalKey();
    personIconMarkerKey = GlobalKey();
    arrowDirectionMarkerKey = GlobalKey();
    staticMarkersKeys = {};
    widget.staticPoints.forEach((gs) {
      staticMarkersKeys.putIfAbsent(gs.id, () => GlobalKey());
    });
    Future.delayed(Duration.zero, () async {
      //check location permission
      if ((widget.controller).initMapWithUserPosition ||
          widget.trackMyPosition) {
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
  void didUpdateWidget(covariant OSMFlutter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (this.widget != oldWidget) {}
  }

  @override
  void dispose() {
    //this._osmController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget widgetMap = AndroidView(
      key: androidViewKey,
      viewType: 'plugins.dali.hamza/osmview',
      onPlatformViewCreated: _onPlatformViewCreated,
      //creationParamsCodec:  StandardMessageCodec(),
    );
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      widgetMap = UiKitView(
        viewType: 'plugins.dali.hamza/osmview',
        onPlatformViewCreated: _onPlatformViewCreated,
        //creationParamsCodec:  StandardMessageCodec(),
      );
    } else if (kIsWeb) {
      return Text(
          '$defaultTargetPlatform is not yet supported by the osm plugin');
    }
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        widgetConfigMap(),
        Container(
          color: Colors.white,
          child: widget.mapIsLoading != null
              ? Stack(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: mapIsReadyListener,
                      builder: (ctx, isReady, _) {
                        return Opacity(
                          opacity: isReady ? 1.0 : 0.0,
                          child: widgetMap,
                        );
                      },
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: mapIsReadyListener,
                      builder: (ctx, isReady, child) {
                        return Visibility(
                          visible: !isReady,
                          child: child!,
                        );
                      },
                      child: widget.mapIsLoading!,
                    ),
                  ],
                )
              : widgetMap,
        ),
        if (widget.showContributorBadgeForOSM) ...[
          Positioned(
            bottom: 0,
            right: 5,
            child: CopyrightOSMWidget(),
          ),
        ],
      ],
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

  Widget widgetConfigMap() {
    return Positioned(
      top: 0,
      bottom: 0,
      left: 0,
      right: 0,
      child: Stack(
        children: <Widget>[
          ValueListenableBuilder<Widget?>(
            valueListenable: dynamicMarkerWidgetNotifier,
            builder: (ctx, widget, child) {
              if (widget == null) {
                return SizedBox.fromSize();
              }
              return RepaintBoundary(
                key: dynamicMarkerKey,
                child: widget,
              );
            },
          ),
          if ((widget.markerOption?.defaultMarker != null)) ...[
            RepaintBoundary(
              key: defaultMarkerKey,
              child: widget.markerOption!.defaultMarker!,
            ),
          ],
          if (widget.markerOption?.advancedPickerMarker != null) ...[
            RepaintBoundary(
              key: advancedPickerMarker,
              child: widget.markerOption?.advancedPickerMarker,
            ),
          ],
          if (widget.staticPoints.isNotEmpty) ...[
            for (int i = 0; i < widget.staticPoints.length; i++) ...[
              RepaintBoundary(
                key: staticMarkersKeys[widget.staticPoints[i].id],
                child: widget.staticPoints[i].markerIcon,
              ),
            ]
          ],
          if (widget.road?.endIcon != null) ...[
            RepaintBoundary(
              key: endIconKey,
              child: widget.road!.endIcon,
            ),
          ],
          if (widget.road?.startIcon != null) ...[
            RepaintBoundary(
              key: startIconKey,
              child: widget.road!.startIcon,
            ),
          ],
          if (widget.road?.middleIcon != null) ...[
            RepaintBoundary(
              key: middleIconKey,
              child: widget.road!.middleIcon,
            ),
          ],
          if (widget.userLocationMarker?.personMarker != null) ...[
            RepaintBoundary(
              key: personIconMarkerKey,
              child: widget.userLocationMarker?.personMarker,
            ),
          ],
          if (widget.userLocationMarker?.directionArrowMarker != null) ...[
            RepaintBoundary(
              key: arrowDirectionMarkerKey,
              child: widget.userLocationMarker?.directionArrowMarker,
            ),
          ],
        ],
      ),
    );
  }

  void _onPlatformViewCreated(int id) async {
    this._osmController = await OSMController.init(id, this);
    widget.controller._init(this._osmController!);
  }
}

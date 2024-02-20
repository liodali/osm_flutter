import 'package:flutter_osm_interface/flutter_osm_interface.dart';

/// [OSMOption]
///
/// this class is use to customize and configure the osm map
///
/// [isPicker] : (bool) if is true, map will behave as picker and will start advanced picker
///
/// [userTrackingOption] : (UserTrackingOption?) if is not null, used to paramter tracking of user location where you can disable/enable follow user
///
/// [showZoomController] : (bool) if us true, you can zoomIn zoomOut directly in the map
///
/// [staticPoints] : (List<StaticPositionGeoPoint>) if you have static point that  you want to show,like static of taxi or location of your stores
///
/// [markerOption] :  contain marker of geoPoint and customisation of advanced picker marker
///
/// [userLocationMarker] : change user marker or direction marker icon in tracking location
///
/// [roadConfiguration] : (RoadConfiguration) set color and icons marker of road
///
/// [showDefaultInfoWindow] : (bool) enable/disable default infoWindow of marker (default = false)
///
/// [showContributorBadgeForOSM] : (bool) for copyright of osm, we need to add badge in bottom of the map (default false)

class OSMOption {
  const OSMOption({
    this.showZoomController = false,
    this.staticPoints = const [],
    this.userLocationMarker,
    this.roadConfiguration,
    this.zoomOption = const ZoomOption(),
    this.enableRotationByGesture = true,
    this.showDefaultInfoWindow = false,
    this.isPicker = false,
    this.showContributorBadgeForOSM = false,
    this.userTrackingOption,
  });
  final bool showZoomController;
  final List<StaticPositionGeoPoint> staticPoints;
  final UserLocationMaker? userLocationMarker;
  final RoadOption? roadConfiguration;
  final ZoomOption zoomOption;
  final bool enableRotationByGesture;
  final bool showDefaultInfoWindow;
  final bool isPicker;
  final bool showContributorBadgeForOSM;
  final UserTrackingOption? userTrackingOption;
}

/// [ZoomOption]
///
/// this class used to customize the zoom for osm map
///
/// [stepZoom] : set default step zoom value (default = 1)
///
/// [initZoom] : set initialized zoom in specific location  (default = 2)
///
/// [minZoomLevel] : set default zoom value (default = 1)
///
/// [maxZoomLevel] : set default zoom value (default = 1)
class ZoomOption {
  const ZoomOption({
    this.stepZoom = 1,
    this.initZoom = 2,
    this.minZoomLevel = 2,
    this.maxZoomLevel = 19,
  })  : assert(maxZoomLevel <= 19),
        assert(minZoomLevel >= 2),
        assert(initZoom >= minZoomLevel || initZoom <= maxZoomLevel);

  /// the default step zoom of map when zoomIn or zoomOut (default = 1)
  final double stepZoom;

  /// the initialized zoom in when initializing the map  (default = 2)
  final double initZoom;

  /// the minimum zoom level of the osm map
  final double minZoomLevel;

  /// the maximum zoom level of the osm map
  final double maxZoomLevel;

  Map<String, int> get toMap => {
    "stepZoom":stepZoom.toInt(),
    "initZoom":initZoom.toInt(),
    "minZoom":minZoomLevel.toInt(),
    "maxZoom":maxZoomLevel.toInt(),
  };
}

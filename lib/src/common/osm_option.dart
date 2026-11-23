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
/// [staticPoints] : [List<StaticPositionGeoPoint>] if you have static point that  you want to show,like static of taxi or location of your stores
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
    this.useTypedCameraRoute = false,
    this.useTypedMarkers = false,
    this.useTypedLayers = false,
    this.useTypedShapes = false,
    this.useTypedRoads = false,
    this.useTypedLocation = false,
    this.useTypedLocationUpdates = false,
    this.useTypedTracking = false,
    this.useTypedLocationIcons = false,
    this.useTypedLifecycleEvents = false,
    this.useTypedInteractionEvents = false,
    this.useTypedMarkerEvents = false,
    this.useTypedRoadEvents = false,
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

  /// Opt-in to route camera commands (absolute zoom, movement, rotation and
  /// the center query) through the typed generated channel when the native
  /// host advertises support at attachment time. Default keeps the legacy
  /// route. Relative zoom steps are always sent through the legacy route.
  final bool useTypedCameraRoute;

  /// Opt-in to route marker commands (add, move, rotation, anchors, icon
  /// updates, removal and static-position groups) through the typed
  /// generated channel when the native host advertises support at
  /// attachment time. Default keeps the legacy route.
  final bool useTypedMarkers;
  /// Opt-in routing of layer commands (tile-source selection and overlay
  /// visibility) through the typed generated channel when the native host
  /// advertises the layers capability at attachment time. Default keeps
  /// the legacy route.
  final bool useTypedLayers;
  /// Opt-in routing of shape commands (circles, rectangles) through the
  /// typed generated channel when the native host advertises the shapes
  /// capability at attachment time. Default keeps the legacy route.
  final bool useTypedShapes;
  /// Opt-in routing of road drawing, removal and clearing through the
  /// typed generated channel when the native host advertises the roads
  /// capability at attachment time. Route fetching/calculation stays
  /// asynchronous in Dart. Default keeps the legacy route.
  final bool useTypedRoads;
  /// Opt-in routing of the my-location layer and single-shot fixes through
  /// the typed generated channel when the native host advertises the
  /// location capability at attachment time. Permission ownership stays
  /// with the host application. Default keeps the legacy route.
  final bool useTypedLocation;
  /// Opt-in routing of start/stop location updates through the typed
  /// generated channel when the native host advertises the
  /// `location.updates` capability at attachment time. Default keeps the
  /// legacy route.
  final bool useTypedLocationUpdates;

  /// Opt-in routing of follow-me tracking (enable/disable) through the
  /// typed generated channel when the native host advertises the
  /// `location.tracking` capability at attachment time. Default keeps the
  /// legacy route.
  final bool useTypedTracking;

  /// Opt-in routing of the person/direction user-location icon replacement
  /// through the typed generated channel when the native host advertises
  /// the `location.icons` capability at attachment time. Default keeps the
  /// legacy `user#locationMarkers` route. Widget rendering stays
  /// asynchronous in Dart: only prepared PNG bytes cross the channel.
  final bool useTypedLocationIcons;

  /// Opt-in routing of the native-to-Dart lifecycle events (map readiness
  /// and restoration) through the typed generated callbacks when the native
  /// host advertises the `events.lifecycle` capability at attachment time.
  /// The route is negotiated before initialization and exactly one delivery
  /// route stays active per attachment. Default keeps the legacy
  /// `map#init` / `map#restored` event plane; the public `onMapIsReady`
  /// stream is unchanged either way.
  final bool useTypedLifecycleEvents;

  /// Opt-in routing of the native-to-Dart map interactions (single presses
  /// and long presses) through the typed generated callbacks when the native
  /// host advertises the `events.interaction` capability at attachment
  /// time. The route is negotiated before initialization and exactly one
  /// delivery route stays active per attachment. Default keeps the legacy
  /// `receiveSinglePress` / `receiveLongPress` event plane; the public
  /// `onSinglePressMapClickListener` / `onLongPressMapClickListener`
  /// streams are unchanged either way.
  final bool useTypedInteractionEvents;

  /// Opt-in routing of the native-to-Dart marker interactions (marker
  /// single presses and long presses) through the typed generated callbacks
  /// when the native host advertises the `events.markers` capability at
  /// attachment time. Same negotiation contract as the interaction events;
  /// default keeps the legacy `receiveGeoPoint` /
  /// `receiveGeoPointLongPress` event plane.
  final bool useTypedMarkerEvents;

  /// Opt-in routing of the native-to-Dart road taps through the typed
  /// generated callback when the native host advertises the `events.roads`
  /// capability at attachment time. The typed payload mirrors the legacy
  /// `receiveRoad` payload field for field. Same negotiation contract as
  /// the interaction events; default keeps the legacy event plane.
  final bool useTypedRoadEvents;
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
  }) : assert(maxZoomLevel <= 19),
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
    "stepZoom": stepZoom.toInt(),
    "initZoom": initZoom.toInt(),
    "minZoom": minZoomLevel.toInt(),
    "maxZoom": maxZoomLevel.toInt(),
  };
}

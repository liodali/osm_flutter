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
    this.useTypedCameraRoute = true,
    this.useTypedMarkers = true,
    this.useTypedLayers = true,
    this.useTypedShapes = true,
    this.useTypedRoads = true,
    this.useTypedLocation = true,
    this.useTypedLocationUpdates = true,
    this.useTypedTracking = true,
    this.useTypedLocationIcons = true,
    this.useTypedLifecycleEvents = true,
    this.useTypedInteractionEvents = true,
    this.useTypedMarkerEvents = true,
    this.useTypedRoadEvents = true,
    this.useTypedLocationEvents = true,
    this.useTypedRegionEvents = true,
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

  /// Routes camera commands (absolute zoom, movement, rotation and the center
  /// query) through the typed generated channel when the native host advertises
  /// support at attachment time. This is the default; set it to `false` to keep
  /// the legacy route. Hosts without the capability stay legacy either way.
  /// Relative zoom steps are always sent through the legacy route.
  final bool useTypedCameraRoute;

  /// Routes marker commands (add, move, rotation, anchors, icon updates,
  /// removal and static-position groups) through the typed generated channel
  /// when the native host advertises support at attachment time. This is the
  /// default; set it to `false` to keep the legacy route. Hosts without the
  /// capability stay legacy either way.
  final bool useTypedMarkers;
  /// Routes layer commands (tile-source selection and overlay visibility)
  /// through the typed generated channel when the native host advertises the
  /// layers capability at attachment time. This is the default; set it to
  /// `false` to keep the legacy route. Hosts without the capability stay legacy
  /// either way.
  final bool useTypedLayers;
  /// Routes shape commands (circles, rectangles) through the typed generated
  /// channel when the native host advertises the shapes capability at
  /// attachment time. This is the default; set it to `false` to keep the legacy
  /// route. Hosts without the capability stay legacy either way.
  final bool useTypedShapes;
  /// Routes road drawing, removal and clearing through the typed generated
  /// channel when the native host advertises the roads capability at attachment
  /// time. Route fetching/calculation stays asynchronous in Dart. This is the
  /// default; set it to `false` to keep the legacy route. Hosts without the
  /// capability stay legacy either way.
  final bool useTypedRoads;
  /// Routes the my-location layer and single-shot fixes through the typed
  /// generated channel when the native host advertises the location capability
  /// at attachment time. Permission ownership stays with the host application.
  /// This is the default; set it to `false` to keep the legacy route. Hosts
  /// without the capability stay legacy either way.
  final bool useTypedLocation;
  /// Routes start/stop location updates through the typed generated channel
  /// when the native host advertises the `location.updates` capability at
  /// attachment time. This is the default; set it to `false` to keep the legacy
  /// route. Hosts without the capability stay legacy either way.
  final bool useTypedLocationUpdates;

  /// Routes follow-me tracking (enable/disable) through the typed generated
  /// channel when the native host advertises the `location.tracking` capability
  /// at attachment time. This is the default; set it to `false` to keep the
  /// legacy route. Hosts without the capability stay legacy either way.
  final bool useTypedTracking;

  /// Routes the person/direction user-location icon replacement through the
  /// typed generated channel when the native host advertises the
  /// `location.icons` capability at attachment time. Widget rendering stays
  /// asynchronous in Dart: only prepared PNG bytes cross the channel. This is
  /// the default; set it to `false` to keep the legacy route. Hosts without the
  /// capability stay legacy either way.
  final bool useTypedLocationIcons;

  /// Routes the native-to-Dart lifecycle events (map readiness and restoration)
  /// through the typed generated callbacks when the native host advertises the
  /// `events.lifecycle` capability at attachment time. The route is negotiated
  /// before initialization and exactly one delivery route stays active per
  /// attachment. This is the default; set it to `false` to keep the legacy
  /// event plane. Hosts without the capability, and JNI command attachments,
  /// keep the legacy plane either way. The public `onMapIsReady` stream is
  /// unchanged either way.
  final bool useTypedLifecycleEvents;

  /// Routes the native-to-Dart map interactions (single presses and long
  /// presses) through the typed generated callbacks when the native host
  /// advertises the `events.interaction` capability at attachment time. Same
  /// negotiation contract as the lifecycle events. This is the default; set it
  /// to `false` to keep the legacy event plane. Hosts without the capability,
  /// and JNI command attachments, keep the legacy plane either way. The public
  /// `onSinglePressMapClickListener` / `onLongPressMapClickListener` streams
  /// are unchanged either way.
  final bool useTypedInteractionEvents;

  /// Routes the native-to-Dart marker interactions (marker single presses and
  /// long presses) through the typed generated callbacks when the native host
  /// advertises the `events.markers` capability at attachment time. Same
  /// negotiation contract as the lifecycle events. This is the default; set it
  /// to `false` to keep the legacy event plane. Hosts without the capability,
  /// and JNI command attachments, keep the legacy plane either way. The public
  /// `onGeoPointClickListener` / `onGeoPointLongPressListener` streams are
  /// unchanged either way.
  final bool useTypedMarkerEvents;

  /// Routes the native-to-Dart road taps through the typed generated callback
  /// when the native host advertises the `events.roads` capability at
  /// attachment time. The typed payload mirrors the legacy `receiveRoad`
  /// payload field for field. Same negotiation contract as the lifecycle
  /// events. This is the default; set it to `false` to keep the legacy event
  /// plane. Hosts without the capability, and JNI command attachments, keep the
  /// legacy plane either way.
  final bool useTypedRoadEvents;

  /// Routes the native-to-Dart user-location fixes through the typed generated
  /// callback when the native host advertises the `events.location` capability
  /// at attachment time. The callback carries the position and heading as raw
  /// doubles and inherits the host's location rate and coalescing unchanged,
  /// whichever consumer started the flow (continuous updates, follow-me
  /// tracking). Same negotiation contract as the lifecycle events. This is the
  /// default; set it to `false` to keep the legacy event plane. Hosts without
  /// the capability, and JNI command attachments, keep the legacy plane either
  /// way. The public `onUserPositionListener` stream is unchanged either way.
  final bool useTypedLocationEvents;

  /// Routes the native-to-Dart visible-region changes through the typed
  /// generated callback when the native host advertises the `events.region`
  /// capability at attachment time. The callback carries the center, the
  /// bounding box and the zoom level as raw doubles and inherits the host's
  /// region-event rate and coalescing unchanged. Same negotiation contract as
  /// the lifecycle events. This is the default; set it to `false` to keep the
  /// legacy event plane. Hosts without the capability, and JNI command
  /// attachments, keep the legacy plane either way. The public
  /// `onRegionIsChangingListener` stream is unchanged either way.
  final bool useTypedRegionEvents;
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

import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

/// The example's legacy baseline.
///
/// Typed (generated) routes are the plugin's default: an [OSMOption] without
/// route flags negotiates every typed family the host advertises. The
/// baseline pages (`old-home`, `simple`, `hook`) switch every family off
/// explicitly, so the same build offers a side-by-side comparison with the
/// home page's typed attachment (see `TYPED_ROUTES_VALIDATION.md`). Public
/// streams and controller APIs are identical on either route.
OSMOption legacyOsmOption({
  bool enableRotationByGesture = true,
  ZoomOption zoomOption = const ZoomOption(),
  UserLocationMaker? userLocationMarker,
  List<StaticPositionGeoPoint> staticPoints = const [],
  RoadOption? roadConfiguration,
  bool showDefaultInfoWindow = false,
  bool showContributorBadgeForOSM = false,
}) => OSMOption(
  enableRotationByGesture: enableRotationByGesture,
  zoomOption: zoomOption,
  userLocationMarker: userLocationMarker,
  staticPoints: staticPoints,
  roadConfiguration: roadConfiguration,
  showDefaultInfoWindow: showDefaultInfoWindow,
  showContributorBadgeForOSM: showContributorBadgeForOSM,
  // Command families.
  useTypedCameraRoute: false,
  useTypedMarkers: false,
  useTypedLayers: false,
  useTypedShapes: false,
  useTypedRoads: false,
  useTypedLocation: false,
  useTypedLocationUpdates: false,
  useTypedTracking: false,
  useTypedLocationIcons: false,
  // Event families.
  useTypedLifecycleEvents: false,
  useTypedInteractionEvents: false,
  useTypedMarkerEvents: false,
  useTypedRoadEvents: false,
  useTypedLocationEvents: false,
  useTypedRegionEvents: false,
);

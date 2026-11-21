import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'channel/osm_method_channel.dart';
import 'channel/pigeon/native_camera_bootstrap.dart';
import 'channel/pigeon/native_camera_client.dart';
import 'channel/pigeon/native_markers_client.dart';
import 'common/osm_event.dart';
import 'types/types.dart';

abstract class OSMPlatform extends PlatformInterface {
  OSMPlatform() : super(token: token);

  static late OSMPlatform _instance = MethodChannelOSM();

  static OSMPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [OSMPlatformInterface] when they register themselves.
  static set instance(OSMPlatform instance) {
    PlatformInterface.verifyToken(instance, token);
    _instance = instance;
  }

  static final Object token = Object();

  Stream<MapInitialization> onMapIsReady(int idMap);

  Stream<SingleTapEvent> onSinglePressMapClickListener(int idMap);

  Stream<LongTapEvent> onLongPressMapClickListener(int idMap);

  Stream<RoadTapEvent> onRoadMapClickListener(int idMap);

  Stream<GeoPointEvent> onGeoPointClickListener(int idMap);

  Stream<GeoPointLongPressEvent> onGeoPointLongPressListener(int idMap);

  Stream<UserLocationEvent> onUserPositionListener(int idMap);

  Stream<RegionIsChangingEvent> onRegionIsChangingListener(int idMap);

  Future<void> init(
    int idOSM,
  );

  void close(int idOSM);

  /// Read-only attach-time probe of the generated-channel protocol.
  /// Must not initialize or mutate the map; implementations run it on the
  /// legacy channel before routing decisions are frozen.
  Future<NativeProtocolProbeResult> probeNativeProtocol(int idOSM);

  /// Freezes the camera routing decision for one map attachment.
  /// Called once after [init] and before the first mutation; the decision
  /// never changes for the life of the attachment (no protocol replay).
  Future<CameraRouteSelection> attachCameraRoute(
    int idOSM, {
    bool optIn = false,
  });

  /// Freezes the markers routing decision for one map attachment.
  /// Same contract as [attachCameraRoute]: one probe, one decision, frozen
  /// before the first mutation.
  Future<CameraRouteSelection> attachMarkersRoute(
    int idOSM, {
    bool optIn = false,
  });

  /// Freezes the layers routing decision for one map attachment (tile
  /// sources and overlay visibility). Same contract as [attachCameraRoute]:
  /// one probe, one decision, frozen before the first mutation. Hosts
  /// without the `layers` capability keep these commands on the legacy
  /// route.
  Future<CameraRouteSelection> attachLayersRoute(
    int idOSM, {
    bool optIn = false,
  });

  /// Freezes the shapes routing decision for one map attachment (circles
  /// and rectangles). Same contract as [attachCameraRoute]: one probe, one
  /// decision, frozen before the first mutation. Hosts without the
  /// `shapes` capability keep these commands on the legacy route.
  Future<CameraRouteSelection> attachShapesRoute(
    int idOSM, {
    bool optIn = false,
  });

  /// Freezes the roads routing decision for one map attachment (manual
  /// road drawing, removal by id, clearing). Same contract as
  /// [attachCameraRoute]: one probe, one decision, frozen before the first
  /// mutation. Hosts without the `roads` capability keep these commands on
  /// the legacy route. Route fetching/calculation is unaffected: it stays
  /// asynchronous in Dart.
  Future<CameraRouteSelection> attachRoadsRoute(
    int idOSM, {
    bool optIn = false,
  });

  /// Freezes the location routing decision for one map attachment (the
  /// my-location layer and single-shot fixes). Same contract as
  /// [attachCameraRoute]: one probe, one decision, frozen before the first
  /// mutation. Hosts without the `location` capability keep these commands
  /// on the legacy route. Permission ownership stays with the host
  /// application; continuous updates and tracking stay on their existing
  /// channels.
  Future<CameraRouteSelection> attachLocationRoute(
    int idOSM, {
    bool optIn = false,
  });

  /// Freezes the continuous-updates routing decision for one map
  /// attachment (start/stop location updates). Same contract as
  /// [attachCameraRoute]: one probe, one decision, frozen before the first
  /// mutation. Hosts without the `location.updates` capability keep these
  /// commands on the legacy route. Location events keep flowing on their
  /// existing channel; stop never prompts and preserves pending one-shot
  /// fixes and tracking.
  Future<CameraRouteSelection> attachLocationUpdatesRoute(
    int idOSM, {
    bool optIn = false,
  });}

abstract class MobileOSMPlatform extends OSMPlatform {
  Stream<IosMapInit> onIosMapInit(int idMap);

  Stream<MapRestoration> onMapRestored(int idMap);

  Future<void> initPositionMap(
    int idOSM,
    GeoPoint point,
  );

  Future<void> changeTileLayer(
    int idOSM,
    CustomTile? tile,
  );

  Future<void> currentLocation(
    int idOSM,
  );

  Future<GeoPoint> getMapCenter(
    int idMap,
  );

  Future<GeoPoint> myLocation(
    int idMap,
  );

  Future<void> customUserLocationMarker(
    int idOSM,
    GlobalKey personGlobalKey,
    GlobalKey directionArrowGlobalKey,
  );

  Future<void> enableTracking(
    int idOSM, {
    bool stopFollowInDrag = false,
    bool disableMarkerRotation = false,
    Anchor anchor = Anchor.center,
    bool useDirectionMarker = false,
  });

  Future<void> startLocationUpdating(
    int idOSM,
  );
  Future<void> stopLocationUpdating(
    int idOSM,
  );
  Future<void> addPosition(
    int idOSM,
    GeoPoint p,
  );

  Future<void> goToPosition(int idOSM, GeoPoint p, {bool animate = false});

  Future<void> addMarker(
    int idOSM,
    GeoPoint p, {
    GlobalKey? globalKeyIcon,
    IconAnchor? iconAnchor,
  });

  Future<void> changeMarker(
    int idOSM,
    GeoPoint oldLocation,
    GeoPoint newLocation, {
    GlobalKey? globalKeyIcon,
    double? angle,
    IconAnchor? iconAnchor,
  });

  Future<void> setIconMarker(
    int idOSM,
    GeoPoint point,
    GlobalKey globalKeyIcon,
  );

  Future<void> removePosition(
    int idOSM,
    GeoPoint p,
  );
  Future<void> removeMarkers(
    int idOSM,
    List<GeoPoint> markers,
  );

  Future<void> removeLastRoad(
    int idOSM,
  );

  Future<void> removeRoad(
    int idOSM,
    String roadKey,
  );
  Future<RoadInfo> drawRoad(
    int idOSM,
    GeoPoint start,
    GeoPoint end, {
    RoadType roadType = RoadType.car,
    List<GeoPoint>? interestPoints,
    RoadOption roadOption,
  });

  Future<List<RoadInfo>> drawMultipleRoad(
    int idOSM,
    List<MultiRoadConfiguration> configs, {
    MultiRoadOption commonRoadOption,
  });

  Future<void> clearAllRoads(
    int idOSM,
  );

  Future<void> drawCircle(
    int idOSM,
    CircleOSM circleOSM,
  );

  Future<void> removeCircle(
    int idOSM,
    String key,
  );

  Future<void> drawRect(
    int idOSM,
    RectOSM rectOSM,
  );

  Future<void> removeRect(
    int idOSM,
    String key,
  );

  Future<void> removeAllRect(
    int idOSM,
  );

  Future<void> removeAllCircle(
    int idOSM,
  );

  Future<void> removeAllShapes(
    int idOSM,
  );

  Future<void> customMarkerStaticPosition(
    int idOSM,
    GlobalKey? globalKey,
    String id, {
    bool refresh = false,
  });

  Future<void> staticPosition(
    int idOSM,
    List<GeoPoint> pList,
    String id,
  );

  Future<double> getZoom(
    int idOSM,
  );

  Future<void> setZoom(
    int idOSM, {
    double? zoomLevel,
    double? stepZoom,
  });

  Future<void> setStepZoom(
    int idOSM,
    int stepZoom,
  );

  Future<void> setMinimumZoomLevel(
    int idOSM,
    double minZoom,
  );

  Future<void> setMaximumZoomLevel(
    int idOSM,
    double maxZoom,
  );

  Future<void> zoomToBoundingBox(
    int idOSM,
    BoundingBox box, {
    int paddinInPixel = 0,
  });

  Future<void> disableTracking(
    int idOSM,
  );

  Future<void> drawRoadManually(
    int idOSM,
    String roadKey,
    List<GeoPoint> road,
    RoadOption roadOption,
  );

  Future<void> mapRotation(
    int idOSM,
    double degree,
  );

  Future<void> limitArea(
    int idOSM,
    BoundingBox box,
  );

  Future<void> removeLimitArea(
    int idOSM,
  );

  Future<BoundingBox> getBounds(
    int idOSM,
  );

  Future<List<GeoPoint>> getGeoPointMarkers(
    int idOSM,
  );

  /// [toggleLayer]
  ///
  /// change visibility of all layers of the map
  Future<void> toggleLayer(
    int idOSM, {
    required bool toggle,
  });
}

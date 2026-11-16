import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:stream_transform/stream_transform.dart';

import 'package:flutter_osm_interface/src/channel/pigeon/native_camera_bootstrap.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_camera_client.dart';
import 'package:flutter_osm_interface/src/channel/pigeon/native_markers_client.dart';
import 'package:flutter_osm_interface/src/common/geo_point_exception.dart';
import 'package:flutter_osm_interface/src/common/osm_event.dart';
import 'package:flutter_osm_interface/src/common/road_exception.dart';
import 'package:flutter_osm_interface/src/common/utilities.dart';
import 'package:flutter_osm_interface/src/osm_interface.dart';
import 'package:flutter_osm_interface/src/types/types.dart';

class MethodChannelOSM extends MobileOSMPlatform {
  final Map<int, MethodChannel> _channels = {};

  /// Frozen at attachment: null entry means legacy camera route; absent key
  /// means the decision has not run yet (also legacy during C1 behavior).
  final Map<int, PigeonCameraClient?> _cameraRoutes = {};

  /// Bumped on disposal so a probe completing after close (or during a
  /// replacement attachment) is recognized as stale and discarded.
  final Map<int, int> _cameraRouteEpochs = {};

  /// Frozen markers-route decision (null = legacy), same lifecycle rules.
  final Map<int, PigeonMarkersClient?> _markersRoutes = {};

  /// GeoPoint key → typed marker ids for maps frozen on the generated
  /// markers route. The legacy public API addresses markers by position;
  /// the typed route addresses them by stable id, so additions mint ids
  /// here and position-keyed mutations resolve through this table.
  /// Legacy coordinate semantics allow (and remove) every marker at one
  /// position, so each key tracks every id added at that coordinate.
  final Map<int, Map<String, List<String>>> _typedMarkerKeys = {};
  final Map<int, int> _typedMarkerSequences = {};

  /// Static-group icon cache: the legacy icon-only command (icon without
  /// points) cannot be expressed by the generated replace-group command,
  /// so icons captured in Dart are replayed with the cached coordinates.
  final Map<int, Map<String, Uint8List>> _typedStaticGroupIcons = {};
  final Map<int, Map<String, Float64List>> _typedStaticGroupPoints = {};

  /// In-flight attach decisions keyed by `<viewId>:<capability>`, so
  /// concurrent calls for one map+family converge on a single probe instead
  /// of racing two decisions.
  final Map<String, Future<CameraRouteSelection>> _routeAttachJobs = {};

  /// Active generated-camera client for [idOSM], or null when the frozen
  /// decision selected the legacy route. Exposed for tests and internal
  /// routing consumers; applications keep using the public controllers.
  @visibleForTesting
  PigeonCameraClient? cameraClientFor(int idOSM) => _cameraRoutes[idOSM];

  //final Map<int, List<EventChannel>> _eventsChannels = {};
  var _streamController = StreamController<EventOSM>.broadcast();

  // Returns a filtered view of the events in the _controller, by mapId.
  Stream<EventOSM> _events(int mapId) =>
      _streamController.stream.where((event) => event.mapId == mapId);

  @override
  Future<void> init(int idOSM) async {
    if (!_channels.containsKey(idOSM)) {
      if (_streamController.isClosed) {
        _streamController = StreamController<EventOSM>.broadcast();
      }
      _channels[idOSM] = MethodChannel('plugins.dali.hamza/osmview_$idOSM');
      setGeoPointHandler(idOSM);
    }
    /*if (!_eventsChannels.containsKey(idOSM)) {
      _eventsChannels[idOSM] = [
       // EventChannel("plugins.dali.hamza/osmview_stream_$idOSM"),
        EventChannel("plugins.dali.hamza/osmview_stream_location_$idOSM"),
      ];
    }*/
  }

  @override
  Stream<MapInitialization> onMapIsReady(int idMap) {
    return _events(idMap).whereType<MapInitialization>();
  }

  @override
  Stream<MapRestoration> onMapRestored(int idMap) {
    return _events(idMap).whereType<MapRestoration>();
  }

  @override
  Stream<SingleTapEvent> onSinglePressMapClickListener(int idMap) {
    return _events(idMap).whereType<SingleTapEvent>();
  }

  @override
  Stream<LongTapEvent> onLongPressMapClickListener(int idMap) {
    return _events(idMap).whereType<LongTapEvent>();
  }

  @override
  Stream<GeoPointEvent> onGeoPointClickListener(int idMap) {
    return _events(idMap).whereType<GeoPointEvent>();
  }

  @override
  Stream<GeoPointLongPressEvent> onGeoPointLongPressListener(int idMap) {
    return _events(idMap).whereType<GeoPointLongPressEvent>();
  }

  @override
  Stream<UserLocationEvent> onUserPositionListener(int idMap) {
    return _events(idMap).whereType<UserLocationEvent>();
  }

  @override
  Stream<RegionIsChangingEvent> onRegionIsChangingListener(int idMap) {
    return _events(idMap).whereType<RegionIsChangingEvent>();
  }

  @override
  Stream<RoadTapEvent> onRoadMapClickListener(int idMap) {
    return _events(idMap).whereType<RoadTapEvent>();
  }

  @override
  Stream<IosMapInit> onIosMapInit(int idMap) {
    return _events(idMap).whereType<IosMapInit>();
  }

  void setGeoPointHandler(int idMap) async {
    _channels[idMap]!.setMethodCallHandler((call) async {
      switch (call.method) {
        case "map#init":
          final result = call.arguments as bool;
          _streamController.add(MapInitialization(idMap, result));
          break;
        case "map#restored":
          _streamController.add(MapRestoration(idMap));
          break;
        case "receiveLongPress":
          final result = call.arguments;
          _streamController.add(LongTapEvent(idMap, GeoPoint.fromMap(result)));
          break;
        case "receiveSinglePress":
          final result = call.arguments;
          _streamController
              .add(SingleTapEvent(idMap, GeoPoint.fromMap(result)));
          break;
        case "receiveRoad":
          final result = call.arguments;
          _streamController.add(RoadTapEvent(idMap, RoadInfo.fromMap(result)));
          break;
        case "receiveGeoPoint":
          final result = call.arguments;
          _streamController.add(GeoPointEvent(idMap, GeoPoint.fromMap(result)));
          break;
        case "receiveGeoPointLongPress":
          final result = call.arguments;
          _streamController
              .add(GeoPointLongPressEvent(idMap, GeoPoint.fromMap(result)));
          break;
        case "receiveUserLocation":
          final result = call.arguments;
          _streamController
              .add(UserLocationEvent(idMap, UserLocation.fromMap(result)));
          break;
        case "receiveRegionIsChanging":
          final result = call.arguments;
          _streamController
              .add(RegionIsChangingEvent(idMap, Region.fromMap(result)));
          break;
        case "map#init#ios":
          final result = call.arguments;
          _streamController.add(IosMapInit(idMap, result));
          break;
      }
      return true;
    });
  }

  @override
  void close(int idOSM) {
    if (_channels.containsKey(idOSM)) {
      _channels.remove(idOSM)?.setMethodCallHandler(null);
    }
    // Invalidate any in-flight attach decision for this map and unfreeze
    // the route so a replacement attachment decides freshly. Dropping the
    // pending job prevents a replacement from joining (and blocking on) the
    // disposed attachment's probe.
    _cameraRouteEpochs[idOSM] = (_cameraRouteEpochs[idOSM] ?? 0) + 1;
    _routeAttachJobs.remove('$idOSM:$kCameraCapability');
    _routeAttachJobs.remove('$idOSM:$kMarkersCapability');
    _cameraRoutes.remove(idOSM);
    _markersRoutes.remove(idOSM);
    _typedMarkerKeys.remove(idOSM);
    _typedMarkerSequences.remove(idOSM);
    _typedStaticGroupIcons.remove(idOSM);
    _typedStaticGroupPoints.remove(idOSM);
    if (_channels.isEmpty) {
      _streamController.close();
    }
  }

  /// Read-only attach-time probe of the generated-channel protocol.
  ///
  /// Runs on the existing legacy channel (primitive codec) before any map
  /// mutation. A missing probe on an old host maps to legacy selection;
  /// malformed answers are reported as [NativeProtocolInvalid] and are never
  /// silently treated as old-host compatibility.
  @override
  Future<NativeProtocolProbeResult> probeNativeProtocol(int idOSM) async {
    final channel = _channels[idOSM];
    if (channel == null) {
      return const NativeProtocolLegacyHost();
    }
    final Object? payload;
    try {
      payload = await channel.invokeMethod<Object>(kNativeBootstrapMethod);
    } on MissingPluginException {
      // Host predates the probe: supported legacy selection.
      return const NativeProtocolLegacyHost();
    } on PlatformException catch (error) {
      if (error.code == 'not_implemented' || error.code == 'notImplemented') {
        return const NativeProtocolLegacyHost();
      }
      // Unexpected channel failure: not old-host compatibility.
      return NativeProtocolInvalid(reason: 'probe failed: ${error.code}');
    }
    return NativeProtocolBootstrap.parse(payload);
  }

  /// Freezes the camera routing decision for one map attachment.
  ///
  /// Runs the read-only probe before any map mutation: the generated route
  /// activates only when the application opted in AND the host advertises a
  /// matching revision and the camera capability. Everything else — old
  /// hosts, malformed probes, non-opt-in — keeps the legacy route. The
  /// decision is never revisited for the life of the attachment (no replay
  /// through the other route after failures).
  @override
  Future<CameraRouteSelection> attachCameraRoute(
    int idOSM, {
    bool optIn = false,
  }) {
    return _attachRoute(
      idOSM: idOSM,
      optIn: optIn,
      capability: kCameraCapability,
      routes: _cameraRoutes,
      createClient: (bootstrap) => PigeonCameraClient(
        viewId: idOSM,
        bootstrap: bootstrap,
      ),
    );
  }

  @override
  Future<CameraRouteSelection> attachMarkersRoute(
    int idOSM, {
    bool optIn = false,
  }) {
    return _attachRoute<PigeonMarkersClient>(
      idOSM: idOSM,
      optIn: optIn,
      capability: kMarkersCapability,
      routes: _markersRoutes,
      createClient: (bootstrap) => PigeonMarkersClient(
        viewId: idOSM,
        bootstrap: bootstrap,
      ),
    );
  }

  /// Active generated client for [idOSM]'s markers family, or null when the
  /// frozen decision selected the legacy route.
  @visibleForTesting
  PigeonMarkersClient? markersClientFor(int idOSM) => _markersRoutes[idOSM];

  static String _geoKey(GeoPoint p) => '${p.latitude},${p.longitude}';

  String _nextTypedMarkerId(int idOSM) {
    final sequence = _typedMarkerSequences[idOSM] ?? 0;
    _typedMarkerSequences[idOSM] = sequence + 1;
    return 'osm-$idOSM-$sequence';
  }

  /// Shared attach machinery: freeze-once per attachment+family, single
  /// in-flight probe per id+family, disposal-epoch invalidation.
  Future<CameraRouteSelection> _attachRoute<C extends Object>({
    required int idOSM,
    required bool optIn,
    required String capability,
    required Map<int, C?> routes,
    required C Function(NativeProtocolBootstrap bootstrap) createClient,
  }) {
    final jobKey = '$idOSM:$capability';
    // Decision already frozen for this attachment: never re-decide.
    if (routes.containsKey(idOSM)) {
      return routes[idOSM] != null
          ? Future.value(CameraRouteSelection.generated)
          : Future.value(CameraRouteSelection.legacy);
    }
    // Converge concurrent attach calls on one probe for this map+family.
    final running = _routeAttachJobs[jobKey];
    if (running != null) {
      return running;
    }
    final job = _decideRoute(
      idOSM,
      optIn: optIn,
      capability: capability,
      routes: routes,
      createClient: createClient,
    );
    _routeAttachJobs[jobKey] = job;
    return job.whenComplete(() {
      // Conditional cleanup: a replacement attachment may have registered
      // its own job under this key while this one was awaiting; only remove
      // the entry if it is still ours.
      if (identical(_routeAttachJobs[jobKey], job)) {
        _routeAttachJobs.remove(jobKey);
      }
    });
  }

  Future<CameraRouteSelection> _decideRoute<C extends Object>(
    int idOSM, {
    required bool optIn,
    required String capability,
    required Map<int, C?> routes,
    required C Function(NativeProtocolBootstrap bootstrap) createClient,
  }) async {
    if (!_channels.containsKey(idOSM)) {
      return CameraRouteSelection.legacy;
    }
    if (!optIn) {
      routes[idOSM] = null;
      return CameraRouteSelection.legacy;
    }
    // Capture the attachment identity before the async probe; a close (or a
    // close + re-init of a replacement map) invalidates this decision.
    final epoch = _cameraRouteEpochs[idOSM] ?? 0;
    // The probe is a trivial local channel call; bound it so a host that
    // never answers cannot hang attachment. A timeout conservatively keeps
    // the legacy route (it is not old-host compatibility: the decision is
    // simply not activated).
    final probe = await probeNativeProtocol(idOSM).timeout(
      const Duration(seconds: 2),
      onTimeout: () => const NativeProtocolLegacyHost(),
    );
    final attachmentChanged = !_channels.containsKey(idOSM) ||
        (_cameraRouteEpochs[idOSM] ?? 0) != epoch;
    if (attachmentChanged) {
      // Stale probe for a disposed/replaced attachment: discard without
      // storing anything; the replacement attachment decides freshly.
      return CameraRouteSelection.legacy;
    }
    if (routes.containsKey(idOSM)) {
      return routes[idOSM] != null
          ? CameraRouteSelection.generated
          : CameraRouteSelection.legacy;
    }
    if (probe is NativeProtocolSupported &&
        probe.bootstrap.isSupportedRevision &&
        probe.bootstrap.schemaId == kNativeCameraSchemaId &&
        probe.bootstrap.advertises(capability)) {
      routes[idOSM] = createClient(probe.bootstrap);
      return CameraRouteSelection.generated;
    }
    routes[idOSM] = null;
    return CameraRouteSelection.legacy;
  }

  @override
  Future<void> initPositionMap(
    int idOSM,
    GeoPoint point,
  ) async {
    Map requestData = {"lon": point.longitude, "lat": point.latitude};
    await _channels[idOSM]?.invokeMethod(
      "initMap",
      requestData,
    );
  }

  @override
  Future<void> currentLocation(int? idOSM) async {
    try {
      await _channels[idOSM]?.invokeMethod("currentLocation", null);
    } on PlatformException catch (e) {
      throw GeoPointException(msg: e.message);
    }
  }

  @override
  Future<GeoPoint> myLocation(int idMap) async {
    try {
      Map<String, dynamic> map =
          (await _channels[idMap]!.invokeMapMethod("user#position"))!;
      return GeoPoint(latitude: map["lat"], longitude: map["lon"]);
    } on PlatformException catch (e) {
      throw GeoPointException(msg: e.message);
    }
  }

  @override
  @Deprecated("message")
  Future<void> addPosition(int idOSM, GeoPoint p) async {
    Map requestData = {"lon": p.longitude, "lat": p.latitude};
    await _channels[idOSM]?.invokeMethod(
      "changePosition",
      requestData,
    );
  }

  @override
  Future<void> customMarkerStaticPosition(
    int idOSM,
    GlobalKey? globalKey,
    String id, {
    bool refresh = false,
  }) async {
    final client = _markersRoutes[idOSM];
    if (client != null) {
      if (globalKey?.currentContext == null) return;
      // Widget rendering is asynchronous: the capture can outlive a
      // close(), so identity-check the attachment before touching state or
      // sending the replacement group.
      final icon = await _capturePng(globalKey!) as Uint8List;
      if (!identical(_markersRoutes[idOSM], client)) return;
      (_typedStaticGroupIcons[idOSM] ??= {})[id] = icon;
      final points = _typedStaticGroupPoints[idOSM]?[id];
      if (points != null) {
        await client.setStaticPositions(id, points, iconBytes: icon);
      }
      return;
    }

    if (globalKey?.currentContext != null) {
      final icon = await _capturePng(globalKey!);

      var args = {
        "id": id,
        "bitmap": icon,
        "refresh": refresh,
      };

      await _channels[idOSM]?.invokeMethod(
        "staticPosition#IconMarker",
        args,
      );
    }
  }

  @override
  Future<void> disableTracking(int idOSM) async {
    await _channels[idOSM]?.invokeMethod('deactivateTrackMe', null);
  }

  @override
  Future<RoadInfo> drawRoad(
    int idOSM,
    GeoPoint start,
    GeoPoint end, {
    RoadType roadType = RoadType.car,
    List<GeoPoint>? interestPoints,
    RoadOption roadOption = const RoadOption.empty(),
  }) async {
    final roadInfo = RoadInfo();

    /// add point of the road
    final Map args = {
      'key': roadInfo.key,
      "wayPoints": [
        start.toMap(),
        end.toMap(),
      ]
    };

    /// add road type that will change api call to get route
    args.addAll({
      "roadType": roadType.toString().split(".").last,
    });

    /// add middle point that will pass through it
    if (interestPoints != null && interestPoints.isNotEmpty) {
      args.addAll(
        {
          "middlePoints": interestPoints.map((e) => e.toMap()).toList(),
        },
      );
    }

    args.addAll(roadOption.toMap());

    try {
      Map? map = await _channels[idOSM]?.invokeMapMethod(
        "road",
        args,
      );
      return RoadInfo.fromMap(map!);
    } on PlatformException catch (e) {
      throw RoadException(msg: e.message);
    }
  }

  @override
  Future<void> enableTracking(
    int idOSM, {
    bool stopFollowInDrag = false,
    bool disableMarkerRotation = false,
    Anchor anchor = Anchor.center,
    bool useDirectionMarker = false,
  }) async {
    final args = <dynamic>[
      stopFollowInDrag,
      disableMarkerRotation,
      useDirectionMarker,
      anchor.toMap()
    ];
    await _channels[idOSM]?.invokeMethod(
      'trackMe',
      args,
    );
  }

  @override
  Future<void> removeLastRoad(int idOSM) async {
    await _channels[idOSM]?.invokeMethod("delete#road");
  }

  @override
  Future<void> removePosition(int idOSM, GeoPoint p) async {
    final client = _markersRoutes[idOSM];
    final keys = _typedMarkerKeys[idOSM];
    final ids = keys?[_geoKey(p)];
    if (client != null && keys != null && ids != null && ids.isNotEmpty) {
      // Legacy coordinate removal deletes every marker at the position.
      await client.removeMarkers(ids);
      // close() may have cleared the table while removal was in flight;
      // only update identity when this is still the attachment's table.
      if (identical(_typedMarkerKeys[idOSM], keys)) {
        keys.remove(_geoKey(p));
      }
      return;
    }
    await _channels[idOSM]
        ?.invokeMethod("user#removeMarkerPosition", p.toMap());
  }

  @override
  Future<void> setStepZoom(int idOSM, int stepZoom) async {
    try {
      await _channels[idOSM]?.invokeMethod("change#stepZoom", stepZoom);
    } on PlatformException catch (e) {
      debugPrint(e.message);
    }
  }

  @override
  Future<void> staticPosition(
    int idOSM,
    List<GeoPoint> pList,
    String id,
  ) async {
    final client = _markersRoutes[idOSM];
    if (client != null) {
      final coordinates = Float64List.fromList([
        for (final p in pList) ...[
          p.latitude,
          p.longitude,
          p is GeoPointWithOrientation ? p.angle * 180 / math.pi : 0.0,
        ],
      ]);
      await client.setStaticPositions(
        id,
        coordinates,
        iconBytes: _typedStaticGroupIcons[idOSM]?[id],
      );
      (_typedStaticGroupPoints[idOSM] ??= {})[id] = coordinates;
      return;
    }

    try {
      List<Map<String, double>> listGeos = [];
      for (GeoPoint p in pList) {
        listGeos.add(p.toMap());
      }
      await _channels[idOSM]?.invokeMethod("staticPosition", {
        "id": id,
        "point": listGeos,
      });
    } on PlatformException catch (e) {
      debugPrint(e.message);
    }
  }

  Future<dynamic> _capturePng(GlobalKey globalKey) async {
    if (globalKey.currentContext == null) {
      throw Exception("Error to draw you custom icon");
    }
    RenderRepaintBoundary boundary =
        globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

    ui.Image image;
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      //added pixelRatio : 5 in apple platforms to get clear image
      image = await boundary.toImage(pixelRatio: 5);
    } else {
      image = await boundary.toImage();
    }

    ByteData byteData =
        (await (image.toByteData(format: ui.ImageByteFormat.png)))!;
    Uint8List pngBytes = byteData.buffer.asUint8List();
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return {
        "icon": pngBytes.convertToString(),
        "size": globalKey.currentContext != null
            ? [
                globalKey.currentContext!.size!.width.toInt(),
                globalKey.currentContext!.size!.height.toInt()
              ]
            : iosSizeIcon
      };
    }
    return pngBytes;
  }

  @override
  Future<void> drawCircle(int idOSM, CircleOSM circleOSM) async {
    await _channels[idOSM]?.invokeMethod("draw#circle", circleOSM.toMap());
  }

  @override
  Future<void> removeAllCircle(int idOSM) async {
    await _channels[idOSM]?.invokeMethod("remove#circle", null);
  }

  @override
  Future<void> removeCircle(int idOSM, String key) async {
    await _channels[idOSM]?.invokeMethod("remove#circle", key);
  }

  @override
  Future<void> drawRect(int idOSM, RectOSM rectOSM) async {
    await _channels[idOSM]?.invokeMethod("draw#rect", rectOSM.toMap());
  }

  @override
  Future<void> removeRect(int idOSM, String key) async {
    await _channels[idOSM]?.invokeMethod("remove#rect", key);
  }

  @override
  Future<void> removeAllRect(int idOSM) async {
    await _channels[idOSM]?.invokeMethod("remove#rect", null);
  }

  @override
  Future<void> removeAllShapes(int idOSM) async {
    await _channels[idOSM]?.invokeMethod("clear#shapes");
  }

  @override
  Future<void> goToPosition(
    int idOSM,
    GeoPoint p, {
    bool animate = false,
  }) async {
    final client = _cameraRoutes[idOSM];
    if (client != null) {
      return client.moveTo(
        p.latitude,
        p.longitude,
        animated: animate,
      );
    }
    Map requestData = {
      "lon": p.longitude,
      "lat": p.latitude,
      "animate": animate,
    };
    await _channels[idOSM]?.invokeMethod(
      "moveTo#position",
      requestData,
    );
  }

  @override
  Future<void> drawRoadManually(
    int idOSM,
    String roadKey,
    List<GeoPoint> road,
    RoadOption roadOption,
  ) async {
    final coordinates = road.map((e) => e.toListNum()).toList();
    final encodedCoordinates = encodePolyline(coordinates);
    Map<String, dynamic> data = {
      'key': roadKey,
      "road": encodedCoordinates,
      "roadWidth": roadOption.roadWidth,
      'isDotted': roadOption.isDotted,
      'zoomIntoRegion': roadOption.zoomInto,
    };
    data.addAll(Map.from(roadOption.toMap()));

    await _channels[idOSM]?.invokeMethod(
      "drawRoad#manually",
      data,
    );
  }

  @override
  Future<void> mapRotation(
    int idOSM,
    double degree,
  ) async {
    final client = _cameraRoutes[idOSM];
    if (client != null) {
      return client.setRotation(degree);
    }
    await _channels[idOSM]?.invokeMethod(
      "map#orientation",
      degree,
    );
  }

  @override
  Future<void> limitArea(int idOSM, BoundingBox box) async {
    await _channels[idOSM]?.invokeMethod("limitArea", [
      box.north,
      box.east,
      box.south,
      box.west,
    ]);
  }

  @override
  Future<void> removeLimitArea(int idOSM) async {
    await _channels[idOSM]?.invokeMethod("remove#limitArea");
  }

  @override
  Future<void> customUserLocationMarker(
    int idOSM,
    GlobalKey personGlobalKey,
    GlobalKey directionArrowGlobalKey,
  ) async {
    final iconPerson = await _capturePng(personGlobalKey);
    final iconArrowDirection = await _capturePng(directionArrowGlobalKey);
    HashMap<String, dynamic> args = HashMap();

    args["personIcon"] = iconPerson;
    args["arrowDirectionIcon"] = iconArrowDirection;

    await _channels[idOSM]?.invokeMethod("user#locationMarkers", args);
  }

  @override
  Future<void> addMarker(
    int idOSM,
    GeoPoint p, {
    GlobalKey? globalKeyIcon,
    IconAnchor? iconAnchor,
  }) async {
    final client = _markersRoutes[idOSM];
    if (client != null) {
      // Flutter widget rendering stays asynchronous on the Dart side; only
      // the resulting PNG bytes cross the generated channel.
      Uint8List? iconBytes;
      if (globalKeyIcon != null) {
        iconBytes = await _capturePng(globalKeyIcon) as Uint8List;
      }
      final markerId = _nextTypedMarkerId(idOSM);
      await client.addMarker(
        markerId,
        p.latitude,
        p.longitude,
        iconBytes: iconBytes,
        // GeoPointWithOrientation carries radians; the typed contract is degrees.
        angleDegrees:
            p is GeoPointWithOrientation ? p.angle * 180 / math.pi : 0,
        anchor: iconAnchor?.toGenerated(),
      );
      // The attachment may have been closed while the add was in flight;
      // only extend identity when this client is still the frozen route.
      if (identical(_markersRoutes[idOSM], client)) {
        final keys = _typedMarkerKeys[idOSM] ??= {};
        (keys[_geoKey(p)] ??= []).add(markerId);
      }
      return;
    }

    Map<String, dynamic> args = {
      "point": p.toMap(),
    };
    if (globalKeyIcon != null) {
      var icon = await _capturePng(globalKeyIcon);

      args["icon"] = icon;
    }
    if (iconAnchor != null) {
      args["iconAnchor"] = iconAnchor.toMap();
    }

    await _channels[idOSM]?.invokeMethod("add#Marker", args);
  }

  @override
  Future<void> setMaximumZoomLevel(int idOSM, double maxZoom) async {
    await _channels[idOSM]?.invokeMethod("set#minZoom", maxZoom);
  }

  @override
  Future<void> setMinimumZoomLevel(int idOSM, double minZoom) async {
    await _channels[idOSM]?.invokeMethod("set#maxZoom", minZoom);
  }

  @override
  Future<double> getZoom(int idOSM) async {
    final client = _cameraRoutes[idOSM];
    if (client != null) {
      return client.getZoom();
    }
    final zoom = await _channels[idOSM]?.invokeMethod('get#Zoom');
    return zoom.toDouble();
  }

  @override
  Future<void> setZoom(
    int idOSM, {
    double? zoomLevel,
    double? stepZoom,
  }) async {
    final client = _cameraRoutes[idOSM];
    if (client != null && zoomLevel != null) {
      // Absolute zoom matches the generated contract (animated, mirroring
      // the legacy host default); relative steps stay on the legacy route.
      return client.setZoom(zoomLevel);
    }
    var args = {};
    if (zoomLevel != null) {
      args["zoomLevel"] = zoomLevel;
    } else if (stepZoom != null) {
      args["stepZoom"] = stepZoom;
    }
    await _channels[idOSM]?.invokeMethod('Zoom', args);
  }

  @override
  Future<GeoPoint> getMapCenter(int idMap) async {
    final client = _cameraRoutes[idMap];
    if (client != null) {
      final position = await client.getCameraPosition();
      return GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }
    final result = await _channels[idMap]?.invokeMethod('map#center', []);
    return GeoPoint.fromMap(result);
  }

  @override
  Future<BoundingBox> getBounds(int idOSM) async {
    final Map mapBounds = await _channels[idOSM]?.invokeMethod('map#bounds');
    return BoundingBox.fromMap(mapBounds);
  }

  @override
  Future<void> zoomToBoundingBox(
    int idOSM,
    BoundingBox box, {
    int paddinInPixel = 0,
  }) async {
    final Map<String, dynamic> args = {};
    args.addAll(box.toMap());
    args.putIfAbsent("padding", () => paddinInPixel);
    await _channels[idOSM]!.invokeMethod(
      "zoomToRegion",
      args,
    );
  }

  @override
  Future<void> setIconMarker(
    int idOSM,
    GeoPoint point,
    GlobalKey<State<StatefulWidget>> globalKeyIcon,
  ) async {
    final client = _markersRoutes[idOSM];
    final ids = _typedMarkerKeys[idOSM]?[_geoKey(point)];
    if (client != null && ids != null && ids.isNotEmpty) {
      // Legacy icon update targets the first marker found at the position.
      final icon = await _capturePng(globalKeyIcon) as Uint8List;
      await client.updateMarkerIcon(ids.first, icon);
      return;
    }

    Map<String, dynamic> args = {"point": point.toMap()};

    args["icon"] = await _capturePng(globalKeyIcon);

    try {
      await _channels[idOSM]?.invokeMethod("update#Marker", args);
    } on PlatformException {
      throw Exception("marker not exist");
    }
  }

  @override
  Future<void> clearAllRoads(
    int idOSM,
  ) async {
    await _channels[idOSM]?.invokeMethod("clear#roads");
  }

  @override
  Future<List<RoadInfo>> drawMultipleRoad(
    int idOSM,
    List<MultiRoadConfiguration> configs, {
    MultiRoadOption commonRoadOption = const MultiRoadOption.empty(),
  }) async {
    final len = configs.length;
    final roadInfos = <RoadInfo>[];
    final args = configs.toListMap(
      commonRoadOption: commonRoadOption,
    );
    for (var i = 0; i < len; i++) {
      final roadInfo = RoadInfo();
      roadInfos.add(roadInfo);
      args[i]['key'] = roadInfo.key;
    }

    final List result =
        (await _channels[idOSM]?.invokeListMethod("draw#multi#road", args))!;
    final List<Map<String, dynamic>> mapRoadInfo =
        result.map((e) => Map<String, dynamic>.from(e)).toList();
    return mapRoadInfo
        .asMap()
        .entries
        .map((entry) => roadInfos[entry.key].copyFromMap(map: entry.value))
        .toList();
  }

  @override
  Future<List<GeoPoint>> getGeoPointMarkers(int idOSM) async {
    final list = await _channels[idOSM]!.invokeListMethod("get#geopoints");
    return (list as List).map((e) => GeoPoint.fromMap(e)).toList();
  }

  @override
  Future<void> changeMarker(
    int idOSM,
    GeoPoint oldLocation,
    GeoPoint newLocation, {
    GlobalKey? globalKeyIcon,
    double? angle,
    IconAnchor? iconAnchor,
  }) async {
    final client = _markersRoutes[idOSM];
    final keys = _typedMarkerKeys[idOSM];
    final ids = keys?[_geoKey(oldLocation)];
    if (client != null && keys != null && ids != null && ids.isNotEmpty) {
      // Legacy change targets the first marker found at the old position.
      final markerId = ids.first;
      await client.moveMarker(
        markerId,
        newLocation.latitude,
        newLocation.longitude,
      );
      // Re-key identity immediately after the movement succeeded: a later
      // icon/rotation/anchor failure must not leave the old position
      // registered for a marker that already moved.
      if (identical(_typedMarkerKeys[idOSM], keys)) {
        final trackedIds = keys[_geoKey(oldLocation)];
        if (trackedIds != null) {
          trackedIds.remove(markerId);
          if (trackedIds.isEmpty) keys.remove(_geoKey(oldLocation));
          (keys[_geoKey(newLocation)] ??= []).add(markerId);
        }
      }
      if (globalKeyIcon != null) {
        final icon = await _capturePng(globalKeyIcon) as Uint8List;
        await client.updateMarkerIcon(markerId, icon);
      }
      if (angle != null) {
        await client.rotateMarker(markerId, angle * 180 / math.pi);
      }
      if (iconAnchor != null) {
        await client.setMarkerAnchor(markerId, iconAnchor.toGenerated());
      }
      return;
    }

    Map<String, dynamic> args = {
      "new_location": newLocation.toMap(),
      "old_location": oldLocation.toMap(),
      "angle": angle,
    };
    if (globalKeyIcon != null) {
      final icon = await _capturePng(globalKeyIcon);
      args["new_icon"] = icon;
    }
    if (iconAnchor != null) {
      args["iconAnchor"] = iconAnchor.toMap();
    }
    await _channels[idOSM]!.invokeMethod("change#Marker", args);
  }

  @override
  Future<void> changeTileLayer(int idOSM, CustomTile? tile) async {
    //osmTileURL
    final argTile = tile?.toMap() ??
        (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS
            ? CustomTile.osm().toMap()
            : null);
    await _channels[idOSM]!.invokeMethod("change#tile", argTile);
  }

  @override
  Future<void> removeRoad(int idOSM, String roadKey) async {
    await _channels[idOSM]!.invokeMethod("delete#road", roadKey);
  }

  @override
  Future<void> removeMarkers(int idOSM, List<GeoPoint> markers) async {
    final client = _markersRoutes[idOSM];
    final keys = _typedMarkerKeys[idOSM];
    if (client != null &&
        keys != null &&
        markers.isNotEmpty &&
        markers.every((point) => keys.containsKey(_geoKey(point)))) {
      // Legacy removal deletes every marker at each coordinate; the typed
      // table tracks every id per coordinate so removal matches it.
      final ids = [
        for (final point in markers) ...keys[_geoKey(point)]!,
      ];
      await client.removeMarkers(ids);
      if (identical(_typedMarkerKeys[idOSM], keys)) {
        for (final point in markers) {
          keys.remove(_geoKey(point));
        }
      }
      return;
    }
    await _channels[idOSM]!.invokeMethod(
      "delete#markers",
      markers.map((e) => e.toMap()).toList(),
    );
  }

  @override
  Future<void> toggleLayer(int idOSM, {required bool toggle}) async {
    await _channels[idOSM]!.invokeMethod("toggle#Alllayer", toggle);
  }

  @override
  Future<void> startLocationUpdating(
    int idOSM,
  ) =>
      _channels[idOSM]!.invokeMethod("startLocationUpdating");

  @override
  Future<void> stopLocationUpdating(
    int idOSM,
  ) =>
      _channels[idOSM]!.invokeMethod("stopLocationUpdating");
}

extension ConfigExt on MethodChannelOSM {
  Future<void> configureZoomMap(
    int idOSM,
    double initZoom,
    double minZoomLevel,
    double maxZoomLevel,
    double stepZoom,
  ) async {
    var args = {
      "initZoom": initZoom,
      "minZoomLevel": minZoomLevel,
      "maxZoomLevel": maxZoomLevel,
      "stepZoom": stepZoom,
    };

    await _channels[idOSM]?.invokeMethod('config#Zoom', args);
  }

  Future<void> initIosMap(int idOSM) async {
    await _channels[idOSM]?.invokeMethod("init#ios#map");
  }
}

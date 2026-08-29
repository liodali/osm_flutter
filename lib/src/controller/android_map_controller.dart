import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart' show Color;
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/src/android_transport/android_transport_factory.dart';
import 'package:permission_handler/permission_handler.dart';

typedef AndroidLocationPermissionRequester = Future<bool> Function();

/// Opt-in Android controller introduced alongside the legacy map controller.
///
/// Commands execute through the selected Android transport and complete from
/// MethodChannel acknowledgements. Optional backend fallback remains
/// attach-only.
final class AndroidMapController extends BaseMapController
    implements AndroidMapPlatform {
  AndroidMapController.withPosition({
    required GeoPoint initPosition,
    this.backend = AndroidMapBackend.methodChannel,
    BoundingBox areaLimit = const BoundingBox.world(),
    super.customTile,
    AndroidMapTransportFactory? transportFactory,
    AndroidLocationPermissionRequester? locationPermissionRequester,
  })  : _transportFactory =
            transportFactory ?? createDefaultAndroidMapTransport,
        _locationPermissionRequester =
            locationPermissionRequester ?? _requestForegroundLocation,
        super(
          initMapWithUserPosition: null,
          initPosition: initPosition,
          areaLimit: areaLimit,
        ) {
    camera = AndroidMapCamera._(this);
    markers = AndroidMapMarkers._(this);
    shapes = AndroidMapShapes._(this);
    staticPositions = AndroidMapStaticPositions._(this);
    roads = AndroidMapRoads._(this);
    layers = AndroidMapLayers._(this);
    location = AndroidMapLocation._(this);
    // Prevent a disposal/attach failure from becoming an unhandled async error
    // when callers only await attach. Awaiting [ready] still receives it.
    _readyCompleter.future.ignore();
  }

  final AndroidMapTransportFactory _transportFactory;
  final AndroidLocationPermissionRequester _locationPermissionRequester;
  final Completer<void> _readyCompleter = Completer<void>();
  final StreamController<AndroidMapEvent> _events =
      StreamController<AndroidMapEvent>.broadcast(sync: true);

  AndroidMapTransport? _transport;
  StreamSubscription<AndroidMapEvent>? _transportEvents;
  Future<void>? _disposeFuture;
  int? _viewId;
  bool _attaching = false;
  bool _attachStarted = false;
  int _markerSequence = 0;
  int _shapeSequence = 0;
  int _staticPositionSequence = 0;
  int _roadSequence = 0;

  late final AndroidMapCamera camera;
  late final AndroidMapMarkers markers;
  late final AndroidMapShapes shapes;
  late final AndroidMapStaticPositions staticPositions;
  late final AndroidMapRoads roads;
  late final AndroidMapLayers layers;
  late final AndroidMapLocation location;

  @override
  final AndroidMapBackend backend;

  @override
  AndroidMapBackend? get activeBackend => _transport?.backend;

  int? get viewId => _viewId;

  @override
  Future<void> get ready => _readyCompleter.future;

  @override
  Stream<AndroidMapEvent> get events => _events.stream;

  @override
  void init() {
    // Initialization is performed atomically by [attachAndroidMap]. The legacy
    // BaseMapController timer must not run without an IBaseOSMController.
  }

  @override
  Future<void> attachAndroidMap(int viewId) async {
    if (_disposeFuture != null) {
      throw AndroidMapException(
        operation: 'attach',
        code: 'controller_disposed',
        viewId: viewId,
      );
    }
    if (_attachStarted || _attaching || _viewId != null) {
      throw AndroidMapException(
        operation: 'attach',
        code: 'already_attached',
        viewId: _viewId ?? viewId,
      );
    }

    _attachStarted = true;
    _attaching = true;
    try {
      final candidates = backend == AndroidMapBackend.auto
          ? const [
              AndroidMapBackend.jni,
              AndroidMapBackend.methodChannel,
            ]
          : [backend];

      for (final candidateBackend in candidates) {
        AndroidMapTransport? candidate;
        try {
          candidate = _transportFactory(candidateBackend);
          await candidate.attach(viewId);
          if (_disposeFuture != null) {
            throw AndroidMapException(
              operation: 'attach',
              code: 'controller_disposed',
              viewId: viewId,
            );
          }
        } catch (error, stackTrace) {
          await candidate?.close();
          final exception = _asException(
            error,
            operation: 'attach',
            viewId: viewId,
          );
          final mayFallback = _disposeFuture == null &&
              backend == AndroidMapBackend.auto &&
              candidateBackend == AndroidMapBackend.jni;
          if (mayFallback) {
            continue;
          }
          _completeReadyError(exception, stackTrace);
          throw exception;
        }

        _transport = candidate;
        _viewId = viewId;
        _transportEvents = candidate.events.listen(
          _onTransportEvent,
          onError: _onTransportError,
        );

        try {
          await candidate.initialize(initialPosition: initPosition!);
          return;
        } catch (error, stackTrace) {
          // Initialization is the first state-changing command. Never replay
          // it through another backend after it has been attempted.
          final exception = _asException(
            error,
            operation: 'initialize',
            viewId: viewId,
          );
          await _releaseTransport();
          _completeReadyError(exception, stackTrace);
          throw exception;
        }
      }

      final exception = AndroidMapException(
        operation: 'attach',
        code: 'no_backend_available',
        viewId: viewId,
      );
      _completeReadyError(exception, StackTrace.current);
      throw exception;
    } finally {
      _attaching = false;
    }
  }

  void _onTransportEvent(AndroidMapEvent event) {
    if (event.viewId != _viewId || _disposeFuture != null) {
      return;
    }
    _events.add(event);
    switch (event) {
      case AndroidMapReady(:final isReady):
        if (isReady && !_readyCompleter.isCompleted) {
          _readyCompleter.complete();
        }
        break;
      case AndroidMapError(:final error):
        _completeReadyError(error, StackTrace.current);
        break;
      default:
        break;
    }
  }

  void _onTransportError(Object error, StackTrace stackTrace) {
    final viewId = _viewId;
    if (viewId == null || _disposeFuture != null) return;
    final exception = _asException(
      error,
      operation: 'event',
      viewId: viewId,
    );
    _onTransportEvent(AndroidMapError(viewId: viewId, error: exception));
    _completeReadyError(exception, stackTrace);
  }

  AndroidMapException _asException(
    Object error, {
    required String operation,
    required int viewId,
  }) {
    if (error is AndroidMapException) return error;
    return AndroidMapException(
      operation: operation,
      code: 'transport_error',
      viewId: viewId,
      cause: error,
    );
  }

  void _completeReadyError(Object error, StackTrace stackTrace) {
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.completeError(error, stackTrace);
    }
  }

  Future<AndroidMapTransport> _readyTransport() async {
    await ready;
    final transport = _transport;
    if (transport == null || _disposeFuture != null) {
      throw AndroidMapException(
        operation: 'command',
        code: 'controller_disposed',
        viewId: _viewId,
      );
    }
    return transport;
  }

  Future<AndroidMapTransport> _locationTransport(
    String operation, {
    required bool requestPermission,
  }) async {
    final transport = await _readyTransport();
    if (!requestPermission) return transport;

    bool granted;
    try {
      granted = await _locationPermissionRequester();
    } catch (error) {
      throw AndroidMapException(
        operation: operation,
        code: 'location_permission_request_failed',
        viewId: _viewId,
        cause: error,
      );
    }
    if (!granted) {
      throw AndroidMapException(
        operation: operation,
        code: 'location_permission_denied',
        viewId: _viewId,
      );
    }
    return transport;
  }

  MarkerId _nextMarkerId() =>
      MarkerId('android-${_viewId ?? 'pending'}-${_markerSequence++}');

  ShapeId _nextShapeId() =>
      ShapeId('android-shape-${_viewId ?? 'pending'}-${_shapeSequence++}');

  StaticPositionId _nextStaticPositionId() => StaticPositionId(
        'android-static-${_viewId ?? 'pending'}-${_staticPositionSequence++}',
      );

  RoadId _nextRoadId() =>
      RoadId('android-road-${_viewId ?? 'pending'}-${_roadSequence++}');

  Future<void> _releaseTransport() async {
    await _transportEvents?.cancel();
    _transportEvents = null;
    await _transport?.close();
    _transport = null;
    _viewId = null;
  }

  Future<void> close() => dispose();

  @override
  Future<void> dispose() {
    final existing = _disposeFuture;
    if (existing != null) return existing;
    super.dispose();
    return _disposeFuture = _dispose();
  }

  Future<void> _dispose() async {
    _completeReadyError(
      AndroidMapException(
        operation: 'dispose',
        code: 'controller_disposed',
        viewId: _viewId,
      ),
      StackTrace.current,
    );
    await _releaseTransport();
    await _events.close();
  }
}

/// Typed camera capability for [AndroidMapController].
final class AndroidMapCamera {
  AndroidMapCamera._(this._controller);

  final AndroidMapController _controller;

  Future<void> moveTo(GeoPoint position, {bool animated = false}) async {
    final transport = await _controller._readyTransport();
    await transport.moveTo(position, animated: animated);
  }

  Future<void> setZoom(double zoom) async {
    final transport = await _controller._readyTransport();
    await transport.setZoom(zoom);
  }

  Future<double> getZoom() async {
    final transport = await _controller._readyTransport();
    return transport.getZoom();
  }

  Future<void> setRotation(double angle, {bool animated = true}) async {
    final transport = await _controller._readyTransport();
    await transport.setRotation(angle, animated: animated);
  }
}

/// Stable-ID marker capability for [AndroidMapController].
final class AndroidMapMarkers {
  AndroidMapMarkers._(this._controller);

  final AndroidMapController _controller;
  final Set<MarkerId> _issuedIds = {};

  /// Adds one marker. [iconBytes] must contain encoded image bytes such as PNG.
  Future<MarkerId> add(
    GeoPoint position, {
    MarkerId? markerId,
    Uint8List? iconBytes,
  }) async {
    if (iconBytes?.isEmpty ?? false) {
      throw _argumentException(_controller, 'addMarker', 'empty_icon');
    }
    final id = markerId ?? _controller._nextMarkerId();
    if (!_issuedIds.add(id)) {
      throw AndroidMapException(
        operation: 'addMarker',
        code: 'duplicate_marker_id',
        viewId: _controller.viewId,
        message: 'Marker ID ${id.value} was already issued by this controller.',
      );
    }
    try {
      final transport = await _controller._readyTransport();
      await transport.addMarker(id, position, iconBytes: iconBytes);
      return id;
    } catch (_) {
      _issuedIds.remove(id);
      rethrow;
    }
  }

  /// Adds markers in one native command and returns their stable IDs.
  Future<List<MarkerId>> addAll(Iterable<GeoPoint> positions) async {
    final values = positions.toList(growable: false);
    if (values.isEmpty) return const [];
    final entries = <MarkerId, GeoPoint>{
      for (final position in values) _controller._nextMarkerId(): position,
    };
    _issuedIds.addAll(entries.keys);
    try {
      final transport = await _controller._readyTransport();
      await transport.addMarkers(entries);
      return entries.keys.toList(growable: false);
    } catch (_) {
      _issuedIds.removeAll(entries.keys);
      rethrow;
    }
  }

  /// Replaces an existing marker icon using encoded image bytes.
  Future<void> updateIcon(MarkerId markerId, Uint8List iconBytes) async {
    if (iconBytes.isEmpty) {
      throw _argumentException(_controller, 'updateMarkerIcon', 'empty_icon');
    }
    final transport = await _controller._readyTransport();
    await transport.updateMarkerIcon(markerId, iconBytes);
  }

  Future<void> remove(MarkerId markerId) async {
    final transport = await _controller._readyTransport();
    await transport.removeMarker(markerId);
    _issuedIds.remove(markerId);
  }

  /// Removes markers in one native command.
  Future<void> removeAll(Iterable<MarkerId> markerIds) async {
    final ids = markerIds.toSet();
    if (ids.isEmpty) return;
    final transport = await _controller._readyTransport();
    await transport.removeMarkers(ids);
    _issuedIds.removeAll(ids);
  }
}

/// Circle and rectangle overlays keyed by [ShapeId].
final class AndroidMapShapes {
  AndroidMapShapes._(this._controller);

  final AndroidMapController _controller;
  final Set<ShapeId> _issuedIds = {};

  Future<ShapeId> addCircle({
    required GeoPoint center,
    required double radius,
    required Color color,
    Color? borderColor,
    double strokeWidth = 1,
    ShapeId? shapeId,
  }) async {
    if (!radius.isFinite ||
        radius <= 0 ||
        !strokeWidth.isFinite ||
        strokeWidth <= 0) {
      throw _argumentException(_controller, 'addCircle', 'invalid_shape');
    }
    final id = _issue(shapeId, 'addCircle');
    try {
      final transport = await _controller._readyTransport();
      await transport.addCircle(
        shapeId: id,
        center: center,
        radius: radius,
        fillColor: _signedArgb(color),
        borderColor: _signedArgb(borderColor ?? color),
        strokeWidth: strokeWidth,
      );
      return id;
    } catch (_) {
      _issuedIds.remove(id);
      rethrow;
    }
  }

  Future<ShapeId> addRectangle({
    required GeoPoint center,
    required double distance,
    required Color color,
    Color? borderColor,
    double strokeWidth = 1,
    ShapeId? shapeId,
  }) async {
    if (!distance.isFinite ||
        distance <= 0 ||
        !strokeWidth.isFinite ||
        strokeWidth <= 0) {
      throw _argumentException(_controller, 'addRectangle', 'invalid_shape');
    }
    final id = _issue(shapeId, 'addRectangle');
    try {
      final transport = await _controller._readyTransport();
      await transport.addRectangle(
        shapeId: id,
        center: center,
        distance: distance,
        fillColor: _signedArgb(color),
        borderColor: _signedArgb(borderColor ?? color),
        strokeWidth: strokeWidth,
      );
      return id;
    } catch (_) {
      _issuedIds.remove(id);
      rethrow;
    }
  }

  ShapeId _issue(ShapeId? requested, String operation) {
    final id = requested ?? _controller._nextShapeId();
    if (!_issuedIds.add(id)) {
      throw AndroidMapException(
        operation: operation,
        code: 'duplicate_shape_id',
        viewId: _controller.viewId,
        message: 'Shape ID ${id.value} was already issued by this controller.',
      );
    }
    return id;
  }

  Future<void> remove(ShapeId shapeId) async {
    final transport = await _controller._readyTransport();
    await transport.removeShape(shapeId);
    _issuedIds.remove(shapeId);
  }

  Future<void> clear() async {
    final transport = await _controller._readyTransport();
    await transport.clearShapes();
    _issuedIds.clear();
  }
}

/// Bulk static-position groups, optionally sharing one encoded icon.
final class AndroidMapStaticPositions {
  AndroidMapStaticPositions._(this._controller);

  final AndroidMapController _controller;
  final Set<StaticPositionId> _issuedIds = {};

  /// Creates or replaces a static-position group in one native command.
  Future<StaticPositionId> set(
    List<GeoPoint> positions, {
    StaticPositionId? groupId,
    Uint8List? iconBytes,
  }) async {
    if (positions.isEmpty) {
      throw _argumentException(
        _controller,
        'setStaticPositions',
        'empty_positions',
      );
    }
    if (iconBytes?.isEmpty ?? false) {
      throw _argumentException(
        _controller,
        'setStaticPositions',
        'empty_icon',
      );
    }
    final id = groupId ?? _controller._nextStaticPositionId();
    final wasIssued = _issuedIds.contains(id);
    _issuedIds.add(id);
    try {
      final transport = await _controller._readyTransport();
      await transport.setStaticPositions(
        id,
        List<GeoPoint>.unmodifiable(positions),
        iconBytes: iconBytes,
      );
      return id;
    } catch (_) {
      if (!wasIssued) _issuedIds.remove(id);
      rethrow;
    }
  }

  Future<void> remove(StaticPositionId groupId) async {
    final transport = await _controller._readyTransport();
    await transport.removeStaticPositions(groupId);
    _issuedIds.remove(groupId);
  }
}

/// Stable-ID road geometry. Route fetching stays in Dart; only coordinates are
/// sent to the Android renderer.
final class AndroidMapRoads {
  AndroidMapRoads._(this._controller);

  final AndroidMapController _controller;
  final Set<RoadId> _issuedIds = {};

  Future<RoadId> draw(
    List<GeoPoint> geometry, {
    RoadId? roadId,
    RoadOption option = const RoadOption.empty(),
  }) async {
    if (geometry.length < 2) {
      throw _argumentException(_controller, 'drawRoad', 'invalid_geometry');
    }
    final id = roadId ?? _controller._nextRoadId();
    if (!_issuedIds.add(id)) {
      throw AndroidMapException(
        operation: 'drawRoad',
        code: 'duplicate_road_id',
        viewId: _controller.viewId,
        message: 'Road ID ${id.value} was already issued by this controller.',
      );
    }
    try {
      final transport = await _controller._readyTransport();
      await transport.drawRoad(
        id,
        List<GeoPoint>.unmodifiable(geometry),
        option,
      );
      return id;
    } catch (_) {
      _issuedIds.remove(id);
      rethrow;
    }
  }

  Future<void> remove(RoadId roadId) async {
    final transport = await _controller._readyTransport();
    await transport.removeRoad(roadId);
    _issuedIds.remove(roadId);
  }

  Future<void> clear() async {
    final transport = await _controller._readyTransport();
    await transport.clearRoads();
    _issuedIds.clear();
  }
}

/// Base tile and overlay-layer configuration.
final class AndroidMapLayers {
  AndroidMapLayers._(this._controller);

  final AndroidMapController _controller;

  /// Sets a raster/vector tile source, or restores OSM when [tile] is null.
  Future<void> setTile(CustomTile? tile) async {
    final transport = await _controller._readyTransport();
    await transport.setTile(tile);
  }

  Future<void> setOverlaysVisible(bool visible) async {
    final transport = await _controller._readyTransport();
    await transport.setOverlaysVisible(visible);
  }
}

/// Foreground Android location capability.
///
/// Permission requests and every location command remain on MethodChannel for
/// both backends. Location subscriptions pause with the host Activity and
/// resume only when they were explicitly requested by the caller.
final class AndroidMapLocation {
  AndroidMapLocation._(this._controller);

  final AndroidMapController _controller;

  Future<void> showCurrentLocation() async {
    final transport = await _controller._locationTransport(
      'showCurrentLocation',
      requestPermission: true,
    );
    await transport.showCurrentLocation();
  }

  Future<GeoPoint> getCurrentLocation() async {
    final transport = await _controller._locationTransport(
      'getCurrentLocation',
      requestPermission: true,
    );
    return transport.getCurrentLocation();
  }

  Future<void> startUpdates() async {
    final transport = await _controller._locationTransport(
      'startLocationUpdates',
      requestPermission: true,
    );
    await transport.startLocationUpdates();
  }

  Future<void> stopUpdates() async {
    final transport = await _controller._locationTransport(
      'stopLocationUpdates',
      requestPermission: false,
    );
    await transport.stopLocationUpdates();
  }

  Future<void> startTracking({
    bool stopFollowOnDrag = false,
    bool disableMarkerRotation = false,
    bool useDirectionMarker = false,
    Anchor anchor = Anchor.center,
  }) async {
    final transport = await _controller._locationTransport(
      'startLocationTracking',
      requestPermission: true,
    );
    await transport.startLocationTracking(
      stopFollowOnDrag: stopFollowOnDrag,
      disableMarkerRotation: disableMarkerRotation,
      useDirectionMarker: useDirectionMarker,
      anchor: anchor,
    );
  }

  Future<void> stopTracking() async {
    final transport = await _controller._locationTransport(
      'stopLocationTracking',
      requestPermission: false,
    );
    await transport.stopLocationTracking();
  }
}

Future<bool> _requestForegroundLocation() async {
  final status = await Permission.locationWhenInUse.request();
  return status.isGranted || status.isLimited;
}

AndroidMapException _argumentException(
  AndroidMapController controller,
  String operation,
  String code,
) =>
    AndroidMapException(
      operation: operation,
      code: code,
      viewId: controller.viewId,
    );

int _signedArgb(Color color) {
  final value = color.toARGB32();
  return value > 0x7fffffff ? value - 0x100000000 : value;
}

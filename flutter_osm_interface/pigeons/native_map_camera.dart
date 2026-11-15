// Canonical camera/markers channel schema (Pigeon channel profile).
//
// This file is the single source of truth for the generated Dart, Kotlin and
// Swift contracts. Regenerate with `dart run pigeon` from this package
// root (pigeon 30.0.2 pinned in pubspec dev_dependencies). Never hand-edit
// the `.g.` outputs; never export generated types from public APIs.
//
// Scope: camera family + markers family (typed, stable ids), session-scoped.
// Events and location are later phases (C4) and live in separate schemas.
// Note: the Apple host advertises only [camera] for now; typed marker ops
// there are a declared C3 follow-up.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/channel/pigeon/native_map_camera.g.dart',
    kotlinOut:
        '../flutter_osm_android/android/src/main/kotlin/hamza/dali/flutter_osm_plugin/pigeon/NativeMapCamera.g.kt',
    swiftOut:
        '../darwin/flutter_osm_plugin/Sources/flutter_osm_plugin/Shared/Pigeon/NativeMapCamera.g.swift',
    kotlinOptions: KotlinOptions(
      package: 'hamza.dali.flutter_osm_plugin.pigeon',
    ),
    dartPackageName: 'flutter_osm_interface',
  ),
)

/// Identifies one live native map session.
///
/// `sessionToken` is minted by the host when the platform view is created and
/// is scoped to the owning engine; `generation` becomes invalid when the view
/// is replaced or disposed. The pair prevents routing commands to another
/// engine's reused view id. It is a routing guard, not a credential.
class NativeCameraSession {
  final String sessionToken;
  final int generation;

  const NativeCameraSession({required this.sessionToken, required this.generation});
}

/// Absolute camera state snapshot returned by queries.
///
/// `zoom` is an absolute zoom level (not a relative step); `rotation` is in
/// degrees, clockwise, matching the legacy `map#orientation` semantics.
class NativeCameraPosition {
  final double latitude;
  final double longitude;
  final double zoom;
  final double rotation;

  const NativeCameraPosition({
    required this.latitude,
    required this.longitude,
    required this.zoom,
    required this.rotation,
  });
}

/// Generated camera command route for one map session.
///
/// Completion semantics: a successful reply means the state was applied or
/// the animation was accepted by the native engine; it does not promise a
/// rendered frame or an animation finished. Errors arrive as standard
/// pigeon/codec errors and are mapped by the handwritten support facade.
@HostApi()
abstract class NativeMapCameraApi {
  /// Absolute zoom level query. Returns the last applied zoom, not an
  /// in-flight animation target.
  double getZoom(NativeCameraSession session);

  /// Sets an absolute zoom level. `animated` selects the native animation
  /// policy; the legacy relative `change#stepZoom` stays on its legacy route.
  void setZoom(NativeCameraSession session, double zoom, bool animated);

  /// Moves the camera center to the given coordinates.
  void moveTo(
    NativeCameraSession session,
    double latitude,
    double longitude,
    bool animated,
  );

  /// Sets the map rotation in degrees, clockwise.
  void setRotation(NativeCameraSession session, double angle, bool animated);

  /// Snapshot of the full camera state (center, zoom, rotation).
  NativeCameraPosition getCameraPosition(NativeCameraSession session);
}

/// Generated markers command route for one map session.
///
/// Mirrors the typed Android marker contract: stable string ids, coordinates
/// in degrees, and icon bytes prepared in Dart (Flutter widget rendering
/// stays asynchronous on the Dart side; only encoded PNG bytes cross the
/// channel). A null icon means the native default marker.
@HostApi()
abstract class NativeMapMarkersApi {
  /// Adds one marker. `iconBytes` is an encoded image (PNG) or null for the
  /// platform default icon.
  void addMarker(
    NativeCameraSession session,
    String markerId,
    double latitude,
    double longitude,
    Uint8List? iconBytes,
  );

  /// Bulk-adds markers with default icons: parallel id list and
  /// [lat, lon, lat, lon, ...] coordinates.
  void addMarkers(
    NativeCameraSession session,
    List<String> markerIds,
    Float64List coordinates,
  );

  /// Replaces one marker's icon with new encoded bytes.
  void updateMarkerIcon(
    NativeCameraSession session,
    String markerId,
    Uint8List iconBytes,
  );

  /// Removes one marker by stable id.
  void removeMarker(NativeCameraSession session, String markerId);

  /// Removes many markers by stable ids.
  void removeMarkers(NativeCameraSession session, List<String> markerIds);
}

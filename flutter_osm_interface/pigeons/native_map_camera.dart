// Canonical camera/markers channel schema (Pigeon channel profile).
//
// This file is the single source of truth for the generated Dart, Kotlin and
// Swift contracts. Regenerate with `dart run pigeon` from this package
// root (pigeon 30.0.2 pinned in pubspec dev_dependencies). Never hand-edit
// the `.g.` outputs; never export generated types from public APIs.
//
// Scope: camera family + markers family (typed, stable ids) + layers family
// (tile sources, overlay visibility) + shapes family (circles, rectangles)
// + roads family (manual drawing, removal, clearing) + location family
// (my-location layer, single-shot fixes) + location updates + follow-me
// tracking + user-location icons, session-scoped, plus the first
// native-to-Dart callback family: map readiness and restoration
// (`events.lifecycle`). All other events (taps, road taps, user location,
// region changes) and the Apple init sequencing stay on their existing
// legacy channels; the legacy event plane also remains the delivery route
// for JNI attachments, which never negotiate the typed event route.
// Note: the Apple host advertises [camera, markers, layers]; its typed
// marker ops live in `PigeonMarkersBridge` and its tile/layer ops in
// `PigeonLayersBridge` on the shared darwin session.
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

  /// Visible-region bounding box snapshot (degrees). Errors with
  /// `camera_not_ready` when the view cannot provide its visible rect yet.
  NativeBounds getBounds(NativeCameraSession session);

  /// Moves/animates the viewport to fit the bounding box with pixel padding.
  /// `paddingInPixel` is advisory; hosts may clamp it to engine limits.
  void zoomToBoundingBox(
    NativeCameraSession session,
    NativeBounds bounds,
    int paddingInPixel,
  );

  /// Restricts the camera to the bounding box area.
  void setBoundsLimit(NativeCameraSession session, NativeBounds bounds);

  /// Removes the camera area limit, restoring the world view.
  void removeBoundsLimit(NativeCameraSession session);

  /// Applies the zoom configuration (init/min/max/step), mirroring the
  /// legacy `config#Zoom` semantics.
  void configureZoom(
    NativeCameraSession session,
    NativeZoomConfiguration configuration,
  );
}

/// Normalized icon anchor in icon-relative units.
///
/// `(0.5, 0.5)` centers the icon on the coordinate; `(0.5, 1.0)` pins the
/// classic pin tip. Mirrors the legacy `IconAnchor` semantics.
class NativeMarkerAnchor {
  final double x;
  final double y;

  const NativeMarkerAnchor({required this.x, required this.y});
}

/// Logical (pre-scale) icon dimensions in Dart-side units.
///
/// Widget captures render at a device pixel ratio, so the raw PNG pixels do
/// not describe the marker's display size. Hosts combine these logical
/// dimensions with the display scale the way the legacy routes do.
class NativeMarkerSize {
  final int width;
  final int height;

  const NativeMarkerSize({required this.width, required this.height});
}

/// WGS84 bounding box in degrees, matching the legacy `BoundingBox` map
/// shape (`north`, `south`, `east`, `west`).
class NativeBounds {
  final double north;
  final double south;
  final double east;
  final double west;

  const NativeBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });
}

/// Zoom configuration applied at attachment time, mirroring the legacy
/// `config#Zoom` payload. Values are OSM zoom levels.
class NativeZoomConfiguration {
  final double initZoom;
  final double minZoomLevel;
  final double maxZoomLevel;
  final double stepZoom;

  const NativeZoomConfiguration({
    required this.initZoom,
    required this.minZoomLevel,
    required this.maxZoomLevel,
    required this.stepZoom,
  });
}

/// One tile-server template in platform-neutral form.
///
/// The url keeps its `{s}`/`{z}`/`{x}`/`{y}` placeholders exactly as the
/// application provided them; each host applies its own substitution rules
/// (Android expands the first subdomain and appends the z/x/y template,
/// Apple lets the map framework append the template). This mirrors what the
/// legacy routes encode per platform without baking either rule into the
/// wire contract.
class NativeTileServer {
  final String url;
  final List<String> subdomains;

  const NativeTileServer({required this.url, required this.subdomains});
}

/// Tile-source configuration mirroring the legacy `CustomTile.toMap()`
/// payload. `styleURL` selects a vector style (hosts derive the vector flag
/// from it, matching the legacy `isVector` encoding). `null` tile in
/// [NativeMapLayersApi.changeTileLayer] resets the platform default OSM
/// layer.
class NativeTileConfiguration {
  final List<NativeTileServer> urls;
  final String tileExtension;
  final String sourceName;
  final int tileSize;
  final int minZoomLevel;
  final int maxZoomLevel;

  /// Key name and value for tile servers requiring API-key access; both are
  /// null when the server needs no key.
  final String? apiKey;
  final String? apiValue;

  /// Vector style URL; null selects the raster path.
  final String? styleURL;

  const NativeTileConfiguration({
    required this.urls,
    required this.tileExtension,
    required this.sourceName,
    required this.tileSize,
    required this.minZoomLevel,
    required this.maxZoomLevel,
    this.apiKey,
    this.apiValue,
    this.styleURL,
  });
}

/// Generated layers command route for one map session (tile-source
/// selection and overlay visibility).
///
/// The host advertises the `layers` capability only when it implements this
/// surface; older hosts keep these commands on their legacy routes.
@HostApi()
abstract class NativeMapLayersApi {
  /// Selects the tile source. A null configuration resets the default OSM
  /// tile layer, mirroring the legacy `change#tile` semantics.
  void changeTileLayer(NativeCameraSession session, NativeTileConfiguration? tile);

  /// Shows or hides the overlay layers (marker overlays), mirroring the
  /// legacy `toggle#Alllayer` semantics.
  void setOverlaysVisible(NativeCameraSession session, bool visible);
}

/// WGS84 shape geometry shared by circles and rectangles.
///
/// Coordinates are degrees at full double precision; `radiusMeters` (circle)
/// and `distanceMeters` (rectangle side span) are meters. Colors are packed
/// `0xAARRGGBB` integers — the hosts decode them into their native color
/// representations the same way the legacy color lists did.
class NativeShapeStyle {
  final int fillColorArgb;
  final int? borderColorArgb;
  final double strokeWidth;

  const NativeShapeStyle({
    required this.fillColorArgb,
    this.borderColorArgb,
    required this.strokeWidth,
  });
}

/// Generated shapes command route for one map session (circles and
/// rectangles).
///
/// The host advertises the `shapes` capability only when it implements this
/// surface; older hosts keep these commands on their legacy routes.
/// Adding a shape with an existing id replaces it, mirroring the legacy
/// `draw#circle`/`draw#rect` behavior. Removal is a silent no-op for
/// unknown ids, like the legacy `remove#circle`/`remove#rect` handlers.
@HostApi()
abstract class NativeMapShapesApi {
  /// Draws (or replaces) one circle around the coordinate with the radius
  /// in meters.
  void addCircle(
    NativeCameraSession session,
    String shapeId,
    double latitude,
    double longitude,
    double radius,
    NativeShapeStyle style,
  );

  /// Draws (or replaces) one rectangle centered on the coordinate with the
  /// side distance in meters.
  void addRectangle(
    NativeCameraSession session,
    String shapeId,
    double latitude,
    double longitude,
    double distance,
    NativeShapeStyle style,
  );

  /// Removes one shape by id; unknown ids succeed without effect.
  void removeShape(NativeCameraSession session, String shapeId);

  /// Removes every circle, mirroring the keyless legacy `remove#circle`.
  void removeCircles(NativeCameraSession session);

  /// Removes every rectangle, mirroring the keyless legacy `remove#rect`.
  void removeRectangles(NativeCameraSession session);

  /// Removes every shape of any kind, mirroring the legacy `clear#shapes`.
  void clearShapes(NativeCameraSession session);
}

/// Road styling mirroring the legacy manual-drawing payload.
///
/// Colors are packed `0xAARRGGBB` integers. A null `borderColorArgb` with a
/// non-null `borderWidth` lets the host apply its legacy default border
/// color (Android transparent-black, Apple `#f55b5b`); a null
/// `borderWidth` draws the road without a border.
class NativeRoadStyle {
  final int roadColorArgb;
  final double roadWidth;
  final int? borderColorArgb;
  final double? borderWidth;
  final bool dotted;

  const NativeRoadStyle({
    required this.roadColorArgb,
    required this.roadWidth,
    this.borderColorArgb,
    this.borderWidth,
    required this.dotted,
  });
}

/// Generated roads command route for one map session: manual road drawing,
/// removal by id and clearing.
///
/// The host advertises the `roads` capability only when it implements this
/// surface; older hosts keep these commands on their legacy routes.
/// Route fetching/calculation stays asynchronous in Dart — only the
/// drawing of an already-computed polyline crosses this channel.
/// Drawing with an existing id replaces the road, mirroring the legacy
/// `drawRoad#manually` behavior; removal of unknown ids is a silent no-op,
/// like the legacy `delete#road`.
@HostApi()
abstract class NativeMapRoadsApi {
  /// Draws (or replaces) one road from flat `[lat, lon, lat, lon, ...]`
  /// coordinates at full double precision. `zoomInto` moves the camera to
  /// fit the road, mirroring the legacy `zoomIntoRegion`.
  void drawRoad(
    NativeCameraSession session,
    String roadId,
    Float64List coordinates,
    NativeRoadStyle style,
    bool zoomInto,
  );

  /// Removes one road by its key; unknown keys succeed without effect.
  void removeRoad(NativeCameraSession session, String roadId);

  /// Removes every road, mirroring the legacy `clear#roads`.
  void clearRoads(NativeCameraSession session);
}

/// Single location fix in degrees.
class NativeLocationFix {
  final double latitude;
  final double longitude;

  const NativeLocationFix({required this.latitude, required this.longitude});
}

/// Generated location command route for one map session: the my-location
/// layer toggle and single-shot fixes.
///
/// The host advertises the `location` capability only when it implements
/// this surface; older hosts keep these commands on their legacy routes.
/// Permission ownership stays with the host application: authorization
/// prompts and usage descriptions are native concerns, and denial arrives
/// as a `permission_denied` error, never as a hang.
///
/// Completion contract: each pending fix completes exactly once — on fix,
/// permission denial, timeout, session disposal, activity detachment or
/// settings denial. Overlapping requests fail immediately with
/// `location_request_in_progress`; late native callbacks are ignored.
@HostApi()
abstract class NativeMapLocationApi {
  /// Enables the my-location layer, opening the location-settings round
  /// trip when the provider is off (mirroring the legacy `currentLocation`).
  /// Completes once the flow is initiated — like the legacy route it does
  /// not wait for a fix; stream updates keep flowing on their existing
  /// event channel.
  @async
  void showMyLocation(NativeCameraSession session);

  /// Single-shot current position, mirroring the legacy `user#position`:
  /// the layer starts when needed and stops after the first fix. Completes
  /// exactly once per the contract above.
  @async
  NativeLocationFix getCurrentLocation(NativeCameraSession session);
}

/// Generated continuous-updates route for one map session.
///
/// The host advertises the `location.updates` capability only when it
/// implements this surface; older hosts keep these commands on their
/// legacy routes. Location events keep flowing on the existing event
/// channel; tracking (follow-me) and custom icons are separate concerns.
///
/// Completion contract: [startLocationUpdates] is idempotent — repeated
/// starts succeed without restarting the underlying service — and
/// completes exactly once with `permission_denied` or
/// `location_service_disabled` when the platform reports denial.
/// [stopLocationUpdates] is idempotent, never triggers an authorization
/// prompt, never fails, and preserves pending one-shot fixes and other
/// location consumers (tracking): it only ends the updates consumer
/// started by [startLocationUpdates].
@HostApi()
abstract class NativeMapLocationUpdatesApi {
  /// Starts continuous user-location updates without follow control.
  @async
  void startLocationUpdates(NativeCameraSession session);

  /// Ends the continuous-updates consumer without touching pending
  /// one-shot fixes or tracking.
  @async
  void stopLocationUpdates(NativeCameraSession session);
}

/// Follow-me tracking configuration, mirroring the legacy `trackMe`
/// arguments.
///
/// `stopFollowInDrag` lets an ending user drag release the follow camera;
/// `disableMarkerRotation` pins the user marker orientation;
/// `useDirectionMarker` swaps the marker for a directional arrow;
/// `anchor` is the normalized icon pivot. A null `anchor` keeps the pivots
/// the live icon configuration already has (per icon), so starting tracking
/// without an explicit override never re-centers icons the application
/// configured itself.
class NativeTrackingConfiguration {
  final bool stopFollowInDrag;
  final bool disableMarkerRotation;
  final bool useDirectionMarker;
  final NativeMarkerAnchor? anchor;

  const NativeTrackingConfiguration({
    required this.stopFollowInDrag,
    required this.disableMarkerRotation,
    required this.useDirectionMarker,
    required this.anchor,
  });
}

/// Generated follow-me tracking route for one map session.
///
/// The host advertises the `location.tracking` capability only when it
/// implements this surface; older hosts keep `trackMe` /
/// `deactivateTrackMe` on their legacy routes. Permission ownership
/// stays with the host application. Tracking shares the location
/// subscription with continuous updates and one-shot fixes: starting
/// tracking never disturbs them, and stopping tracking preserves both.
@HostApi()
abstract class NativeMapTrackingApi {
  /// Starts follow-me tracking; idempotent, completes exactly once with
  /// `location_service_disabled` when the platform reports the provider
  /// off.
  @async
  void enableTracking(
    NativeCameraSession session,
    NativeTrackingConfiguration configuration,
  );

  /// Ends follow-me tracking; idempotent, never prompts, never fails.
  /// Continuous updates and pending one-shot fixes keep running. Async so
  /// the Dart facade awaits native session validation and completion
  /// (stale sessions surface instead of firing into the void).
  @async
  void disableTracking(NativeCameraSession session);
}

/// Generated markers command route for one map session.
///
/// Mirrors the typed Android marker contract: stable string ids, coordinates
/// in degrees, and icon bytes prepared in Dart (Flutter widget rendering
/// stays asynchronous on the Dart side; only encoded PNG bytes cross the
/// channel). A null icon means the native default marker. Marker `angle`
/// is in degrees, clockwise, matching the camera rotation unit.
@HostApi()
abstract class NativeMapMarkersApi {
  /// Adds one marker. `iconBytes` is an encoded image (PNG) or null for the
  /// platform default icon. `angleDegrees` pre-rotates the icon;
  /// `anchor` selects the icon pivot (null = centered). `iconLogicalSize`
  /// carries the pre-scale widget dimensions for display scaling.
  void addMarker(
    NativeCameraSession session,
    String markerId,
    double latitude,
    double longitude,
    Uint8List? iconBytes,
    double angleDegrees,
    NativeMarkerAnchor? anchor,
    NativeMarkerSize? iconLogicalSize,
  );

  /// Bulk-adds markers with default icons: parallel id list and
  /// [lat, lon, lat, lon, ...] coordinates.
  void addMarkers(
    NativeCameraSession session,
    List<String> markerIds,
    Float64List coordinates,
  );

  /// Replaces one marker's icon with new encoded bytes. `iconLogicalSize`
  /// carries the pre-scale widget dimensions for display scaling.
  void updateMarkerIcon(
    NativeCameraSession session,
    String markerId,
    Uint8List iconBytes,
    NativeMarkerSize? iconLogicalSize,
  );

  /// Moves one marker to new coordinates without recreating it.
  void moveMarker(
    NativeCameraSession session,
    String markerId,
    double latitude,
    double longitude,
  );

  /// Replaces one marker's icon rotation in degrees, clockwise.
  void rotateMarker(
    NativeCameraSession session,
    String markerId,
    double angleDegrees,
  );

  /// Replaces one marker's icon anchor.
  void setMarkerAnchor(
    NativeCameraSession session,
    String markerId,
    NativeMarkerAnchor anchor,
  );

  /// Creates or replaces a static-position group: flat
  /// `[lat, lon, angleDegrees, lat, lon, angleDegrees, ...]` coordinates
  /// sharing one icon (`iconBytes` null = platform default icon;
  /// `iconLogicalSize` carries the pre-scale widget dimensions).
  void setStaticPositions(
    NativeCameraSession session,
    String groupId,
    Float64List coordinates,
    Uint8List? iconBytes,
    NativeMarkerSize? iconLogicalSize,
  );

  /// Removes one static-position group by id.
  void removeStaticPositions(NativeCameraSession session, String groupId);

  /// Removes one marker by stable id.
  void removeMarker(NativeCameraSession session, String markerId);

  /// Removes many markers by stable ids.
  void removeMarkers(NativeCameraSession session, List<String> markerIds);
}

/// One user-location icon prepared in Dart.
///
/// The application supplies the icon as a Flutter widget; the Dart side
/// renders it (asynchronously, with the capture rules the legacy
/// `user#locationMarkers` route uses) and only the encoded PNG bytes, the
/// logical (pre-scale) widget dimensions and the normalized anchor cross
/// this channel. Hosts combine the logical size with their own display
/// scale, exactly like the typed marker icon contract.
///
/// `anchor` is a normalized icon pivot: `(0.5, 0.5)` centers the icon on the
/// user coordinate and `(0.5, 1.0)` pins a pin tip. A null anchor preserves
/// the anchor the live configuration already has, so replacing icon bytes
/// never moves an active marker.
class NativeUserLocationIcon {
  final Uint8List iconBytes;
  final NativeMarkerSize? logicalSize;
  final NativeMarkerAnchor? anchor;

  const NativeUserLocationIcon({
    required this.iconBytes,
    this.logicalSize,
    this.anchor,
  });
}

/// The person + direction icon pair of the my-location layer.
///
/// Both icons are captured from their widgets, mirroring the legacy
/// `user#locationMarkers` payload that always carries the two images.
class NativeUserLocationIcons {
  final NativeUserLocationIcon person;
  final NativeUserLocationIcon direction;

  const NativeUserLocationIcons({
    required this.person,
    required this.direction,
  });
}

/// Generated user-location icon route for one map session.
///
/// The host advertises the `location.icons` capability only when it
/// implements this surface; older hosts keep the person/direction icon
/// replacement on their legacy `user#locationMarkers` route.
///
/// Completion contract: the call only swaps the layer icons, so it never
/// starts, stops or restarts the location subscription. Follow-me tracking,
/// continuous updates and pending one-shot fixes keep running untouched
/// (their markers are re-rendered in place), and denial/permission flows are
/// never triggered. A null configuration restores the platform default
/// icons and the default center anchor, mirroring the reset semantics of
/// the typed layers route.
@HostApi()
abstract class NativeMapUserLocationIconsApi {
  /// Replaces the person and direction icons of the my-location layer.
  ///
  /// `icons` null restores the platform defaults. Android keeps one pivot
  /// for both icons: the person anchor wins, falling back to the direction
  /// anchor when the person anchor is null.
  void setUserLocationIcons(
    NativeCameraSession session,
    NativeUserLocationIcons? icons,
  );
}

/// Generated native-to-Dart lifecycle event route for one map session.
///
/// The host advertises the `events.lifecycle` capability only when it
/// implements this surface. The route is negotiated before initialization
/// through the legacy-channel `map#events#lifecycle#route` selection: the
/// host defaults to the legacy event plane (`map#init` / `map#restored`
/// method-channel messages) and switches lifecycle delivery to these
/// callbacks only after a selection validated against the session identity.
/// Exactly one delivery route is active per attachment: once switched, the
/// host never emits lifecycle events on the legacy plane, and attachments
/// that never select this route (older hosts, non-opt-in, JNI command
/// planes) keep the legacy plane untouched.
///
/// Every callback carries the [NativeCameraSession] it belongs to; clients
/// drop callbacks whose token/generation does not match the attachment
/// (stale sessions after view replacement or disposal).
///
/// Delivery contract: readiness reports state transitions — hosts emit once
/// per initialization outcome and clients coalesce repeated identical
/// values, so one initialization produces exactly one readiness delivery.
/// Restoration is a discrete event emitted when the host restores a saved
/// map state (Android activity recreation); hosts without a restoration
/// concept (Apple) never emit it.
@FlutterApi()
abstract class NativeMapLifecycleEventsApi {
  /// Map readiness transition for the session (`true` after a successful
  /// initialization, `false` when readiness is lost).
  void onMapReady(NativeCameraSession session, bool isReady);

  /// The host restored the session's saved map state.
  void onMapRestored(NativeCameraSession session);
}

/// Generated native-to-Dart map-interaction event route for one map
/// session.
///
/// The host advertises the `events.interaction` capability only when it
/// implements this surface. The route is negotiated before initialization
/// through the legacy-channel `map#events#interaction#route` selection: the
/// host defaults to the legacy event plane (`receiveSinglePress` /
/// `receiveLongPress` method-channel messages) and switches interaction
/// delivery to these callbacks only after a selection validated against
/// the session identity. Exactly one delivery route is active per
/// attachment: once switched, the host never emits interaction events on
/// the legacy plane, and attachments that never select this route (older
/// hosts, non-opt-in applications and the JNI command plane) keep the
/// legacy event plane untouched.
///
/// Every callback carries the [NativeCameraSession] it belongs to; clients
/// drop callbacks whose token/generation does not match the attachment
/// (stale sessions after view replacement or disposal).
///
/// Delivery contract: single presses and long presses are discrete user
/// interactions. Each occurrence delivers exactly once through exactly one
/// route, and repeats are never coalesced — two identical taps deliver two
/// events. Coordinates travel as wire doubles, preserving the host's full
/// precision without a map round-trip.
@FlutterApi()
abstract class NativeMapInteractionEventsApi {
  /// The user single-pressed the map at the geographic coordinate.
  ///
  /// `latitude` / `longitude` are the press position in degrees with the
  /// host's full double precision.
  void onSinglePress(
    NativeCameraSession session,
    double latitude,
    double longitude,
  );

  /// The user long-pressed the map at the geographic coordinate.
  ///
  /// `latitude` / `longitude` are the press position in degrees with the
  /// host's full double precision.
  void onLongPress(
    NativeCameraSession session,
    double latitude,
    double longitude,
  );
}

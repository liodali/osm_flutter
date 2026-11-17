import Cocoa
import CoreLocation
import FlutterMacOS
import OSMFlutterFramework
import XCTest
@testable import flutter_osm_plugin

class RunnerTests: XCTestCase {

  func testRoadDestinationInstructionsDoNotContainOptionalDescriptions() {
    let instructions: [String: Any] = [
      "v5": [
        "turn": ["default": ["default": "Continue", "destination": "Continue toward {destination}"]],
        "constants": ["modifier": [String: String](), "ordinalize": [String: String]()],
      ]
    ]
    let cases = [
      ("A1:Berlin", "Continue toward A1: Berlin"),
      ("A1,A2:Berlin,Paris", "Continue toward A1: Berlin"),
      (",:Berlin", "Continue toward Berlin"),
      ("A1:,", "Continue toward A1"),
      (":", "Continue toward "),
      ("Berlin", "Continue toward Berlin"),
    ]
    for (destination, expected) in cases {
      let step = RoadStep(json: [
        "name": "", "duration": 0.0, "distance": 0.0, "driving_side": "right",
        "destinations": destination, "intersections": [[String: Any]](),
        "maneuver": ["type": "turn", "location": [8.0, 47.0],
                     "bearing_before": 0.0, "bearing_after": 0.0],
      ])
      XCTAssertEqual(step.buildInstruction(instructions: instructions,
        options: ["legIndex": 0, "legCount": 0]), expected, destination)
    }
  }

  @MainActor
  private func session(_ messenger: RecordingMessenger, id: Int64 = 1) -> MapSession {
    MapSession(.zero, viewId: id,
      channel: FlutterMethodChannel(name: "map_\(id)", binaryMessenger: messenger),
      binaryMessenger: messenger,
      args: ["isStaticMap": false], defaultPin: nil)
  }

  @MainActor
  func testCenterCompletesExactlyOnce() {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    var replies: [Any?] = []
    map.onListenMethodChannel(call: FlutterMethodCall(methodName: "map#center", arguments: nil)) {
      replies.append($0)
    }
    XCTAssertEqual(replies.count, 1)
    XCTAssertNotNil(replies[0] as? [String: Double])
  }

  @MainActor
  func testPermissionDenialCompletesPendingLocationOnceAndAllowsRetry() {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    var errors: [FlutterError] = []
    map.resultFlutter = { if let error = $0 as? FlutterError { errors.append(error) } }
    map.handlePermission(state: .NotGranted)
    map.handlePermission(state: .NotGranted)
    XCTAssertEqual(errors.map(\.code), ["permission"])
    XCTAssertNil(map.resultFlutter)

    var locations = 0
    map.resultFlutter = { if $0 is [String: Double] { locations += 1 } }
    map.locationChanged(userLocation: CLLocationCoordinate2D(latitude: 47, longitude: 8), heading: 0)
    map.locationChanged(userLocation: CLLocationCoordinate2D(latitude: 47, longitude: 8), heading: 0)
    XCTAssertEqual(locations, 1)
    XCTAssertNil(map.resultFlutter)
  }

  @MainActor
  func testDisposeFailsPendingResultsOnceAndIgnoresLateRoadCompletion() {
    let messenger = RecordingMessenger()
    let map = session(messenger)
    var errors: [String] = []
    map.resultFlutter = { errors.append(($0 as! FlutterError).code) }
    let completion = map.trackRoadResult(id: "pending") { errors.append(($0 as! FlutterError).code) }
    map.dispose()
    map.dispose()
    completion(["key": "late"])
    XCTAssertEqual(errors, ["disposed", "disposed"])
    XCTAssertTrue(messenger.handlers.isEmpty)
    XCTAssertNil(map.mapOSM.onMapGestureDelegate)
    XCTAssertNil(map.mapOSM.mapHandlerDelegate)
    XCTAssertNil(map.mapOSM.userLocationDelegate)
    XCTAssertNil(map.mapOSM.roadTapHandlerDelegate)
    XCTAssertNil(map.mapOSM.onMapMove)
  }

  @MainActor
  func testRoadResultOnlyCompletesOnce() {
    let map = session(RecordingMessenger())
    var count = 0
    let completion = map.trackRoadResult(id: "road") { _ in count += 1 }
    completion(nil)
    completion(nil)
    map.dispose()
    XCTAssertEqual(count, 1)
  }

  @MainActor
  func testBackingRefreshPreservesExactMarkerCoordinates() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let point = ["lat": 47.376912345, "lon": 8.541712345]
    map.onListenMethodChannel(
      call: FlutterMethodCall(methodName: "add#Marker", arguments: ["point": point])
    ) { _ in }
    map.handleDisplayScaleChanged()
    map.handleDisplayScaleChanged()
    let markers = map.mapOSM.markerManager.getAllMarkers()
    XCTAssertEqual(markers.count, 1)
    let coordinate = try XCTUnwrap(markers.first)
    // Regression: rounded lookup keys must never become refreshed positions.
    XCTAssertEqual(coordinate.latitude, point["lat"]!)
    XCTAssertEqual(coordinate.longitude, point["lon"]!)
  }

  @MainActor
  func testRemovingHostReleasesSessionAndLeavesOtherMapAttached() async throws {
    let messenger = RecordingMessenger()
    let other = session(messenger, id: 2)
    weak var released: MapSession?
    autoreleasepool {
      var host: MacOSMapHostView? = MacOSMapHostView(frame: .zero, session: session(messenger))
      released = host?.session
      // Two sessions on one messenger: each registers its legacy channel,
      // the ten generated camera channels (five original + five bounds and
      // zoom-configuration operations), and the ten generated marker
      // channels (alongside, never replacing legacy endpoints).
      XCTAssertEqual(messenger.handlers.count, 42)
      host = nil
    }
    // AppKit autoreleases views and the framework can have queued callbacks.
    // Give those transient references a bounded chance to drain.
    for _ in 0..<20 where released != nil {
      try await Task.sleep(nanoseconds: 50_000_000)
    }
    XCTAssertNil(released)
    // Disposal removes exactly this session's legacy channel and its
    // generated camera and marker channels; the other live map keeps its
    // full set.
    XCTAssertEqual(messenger.handlers.count, 21)
    XCTAssertEqual(messenger.handlers.keys.filter { $0.hasPrefix("map_") }, ["map_2"])
    XCTAssertFalse(
      messenger.handlers.keys.contains { $0.contains(".view_1") },
      "disposed session's generated channels must be unregistered")
    XCTAssertTrue(
      messenger.handlers.keys.contains { $0.hasSuffix(".view_2") },
      "the surviving session keeps its generated channels")
    var count = 0
    other.onListenMethodChannel(call: FlutterMethodCall(methodName: "map#center", arguments: nil)) { _ in count += 1 }
    XCTAssertEqual(count, 1)
    other.dispose()
  }

  // MARK: - Typed camera bounds and zoom configuration (Pigeon route)

  @MainActor
  private func cameraWireSession(_ map: MapSession) -> NativeCameraSession {
    NativeCameraSession(sessionToken: map.sessionToken, generation: map.generation)
  }

  @MainActor
  func testTypedCameraBridgeBoundsAndZoomConfiguration() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.cameraBridge)
    let wire = cameraWireSession(map)

    // Bounds query returns the visible box in degrees.
    let bounds = try bridge.getBounds(session: wire)
    XCTAssertTrue(bounds.north.isFinite)
    XCTAssertTrue(bounds.south.isFinite)

    // Zoom-to-bounds and limits apply without crashing.
    try bridge.zoomToBoundingBox(
      session: wire,
      bounds: NativeBounds(north: 49, south: 47, east: 4, west: 1),
      paddingInPixel: 24)
    try bridge.setBoundsLimit(
      session: wire,
      bounds: NativeBounds(north: 49, south: 47, east: 4, west: 1))
    try bridge.removeBoundsLimit(session: wire)

    // Zoom configuration updates the shared session configuration.
    try bridge.configureZoom(
      session: wire,
      configuration: NativeZoomConfiguration(
        initZoom: 8, minZoomLevel: 2, maxZoomLevel: 19, stepZoom: 3))
    XCTAssertEqual(map.zoomConfig.initZoom, 8)
    XCTAssertEqual(map.zoomConfig.minZoom, 2)
    XCTAssertEqual(map.zoomConfig.maxZoom, 19)
    XCTAssertEqual(map.zoomConfig.step, 3)
  }

  @MainActor
  func testTypedCameraBridgeRejectsStaleSessions() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.cameraBridge)
    let stale = NativeCameraSession(sessionToken: "wrong", generation: 0)

    XCTAssertThrowsError(try bridge.getBounds(session: stale)) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "stale_session")
    }
    XCTAssertThrowsError(
      try bridge.configureZoom(
        session: stale,
        configuration: NativeZoomConfiguration(
          initZoom: 8, minZoomLevel: 2, maxZoomLevel: 19, stepZoom: 1))
    ) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "stale_session")
    }
    XCTAssertThrowsError(
      try bridge.zoomToBoundingBox(
        session: stale,
        bounds: NativeBounds(north: 1, south: 0, east: 1, west: 0),
        paddingInPixel: 0)
    ) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "stale_session")
    }
  }

  // MARK: - Typed markers family (Pigeon route)

  /// Valid session envelope for the map's own generated channels.
  @MainActor
  private func wireSession(_ map: MapSession) -> NativeCameraSession {
    NativeCameraSession(sessionToken: map.sessionToken, generation: map.generation)
  }

  /// Renders a small solid PNG for icon-byte payloads.
  private func pngIconData() -> Data {
    let image = NSImage(size: NSSize(width: 8, height: 8))
    image.lockFocus()
    NSColor.red.setFill()
    NSRect(x: 0, y: 0, width: 8, height: 8).fill()
    image.unlockFocus()
    let tiff = image.tiffRepresentation!
    let rep = NSBitmapImageRep(data: tiff)!
    return rep.representation(using: .png, properties: [:])!
  }

  private func float64(_ values: [Double]) -> FlutterStandardTypedData {
    var data = Data(count: values.count * MemoryLayout<Double>.size)
    data.withUnsafeMutableBytes { raw in
      for (index, value) in values.enumerated() {
        raw.storeBytes(
          of: value,
          toByteOffset: index * MemoryLayout<Double>.size,
          as: Double.self)
      }
    }
    return FlutterStandardTypedData(float64: data)
  }

  @MainActor
  func testTypedMarkersBridgeAddsMovesRotatesAnchorsAndRemoves() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.markersBridge)
    let wire = wireSession(map)

    try bridge.addMarker(
      session: wire, markerId: "m-1", latitude: 47.0, longitude: 8.0,
      iconBytes: nil, angleDegrees: 0, anchor: nil, iconLogicalSize: nil)
    var markers = map.mapOSM.markerManager.getAllMarkers()
    XCTAssertEqual(markers.count, 1)
    XCTAssertEqual(markers.first?.latitude, 47.0)
    XCTAssertEqual(map.typedMarkerCoordinates["m-1"]?.longitude, 8.0)

    // Movement keeps exactly one marker and re-points the stable id.
    try bridge.moveMarker(session: wire, markerId: "m-1", latitude: 48.0, longitude: 9.0)
    markers = map.mapOSM.markerManager.getAllMarkers()
    XCTAssertEqual(markers.count, 1)
    XCTAssertEqual(markers.first?.latitude, 48.0)
    XCTAssertEqual(map.typedMarkerCoordinates["m-1"]?.longitude, 9.0)
    XCTAssertNil(map.typedMarkerId(at: CLLocationCoordinate2D(latitude: 47, longitude: 8)))

    // Rotation and anchor keep the marker in place (degrees in, radians kept).
    try bridge.rotateMarker(session: wire, markerId: "m-1", angleDegrees: 90)
    try bridge.setMarkerAnchor(
      session: wire, markerId: "m-1", anchor: NativeMarkerAnchor(x: 0.5, y: 1.0))
    markers = map.mapOSM.markerManager.getAllMarkers()
    XCTAssertEqual(markers.count, 1)
    XCTAssertEqual(markers.first?.longitude, 9.0)

    try bridge.removeMarker(session: wire, markerId: "m-1")
    XCTAssertEqual(map.mapOSM.markerManager.getAllMarkers().count, 0)
    XCTAssertTrue(map.typedMarkerCoordinates.isEmpty)
  }

  @MainActor
  func testTypedMarkersBridgeDuplicateAddsShareCoordinatesAndRemoveTogether()
    throws
  {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.markersBridge)
    let wire = wireSession(map)

    try bridge.addMarker(
      session: wire, markerId: "m-1", latitude: 47.0, longitude: 8.0,
      iconBytes: nil, angleDegrees: 0, anchor: nil, iconLogicalSize: nil)
    try bridge.addMarker(
      session: wire, markerId: "m-2", latitude: 47.0, longitude: 8.0,
      iconBytes: nil, angleDegrees: 0, anchor: nil, iconLogicalSize: nil)
    XCTAssertEqual(map.mapOSM.markerManager.getAllMarkers().count, 2)

    let coordinate = CLLocationCoordinate2D(latitude: 47, longitude: 8)
    XCTAssertEqual(Set(map.typedMarkerIds(at: coordinate)), ["m-1", "m-2"])

    // Coordinate-based removal deletes every marker at the position.
    let legacyIds = map.typedMarkerIds(at: coordinate)
    try bridge.removeMarkers(session: wire, markerIds: legacyIds)
    XCTAssertEqual(map.mapOSM.markerManager.getAllMarkers().count, 0)
    XCTAssertTrue(map.typedMarkerCoordinates.isEmpty)
  }

  @MainActor
  func testTypedMarkersBridgeRejectsAmbiguousDuplicateTargets() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.markersBridge)
    let wire = wireSession(map)

    // Two markers share one coordinate; native updates hit the first match.
    try bridge.addMarker(
      session: wire, markerId: "m-1", latitude: 47.0, longitude: 8.0,
      iconBytes: nil, angleDegrees: 0, anchor: nil, iconLogicalSize: nil)
    try bridge.addMarker(
      session: wire, markerId: "m-2", latitude: 47.0, longitude: 8.0,
      iconBytes: nil, angleDegrees: 0, anchor: nil, iconLogicalSize: nil)

    let icon = FlutterStandardTypedData(bytes: pngIconData())

    // The non-primary duplicate must be rejected for every id-targeted
    // mutation: mutating it would silently change the first marker while
    // the registry claimed the requested one.
    XCTAssertThrowsError(
      try bridge.moveMarker(
        session: wire, markerId: "m-2", latitude: 48.0, longitude: 9.0)
    ) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "markers_not_ready")
    }
    XCTAssertThrowsError(
      try bridge.updateMarkerIcon(
        session: wire, markerId: "m-2", iconBytes: icon,
        iconLogicalSize: NativeMarkerSize(width: 8, height: 8))
    )
    XCTAssertThrowsError(
      try bridge.rotateMarker(session: wire, markerId: "m-2", angleDegrees: 45)
    )
    XCTAssertThrowsError(
      try bridge.setMarkerAnchor(
        session: wire, markerId: "m-2", anchor: NativeMarkerAnchor(x: 0.5, y: 1.0))
    )
    XCTAssertThrowsError(
      try bridge.removeMarker(session: wire, markerId: "m-2")
    )

    // Nothing moved: both markers are still at the shared coordinate.
    let markers = map.mapOSM.markerManager.getAllMarkers()
    XCTAssertEqual(markers.count, 2)
    XCTAssertTrue(markers.allSatisfy { $0.latitude == 47.0 && $0.longitude == 8.0 })

    // The primary id stays fully mutable.
    try bridge.moveMarker(
      session: wire, markerId: "m-1", latitude: 48.0, longitude: 9.0)
    let moved = map.mapOSM.markerManager.getAllMarkers()
    XCTAssertEqual(moved.filter { $0.latitude == 48.0 }.count, 1)
    XCTAssertEqual(moved.filter { $0.latitude == 47.0 }.count, 1)
    XCTAssertEqual(map.typedMarkerCoordinates["m-1"]?.latitude, 48.0)
    XCTAssertEqual(map.typedMarkerCoordinates["m-2"]?.latitude, 47.0)

    // Batch removal of both ids at the shared coordinate is unambiguous.
    try bridge.removeMarkers(session: wire, markerIds: ["m-1", "m-2"])
    XCTAssertTrue(map.typedMarkerCoordinates.isEmpty)
    XCTAssertEqual(map.mapOSM.markerManager.getAllMarkers().count, 0)
  }

  @MainActor
  func testTypedMarkersDuplicatePrimarityFollowsInsertionOrder() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.markersBridge)
    let wire = wireSession(map)

    // Insertion order decides primarity: m-1 first, m-2 second.
    try bridge.addMarker(
      session: wire, markerId: "m-1", latitude: 47.0, longitude: 8.0,
      iconBytes: nil, angleDegrees: 0, anchor: nil, iconLogicalSize: nil)
    try bridge.addMarker(
      session: wire, markerId: "m-2", latitude: 47.0, longitude: 8.0,
      iconBytes: nil, angleDegrees: 0, anchor: nil, iconLogicalSize: nil)
    XCTAssertEqual(map.typedMarkerId(at: CLLocationCoordinate2D(latitude: 47, longitude: 8)), "m-1")

    // Moving the primary away promotes the second id to primary even after
    // the dictionary order is perturbed by unrelated markers.
    try bridge.moveMarker(
      session: wire, markerId: "m-1", latitude: 48.0, longitude: 9.0)
    try bridge.addMarker(
      session: wire, markerId: "m-3", latitude: 46.0, longitude: 7.0,
      iconBytes: nil, angleDegrees: 0, anchor: nil, iconLogicalSize: nil)
    XCTAssertEqual(
      map.typedMarkerId(at: CLLocationCoordinate2D(latitude: 47, longitude: 8)),
      "m-2",
      "primarity must follow native insertion order, not dictionary order")

    // The promoted duplicate is now an unambiguous target.
    try bridge.moveMarker(
      session: wire, markerId: "m-2", latitude: 49.0, longitude: 10.0)
    XCTAssertEqual(map.typedMarkerCoordinates["m-2"]?.latitude, 49.0)
    XCTAssertEqual(
      map.mapOSM.markerManager.getAllMarkers().count, 3,
      "the promoted move relocates the second duplicate, not the first")
  }

  @MainActor
  func testTypedStaticGroupIconWithoutDimensionsOmitsSizeForRefresh() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.markersBridge)
    let wire = wireSession(map)

    try bridge.setStaticPositions(
      session: wire, groupId: "group-1",
      coordinates: float64([47.0, 8.0, 0.0]),
      iconBytes: FlutterStandardTypedData(bytes: pngIconData()),
      iconLogicalSize: nil)

    // Unknown dimensions are recorded absent (never as an empty array that
    // would crash `toMarkerSize` during a display-scale refresh). The
    // record holds the bitmap payload alone; the refresh rebuilds the
    // legacy call around it.
    let payload = map.storedStaticPoiIconArgs(id: "group-1")
    XCTAssertNotNil(payload)
    XCTAssertNotNil(payload?["icon"])
    XCTAssertNil(payload?["size"])

    // A display-scale refresh must survive the recorded arguments.
    map.handleDisplayScaleChanged()
  }

  @MainActor
  func testLegacyChangeRecordsNewlyAppliedAnchor() {
    let map = session(RecordingMessenger())
    defer { map.dispose() }

    map.onListenMethodChannel(
      call: FlutterMethodCall(
        methodName: "add#Marker",
        arguments: [
          "point": ["lat": 47.0, "lon": 8.0],
          "iconAnchor": ["x": 0.5, "y": 1.0],
        ]
      )
    ) { _ in }

    map.onListenMethodChannel(
      call: FlutterMethodCall(
        methodName: "change#Marker",
        arguments: [
          "old_location": ["lat": 47.0, "lon": 8.0],
          "new_location": ["lat": 48.0, "lon": 9.0],
          "iconAnchor": ["x": 0.0, "y": 0.0],
        ]
      )
    ) { _ in }

    // The scale record must carry the newly applied anchor; keeping the old
    // cached one would revert the anchor on the next display-scale refresh.
    let anchorArgs = map.markerScaleRecordAnchorArgs(
      at: CLLocationCoordinate2D(latitude: 48, longitude: 9))
    XCTAssertEqual(anchorArgs?["x"] as? Double, 0.0)
    XCTAssertEqual(anchorArgs?["y"] as? Double, 0.0)

    // And the refresh reapplies exactly that anchor without crashing.
    map.handleDisplayScaleChanged()
    XCTAssertEqual(map.mapOSM.markerManager.getAllMarkers().count, 1)
  }

  @MainActor
  func testTypedMarkersBridgeRejectsPartiallySharedBatchRemoval() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.markersBridge)
    let wire = wireSession(map)

    try bridge.addMarker(
      session: wire, markerId: "m-1", latitude: 47.0, longitude: 8.0,
      iconBytes: nil, angleDegrees: 0, anchor: nil, iconLogicalSize: nil)
    try bridge.addMarker(
      session: wire, markerId: "m-2", latitude: 47.0, longitude: 8.0,
      iconBytes: nil, angleDegrees: 0, anchor: nil, iconLogicalSize: nil)
    try bridge.addMarker(
      session: wire, markerId: "m-3", latitude: 50.0, longitude: 10.0,
      iconBytes: nil, angleDegrees: 0, anchor: nil, iconLogicalSize: nil)

    // Removing only one of the two ids sharing a coordinate is ambiguous.
    XCTAssertThrowsError(
      try bridge.removeMarkers(session: wire, markerIds: ["m-2", "m-3"])
    )
    XCTAssertEqual(map.mapOSM.markerManager.getAllMarkers().count, 3)
    XCTAssertEqual(map.typedMarkerCoordinates.count, 3)
  }

  @MainActor
  func testTypedMarkersBridgeIconUpdateRequiresKnownIdAndKeepsLocation()
    throws
  {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.markersBridge)
    let wire = wireSession(map)

    let icon = FlutterStandardTypedData(bytes: pngIconData())
    // Unknown id fails without side effects.
    XCTAssertThrowsError(
      try bridge.updateMarkerIcon(
        session: wire, markerId: "missing", iconBytes: icon,
        iconLogicalSize: NativeMarkerSize(width: 8, height: 8))
    ) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "markers_not_ready")
    }

    try bridge.addMarker(
      session: wire, markerId: "m-1", latitude: 47.0, longitude: 8.0,
      iconBytes: nil, angleDegrees: 0, anchor: nil, iconLogicalSize: nil)
    try bridge.updateMarkerIcon(
      session: wire, markerId: "m-1", iconBytes: icon,
      iconLogicalSize: NativeMarkerSize(width: 8, height: 8))

    let markers = map.mapOSM.markerManager.getAllMarkers()
    XCTAssertEqual(markers.count, 1)
    XCTAssertEqual(markers.first?.latitude, 47.0)
    XCTAssertEqual(markers.first?.longitude, 8.0)
  }

  @MainActor
  func testTypedMarkersBridgeBatchAddValidatesPreconditions() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.markersBridge)
    let wire = wireSession(map)

    try bridge.addMarkers(
      session: wire, markerIds: ["a", "b"],
      coordinates: float64([47.0, 8.0, 48.0, 9.0]))
    XCTAssertEqual(map.mapOSM.markerManager.getAllMarkers().count, 2)

    // Mismatched payload fails without partial application.
    XCTAssertThrowsError(
      try bridge.addMarkers(session: wire, markerIds: ["c"], coordinates: float64([1.0]))
    )
    XCTAssertEqual(map.mapOSM.markerManager.getAllMarkers().count, 2)

    // Duplicate id fails without side effects.
    XCTAssertThrowsError(
      try bridge.addMarkers(
        session: wire, markerIds: ["a"], coordinates: float64([49.0, 10.0]))
    )
    XCTAssertEqual(map.mapOSM.markerManager.getAllMarkers().count, 2)

    // All-or-nothing removal: an unknown id rejects the whole command.
    XCTAssertThrowsError(
      try bridge.removeMarkers(session: wire, markerIds: ["a", "missing"])
    ) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "markers_not_ready")
    }
    XCTAssertEqual(map.mapOSM.markerManager.getAllMarkers().count, 2)
    try bridge.removeMarkers(session: wire, markerIds: ["a", "b"])
    XCTAssertEqual(map.mapOSM.markerManager.getAllMarkers().count, 0)
  }

  @MainActor
  func testTypedMarkersBridgeStaticGroupsDoNotTouchRegularMarkers() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.markersBridge)
    let wire = wireSession(map)

    try bridge.addMarker(
      session: wire, markerId: "m-1", latitude: 46.0, longitude: 7.0,
      iconBytes: nil, angleDegrees: 0, anchor: nil, iconLogicalSize: nil)

    // [lat, lon, angleDegrees] triples; 90 degrees converts to radians.
    try bridge.setStaticPositions(
      session: wire, groupId: "group-1",
      coordinates: float64([47.0, 8.0, 0.0, 48.0, 9.0, 90.0]),
      iconBytes: nil, iconLogicalSize: nil)
    // Regular markers are untouched by group mutations.
    let markers = map.mapOSM.markerManager.getAllMarkers()
    XCTAssertEqual(markers.count, 1)
    XCTAssertEqual(markers.first?.latitude, 46.0)

    try bridge.removeStaticPositions(session: wire, groupId: "group-1")
    XCTAssertEqual(map.mapOSM.markerManager.getAllMarkers().count, 1)

    // Malformed triples fail without touching the POI layer.
    XCTAssertThrowsError(
      try bridge.setStaticPositions(
        session: wire, groupId: "group-2",
        coordinates: float64([47.0, 8.0]), iconBytes: nil, iconLogicalSize: nil)
    )
  }

  @MainActor
  func testTypedMarkersBridgeRejectsStaleSessions() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.markersBridge)
    let stale = NativeCameraSession(sessionToken: "wrong", generation: 0)

    XCTAssertThrowsError(
      try bridge.addMarker(
        session: stale, markerId: "m-1", latitude: 47, longitude: 8,
        iconBytes: nil, angleDegrees: 0, anchor: nil, iconLogicalSize: nil)
    ) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "stale_session")
    }
    XCTAssertThrowsError(
      try bridge.removeStaticPositions(session: stale, groupId: "g")
    ) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "stale_session")
    }
    XCTAssertTrue(map.typedMarkerCoordinates.isEmpty)
  }

  @MainActor
  func testLegacyMarkerOpsShareTheTypedRegistry() {
    let map = session(RecordingMessenger())
    defer { map.dispose() }

    // Legacy add joins the shared registry under a minted UUID id.
    map.onListenMethodChannel(
      call: FlutterMethodCall(
        methodName: "add#Marker",
        arguments: ["point": ["lat": 47.0, "lon": 8.0]]
      )
    ) { _ in }
    XCTAssertEqual(map.typedMarkerCoordinates.count, 1)
    XCTAssertEqual(map.mapOSM.markerManager.getAllMarkers().count, 1)

    // Legacy change moves the same registry entry (coordinate identity).
    map.onListenMethodChannel(
      call: FlutterMethodCall(
        methodName: "change#Marker",
        arguments: [
          "old_location": ["lat": 47.0, "lon": 8.0],
          "new_location": ["lat": 48.0, "lon": 9.0],
        ]
      )
    ) { _ in }
    XCTAssertEqual(map.typedMarkerCoordinates.count, 1)
    XCTAssertEqual(
      map.typedMarkerCoordinates.values.first?.latitude, 48.0)
    let markers = map.mapOSM.markerManager.getAllMarkers()
    XCTAssertEqual(markers.count, 1)
    XCTAssertEqual(markers.first?.latitude, 48.0)

    // Legacy coordinate-based deletion clears the registry entry too.
    map.onListenMethodChannel(
      call: FlutterMethodCall(
        methodName: "delete#markers",
        arguments: [["lat": 48.0, "lon": 9.0]]
      )
    ) { _ in }
    XCTAssertEqual(map.typedMarkerCoordinates.count, 0)
    XCTAssertEqual(map.mapOSM.markerManager.getAllMarkers().count, 0)
  }
}

// Captures real FlutterMethodChannel registration without starting a Dart engine
// or contacting location services. Tests drive session callbacks explicitly.
private final class RecordingMessenger: NSObject, FlutterBinaryMessenger {
  var handlers: [String: FlutterBinaryMessageHandler] = [:]
  private var connections: [String: FlutterBinaryMessengerConnection] = [:]
  private var nextConnection: FlutterBinaryMessengerConnection = 0
  func send(onChannel channel: String, message: Data?) {}
  func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {
    callback?(nil)
  }
  func setMessageHandlerOnChannel(_ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler?) -> FlutterBinaryMessengerConnection {
    handlers[channel] = handler
    nextConnection += 1
    connections[channel] = nextConnection
    return nextConnection
  }
  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {
    guard let channel = connections.first(where: { $0.value == connection })?.key else { return }
    connections.removeValue(forKey: channel)
    handlers.removeValue(forKey: channel)
  }
}

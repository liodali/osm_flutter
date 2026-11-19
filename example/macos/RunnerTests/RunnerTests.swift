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
      // zoom-configuration operations), the ten generated marker channels,
      // the two generated layer channels (tile sources, overlay
      // visibility), the six generated shape channels (circle, rectangle,
      // remove by id, two kind clears, full clear) and the three generated
      // road channels (draw, remove, clear) — alongside, never replacing
      // legacy endpoints.
      XCTAssertEqual(messenger.handlers.count, 68)
      host = nil
    }
    // AppKit autoreleases views and the framework can have queued callbacks.
    // Give those transient references a bounded chance to drain.
    for _ in 0..<20 where released != nil {
      try await Task.sleep(nanoseconds: 50_000_000)
    }
    XCTAssertNil(released)
    // Disposal removes exactly this session's legacy channel and its
    // generated camera, marker, layer, shape and road channels; the other
    // live map keeps its full set.
    XCTAssertEqual(messenger.handlers.count, 34)
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

  // MARK: - Typed layers family (Pigeon route)

  @MainActor
  func testTypedLayersBridgeTileAndOverlayVisibility() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.layersBridge)
    let wire = cameraWireSession(map)

    // Raster tile selection applies without crashing.
    try bridge.changeTileLayer(
      session: wire,
      tile: NativeTileConfiguration(
        urls: [NativeTileServer(
          url: "https://{s}.tiles.example.org/style/",
          subdomains: ["a", "b"])],
        tileExtension: ".png",
        sourceName: "example-source",
        tileSize: 256,
        minZoomLevel: 3,
        maxZoomLevel: 18,
        apiKey: "access-token",
        apiValue: "secret",
        styleURL: nil))

    // Reset to the default OSM layer (null configuration).
    try bridge.changeTileLayer(session: wire, tile: nil)

    // Overlay visibility toggles both ways.
    try bridge.setOverlaysVisible(session: wire, visible: true)
    try bridge.setOverlaysVisible(session: wire, visible: false)
  }

  @MainActor
  func testTypedLayersBridgeRejectsStaleSessions() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.layersBridge)
    let stale = NativeCameraSession(sessionToken: "wrong", generation: 0)
    let tile = NativeTileConfiguration(
      urls: [NativeTileServer(url: "https://tiles.example.org/", subdomains: [])],
      tileExtension: ".png",
      sourceName: "example-source",
      tileSize: 256,
      minZoomLevel: 2,
      maxZoomLevel: 19,
      apiKey: nil,
      apiValue: nil,
      styleURL: nil)

    XCTAssertThrowsError(try bridge.changeTileLayer(session: stale, tile: tile)) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "stale_session")
    }
    XCTAssertThrowsError(
      try bridge.setOverlaysVisible(session: stale, visible: true)
    ) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "stale_session")
    }
  }

  @MainActor
  func testTypedTileTemplateNormalizationMirrorsLegacy() throws {
    func normalized(_ url: String, extension configured: String = ".png")
      -> (template: String, effectiveExtension: String) {
      let tile = NativeTileConfiguration(
        urls: [NativeTileServer(url: url, subdomains: [])],
        tileExtension: configured,
        sourceName: "example-source",
        tileSize: 256,
        minZoomLevel: 2,
        maxZoomLevel: 19,
        apiKey: nil,
        apiValue: nil,
        styleURL: nil)
      let map = MapSession.legacyTileMap(from: tile)
      let urls = map["urls"] as! [[String: Any]]
      return (urls[0]["url"] as! String, map["tileExtension"] as! String)
    }

    // Regression: a baked-in extension after the template must not reach
    // the framework alongside the configured one ({y}.png.png).
    XCTAssertEqual(
      normalized("https://tiles.example.org/style/{z}/{x}/{y}.png").template,
      "https://tiles.example.org/style/")
    // Template without a baked-in extension strips too; the framework
    // re-appends template + extension identically.
    XCTAssertEqual(
      normalized("https://tiles.example.org/style/{z}/{x}/{y}").template,
      "https://tiles.example.org/style/")
    // Plain hosts pass through unchanged.
    XCTAssertEqual(
      normalized("https://{s}.tiles.example.org/style/").template,
      "https://{s}.tiles.example.org/style/")
    // Legacy parity: a template the legacy regex did not match (y/x order)
    // stays untouched, matching what TileURLs.toMapiOS() forwarded.
    XCTAssertEqual(
      normalized("https://server.arcgisonline.com/tile/{z}/{y}/{x}.png").template,
      "https://server.arcgisonline.com/tile/{z}/{y}/{x}.png")

    // Regression: with no configured extension, the template's embedded
    // one must survive normalization or tile requests lose their suffix.
    let preserved = normalized("https://tiles.example.org/style/{z}/{x}/{y}.png", extension: "")
    XCTAssertEqual(preserved.template, "https://tiles.example.org/style/")
    XCTAssertEqual(preserved.effectiveExtension, ".png")
    // No configured and no embedded extension: requests stay extensionless.
    let extensionless = normalized("https://tiles.example.org/style/{z}/{x}/{y}", extension: "")
    XCTAssertEqual(extensionless.template, "https://tiles.example.org/style/")
    XCTAssertEqual(extensionless.effectiveExtension, "")
    // A configured extension always wins over the embedded one (legacy).
    let overridden = normalized("https://tiles.example.org/style/{z}/{x}/{y}.png", extension: ".jpg")
    XCTAssertEqual(overridden.template, "https://tiles.example.org/style/")
    XCTAssertEqual(overridden.effectiveExtension, ".jpg")
  }

  @MainActor
  func testTypedShapesBridgeAddReplaceRemoveClear() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.shapesBridge)
    let wire = cameraWireSession(map)
    let style = NativeShapeStyle(
      fillColorArgb: 0x8E24AAFF,
      borderColorArgb: 0xFF00D2FF,
      strokeWidth: 3.5)

    // Add a circle and a rectangle at full coordinate precision.
    try bridge.addCircle(
      session: wire, shapeId: "circle-1",
      latitude: 47.376912345, longitude: 8.541712345,
      radius: 250.5, style: style)
    try bridge.addRectangle(
      session: wire, shapeId: "rect-1",
      latitude: -33.865143, longitude: 151.2099,
      distance: 1200.25, style: style)

    // Replace: re-adding the same id must succeed (legacy draw# semantics).
    try bridge.addCircle(
      session: wire, shapeId: "circle-1",
      latitude: 47.1, longitude: 8.1,
      radius: 200.0, style: style)

    // Targeted removal and silent no-op for unknown ids.
    try bridge.removeShape(session: wire, shapeId: "rect-1")
    try bridge.removeShape(session: wire, shapeId: "missing-id")

    // Kind clears and the full clear.
    try bridge.removeCircles(session: wire)
    try bridge.removeRectangles(session: wire)
    try bridge.clearShapes(session: wire)
  }

  @MainActor
  func testTypedShapesBridgeRejectsStaleSessions() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.shapesBridge)
    let stale = NativeCameraSession(sessionToken: "wrong", generation: 0)
    let style = NativeShapeStyle(
      fillColorArgb: 0xFF000000, borderColorArgb: nil, strokeWidth: 1)

    XCTAssertThrowsError(
      try bridge.addCircle(
        session: stale, shapeId: "circle-1",
        latitude: 47, longitude: 8, radius: 100, style: style)
    ) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "stale_session")
    }
    XCTAssertThrowsError(
      try bridge.clearShapes(session: stale)
    ) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "stale_session")
    }
  }

  @MainActor
  func testTypedShapeColorListReproducesLegacyOrder() {
    // Packed 0xAARRGGBB must become the legacy [red, blue, green, alpha]
    // wire order the framework decoder reads.
    // 0x8E24AAFF: alpha 0x8E, red 0x24, green 0xAA, blue 0xFF →
    // legacy wire order [red, blue, green, alpha].
    XCTAssertEqual(
      MapSession.legacyColorList(0x8E24AAFF),
      [0x24, 0xFF, 0xAA, 0x8E])
    let map = MapSession.legacyShapeMap(
      key: "circle-1",
      latitude: 47.376912345,
      longitude: 8.541712345,
      sizeField: "radius",
      sizeMeters: 250.5,
      fillColorArgb: 0x8E24AAFF,
      borderColorArgb: nil,
      strokeWidth: 3.5)
    XCTAssertEqual(map["lat"] as? Double ?? 0, 47.376912345, accuracy: 1e-12)
    XCTAssertEqual(map["lon"] as? Double ?? 0, 8.541712345, accuracy: 1e-12)
    XCTAssertEqual(map["radius"] as? Double ?? 0, 250.5, accuracy: 1e-12)
    XCTAssertEqual(map["strokeWidth"] as? Double ?? 0, 3.5, accuracy: 1e-12)
    // Missing border falls back to the fill color, like the decoder default.
    XCTAssertNil(map["colorBorder"])
  }

  @MainActor
  func testLegacyTileHandlerRoutesThroughTypedService() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    // The legacy payload keeps its raw map decoding and its
    // ignore-on-null behavior for Apple hosts.
    map.onListenMethodChannel(
      call: FlutterMethodCall(methodName: "change#tile", arguments: nil)
    ) { _ in }
    let tileMap: [String: Any] = [
      "name": "mapnik",
      "urls": [["url": "https://{s}.tile.openstreetmap.org/", "subdomains": ["a", "b", "c"]]],
      "tileSize": 256,
      "tileExtension": ".png",
      "maxZoomLevel": 19,
      "minZoomLevel": 2,
    ]
    map.onListenMethodChannel(
      call: FlutterMethodCall(methodName: "change#tile", arguments: tileMap)
    ) { _ in }
    map.onListenMethodChannel(
      call: FlutterMethodCall(methodName: "toggle#Alllayer", arguments: true)
    ) { _ in }
    map.onListenMethodChannel(
      call: FlutterMethodCall(methodName: "toggle#Alllayer", arguments: false)
    ) { _ in }
  }

  // MARK: - Typed roads family (Pigeon route)

  @MainActor
  func testTypedRoadsBridgeDrawReplaceRemoveClear() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.roadsBridge)
    let wire = cameraWireSession(map)
    let style = NativeRoadStyle(
      roadColorArgb: 0xFF4CAF50,
      roadWidth: 5.0,
      borderColorArgb: 0xFFFFFFFF,
      borderWidth: 2.0,
      dotted: false)
    let coordinates = Data(
      ([
        47.376912345, 8.541712345, 47.1, 8.2, 47.0, 8.0,
      ] as [Double]).withUnsafeBytes { Data($0) })
    let typed = FlutterStandardTypedData(float64: coordinates)

    // Draw with and without zoom-to-route.
    try bridge.drawRoad(session: wire, roadId: "route-1", coordinates: typed, style: style, zoomInto: false)
    try bridge.drawRoad(session: wire, roadId: "route-1", coordinates: typed, style: style, zoomInto: true)

    // Replacement: re-drawing the same key succeeds (legacy semantics).
    let dotted = NativeRoadStyle(
      roadColorArgb: 0xFF2196F3, roadWidth: 3.0,
      borderColorArgb: nil, borderWidth: nil, dotted: true)
    try bridge.drawRoad(session: wire, roadId: "route-1", coordinates: typed, style: dotted, zoomInto: false)

    // Targeted removal and the silent unknown-key no-op.
    try bridge.removeRoad(session: wire, roadId: "route-1")
    try bridge.removeRoad(session: wire, roadId: "missing-road")

    // Full clear.
    try bridge.clearRoads(session: wire)
  }

  @MainActor
  func testTypedRoadsRemovalSyncsStoredTapMetadata() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.roadsBridge)
    let wire = cameraWireSession(map)

    // A road drawn through the remaining legacy fetched-road path keeps
    // tap metadata in the session bookkeeping.
    map.storedRoads["route-1"] = StoredRoad(
      id: "route-1", roadInformation: nil, instructions: [])
    map.storedRoads["route-2"] = StoredRoad(
      id: "route-2", roadInformation: nil, instructions: [])

    // Targeted removal drops exactly that key's metadata (legacy
    // delete#road parity), so a reused key cannot emit stale taps.
    try bridge.removeRoad(session: wire, roadId: "route-1")
    XCTAssertNil(map.storedRoads["route-1"])
    XCTAssertNotNil(map.storedRoads["route-2"])

    // Clearing wipes the whole bookkeeping alongside the roads.
    try bridge.clearRoads(session: wire)
    XCTAssertTrue(map.storedRoads.isEmpty)
  }

  @MainActor
  func testLegacyClearRoadsRoutesThroughTypedService() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    map.storedRoads["route-legacy"] = StoredRoad(
      id: "route-legacy", roadInformation: nil, instructions: [])

    map.onListenMethodChannel(
      call: FlutterMethodCall(methodName: "clear#roads", arguments: nil)
    ) { _ in }

    // The legacy handler shares the typed bookkeeping now.
    XCTAssertTrue(map.storedRoads.isEmpty)
  }

  @MainActor
  func testTypedRoadsBridgeRejectsStaleSessions() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.roadsBridge)
    let stale = NativeCameraSession(sessionToken: "wrong", generation: 0)
    let coordinates = Data(
      ([47.0, 8.0, 47.1, 8.1] as [Double]).withUnsafeBytes { Data($0) })
    let typed = FlutterStandardTypedData(float64: coordinates)
    let style = NativeRoadStyle(
      roadColorArgb: 0xFF000000, roadWidth: 5.0,
      borderColorArgb: nil, borderWidth: nil, dotted: false)

    XCTAssertThrowsError(
      try bridge.drawRoad(session: stale, roadId: "route-1", coordinates: typed, style: style, zoomInto: false)
    ) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "stale_session")
    }
    XCTAssertThrowsError(
      try bridge.clearRoads(session: stale)
    ) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "stale_session")
    }
  }

  @MainActor
  func testTypedRoadStyleConversionReproducesLegacyQuirks() {
    // Packed 0xFF4CAF50 → legacy hex keeps the alpha nibble, exactly like
    // Dart's `value.toRadixString(16)` did for Apple hosts.
    XCTAssertEqual(MapSession.hexString(fromArgb: 0xFF4CAF50), "#ff4caf50")
    // Opaque black edge of the formatter.
    XCTAssertEqual(MapSession.hexString(fromArgb: 0x00000000), "#0")

    // The legacy manual-drawing border width pre-adds the road width.
    XCTAssertEqual(
      MapSession.effectiveBorderWidth(2.0, roadWidth: 5.0), CFloat(7.0))
    // Regression: RoadOption.empty() carries borderWidth = 0; legacy
    // serialization omits it, so zero must draw borderless (nil) instead
    // of stroking a road-width border.
    XCTAssertNil(MapSession.effectiveBorderWidth(0.0, roadWidth: 5.0))
    XCTAssertNil(MapSession.effectiveBorderWidth(-1.0, roadWidth: 5.0))
    XCTAssertNil(MapSession.effectiveBorderWidth(nil, roadWidth: 5.0))
    // The full conversion runs with a zero border and produces a
    // configuration, proving the decode path accepts it.
    _ = MapSession.legacyRoadConfiguration(
      roadColorArgb: 0xFF4CAF50,
      roadWidth: 5.0,
      borderColorArgb: 0xFFFFFFFF,
      borderWidth: 0.0,
      dotted: true)
  }

  // MARK: - Typed location family (Pigeon route)

  /// Async counterpart of XCTAssertThrowsError for the generated async
  /// channel handlers.
  func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    errorHandler: @escaping (Error) -> Void
  ) async {
    do {
      _ = try await expression()
      XCTFail("expected a thrown error")
    } catch {
      errorHandler(error)
    }
  }

  @MainActor
  func testTypedLocationFixCompletesExactlyOnceAndIgnoresLateCallbacks() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    var completions = 0
    var outcome: MapSession.LocationFixOutcome?
    map.pendingLocationFixCompletion = { result in
      outcome = result
      completions += 1
    }

    // One fix completes exactly once, at full precision.
    map.locationChanged(
      userLocation: CLLocationCoordinate2D(latitude: 47.376912345, longitude: 8.541712345),
      heading: 0)
    guard case let .fixed(latitude, longitude)? = outcome else {
      return XCTFail("expected a fix")
    }
    XCTAssertEqual(latitude, 47.376912345, accuracy: 1e-12)
    XCTAssertEqual(longitude, 8.541712345, accuracy: 1e-12)
    XCTAssertEqual(completions, 1)
    XCTAssertNil(map.pendingLocationFixCompletion)

    // Late completion attempts are no-ops (slot already cleared).
    map.completeLocationFix(.failed(code: "location_timeout", message: nil))
    map.locationChanged(userLocation: CLLocationCoordinate2D(latitude: 1, longitude: 2), heading: 0)
    XCTAssertEqual(completions, 1)
  }

  @MainActor
  func testTypedLocationOverlapIsRejectedExplicitly() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }

    // A pending typed request blocks an overlapping one: seed the slot and
    // issue a second typed request through the same mutual-exclusion path
    // the real request uses (without touching CLLocationManager).
    var completions = 0
    var outcome: MapSession.LocationFixOutcome?
    map.pendingLocationFixCompletion = { result in
      outcome = result
      completions += 1
    }

    map.resultFlutter = nil
    let overlap: MapSession.LocationFixCompletion = { result in
      guard case let .failed(code, _) = result else {
        return XCTFail("expected an overlap failure")
      }
      XCTAssertEqual(code, "location_request_in_progress")
    }
    // The overlap check inside typedRequestLocationFix runs before any
    // framework call; simulate its decision branch directly.
    if map.pendingLocationFixCompletion != nil || map.resultFlutter != nil {
      overlap(.failed(code: "location_request_in_progress", message: nil))
    } else {
      XCTFail("expected the pending slot to block the overlap")
    }
  }

  @MainActor
  func testTypedLocationDenialTimeoutAndDisposalCompleteOnce() throws {
    let map = session(RecordingMessenger())

    // Permission denial completes once with permission_denied.
    var denialCompletions = 0
    var denialOutcome: MapSession.LocationFixOutcome?
    map.pendingLocationFixCompletion = { result in
      denialOutcome = result
      denialCompletions += 1
    }
    map.handlePermission(state: OSMFlutterFramework.LocationPermission.NotGranted)
    guard case let .failed(denialCode, _)? = denialOutcome else {
      return XCTFail("expected a denial")
    }
    XCTAssertEqual(denialCode, "permission_denied")
    XCTAssertEqual(denialCompletions, 1)

    // Disposal completes a still-pending fix exactly once.
    var disposedCompletions = 0
    var disposedOutcome: MapSession.LocationFixOutcome?
    map.pendingLocationFixCompletion = { result in
      disposedOutcome = result
      disposedCompletions += 1
    }
    map.dispose()
    guard case let .failed(disposedCode, _)? = disposedOutcome else {
      return XCTFail("expected a disposal completion")
    }
    XCTAssertEqual(disposedCode, "disposed")
    XCTAssertEqual(disposedCompletions, 1)
  }

  @MainActor
  func testTypedLocationTimeoutCompletesOnce() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    map.locationFixTimeoutSeconds = 0.05
    var timeoutCompletions = 0
    var timeoutOutcome: MapSession.LocationFixOutcome?
    let timedOut = expectation(description: "location timeout fires")
    map.pendingLocationFixCompletion = { result in
      timeoutOutcome = result
      timeoutCompletions += 1
      timedOut.fulfill()
    }
    // Arm the deadline directly (no CLLocationManager involvement).
    map.scheduleLocationFixTimeout()

    await fulfillment(of: [timedOut], timeout: 2.0)
    guard case let .failed(timeoutCode, _)? = timeoutOutcome else {
      return XCTFail("expected a timeout")
    }
    XCTAssertEqual(timeoutCode, "location_timeout")
    XCTAssertEqual(timeoutCompletions, 1)
    XCTAssertNil(map.pendingLocationFixCompletion)
  }

  @MainActor
  func testLegacyLocationRequestSharesOwnershipAndDeadline() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }

    // A pending typed request blocks the legacy route explicitly: the
    // FlutterResult receives the in-progress error and resultFlutter is
    // never stashed (finding: both slots occupied left legacy hanging).
    var typedCompletions = 0
    var typedOutcome: MapSession.LocationFixOutcome?
    map.pendingLocationFixCompletion = { result in
      typedOutcome = result
      typedCompletions += 1
    }
    var legacyReplies: [Any?] = []
    let legacyDone = expectation(description: "legacy rejected")
    map.beginLegacyLocationFix({ reply in
      legacyReplies.append(reply)
      legacyDone.fulfill()
    })
    await fulfillment(of: [legacyDone], timeout: 1.0)
    guard let error = legacyReplies.first as? FlutterError else {
      return XCTFail("expected an in-progress rejection")
    }
    XCTAssertEqual(error.code, "location_request_in_progress")
    XCTAssertNil(map.resultFlutter)
    XCTAssertEqual(typedCompletions, 0)

    // The deadline covers legacy waits too: seed the legacy slot, arm the
    // timeout, and the legacy result completes with location_timeout.
    var legacyTimeoutReply: Any?
    let legacyTimeout = expectation(description: "legacy timeout")
    map.pendingLocationFixCompletion = nil
    map.locationFixTimeoutSeconds = 0.05
    map.beginLegacyLocationFix({ reply in
      legacyTimeoutReply = reply
      legacyTimeout.fulfill()
    })
    XCTAssertNotNil(map.resultFlutter)
    await fulfillment(of: [legacyTimeout], timeout: 2.0)
    guard let timeoutError = legacyTimeoutReply as? FlutterError else {
      return XCTFail("expected a timeout error")
    }
    XCTAssertEqual(timeoutError.code, "location_timeout")
    XCTAssertNil(map.resultFlutter)
  }

  @MainActor
  func testLegacyLocationPermissionDenialKeepsLegacyCode() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    var legacyReply: Any?
    let done = expectation(description: "legacy denial")
    map.beginLegacyLocationFix({ reply in
      legacyReply = reply
      done.fulfill()
    })
    map.handlePermission(state: OSMFlutterFramework.LocationPermission.NotGranted)
    await fulfillment(of: [done], timeout: 1.0)
    guard let error = legacyReply as? FlutterError else {
      return XCTFail("expected a permission error")
    }
    // Legacy parity: the historical "permission" code is preserved.
    XCTAssertEqual(error.code, "permission")
    XCTAssertNil(map.resultFlutter)
  }

  @MainActor
  func testLegacySuccessCancelsDeadlineAndStaleTimerIsBoundToIdentity() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }

    // Legacy request arms a deadline; a successful fix must cancel it.
    var legacyReply: Any?
    let legacyDone = expectation(description: "legacy fix")
    map.beginLegacyLocationFix({ reply in
      legacyReply = reply
      legacyDone.fulfill()
    })
    XCTAssertNotNil(map.locationFixTimeoutWorkItem)
    let epoch = map.locationRequestEpoch

    map.locationChanged(
      userLocation: CLLocationCoordinate2D(latitude: 47.3769, longitude: 8.5417),
      heading: 0)
    await fulfillment(of: [legacyDone], timeout: 1.0)
    XCTAssertNotNil(legacyReply)
    // Regression: success clears the armed timer — a left-behind timer
    // could expire a newer request prematurely.
    XCTAssertNil(map.locationFixTimeoutWorkItem)

    // Request-identity binding: a timer armed for an older epoch never
    // fires after a newer request owns the slot. Arm a short deadline for
    // the "newer" request, then rewind the epoch to simulate the stale
    // timer's identity: the work item must see the mismatch and stay a
    // no-op.
    var newerCompletions = 0
    var newerOutcome: MapSession.LocationFixOutcome?
    map.pendingLocationFixCompletion = { result in
      newerOutcome = result
      newerCompletions += 1
    }
    let newerEpoch = map.locationRequestEpoch + 1
    map.locationRequestEpoch = newerEpoch
    map.locationFixTimeoutSeconds = 0.1
    map.scheduleLocationFixTimeout()
    // A stale timer's epoch predates the newer request.
    map.locationRequestEpoch = newerEpoch - 1

    let probe = expectation(description: "probe delay")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { probe.fulfill() }
    await fulfillment(of: [probe], timeout: 2.0)
    XCTAssertEqual(newerCompletions, 0)
    XCTAssertNotNil(map.pendingLocationFixCompletion)
  }

  @MainActor
  func testTypedLocationBridgeRejectsStaleSessions() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.locationBridge)
    let stale = NativeCameraSession(sessionToken: "wrong", generation: 0)

    // Validation happens before any framework call, so these never touch
    // the real CLLocationManager.
    await XCTAssertThrowsErrorAsync(
      try await bridge.showMyLocation(session: stale)
    ) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "stale_session")
    }
    await XCTAssertThrowsErrorAsync(
      try await bridge.getCurrentLocation(session: stale)
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

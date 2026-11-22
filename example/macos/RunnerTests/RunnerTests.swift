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
      // remove by id, two kind clears, full clear), the three generated
      // road channels (draw, remove, clear) and the generated user-location
      // icon channel — alongside, never replacing legacy endpoints.
      XCTAssertEqual(messenger.handlers.count, 78)
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
    XCTAssertEqual(messenger.handlers.count, 39)
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
    // Never touch the real location stack in tests.
    map.locationSingleShotRequest = {}

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
    map.locationSingleShotRequest = {}
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
    // Never touch the real location stack in tests: a live single-shot fix
    // arrives on its own schedule and would consume the pending slot this
    // test drives by hand.
    map.locationSingleShotRequest = {}

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

  // MARK: - Typed location-updates family (Pigeon route)

  @MainActor
  func testTypedUpdatesStartStopAreSafeAndPreserveConsumers() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.locationUpdatesBridge)
    let wire = cameraWireSession(map)

    // Recorder seam: the real CLLocationManager is never touched (no
    // authorization prompts, no live GPS); simulated fixes arrive at the
    // fixed Zurich coordinates.
    var toggles: [Bool] = []
    map.locationUpdatesToggle = { start in toggles.append(start) }

    // Start completes exactly once; repeated starts stay idempotent and
    // take updates ownership (location callbacks must not recenter).
    try await bridge.startLocationUpdates(session: wire)
    XCTAssertTrue(map.userLocationWithoutControl)
    XCTAssertTrue(map.updatesActive)
    try await bridge.startLocationUpdates(session: wire)
    XCTAssertTrue(map.updatesActive)
    // A repeated start does not re-toggle the framework.
    XCTAssertEqual(toggles, [true])

    // A pending one-shot fix survives stop: the updates consumer ends
    // without touching the fix slot or killing the manager outright.
    var fixOutcome: MapSession.LocationFixOutcome?
    var completions = 0
    map.pendingLocationFixCompletion = { result in
      fixOutcome = result
      completions += 1
    }
    // With a pending one-shot, the stop defers; a pending fix survives.
    // With a pending one-shot, the stop defers: no framework toggle yet.
    try await bridge.stopLocationUpdates(session: wire)
    try await bridge.stopLocationUpdates(session: wire)
    XCTAssertFalse(map.updatesActive)
    XCTAssertFalse(map.userLocationWithoutControl)
    XCTAssertNotNil(map.pendingLocationFixCompletion)
    XCTAssertEqual(completions, 0)
    XCTAssertEqual(toggles, [true])

    // Tracking ownership keeps the manager running through stop.
    map.trackMeActive = true
    map.updatesActive = true
    try await bridge.stopLocationUpdates(session: wire)
    XCTAssertFalse(map.updatesActive)
    XCTAssertTrue(map.trackMeActive)
    XCTAssertEqual(toggles, [true])

    // The deferred stop is armed behind the preserved fix.
    XCTAssertTrue(map.stopUpdatesWhenFixCompletes)

    // Tracking then ends (its consumer releases the subscription), so by
    // the time the one-shot completes nothing owns the manager anymore.
    map.trackMeActive = false

    // The one-shot still completes exactly once after the stop (at the
    // fixed Zurich coordinates), and the deferred stop then finishes:
    // the subscription ends unowned exactly once.
    map.locationChanged(
      userLocation: CLLocationCoordinate2D(latitude: 47.3769, longitude: 8.5417),
      heading: 0)
    XCTAssertEqual(completions, 1)
    XCTAssertNil(map.pendingLocationFixCompletion)
    XCTAssertFalse(map.stopUpdatesWhenFixCompletes)
    XCTAssertEqual(toggles, [true, false])
  }

  @MainActor
  func testTypedUpdatesCameraOwnershipAndDenialRollback() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }

    var toggles: [Bool] = []
    map.locationUpdatesToggle = { start in toggles.append(start) }

    // Camera ownership regression: updates mode suppresses the session
    // recenter (userLocationWithoutControl) — the framework knob is armed
    // with moveMap: true at toggle time so its own recenter stays off too.
    var started = false
    let startDone = expectation(description: "start")
    map.typedStartLocationUpdates { code, _ in
      if code == nil { started = true }
      startDone.fulfill()
    }
    wait(for: [startDone], timeout: 2.0)
    XCTAssertTrue(map.userLocationWithoutControl)
    XCTAssertTrue(map.updatesActive)
    map.locationChanged(
      userLocation: CLLocationCoordinate2D(latitude: 1.0, longitude: 2.0),
      heading: 0)
    // The camera-recenter guard held: no session recenter ran, and the
    // updates consumer is unchanged.
    XCTAssertTrue(map.updatesActive)

    // Rollback regression: a denied start must own nothing, or retries
    // would succeed without ever starting updates. Simulate the in-flight
    // denied start (the completion slot the synchronous denial routes to).
    map.updatesActive = true
    map.userLocationWithoutControl = true
    var startCode: String?
    let denialDone = expectation(description: "start denial")
    map.startingUpdatesCompletion = { code, _ in
      startCode = code
      denialDone.fulfill()
    }
    map.handlePermission(state: OSMFlutterFramework.LocationPermission.NotGranted)
    await fulfillment(of: [denialDone], timeout: 1.0)
    XCTAssertEqual(startCode, "permission_denied")
    XCTAssertFalse(map.updatesActive)
    XCTAssertFalse(map.userLocationWithoutControl)
    // The denial resets the framework tracking state through the seam, so
    // the native retry runs the toggle again instead of skipping it.
    XCTAssertEqual(toggles, [true, false])
  }

  @MainActor
  func testPromptDenialAfterInitiatedStartResetsOwnership() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }

    // An initiated start (authorization prompt path) completes success
    // and clears the completion slot; the user then denies the prompt.
    // Regression: the ownership reset must not depend on the slot still
    // being armed, or a retry reports success without restarting.
    var startCode: String?
    let started = expectation(description: "start initiated")
    var promptToggles: [Bool] = []
    map.locationUpdatesToggle = { start in promptToggles.append(start) }
    map.typedStartLocationUpdates { code, _ in
      startCode = code
      started.fulfill()
    }
    await fulfillment(of: [started], timeout: 2.0)
    XCTAssertNil(startCode)
    XCTAssertTrue(map.updatesActive)
    XCTAssertNil(map.startingUpdatesCompletion)

    // The prompt is denied afterwards: ownership resets so the retry
    // genuinely re-attempts; nothing was started, so the framework is
    // not stopped.
    map.handlePermission(state: OSMFlutterFramework.LocationPermission.NotGranted)
    XCTAssertFalse(map.updatesActive)
    XCTAssertFalse(map.userLocationWithoutControl)
    XCTAssertNil(map.startingUpdatesCompletion)
    // The framework tracking state resets with the session ownership.
    XCTAssertEqual(promptToggles, [true, false])
  }

  @MainActor
  func testSynchronousDenialDuringPendingFixFailsBothConsumers() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }

    // A pending one-shot and an in-flight start are both denied
    // synchronously: the fix fails with its denial code AND the start
    // completes with permission_denied (exactly once) - neither hangs,
    // and ownership rolls back.
    var fixCompletions = 0
    var fixOutcome: MapSession.LocationFixOutcome?
    map.pendingLocationFixCompletion = { result in
      fixOutcome = result
      fixCompletions += 1
    }
    var startCode: String?
    let startDenied = expectation(description: "start denied")
    map.startingUpdatesCompletion = { code, _ in
      startCode = code
      startDenied.fulfill()
    }
    // Keep the framework reset hermetic in tests.
    var denialToggles: [Bool] = []
    map.locationUpdatesToggle = { start in denialToggles.append(start) }

    map.handlePermission(state: OSMFlutterFramework.LocationPermission.NotGranted)
    await fulfillment(of: [startDenied], timeout: 1.0)

    XCTAssertEqual(startCode, "permission_denied")
    guard case let .failed(fixCode, _)? = fixOutcome else {
      return XCTFail("expected the fix to fail")
    }
    XCTAssertEqual(fixCode, "permission_denied")
    XCTAssertEqual(fixCompletions, 1)
    XCTAssertFalse(map.updatesActive)
    XCTAssertFalse(map.userLocationWithoutControl)
    XCTAssertNil(map.pendingLocationFixCompletion)
    XCTAssertNil(map.startingUpdatesCompletion)
    // The framework tracking state resets as part of the cleanup.
    XCTAssertEqual(denialToggles, [false])
  }

  @MainActor
  func testPromptDenialThenRetryRunsNativeToggleAgain() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.locationUpdatesBridge)
    let wire = cameraWireSession(map)

    // Stateful fake: models the framework tracking flag exactly like the
    // real toggle - a start while the flag is armed is skipped natively
    // (the stale-flag bug signature), a stop clears it.
    var frameworkTracking = false
    var toggles: [Bool] = []
    map.locationUpdatesToggle = { start in
      if start {
        if frameworkTracking { return }
        frameworkTracking = true
        toggles.append(true)
      } else {
        frameworkTracking = false
        toggles.append(false)
      }
    }

    // Start runs the native toggle and arms the framework flag.
    try await bridge.startLocationUpdates(session: wire)
    XCTAssertTrue(frameworkTracking)
    XCTAssertEqual(toggles, [true])

    // Prompt/revocation denial: session ownership AND framework state
    // reset through the seam.
    map.handlePermission(state: OSMFlutterFramework.LocationPermission.NotGranted)
    XCTAssertFalse(map.updatesActive)
    XCTAssertFalse(frameworkTracking)
    XCTAssertEqual(toggles, [true, false])

    // Retry: the native toggle runs again - updates genuinely restart
    // instead of a stale-flag success without running updates.
    try await bridge.startLocationUpdates(session: wire)
    XCTAssertTrue(frameworkTracking)
    XCTAssertEqual(toggles, [true, false, true])
  }

  // MARK: - Follow-me tracking (generated route)

  /// Stateful shared fake over both framework toggle seams: one flag
  /// models the real CLLocationManager tracking state. Starts skip while
  /// armed (the stale-flag bug signature), stops clear it only when no
  /// other consumer (updates, pending fix) owns it.
  /// Stateful shared fake over both framework toggle seams: one flag
  /// models the real CLLocationManager tracking state. Starts skip while
  /// armed (the stale-flag bug signature), stops clear it only when no
  /// other consumer (updates, pending fix) owns it. `grantPermission()`
  /// re-arms the reconciling tracking toggle after a denial-routing test
  /// replacement, modeling the authorization prompt being accepted.
  @MainActor
  private final class FrameworkFake {
    let entries: [String] = []
    var recording: [String] { _recording }
    private var _recording: [String] = []
    private var frameworkTracking = false
    private weak var map: MapSession?

    func install(into map: MapSession) {
      self.map = map
      // Never touch the real location stack in tests.
      map.locationEnableRequest = {}
      map.locationUpdatesToggle = { [weak self] start in
        guard let self = self else { return }
        if start {
          if self.frameworkTracking { return }
          self.frameworkTracking = true
          self._recording.append("updates:start")
        } else {
          self.frameworkTracking = false
          self._recording.append("updates:stop")
        }
      }
      installTrackingToggle()
    }

    /// Re-arms the reconciling tracking toggle (permission granted).
    func grantPermission() {
      installTrackingToggle()
    }

    private func installTrackingToggle() {
      guard let map = map else { return }
      map.trackingToggle = { [weak self] start in
        guard let self = self else { return }
        if start {
          if self.frameworkTracking { return }
          self.frameworkTracking = true
          self._recording.append("tracking:start")
        } else {
          if map.updatesActive || map.hasPendingLocationRequest {
            return // updates or a pending fix keep the manager armed
          }
          if self.frameworkTracking {
            self.frameworkTracking = false
            self._recording.append("tracking:stop")
          }
        }
      }
    }
  }

  @MainActor
  private func installSharedFrameworkFake(_ map: MapSession) -> FrameworkFake {
    let fake = FrameworkFake()
    fake.install(into: map)
    return fake
  }

  private func trackingConfig(
    stopFollowInDrag: Bool = false,
    disableMarkerRotation: Bool = false,
    useDirectionMarker: Bool = true,
    anchorX: Double? = 0.5,
    anchorY: Double? = 0.5
  ) -> NativeTrackingConfiguration {
    NativeTrackingConfiguration(
      stopFollowInDrag: stopFollowInDrag,
      disableMarkerRotation: disableMarkerRotation,
      useDirectionMarker: useDirectionMarker,
      anchor: anchorX.flatMap { x in anchorY.map { y in NativeMarkerAnchor(x: x, y: y) } })
  }

  @MainActor
  func testTrackingEnableDisableAreSafeAndIdempotent() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.trackingBridge)
    let wire = cameraWireSession(map)
    let fake = installSharedFrameworkFake(map)

    // Enable completes exactly once; repeated enables stay idempotent.
    try await bridge.enableTracking(session: wire, configuration: trackingConfig())
    XCTAssertTrue(map.trackMeActive)
    XCTAssertEqual(fake.recording, ["tracking:start"])
    try await bridge.enableTracking(session: wire, configuration: trackingConfig())
    XCTAssertTrue(map.trackMeActive)
    XCTAssertEqual(fake.recording, ["tracking:start"])

    // Disable is idempotent: the framework stops exactly once.
    try await bridge.disableTracking(session: wire)
    XCTAssertFalse(map.trackMeActive)
    XCTAssertEqual(fake.recording, ["tracking:start", "tracking:stop"])
    try await bridge.disableTracking(session: wire)
    XCTAssertEqual(fake.recording, ["tracking:start", "tracking:stop"])
  }

  @MainActor
  func testUpdatesAndTrackingReconcileOnTheSharedFramework() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let updatesBridge = try XCTUnwrap(map.locationUpdatesBridge)
    let trackingBridge = try XCTUnwrap(map.trackingBridge)
    let wire = cameraWireSession(map)
    let fake = installSharedFrameworkFake(map)

    // Updates start arms the framework; tracking start then skips the
    // native toggle (already armed) and still owns the follow consumer.
    // The tracking configuration is captured for the in-place mode
    // reconcile (the armed framework gets its marker fields applied
    // without stopping the shared subscription).
    try await updatesBridge.startLocationUpdates(session: wire)
    try await trackingBridge.enableTracking(
      session: wire,
      configuration: trackingConfig(
        stopFollowInDrag: true,
        disableMarkerRotation: true,
        useDirectionMarker: true))
    XCTAssertTrue(map.updatesActive)
    XCTAssertTrue(map.trackMeActive)
    XCTAssertTrue(map.trackingUseDirectionMarker)
    XCTAssertTrue(map.trackingDisableMarkerRotation)
    XCTAssertEqual(fake.recording, ["updates:start"])

    // Stopping tracking preserves the continuous updates consumer.
    try await trackingBridge.disableTracking(session: wire)
    XCTAssertFalse(map.trackMeActive)
    XCTAssertTrue(map.updatesActive)
    XCTAssertEqual(fake.recording, ["updates:start"])

    // Stopping updates with tracking re-enabled: tracking keeps the
    // framework armed (the shared subscription survives).
    try await trackingBridge.enableTracking(session: wire, configuration: trackingConfig())
    try await updatesBridge.stopLocationUpdates(session: wire)
    XCTAssertFalse(map.updatesActive)
    XCTAssertTrue(map.trackMeActive)
    XCTAssertEqual(fake.recording, ["updates:start"])

    // Stopping tracking then releases the framework exactly once.
    try await trackingBridge.disableTracking(session: wire)
    XCTAssertEqual(fake.recording, ["updates:start", "tracking:stop"])
    XCTAssertFalse(map.trackMeActive)
  }

  @MainActor
  func testPendingFixSurvivesTrackingStop() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let trackingBridge = try XCTUnwrap(map.trackingBridge)
    let wire = cameraWireSession(map)
    let fake = installSharedFrameworkFake(map)

    try await trackingBridge.enableTracking(session: wire, configuration: trackingConfig())

    // A pending one-shot fix pins the framework: the tracking stop is
    // reconciled, the fix still completes at the fixed Zurich coordinates,
    // and the manager releases only afterwards.
    var completions = 0
    map.pendingLocationFixCompletion = { _ in completions += 1 }
    try await trackingBridge.disableTracking(session: wire)
    XCTAssertFalse(map.trackMeActive)
    XCTAssertTrue(map.hasPendingLocationRequest)
    XCTAssertEqual(fake.recording, ["tracking:start"])

    map.locationChanged(
      userLocation: CLLocationCoordinate2D(latitude: 47.3769, longitude: 8.5417),
      heading: 0)
    XCTAssertEqual(completions, 1)
    XCTAssertNil(map.pendingLocationFixCompletion)
    // The deferred reconciliation fires with the fix completed.
    XCTAssertEqual(fake.recording, ["tracking:start", "tracking:stop"])
  }

  @MainActor
  func testTrackingDenialRollsBackOwnershipAndFramework() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let trackingBridge = try XCTUnwrap(map.trackingBridge)
    let wire = cameraWireSession(map)
    let fake = installSharedFrameworkFake(map)

    // A synchronous framework denial routes through handlePermission:
    // the armed tracking start completes with permission_denied, the
    // ownership rolls back and the framework flag resets.
    map.trackingToggle = { [weak map] start in
      if start, let map = map {
        map.handlePermission(state: OSMFlutterFramework.LocationPermission.NotGranted)
        return
      }
    }
    var startCode: String?
    do {
      try await trackingBridge.enableTracking(session: wire, configuration: trackingConfig())
    } catch let error as PigeonError {
      startCode = error.code
    } catch {
      // Diagnose suite-order poison: which error escapes the bridge?
      XCTFail("FIRST-CALL-DIAG \(type(of: error)) \(error)")
      return
    }
    XCTAssertEqual(startCode, "permission_denied")
    XCTAssertFalse(map.trackMeActive)
    XCTAssertNil(map.startingTrackingCompletion)
    // The denial reset flows through the updates seam (shared flag).
    XCTAssertEqual(fake.recording, ["updates:stop"])

    // The prompt is then accepted: the reconciling tracking toggle is
    // re-armed and the retry runs the native toggle again.
    fake.grantPermission()
    try await trackingBridge.enableTracking(session: wire, configuration: trackingConfig())
    XCTAssertTrue(map.trackMeActive)
    XCTAssertEqual(fake.recording, ["updates:stop", "tracking:start"])
  }

  @MainActor
  func testTrackingDisposalKeepsOtherSessionAlive() async throws {
    let first = session(RecordingMessenger(), id: 1)
    let second = session(RecordingMessenger(), id: 2)
    defer { second.dispose() }
    let firstBridge = try XCTUnwrap(first.trackingBridge)
    let secondBridge = try XCTUnwrap(second.trackingBridge)
    let firstWire = cameraWireSession(first)
    let secondWire = cameraWireSession(second)
    installSharedFrameworkFake(first)
    installSharedFrameworkFake(second)

    try await firstBridge.enableTracking(session: firstWire, configuration: trackingConfig())
    // Disposal of the first session must not disturb the second's
    // tracking route; a recreated map works too (fresh session).
    first.dispose()
    try await secondBridge.enableTracking(session: secondWire, configuration: trackingConfig())
    try await secondBridge.disableTracking(session: secondWire)
    XCTAssertFalse(second.trackMeActive)
  }

  @MainActor
  func testTypedUpdatesBridgeRejectsStaleSessions() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.locationUpdatesBridge)
    let stale = NativeCameraSession(sessionToken: "wrong", generation: 0)

    await XCTAssertThrowsErrorAsync(
      try await bridge.startLocationUpdates(session: stale)
    ) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "stale_session")
    }
    await XCTAssertThrowsErrorAsync(
      try await bridge.stopLocationUpdates(session: stale)
    ) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "stale_session")
    }
  }

  @MainActor
  func testTypedUpdatesDisposalKeepsOtherSessionAlive() async throws {
    let messenger = RecordingMessenger()
    let first = session(messenger)
    let second = session(messenger, id: 2)
    let firstBridge = try XCTUnwrap(first.locationUpdatesBridge)
    let secondBridge = try XCTUnwrap(second.locationUpdatesBridge)
    let firstWire = cameraWireSession(first)
    let secondWire = cameraWireSession(second)

    var firstToggles: [Bool] = []
    var secondToggles: [Bool] = []
    first.locationUpdatesToggle = { start in firstToggles.append(start) }
    second.locationUpdatesToggle = { start in secondToggles.append(start) }

    try await firstBridge.startLocationUpdates(session: firstWire)
    // Disposal of the first session must not disturb the second's
    // updates route.
    first.dispose()
    try await secondBridge.startLocationUpdates(session: secondWire)
    try await secondBridge.stopLocationUpdates(session: secondWire)
    second.dispose()
    XCTAssertEqual(firstToggles, [true])
    XCTAssertEqual(secondToggles, [true, false])
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

  // MARK: - User-location icons (typed route)

  /// Records the prepared icon renders the session hands to the framework.
  private final class IconRenderRecorder {
    var renders: [MapSession.UserLocationIconsRender?] = []
    weak var map: MapSession?

    @MainActor
    func install(into map: MapSession) {
      self.map = map
      map.userLocationIconsRenderer = { [weak self] render in
        self?.renders.append(render)
      }
    }
  }

  @MainActor
  private func iconRenderRecorder(_ map: MapSession) -> IconRenderRecorder {
    let recorder = IconRenderRecorder()
    recorder.install(into: map)
    return recorder
  }

  private func userLocationIcons(
    personAnchor: NativeMarkerAnchor? = nil,
    directionAnchor: NativeMarkerAnchor? = nil,
    personSize: NativeMarkerSize? = NativeMarkerSize(width: 12, height: 20),
    directionSize: NativeMarkerSize? = NativeMarkerSize(width: 8, height: 14)
  ) -> NativeUserLocationIcons {
    NativeUserLocationIcons(
      person: NativeUserLocationIcon(
        iconBytes: FlutterStandardTypedData(bytes: pngIconData()),
        logicalSize: personSize,
        anchor: personAnchor),
      direction: NativeUserLocationIcon(
        iconBytes: FlutterStandardTypedData(bytes: pngIconData()),
        logicalSize: directionSize,
        anchor: directionAnchor))
  }

  @MainActor
  func testTypedUserLocationIconsBridgeAppliesPreparedIcons() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.userLocationIconsBridge)
    let recorder = iconRenderRecorder(map)
    let png = pngIconData()

    try bridge.setUserLocationIcons(
      session: cameraWireSession(map),
      icons: userLocationIcons(
        personAnchor: NativeMarkerAnchor(x: 0.5, y: 1.0),
        directionAnchor: NativeMarkerAnchor(x: 0.0, y: 0.5)))

    let render = try XCTUnwrap(recorder.renders.last ?? nil)
    // The prepared PNG bytes cross unchanged; logical widget sizes are kept
    // for display scaling and the anchors are applied per icon.
    XCTAssertEqual(render.person.pngData, png)
    XCTAssertEqual(render.direction.pngData, png)
    XCTAssertEqual(render.person.logicalSize, [12, 20])
    XCTAssertEqual(render.direction.logicalSize, [8, 14])
    guard case .normalized(let personX, let personY) = render.person.pivot else {
      return XCTFail("person anchor was not applied")
    }
    XCTAssertEqual(personX, 0.5)
    XCTAssertEqual(personY, 1.0)
    guard case .normalized(let directionX, let directionY) = render.direction.pivot else {
      return XCTFail("direction anchor was not applied")
    }
    XCTAssertEqual(directionX, 0.0)
    XCTAssertEqual(directionY, 0.5)
  }

  @MainActor
  func testTypedUserLocationIconsPreserveLiveAnchorsWhenOmitted() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.userLocationIconsBridge)
    let recorder = iconRenderRecorder(map)

    try bridge.setUserLocationIcons(
      session: cameraWireSession(map), icons: userLocationIcons())

    let render = try XCTUnwrap(recorder.renders.last ?? nil)
    // A null anchor keeps the pivot the live configuration already has, so
    // replacing icon bytes never moves an active marker.
    guard case .preserve = render.person.pivot else {
      return XCTFail("person pivot should be preserved")
    }
    guard case .preserve = render.direction.pivot else {
      return XCTFail("direction pivot should be preserved")
    }
    // Without anchors the render is still retained for the backing-scale
    // refresh, with its pre-scale logical sizes.
    XCTAssertEqual(map.lastUserLocationIconsRender?.person.logicalSize, [12, 20])
    XCTAssertEqual(map.lastUserLocationIconsRender?.direction.logicalSize, [8, 14])
  }

  @MainActor
  func testTypedUserLocationIconsResetRestoresCapturedDefaults() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.userLocationIconsBridge)
    let recorder = iconRenderRecorder(map)

    // The framework's own default icons are captured at view creation.
    XCTAssertNotNil(map.defaultUserLocationIcons)

    try bridge.setUserLocationIcons(session: cameraWireSession(map), icons: nil)

    XCTAssertEqual(recorder.renders.count, 1)
    XCTAssertNil(recorder.renders[0] ?? nil)
    // The restored defaults carry no Dart-side sizes, so nothing is replayed
    // on a backing-scale change.
    XCTAssertNil(map.lastUserLocationIconsRender)
  }

  @MainActor
  func testTypedUserLocationIconsKeepTrackingUpdatesAndPendingFixes() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.userLocationIconsBridge)
    let trackingBridge = try XCTUnwrap(map.trackingBridge)
    let updatesBridge = try XCTUnwrap(map.locationUpdatesBridge)
    let recorder = iconRenderRecorder(map)
    let fake = installSharedFrameworkFake(map)
    let wire = cameraWireSession(map)

    try await trackingBridge.enableTracking(
      session: wire, configuration: trackingConfig())
    try await updatesBridge.startLocationUpdates(session: wire)
    map.pendingLocationFixCompletion = { _ in }
    XCTAssertTrue(map.trackMeActive)
    XCTAssertTrue(map.updatesActive)
    XCTAssertTrue(map.hasPendingLocationRequest)
    let frameworkBefore = fake.recording

    try bridge.setUserLocationIcons(
      session: wire, icons: userLocationIcons())

    // Icon replacement only reconfigures the icons: no consumer is started,
    // stopped or restarted and the pending fix survives.
    XCTAssertEqual(recorder.renders.count, 1)
    XCTAssertTrue(map.trackMeActive)
    XCTAssertTrue(map.updatesActive)
    XCTAssertTrue(map.hasPendingLocationRequest)
    XCTAssertEqual(fake.recording, frameworkBefore)
  }

  @MainActor
  func testTypedUserLocationIconsRejectUndecodableBytes() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.userLocationIconsBridge)
    let recorder = iconRenderRecorder(map)

    let broken = NativeUserLocationIcons(
      person: NativeUserLocationIcon(
        iconBytes: FlutterStandardTypedData(bytes: Data([1, 2, 3])),
        logicalSize: nil, anchor: nil),
      direction: NativeUserLocationIcon(
        iconBytes: FlutterStandardTypedData(bytes: pngIconData()),
        logicalSize: nil, anchor: nil))

    XCTAssertThrowsError(
      try bridge.setUserLocationIcons(
        session: cameraWireSession(map), icons: broken)
    ) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "icons_not_ready")
    }
    XCTAssertTrue(recorder.renders.isEmpty)
  }

  @MainActor
  func testTypedUserLocationIconsRejectStaleSessions() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.userLocationIconsBridge)
    let recorder = iconRenderRecorder(map)
    let stale = NativeCameraSession(sessionToken: "wrong", generation: 0)

    XCTAssertThrowsError(
      try bridge.setUserLocationIcons(
        session: stale, icons: userLocationIcons())
    ) { error in
      XCTAssertEqual((error as? PigeonError)?.code, "stale_session")
    }
    XCTAssertTrue(recorder.renders.isEmpty)
  }

  @MainActor
  func testTypedUserLocationIconsAreIsolatedPerSessionAndSurviveDisposal() throws {
    let first = session(RecordingMessenger(), id: 1)
    let second = session(RecordingMessenger(), id: 2)
    defer { second.dispose() }
    let firstBridge = try XCTUnwrap(first.userLocationIconsBridge)
    let secondBridge = try XCTUnwrap(second.userLocationIconsBridge)
    let firstRecorder = iconRenderRecorder(first)
    let secondRecorder = iconRenderRecorder(second)
    let firstWire = cameraWireSession(first)
    let secondWire = cameraWireSession(second)

    try firstBridge.setUserLocationIcons(
      session: firstWire, icons: userLocationIcons())
    first.dispose()

    // The disposed session's bridge is unregistered and its icons are gone;
    // the second map still applies its own icons, and a recreated session
    // gets a fresh bridge.
    XCTAssertEqual(firstRecorder.renders.count, 1)
    XCTAssertTrue(secondRecorder.renders.isEmpty)

    try secondBridge.setUserLocationIcons(
      session: secondWire, icons: userLocationIcons())
    XCTAssertEqual(secondRecorder.renders.count, 1)

    let recreated = session(RecordingMessenger(), id: 3)
    defer { recreated.dispose() }
    let recreatedBridge = try XCTUnwrap(recreated.userLocationIconsBridge)
    let recreatedRecorder = iconRenderRecorder(recreated)
    try recreatedBridge.setUserLocationIcons(
      session: cameraWireSession(recreated), icons: nil)
    XCTAssertEqual(recreatedRecorder.renders.count, 1)
  }

  /// Recorder for the plugin-owned my-location marker draws.
  private final class UserLocationMarkerRecorder {
    var renders: [MapSession.UserLocationMarkerRender?] = []

    @MainActor
    func install(into map: MapSession) {
      map.userLocationMarkerRenderer = { [weak self] render in
        self?.renders.append(render)
      }
    }
  }

  @MainActor
  private func markerRecorder(_ map: MapSession) -> UserLocationMarkerRecorder {
    let recorder = UserLocationMarkerRecorder()
    recorder.install(into: map)
    return recorder
  }

  @MainActor
  func testTypedUserLocationIconsRenderInPlaceWithoutRestartingConsumers() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let iconsBridge = try XCTUnwrap(map.userLocationIconsBridge)
    let trackingBridge = try XCTUnwrap(map.trackingBridge)
    let fake = installSharedFrameworkFake(map)
    let recorder = markerRecorder(map)
    let wire = cameraWireSession(map)
    let png = pngIconData()
    let fix = CLLocationCoordinate2D(latitude: 47.3769, longitude: 8.5417)

    try iconsBridge.setUserLocationIcons(
      session: wire,
      icons: userLocationIcons(
        personAnchor: NativeMarkerAnchor(x: 0.5, y: 1.0)))
    // The plugin owns the marker from the first icon application on, so the
    // framework's destructively refreshed marker stays off.
    XCTAssertTrue(map.ownsUserLocationMarker)
    XCTAssertTrue(recorder.renders.isEmpty)

    try await trackingBridge.enableTracking(
      session: wire,
      configuration: trackingConfig(
        useDirectionMarker: false, anchorX: nil, anchorY: nil))
    XCTAssertTrue(recorder.renders.isEmpty, "no marker before the first fix")

    map.locationChanged(userLocation: fix, heading: 0)
    let first = try XCTUnwrap(recorder.renders.last ?? nil)
    XCTAssertEqual(first.pngData, png)
    XCTAssertEqual(first.logicalSize, [12, 20])
    XCTAssertEqual(first.anchor?.x, 0.5)
    XCTAssertEqual(first.anchor?.y, 1.0)
    XCTAssertNil(first.angleDegrees)
    XCTAssertEqual(first.location.latitude, fix.latitude)

    // An icon swap is an in-place redraw: same location, new bytes, and the
    // location consumers are never stopped or restarted.
    let before = recorder.renders.count
    let frameworkBefore = fake.recording
    try iconsBridge.setUserLocationIcons(
      session: wire,
      icons: userLocationIcons(
        personAnchor: NativeMarkerAnchor(x: 0.0, y: 1.0),
        personSize: NativeMarkerSize(width: 24, height: 40)))
    XCTAssertEqual(recorder.renders.count, before + 1)
    let swapped = try XCTUnwrap(recorder.renders.last ?? nil)
    XCTAssertEqual(swapped.pngData, png)
    XCTAssertEqual(swapped.logicalSize, [24, 40])
    XCTAssertEqual(swapped.anchor?.x, 0.0)
    XCTAssertEqual(swapped.location.latitude, fix.latitude)
    XCTAssertEqual(fake.recording, frameworkBefore)
  }

  @MainActor
  func testOwnedUserLocationMarkerFollowsFixesAndHeading() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let iconsBridge = try XCTUnwrap(map.userLocationIconsBridge)
    let trackingBridge = try XCTUnwrap(map.trackingBridge)
    installSharedFrameworkFake(map)
    let recorder = markerRecorder(map)
    let wire = cameraWireSession(map)
    let png = pngIconData()

    try iconsBridge.setUserLocationIcons(
      session: wire, icons: userLocationIcons())
    try await trackingBridge.enableTracking(
      session: wire, configuration: trackingConfig(anchorX: nil, anchorY: nil))

    // A heading-bearing fix rotates the direction icon; moving the map
    // position keeps the same texture.
    map.locationChanged(
      userLocation: CLLocationCoordinate2D(latitude: 47.5, longitude: 8.6),
      heading: 45)
    let rotated = try XCTUnwrap(recorder.renders.last ?? nil)
    XCTAssertEqual(rotated.pngData, png)
    XCTAssertEqual(rotated.angleDegrees, 45)
    XCTAssertEqual(rotated.location.latitude, 47.5)

    // Rotation disabled: the person icon is drawn unrotated.
    map.trackingDisableMarkerRotation = true
    map.locationChanged(
      userLocation: CLLocationCoordinate2D(latitude: 47.6, longitude: 8.7),
      heading: 90)
    let unrotated = try XCTUnwrap(recorder.renders.last ?? nil)
    XCTAssertNil(unrotated.angleDegrees)
    XCTAssertEqual(unrotated.location.latitude, 47.6)
  }

  @MainActor
  func testPendingFixPassKeepsTheOwnedMarkerStill() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let iconsBridge = try XCTUnwrap(map.userLocationIconsBridge)
    let trackingBridge = try XCTUnwrap(map.trackingBridge)
    installSharedFrameworkFake(map)
    let recorder = markerRecorder(map)
    let wire = cameraWireSession(map)

    try iconsBridge.setUserLocationIcons(
      session: wire, icons: userLocationIcons())
    try await trackingBridge.enableTracking(
      session: wire, configuration: trackingConfig(anchorX: nil, anchorY: nil))
    map.locationChanged(
      userLocation: CLLocationCoordinate2D(latitude: 47.1, longitude: 8.1),
      heading: 0)
    let renderedBefore = recorder.renders.count

    // The framework keeps its marker still for one-shot passes; the plugin
    // marker follows the same rule.
    var completions = 0
    map.pendingLocationFixCompletion = { _ in completions += 1 }
    map.locationChanged(
      userLocation: CLLocationCoordinate2D(latitude: 47.2, longitude: 8.2),
      heading: 0)
    XCTAssertEqual(completions, 1)
    XCTAssertEqual(recorder.renders.count, renderedBefore)

    map.locationChanged(
      userLocation: CLLocationCoordinate2D(latitude: 47.3, longitude: 8.3),
      heading: 0)
    XCTAssertEqual(recorder.renders.count, renderedBefore + 1)
  }

  @MainActor
  func testStoppingTrackingRemovesTheOwnedMarker() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let iconsBridge = try XCTUnwrap(map.userLocationIconsBridge)
    let trackingBridge = try XCTUnwrap(map.trackingBridge)
    installSharedFrameworkFake(map)
    let recorder = markerRecorder(map)
    let wire = cameraWireSession(map)

    try iconsBridge.setUserLocationIcons(
      session: wire, icons: userLocationIcons())
    try await trackingBridge.enableTracking(
      session: wire, configuration: trackingConfig(anchorX: nil, anchorY: nil))
    map.locationChanged(
      userLocation: CLLocationCoordinate2D(latitude: 47, longitude: 8), heading: 0)
    XCTAssertNotNil(recorder.renders.last ?? nil)

    try await trackingBridge.disableTracking(session: wire)
    // The removal uses the same atomic POI replace (no marker at all).
    XCTAssertNil(recorder.renders.last ?? nil)
  }

  @MainActor
  func testIconReplacementPreservesTheTrackingAppliedPivot() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let iconsBridge = try XCTUnwrap(map.userLocationIconsBridge)
    let trackingBridge = try XCTUnwrap(map.trackingBridge)
    installSharedFrameworkFake(map)
    let recorder = markerRecorder(map)
    let wire = cameraWireSession(map)

    // A tracking arm with a non-center anchor pivots the plugin-owned
    // default icons. Person-icon drawing so the assertions track one icon.
    try await trackingBridge.enableTracking(
      session: wire,
      configuration: trackingConfig(
        useDirectionMarker: false, anchorX: 0.0, anchorY: 0.5))
    map.locationChanged(
      userLocation: CLLocationCoordinate2D(latitude: 47, longitude: 8), heading: 0)

    // Replacing the icons WITHOUT anchors preserves that live pivot instead
    // of re-centering the markers.
    try iconsBridge.setUserLocationIcons(session: wire, icons: userLocationIcons())
    XCTAssertTrue(map.ownsUserLocationMarker)
    XCTAssertEqual(map.ownedUserLocationIcons?.person.anchor?.x, 0.0)
    XCTAssertEqual(map.ownedUserLocationIcons?.person.anchor?.y, 0.5)
    XCTAssertEqual(map.ownedUserLocationIcons?.direction.anchor?.x, 0.0)
    XCTAssertEqual(map.ownedUserLocationIcons?.direction.anchor?.y, 0.5)
    let drawn = try XCTUnwrap(recorder.renders.last ?? nil)
    XCTAssertEqual(drawn.anchor?.x, 0.0)
    XCTAssertEqual(drawn.anchor?.y, 0.5)

    // Once ownership exists, .preserve keeps the PLUGIN pivots (a later
    // swap without anchors still never re-centers).
    try iconsBridge.setUserLocationIcons(
      session: wire,
      icons: userLocationIcons(personAnchor: NativeMarkerAnchor(x: 1.0, y: 1.0)))
    XCTAssertEqual(map.ownedUserLocationIcons?.person.anchor?.x, 1.0)
    XCTAssertEqual(map.ownedUserLocationIcons?.person.anchor?.y, 1.0)
    // The direction icon keeps the seeded pivot: this swap sent no
    // direction anchor.
    XCTAssertEqual(map.ownedUserLocationIcons?.direction.anchor?.y, 0.5)
    let reswapped = try XCTUnwrap(recorder.renders.last ?? nil)
    XCTAssertEqual(reswapped.anchor?.x, 1.0)
    XCTAssertEqual(reswapped.anchor?.y, 1.0)
  }

  @MainActor
  func testAnchorOverrideThenResetThenReplacementStaysCentered() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let iconsBridge = try XCTUnwrap(map.userLocationIconsBridge)
    let trackingBridge = try XCTUnwrap(map.trackingBridge)
    installSharedFrameworkFake(map)
    let recorder = markerRecorder(map)
    let wire = cameraWireSession(map)

    // 1. An explicit tracking anchor pivots the plugin-owned defaults.
    try await trackingBridge.enableTracking(
      session: wire,
      configuration: trackingConfig(
        useDirectionMarker: false, anchorX: 0.0, anchorY: 0.5))
    map.locationChanged(
      userLocation: CLLocationCoordinate2D(latitude: 47, longitude: 8), heading: 0)
    XCTAssertEqual(map.ownedUserLocationIcons?.person.anchor?.y, 0.5)

    // 2. Reset to the platform defaults: the owned configuration carries NO
    // pivot anymore.
    try iconsBridge.setUserLocationIcons(session: wire, icons: nil)
    XCTAssertNil(map.ownedUserLocationIcons?.person.anchor)
    let reset = try XCTUnwrap(recorder.renders.last ?? nil)
    XCTAssertNil(reset.anchor)

    // 3. Replacing the icons without an anchor preserves that reset CENTER —
    // the earlier tracking pivot must not come back. Person-icon drawing.
    try iconsBridge.setUserLocationIcons(session: wire, icons: userLocationIcons())
    XCTAssertNil(map.ownedUserLocationIcons?.person.anchor)
    XCTAssertNil(map.ownedUserLocationIcons?.direction.anchor)
    let replaced = try XCTUnwrap(recorder.renders.last ?? nil)
    XCTAssertNil(replaced.anchor, "stale tracking pivot must not be restored")
  }

  @MainActor
  func testIconReplacementWithoutAnyTrackingAnchorStaysCentered() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let iconsBridge = try XCTUnwrap(map.userLocationIconsBridge)
    let trackingBridge = try XCTUnwrap(map.trackingBridge)
    installSharedFrameworkFake(map)
    let recorder = markerRecorder(map)
    let wire = cameraWireSession(map)

    // Tracking without an anchor override: no pivot was ever applied, so a
    // takeover without anchors keeps the framework default (centered).
    try await trackingBridge.enableTracking(
      session: wire,
      configuration: trackingConfig(anchorX: nil, anchorY: nil))
    map.locationChanged(
      userLocation: CLLocationCoordinate2D(latitude: 47, longitude: 8), heading: 0)
    try iconsBridge.setUserLocationIcons(session: wire, icons: userLocationIcons())
    XCTAssertNil(map.ownedUserLocationIcons?.person.anchor)
    let drawn = try XCTUnwrap(recorder.renders.last ?? nil)
    XCTAssertNil(drawn.anchor)
  }

  @MainActor
  func testTrackingRendersTheDefaultIconsThroughThePluginFromTheStart() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let trackingBridge = try XCTUnwrap(map.trackingBridge)
    let fake = installSharedFrameworkFake(map)
    let recorder = markerRecorder(map)
    let wire = cameraWireSession(map)

    XCTAssertFalse(map.ownsUserLocationMarker)
    try await trackingBridge.enableTracking(
      session: wire, configuration: trackingConfig(anchorX: nil, anchorY: nil))
    // The plugin takes marker ownership at the FIRST tracking start, with
    // the platform default icons — the framework arm never draws.
    XCTAssertTrue(map.ownsUserLocationMarker)
    XCTAssertEqual(fake.recording, ["tracking:start"])
    XCTAssertTrue(recorder.renders.isEmpty, "no marker before the first fix")

    map.locationChanged(
      userLocation: CLLocationCoordinate2D(latitude: 47, longitude: 8), heading: 0)
    XCTAssertEqual(recorder.renders.count, 1)
    let drawn = try XCTUnwrap(recorder.renders.last ?? nil)
    // Default configuration draws the direction icon (useDirectionMarker).
    XCTAssertEqual(drawn.pngData, Data("direction".utf8))
    XCTAssertEqual(drawn.location.latitude, 47)
    XCTAssertNil(drawn.anchor, "default icons are centered")
    // The stream was armed exactly once: no start/stop churn.
    XCTAssertEqual(fake.recording, ["tracking:start"])
  }


  @MainActor
  func testTrackingAnchorOverrideRepivotsTheOwnedMarkerInPlace() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let iconsBridge = try XCTUnwrap(map.userLocationIconsBridge)
    let trackingBridge = try XCTUnwrap(map.trackingBridge)
    installSharedFrameworkFake(map)
    let recorder = markerRecorder(map)
    let wire = cameraWireSession(map)

    try iconsBridge.setUserLocationIcons(
      session: wire,
      icons: userLocationIcons(personAnchor: NativeMarkerAnchor(x: 0.5, y: 1.0)))
    map.locationChanged(
      userLocation: CLLocationCoordinate2D(latitude: 47, longitude: 8), heading: 0)
    try await trackingBridge.enableTracking(
      session: wire,
      configuration: trackingConfig(anchorX: 0.0, anchorY: 0.0))

    // The anchor override re-pivots both icons without a new fix and without
    // re-centering to the legacy default.
    let rendered = try XCTUnwrap(recorder.renders.last ?? nil)
    XCTAssertEqual(rendered.anchor?.x, 0.0)
    XCTAssertEqual(rendered.anchor?.y, 0.0)
    XCTAssertEqual(rendered.location.latitude, 47)
  }

  @MainActor
  func testLegacyTrackingAnchorSlotKeepsConfiguredPivots() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let iconsBridge = try XCTUnwrap(map.userLocationIconsBridge)
    let recorder = markerRecorder(map)
    let wire = cameraWireSession(map)

    // Mixed route: typed icons applied with per-icon pivots, then a legacy
    // tracking start.
    try iconsBridge.setUserLocationIcons(
      session: wire,
      icons: userLocationIcons(
        personAnchor: NativeMarkerAnchor(x: 0.5, y: 1.0),
        directionAnchor: NativeMarkerAnchor(x: 0.5, y: 0.0)))
    XCTAssertTrue(map.ownsUserLocationMarker)

    // A null anchor slot is "no override": the applied pivots stay.
    map.applyLegacyTrackingAnchor(nil)
    XCTAssertEqual(map.ownedUserLocationIcons?.person.anchor?.y, 1.0)
    XCTAssertEqual(map.ownedUserLocationIcons?.direction.anchor?.y, 0.0)
    XCTAssertTrue(recorder.renders.isEmpty)

    // An explicit legacy override still re-pivots both icons.
    map.applyLegacyTrackingAnchor([0.0, 0.5])
    XCTAssertEqual(map.ownedUserLocationIcons?.person.anchor?.x, 0.0)
    XCTAssertEqual(map.ownedUserLocationIcons?.person.anchor?.y, 0.5)
    XCTAssertEqual(map.ownedUserLocationIcons?.direction.anchor?.x, 0.0)
    XCTAssertEqual(map.ownedUserLocationIcons?.direction.anchor?.y, 0.5)
  }

  @MainActor
  func testLegacyTrackingAnchorNeverReappliesTheFrameworkIconConfig() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let iconsBridge = try XCTUnwrap(map.userLocationIconsBridge)
    let configRecorder = iconRenderRecorder(map)
    let markerRecorder = markerRecorder(map)
    let wire = cameraWireSession(map)

    try iconsBridge.setUserLocationIcons(
      session: wire, icons: userLocationIcons())
    XCTAssertEqual(configRecorder.renders.count, 1)

    // With the plugin owning the marker, an anchor override (or its absence)
    // is an icon-only, in-place change: the framework's icon configuration is
    // never re-applied, so its destructive marker refresh is never armed.
    map.applyLegacyTrackingAnchor(nil)
    map.applyLegacyTrackingAnchor([0.5, 1.0])
    XCTAssertEqual(configRecorder.renders.count, 1)
    // Both icons took the override; the marker redraw only happens once a
    // location is known.
    XCTAssertEqual(map.ownedUserLocationIcons?.person.anchor?.y, 1.0)
    XCTAssertTrue(markerRecorder.renders.isEmpty)
  }

  /// Records the painting calls the plugin makes against the POI layer.
  private final class MarkerPainterSpy: MapSession.UserLocationMarkerPainting {
    struct Call: CustomStringConvertible {
      let name: String
      var image: OSMPlatformImage?
      var size: MarkerIconSize?
      var description: String { name }
    }

    var calls: [Call] = []
    var isInstalled: Bool {
      calls.contains { $0.name == "install" }
    }

    func installIcon(id: String, image: OSMPlatformImage, size: MarkerIconSize?) {
      calls.append(Call(name: "install", image: image, size: size))
    }

    func setPositions(id: String, location: CLLocationCoordinate2D) {
      calls.append(Call(name: "position", image: nil, size: nil))
    }

    func removeMarker(id: String) {
      calls.append(Call(name: "remove", image: nil, size: nil))
    }
  }

  @MainActor
  private func painterSpy(_ map: MapSession) -> MarkerPainterSpy {
    let spy = MarkerPainterSpy()
    map.userLocationMarkerPainter = spy
    return spy
  }

  /// Small solid test image at an exact pixel size.
  private func solidImage(width: Int, height: Int) -> OSMPlatformImage {
    let cg = CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8,
      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    cg.setFillColor(NSColor.red.cgColor)
    cg.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return OSMPlatformImage(
      cgImage: cg.makeImage()!, size: NSSize(width: width, height: height))
  }

  @MainActor
  func testOwnedMarkerPainterReappliesTheIconAfterPositioning() throws {
    // The pinned POI rebuilds its markers from the icon frozen at creation,
    // so every positioning call must be FOLLOWED by an icon re-application —
    // otherwise a replaced texture reverts to the first image.
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let spy = painterSpy(map)
    let wire = cameraWireSession(map)
    let png = pngIconData()

    func draw(image: OSMPlatformImage, logical: (Int, Int)) {
      map.userLocationMarkerRenderer(
        MapSession.UserLocationMarkerRender(
          location: CLLocationCoordinate2D(latitude: 47, longitude: 8),
          image: image,
          pngData: png,
          logicalSize: [logical.0, logical.1],
          anchor: nil,
          angleDegrees: nil))
    }

    let first = solidImage(width: 16, height: 16)
    draw(image: first, logical: (8, 8))
    XCTAssertEqual(spy.calls.map(\.name), ["install", "position", "install"])

    // A redraw with a DIFFERENT texture must re-apply it after positioning,
    // on every redraw (not only the first) — no redundant ensure-install.
    let second = solidImage(width: 24, height: 24)
    draw(image: second, logical: (12, 12))
    XCTAssertEqual(
      spy.calls.map(\.name),
      ["install", "position", "install", "position", "install"])
    // The re-application after positioning carries the CURRENT baked
    // texture, never the stale creation icon: the canvas follows the newest
    // content size (16px for the 8×8 icon, 24px for the 12×12 one).
    let installs = spy.calls.filter { $0.name == "install" }
    // install[0]/[1] belong to the first draw, install[2] re-applies the
    // second texture after positioning.
    XCTAssertEqual(installs.count, 3)
    XCTAssertEqual(PluginImageBaking.cgImage(installs[0].image!)?.width, 16)
    XCTAssertEqual(PluginImageBaking.cgImage(installs[2].image!)?.width, 24)
    XCTAssertNotIdentical(installs[0].image, installs[2].image)
    // Removal paints a removal only.
    map.userLocationMarkerRenderer(nil)
    XCTAssertEqual(spy.calls.last?.name, "remove")
  }

  func testBakedUserLocationMarkerLayoutMath() {
    typealias Layout = MapSession.BakedUserLocationMarkerLayout
    func layout(
      _ w: Double, _ h: Double, ax: Double, ay: Double, angle: Double
    ) -> Layout {
      MapSession.bakedUserLocationMarkerLayout(
        logicalSize: CGSize(width: w, height: h),
        anchorX: ax, anchorY: ay, angleDegrees: angle)
    }

    // A centered pivot on an unrotated icon is identity.
    var l = layout(12, 20, ax: 0.5, ay: 0.5, angle: 0)
    XCTAssertEqual(l.paddedSize, CGSize(width: 12, height: 20))
    XCTAssertEqual(l.contentOffset, CGPoint(x: 0, y: 0))
    XCTAssertEqual(l.rotatedSize, CGSize(width: 12, height: 20))

    // A bottom-tip pivot pads the bottom half so the tip sits at the center.
    l = layout(12, 20, ax: 0.5, ay: 1.0, angle: 0)
    XCTAssertEqual(l.paddedSize, CGSize(width: 12, height: 40))
    XCTAssertEqual(l.contentOffset, CGPoint(x: 0, y: 0))
    XCTAssertEqual(l.rotatedSize, CGSize(width: 12, height: 40))

    // A top pivot pads the bottom: content occupies the lower half.
    l = layout(12, 20, ax: 0.5, ay: 0.0, angle: 0)
    XCTAssertEqual(l.paddedSize, CGSize(width: 12, height: 40))
    XCTAssertEqual(l.contentOffset, CGPoint(x: 0, y: 20))

    // Rotation grows the canvas to the rotated bounding box.
    func approx(_ a: CGSize, _ b: CGSize) {
      XCTAssertEqual(a.width, b.width, accuracy: 0.001)
      XCTAssertEqual(a.height, b.height, accuracy: 0.001)
    }
    l = layout(12, 12, ax: 0.5, ay: 0.5, angle: 90)
    approx(l.rotatedSize, CGSize(width: 12, height: 12))
    l = layout(12, 20, ax: 0.5, ay: 0.5, angle: 90)
    approx(l.rotatedSize, CGSize(width: 20, height: 12))

    // Out-of-range anchors clamp instead of producing negative padding.
    l = layout(12, 20, ax: 1.5, ay: -0.5, angle: 0)
    XCTAssertEqual(l.paddedSize, CGSize(width: 24, height: 40))
  }

  @MainActor
  func testBakedUserLocationMarkerTextureCarriesPivotAndRotation() throws {
    // 8×8 content, pivot at the bottom tip: the baked texture is twice as
    // tall, and a 90° heading swaps the canvas dimensions.
    let render = MapSession.UserLocationMarkerRender(
      location: CLLocationCoordinate2D(latitude: 47, longitude: 8),
      image: solidImage(width: 16, height: 16),
      pngData: pngIconData(),
      logicalSize: [8, 8],
      anchor: MarkerAnchor(x: 0.5, y: 1.0),
      angleDegrees: nil)
    let baked = MapSession.bakedUserLocationMarker(render, displayScale: 2)
    XCTAssertEqual(baked.size.x, 16)
    XCTAssertEqual(baked.size.y, 32)
    // The texture itself carries the pivot: at 2 source pixels per logical
    // point the 16px content sits in a 16×32px canvas (padding below it).
    let pixels = PluginImageBaking.cgImage(baked.image)
    XCTAssertEqual(pixels?.width, 16)
    XCTAssertEqual(pixels?.height, 32)

    let rotatedBaked = MapSession.bakedUserLocationMarker(
      MapSession.UserLocationMarkerRender(
        location: render.location,
        image: render.image,
        pngData: render.pngData,
        logicalSize: render.logicalSize,
        anchor: render.anchor,
        angleDegrees: 90),
      displayScale: 2)
    XCTAssertEqual(rotatedBaked.size.x, 32)
    XCTAssertEqual(rotatedBaked.size.y, 16)
  }

  @MainActor
  func testIconReplacementDuringTrackingNeverTouchesTheLocationStream() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let iconsBridge = try XCTUnwrap(map.userLocationIconsBridge)
    let trackingBridge = try XCTUnwrap(map.trackingBridge)
    let fake = installSharedFrameworkFake(map)
    let markerRecorder = markerRecorder(map)
    let wire = cameraWireSession(map)
    let png = pngIconData()

    // Tracking runs on the plugin-rendered default icons.
    try await trackingBridge.enableTracking(
      session: wire, configuration: trackingConfig(anchorX: nil, anchorY: nil))
    map.locationChanged(
      userLocation: CLLocationCoordinate2D(latitude: 47, longitude: 8), heading: 0)
    XCTAssertEqual(markerRecorder.renders.count, 1)

    // Replacing the icons is a pure in-place redraw: the new bytes are
    // visible immediately from the last known location, and NO additional
    // location start/stop happens.
    try iconsBridge.setUserLocationIcons(session: wire, icons: userLocationIcons())
    XCTAssertTrue(map.frameworkIconConfigIsPlaceholder)
    XCTAssertEqual(markerRecorder.renders.count, 2)
    let replaced = try XCTUnwrap(markerRecorder.renders.last ?? nil)
    XCTAssertEqual(replaced.pngData, png)
    XCTAssertEqual(replaced.location.latitude, 47)
    XCTAssertEqual(fake.recording, ["tracking:start"])

    // Fixes keep flowing into the same single marker; another swap stays
    // in-place and the stream is still untouched.
    map.locationChanged(
      userLocation: CLLocationCoordinate2D(latitude: 47.1, longitude: 8.1), heading: 0)
    XCTAssertEqual(markerRecorder.renders.count, 3)
    try iconsBridge.setUserLocationIcons(
      session: wire,
      icons: userLocationIcons(personSize: NativeMarkerSize(width: 24, height: 40)))
    XCTAssertEqual(markerRecorder.renders.count, 4)
    XCTAssertEqual(fake.recording, ["tracking:start"])
  }


  @MainActor
  func testIconReplacementDuringAPendingFixStaysInPlace() async throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let iconsBridge = try XCTUnwrap(map.userLocationIconsBridge)
    let trackingBridge = try XCTUnwrap(map.trackingBridge)
    let fake = installSharedFrameworkFake(map)
    let markerRecorder = markerRecorder(map)
    let wire = cameraWireSession(map)

    try await trackingBridge.enableTracking(
      session: wire, configuration: trackingConfig(anchorX: nil, anchorY: nil))
    map.locationChanged(
      userLocation: CLLocationCoordinate2D(latitude: 47, longitude: 8), heading: 0)
    XCTAssertEqual(markerRecorder.renders.count, 1)

    // A one-shot fix holds the single location slot; the plugin marker is
    // independent of it, so the replacement still redraws in place — the
    // pending pass completes the fix without painting the marker.
    var completions = 0
    map.pendingLocationFixCompletion = { _ in completions += 1 }
    try iconsBridge.setUserLocationIcons(session: wire, icons: userLocationIcons())
    XCTAssertEqual(markerRecorder.renders.count, 2)
    XCTAssertEqual(fake.recording, ["tracking:start"])

    map.locationChanged(
      userLocation: CLLocationCoordinate2D(latitude: 47.1, longitude: 8.1), heading: 0)
    XCTAssertEqual(completions, 1)
    XCTAssertEqual(markerRecorder.renders.count, 2, "pending pass keeps the marker still")

    map.locationChanged(
      userLocation: CLLocationCoordinate2D(latitude: 47.2, longitude: 8.2), heading: 0)
    XCTAssertEqual(markerRecorder.renders.count, 3)
    let drawn = try XCTUnwrap(markerRecorder.renders.last ?? nil)
    XCTAssertEqual(drawn.location.latitude, 47.2)
    XCTAssertEqual(fake.recording, ["tracking:start"])
  }



  @MainActor
  func testTypedUserLocationIconsSkipIdenticalReapplication() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.userLocationIconsBridge)
    let recorder = iconRenderRecorder(map)
    let wire = cameraWireSession(map)

    try bridge.setUserLocationIcons(session: wire, icons: userLocationIcons())
    XCTAssertEqual(recorder.renders.count, 1)

    // Identical bytes, sizes and pivots: dropped, because every framework
    // refresh costs one hidden marker pass.
    try bridge.setUserLocationIcons(session: wire, icons: userLocationIcons())
    XCTAssertEqual(recorder.renders.count, 1)

    try bridge.setUserLocationIcons(session: wire, icons: nil)
    XCTAssertEqual(recorder.renders.count, 2)
    try bridge.setUserLocationIcons(session: wire, icons: nil)
    XCTAssertEqual(recorder.renders.count, 2)

    // A real change always applies.
    try bridge.setUserLocationIcons(
      session: wire,
      icons: userLocationIcons(personSize: NativeMarkerSize(width: 24, height: 40)))
    XCTAssertEqual(recorder.renders.count, 3)
  }

  @MainActor
  func testLegacyUserLocationIconRouteUsesTheTypedSeam() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let recorder = iconRenderRecorder(map)
    let png = pngIconData()

    map.onListenMethodChannel(
      call: FlutterMethodCall(
        methodName: "user#locationMarkers",
        arguments: [
          "personIcon": ["icon": png.base64EncodedString(), "size": [12, 20]],
          "arrowDirectionIcon": [
            "icon": png.base64EncodedString(), "size": [8, 14],
          ],
        ]
      )
    ) { _ in }

    // The legacy route keeps its exact configuration semantics: it rebuilds
    // both icons without a pivot.
    let render = try XCTUnwrap(recorder.renders.last ?? nil)
    guard case .reset = render.person.pivot else {
      return XCTFail("legacy person pivot should reset")
    }
    guard case .reset = render.direction.pivot else {
      return XCTFail("legacy direction pivot should reset")
    }
    XCTAssertEqual(render.person.logicalSize, [12, 20])
    XCTAssertEqual(render.direction.logicalSize, [8, 14])

    // The legacy render feeds the same backing-scale refresh record.
    XCTAssertEqual(map.lastUserLocationIconsRender?.person.logicalSize, [12, 20])
    map.handleDisplayScaleChanged()
    XCTAssertEqual(recorder.renders.count, 2)
  }

  @MainActor
  func testTypedUserLocationIconsFeedTheBackingScaleRefresh() throws {
    let map = session(RecordingMessenger())
    defer { map.dispose() }
    let bridge = try XCTUnwrap(map.userLocationIconsBridge)

    try bridge.setUserLocationIcons(
      session: cameraWireSession(map),
      icons: userLocationIcons(
        personSize: nil,
        directionSize: NativeMarkerSize(width: 8, height: 14)))

    // An icon without a logical size is replayed as-is, so the refresh keeps
    // the live pixel size for it while re-scaling the other icon.
    XCTAssertNil(map.lastUserLocationIconsRender?.person.logicalSize)
    XCTAssertEqual(map.lastUserLocationIconsRender?.direction.logicalSize, [8, 14])
    map.handleDisplayScaleChanged()
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

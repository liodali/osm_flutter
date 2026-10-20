import Cocoa
import CoreLocation
import FlutterMacOS
import OSMFlutterFramework
import XCTest
@testable import flutter_osm_plugin

class RunnerTests: XCTestCase {

  @MainActor
  private func session(_ messenger: RecordingMessenger, id: Int64 = 1) -> MapSession {
    MapSession(.zero, viewId: id,
      channel: FlutterMethodChannel(name: "map_\(id)", binaryMessenger: messenger),
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
      XCTAssertEqual(messenger.handlers.count, 2)
      host = nil
    }
    // AppKit autoreleases views and the framework can have queued callbacks.
    // Give those transient references a bounded chance to drain.
    for _ in 0..<20 where released != nil {
      try await Task.sleep(nanoseconds: 50_000_000)
    }
    XCTAssertNil(released)
    XCTAssertEqual(Set(messenger.handlers.keys), ["map_2"])
    var count = 0
    other.onListenMethodChannel(call: FlutterMethodCall(methodName: "map#center", arguments: nil)) { _ in count += 1 }
    XCTAssertEqual(count, 1)
    other.dispose()
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

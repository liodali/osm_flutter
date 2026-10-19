//
//  MapSession.swift
//  flutter_osm_plugin
//
//  Created by Dali Hamza on 19.11.23.
//

import CoreLocation
#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterMacOS)
import FlutterMacOS
#endif
import Foundation
@preconcurrency import OSMFlutterFramework

@_implementationOnly import Polyline

/// Shared per-map session: owns the native `OSMView`, the method channel,
/// the map state and the forwarding of framework events to Dart.
///
/// The iOS `FlutterPlatformView` wrapper and the macOS `NSView` host each
/// retain exactly one session, so every created map stays independent.
@MainActor
class MapSession: NSObject, OnMapGesture, OnMapMoved, MapMarkerHandler, OSMUserLocationHandler,
    PoylineHandler
{

    let mapOSM: OSMView
    var isStaticMap: Bool = false
    var homeMarker: OSMPlatformImage? = nil
    var customTiles: CustomTiles? = nil
    var boundingbox: BoundingBox? = nil
    let channel: FlutterMethodChannel
    var zoomConfig: ZoomConfiguration = ZoomConfiguration(
        initZoom: 8, minZoom: 2, maxZoom: 19, step: 1)
    lazy var roadManager: OSMRoadManager = OSMRoadManager()
    let roadColor: String = "#ff0000ff"
    var lastRoadKey: String? = nil
    var resultFlutter: FlutterResult? = nil
    @MainActor
    var storedRoads: [String: StoredRoad] = [:]
    var isMovedToLocation: Bool = false
    var canSkipFollow: Bool = false
    var userLocationWithoutControl: Bool = false
    var mapInitialized: Bool = false
    let defaultMarker: String?
    private(set) var latestUserLocation: CLLocationCoordinate2D? = nil
    private var isDisposed: Bool = false
    /// Results of in-flight road commands; completed exactly once and failed
    /// collectively on disposal so the Dart futures can never hang.
    private var outstandingRoadResults: [(id: String, result: FlutterResult)] = []
    #if os(macOS)
    /// Arguments of the last `user#locationMarkers` call, replayed when the
    /// hosting window moves between displays so user-location markers re-render
    /// at the new backing scale.
    var lastUserLocationMarkersArgs: [String: Any]? = nil
    #endif

    /// The native view to embed: a `UIView` on iOS, an `NSView` on macOS.
    var platformView: OSMPlatformView {
        mapOSM
    }

    init(
        _ frame: CGRect, viewId: Int64, channel: FlutterMethodChannel, args: Any?,
        defaultPin: String?
    ) {
        var initLocation: CLLocationCoordinate2D?
        var enableRotationGesture = false
        defaultMarker = defaultPin
        if (args as? [String: Any]) != nil {
            if (args as! [String: Any]).keys.contains("customTile") {
                customTiles = CustomTiles(
                    ((args as! [String: Any])["customTile"] as? [String: Any])!)

            }
            if (args as! [String: Any]).keys.contains("bounds") {
                let boundArgs = (args as! [String: Any])["bounds"] as? [Double]
                boundingbox = BoundingBox(boundingBoxs: boundArgs!)
            }
            if (args as! [String: Any]).keys.contains("zoomOption") {
                let zoomArgs = (args as! [String: Any])["zoomOption"] as? [String: Int]
                self.zoomConfig = ZoomConfiguration(zoomArgs!)
            }
            if (args as! [String: Any]).keys.contains("location") {
                let locationArgs = (args as! [String: Any])["location"] as? [String: Double]
                initLocation = CLLocationCoordinate2D(
                    latitude: (locationArgs!["lat"])!, longitude: locationArgs!["lon"]!)
            }

            if (args as! [String: Any]).keys.contains("enableRotationGesture") {
                enableRotationGesture = (args as! [String: Any])["enableRotationGesture"] as! Bool

            }
        }
        isStaticMap = (args as! [String: Any])["isStaticMap"] as? Bool ?? false

        let configuration = OSMMapConfiguration(
            zoomLevelScaleFactor: 0.65, adaptScaleToScreen: true)
        self.mapOSM = OSMView(
            rect: frame, location: initLocation, zoomConfig: self.zoomConfig,
            mapTileConfiguration: configuration)
        self.channel = channel
        super.init()
        self.mapOSM.enableRotation(enable: enableRotationGesture)
        channel.setMethodCallHandler({ [weak self]
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            self?.onListenMethodChannel(call: call, result: result)
        })
        // Route every framework delegate through a weak proxy so the map view
        // never retains the session directly (see MapDelegateProxy).
        let delegateProxy = MapDelegateProxy(session: self)
        self.mapOSM.onMapGestureDelegate = delegateProxy
        self.mapOSM.mapHandlerDelegate = delegateProxy
        self.mapOSM.userLocationDelegate = delegateProxy
        self.mapOSM.roadTapHandlerDelegate = delegateProxy
        self.mapOSM.onMapMove = delegateProxy
        self.mapOSM.enableRotation(enable: enableRotationGesture)
        if self.isStaticMap {
            self.mapOSM.disableTouch()
        }
    }

    /// Wraps a road-command result so it is completed exactly once: either by
    /// the normal command flow or with a disposal error when the map goes away
    /// before the routing request finishes.
    func trackRoadResult(id: String, _ result: @escaping FlutterResult) -> FlutterResult {
        outstandingRoadResults.append((id, result))
        return { [weak self] reply in
            self?.completeRoadResult(id: id, reply: reply)
        }
    }

    private func completeRoadResult(id: String, reply: Any?) {
        guard let index = outstandingRoadResults.firstIndex(where: { $0.id == id }) else {
            // Already completed (or failed during disposal).
            return
        }
        let entry = outstandingRoadResults.remove(at: index)
        entry.result(reply)
    }

    /// macOS hook invoked by the hosting view when its backing properties
    /// (display scale, color space) change: re-applies the user-location marker
    /// icons at the new scale.
    func handleDisplayScaleChanged() {
        #if os(macOS)
        guard !isDisposed, let args = lastUserLocationMarkersArgs else {
            return
        }
        configureUserLocation(
            call: FlutterMethodCall(methodName: "user#locationMarkers", arguments: args))
        #endif
    }

    /// Tears down the session: stops the method-channel handler, detaches every
    /// framework delegate, stops location work and fails any pending result.
    /// Safe to call more than once (from the platform wrapper and from deinit).
    func dispose() {
        guard !isDisposed else {
            return
        }
        isDisposed = true
        channel.setMethodCallHandler(nil)
        mapOSM.onMapGestureDelegate = nil
        mapOSM.mapHandlerDelegate = nil
        mapOSM.userLocationDelegate = nil
        mapOSM.roadTapHandlerDelegate = nil
        mapOSM.onMapMove = nil
        mapOSM.locationManager.stopLocation()
        if let pendingResult = resultFlutter {
            pendingResult(
                FlutterError(code: "disposed", message: "map was disposed", details: nil))
        }
        resultFlutter = nil
        let pendingRoads = outstandingRoadResults
        outstandingRoadResults.removeAll()
        for entry in pendingRoads {
            entry.result(
                FlutterError(
                    code: "disposed", message: "map was disposed before the road completed",
                    details: nil))
        }
    }

    deinit {
        // MapSession references are only dropped by the engine on the main
        // thread (platform-view teardown), so main-actor isolation holds here.
        MainActor.assumeIsolated {
            self.dispose()
        }
    }

    // MARK: - Framework event forwarding

    func onTap(roadId: String) {
        DispatchQueue.main.async {
            let roadSelected = self.storedRoads[roadId]
            if let road = roadSelected {
                var mapInfo = road.roadInformation?.toMap(instructions: road.instructions) ?? [:]
                mapInfo["key"] = roadId
                self.channel.invokeMethod("receiveRoad", arguments: mapInfo)
            } else {
                self.channel.invokeMethod("receiveRoad", arguments: ["key": roadId])
            }
        }

    }

    func onMove(center: CLLocationCoordinate2D, bounds: BoundingBox, zoom: Double) {
        let data: [String: Any] = [
            "center": center.toGeoPoint(), "bounding": bounds.toMap(), "zoomLevel": zoom,
        ]
        if self.mapOSM.locationManager.isTrackingEnabled() && !isMovedToLocation
            && latestUserLocation != nil && latestUserLocation! - center
        {
            isMovedToLocation = true
        }
        DispatchQueue.main.async {
            self.channel.invokeMethod("receiveRegionIsChanging", arguments: data)
        }
    }

    func onRotate(angle: Double) {

    }

    func onMapInteraction() {
        if self.mapOSM.locationManager.isTrackingEnabled() && isMovedToLocation
            && latestUserLocation != nil && !canSkipFollow && !userLocationWithoutControl
        {
            canSkipFollow = true
            self.mapOSM.stopCamera()
        }
    }

    func locationChanged(userLocation: CLLocationCoordinate2D, heading: Double) {
        let geoMap = userLocation.toUserLocation(heading: heading)
        latestUserLocation = userLocation
        channel.invokeMethod("receiveUserLocation", arguments: geoMap)
        if (!isMovedToLocation || !canSkipFollow) && !userLocationWithoutControl && mapInitialized {
            self.mapOSM.locationManager.moveToUserLocation(animated: true)
        }

        if let result = resultFlutter {
            result(geoMap)
            resultFlutter = nil
        }
    }

    func handlePermission(state: OSMFlutterFramework.LocationPermission) {

    }

    func onMarkerSingleTap(location: CLLocationCoordinate2D) {
        DispatchQueue.main.async {
            self.channel.invokeMethod("receiveGeoPoint", arguments: location.toGeoPoint())
        }
    }

    func onMarkerLongPress(location: CLLocationCoordinate2D) {
        DispatchQueue.main.async {
            self.channel.invokeMethod("receiveGeoPointLongPress", arguments: location.toGeoPoint())
        }
    }

    func onSingleTap(location: CLLocationCoordinate2D) {
        DispatchQueue.main.async {
            self.channel.invokeMethod("receiveSinglePress", arguments: location.toGeoPoint())
        }

    }

    func onLongTap(location: CLLocationCoordinate2D) {
        DispatchQueue.main.async {
            self.channel.invokeMethod("receiveLongPress", arguments: location.toGeoPoint())
        }

    }
}

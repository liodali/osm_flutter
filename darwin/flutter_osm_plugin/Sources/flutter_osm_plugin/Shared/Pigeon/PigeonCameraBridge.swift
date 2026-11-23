//
//  PigeonCameraBridge.swift
//  flutter_osm_plugin
//
//  Generated-channel host for the camera family (Pigeon channel profile).
//  This bridge is the only component that decodes generated camera calls. It
//  validates the per-map session token/generation pair, then delegates to the
//  typed camera service on the shared session, so legacy and generated
//  endpoints reach one owner. Registration lives alongside the legacy
//  endpoints; it never replaces them.
//

import Foundation
#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterMacOS)
import FlutterMacOS
#endif

final class PigeonCameraBridge: NativeMapCameraApi {

    private weak var session: MapSession?
    private let sessionToken: String
    private let generation: Int64

    init(session: MapSession) {
        self.session = session
        self.sessionToken = session.sessionToken
        self.generation = session.generation
    }

    func getZoom(session: NativeCameraSession) throws -> Double {
        try MainActor.assumeIsolated {
            try validate(session)
            return try requireSession().typedZoom()
        }
    }

    func setZoom(session: NativeCameraSession, zoom: Double, animated: Bool) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            try requireSession().typedSetZoom(zoom, animated: animated)
        }
    }

    func moveTo(
        session: NativeCameraSession, latitude: Double, longitude: Double, animated: Bool
    ) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            try requireSession().typedMoveTo(latitude: latitude, longitude: longitude, animated: animated)
        }
    }

    func setRotation(session: NativeCameraSession, angle: Double, animated: Bool) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            try requireSession().typedSetRotation(angle, animated: animated)
        }
    }

    func getCameraPosition(session: NativeCameraSession) throws -> NativeCameraPosition {
        try MainActor.assumeIsolated {
            try validate(session)
            guard let position = try requireSession().typedCameraPosition() else {
                throw PigeonError(code: "camera_not_ready", message: nil, details: nil)
            }
            return NativeCameraPosition(
                latitude: position.latitude,
                longitude: position.longitude,
                zoom: position.zoom,
                rotation: position.rotation)
        }
    }

    func getBounds(session: NativeCameraSession) throws -> NativeBounds {
        try MainActor.assumeIsolated {
            try validate(session)
            guard let bounds = try requireSession().typedBounds() else {
                throw PigeonError(code: "camera_not_ready", message: nil, details: nil)
            }
            return NativeBounds(
                north: bounds.north, south: bounds.south,
                east: bounds.east, west: bounds.west)
        }
    }

    func zoomToBoundingBox(
        session: NativeCameraSession, bounds: NativeBounds, paddingInPixel: Int64
    ) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            try requireSession().typedZoomToBoundingBox(
                north: bounds.north, south: bounds.south,
                east: bounds.east, west: bounds.west,
                paddingInPixel: Int(paddingInPixel))
        }
    }

    func setBoundsLimit(session: NativeCameraSession, bounds: NativeBounds) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            try requireSession().typedSetBoundsLimit(
                north: bounds.north, east: bounds.east,
                south: bounds.south, west: bounds.west)
        }
    }

    func removeBoundsLimit(session: NativeCameraSession) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            try requireSession().typedRemoveBoundsLimit()
        }
    }

    func configureZoom(
        session: NativeCameraSession, configuration: NativeZoomConfiguration
    ) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            try requireSession().typedConfigureZoom(
                initZoom: configuration.initZoom,
                minZoomLevel: configuration.minZoomLevel,
                maxZoomLevel: configuration.maxZoomLevel,
                stepZoom: configuration.stepZoom)
        }
    }

    // MARK: registration

    func register(messenger: FlutterBinaryMessenger, viewId: Int64) {
        NativeMapCameraApiSetup.setUp(
            binaryMessenger: messenger, api: self,
            messageChannelSuffix: Self.viewChannelSuffix(viewId))
    }

    /// Removes this bridge's handlers without touching legacy endpoints.
    func unregister(messenger: FlutterBinaryMessenger, viewId: Int64) {
        NativeMapCameraApiSetup.setUp(
            binaryMessenger: messenger, api: nil,
            messageChannelSuffix: Self.viewChannelSuffix(viewId))
    }

    // MARK: session validation

    private func validate(_ wireSession: NativeCameraSession) throws {
        if wireSession.sessionToken != sessionToken || wireSession.generation != generation {
            throw PigeonError(code: "stale_session", message: nil, details: nil)
        }
    }

    private func requireSession() throws -> MapSession {
        guard let session = session else {
            throw PigeonError(code: "disposed", message: "map was disposed", details: nil)
        }
        return session
    }

    // MARK: bootstrap contract

    static let nativeProtocolRevision = 1
    static let nativeCameraSchemaId = "flutter_osm.native.camera.v1"
    static let capabilityCamera = "camera"
    static let capabilityMarkers = "markers"

    /// Expanded camera surface: bounds queries, zoom-to-bounds, camera
    /// limits/reset and zoom configuration.
    static let capabilityCameraConfig = "camera.config"

    /// Layers surface: tile-source selection and overlay visibility.
    static let capabilityLayers = "layers"

    /// Shapes surface: circles and rectangles.
    static let capabilityShapes = "shapes"

    /// Roads surface: manual drawing, removal, clearing.
    static let capabilityRoads = "roads"

    /// Location surface: my-location layer, single-shot fixes.
    static let capabilityLocation = "location"

    /// Continuous-updates surface: start/stop location updates.
    static let capabilityLocationUpdates = "location.updates"

    /// Follow-me tracking surface: enable/disable tracking.
    static let capabilityTracking = "location.tracking"

    /// User-location icons surface: person/direction icon replacement.
    static let capabilityLocationIcons = "location.icons"

    /// Tracking accepts omitted anchors (keep the configured pivots).
    static let capabilityTrackingOptionalAnchor = "location.tracking.anchor"

    /// Native-to-Dart lifecycle callbacks: readiness (and restoration on
    /// hosts with a restoration concept). Advertised only because
    /// `PigeonLifecycleEventsBridge` and the `map#events#lifecycle#route`
    /// selection are implemented.
    static let capabilityLifecycleEvents = "events.lifecycle"

    /// Native-to-Dart interaction callbacks: single and long presses.
    /// Advertised only because `PigeonInteractionEventsBridge` and the
    /// `map#events#interaction#route` selection are implemented.
    static let capabilityInteractionEvents = "events.interaction"

    /// Native-to-Dart marker interaction callbacks: marker single press
    /// and long press. Advertised only because
    /// `PigeonMarkerEventsBridge` and the `map#events#markers#route`
    /// selection are implemented.
    static let capabilityMarkerEvents = "events.markers"

    /// Native-to-Dart road tap callback. Advertised only because
    /// `PigeonRoadEventsBridge` and the `map#events#roads#route`
    /// selection are implemented.
    static let capabilityRoadEvents = "events.roads"

    static func viewChannelSuffix(_ viewId: Int64) -> String {
        "view_\(viewId)"
    }

    /// Payload of the read-only `map#bootstrap#protocol` legacy-channel probe.
    /// Must stay in sync with the Dart bootstrap contract in
    /// flutter_osm_interface (`native_camera_bootstrap.dart`) and the Kotlin
    /// `PigeonNativeCameraBridge.bootstrapPayload`. The markers capability is
    /// advertised only now that the full marker family (add, batch add, icon
    /// update, movement, rotation, anchors, removal, static groups) is
    /// implemented in `PigeonMarkersBridge` and covered by the macOS session
    /// tests.
    static func bootstrapPayload(sessionToken: String, generation: Int64) -> [String: Any] {
        [
            "revision": nativeProtocolRevision,
            "schemaId": nativeCameraSchemaId,
            "capabilities": [
                capabilityCamera, capabilityMarkers, capabilityCameraConfig,
                capabilityLayers, capabilityShapes, capabilityRoads,
                capabilityLocation, capabilityLocationUpdates,
                capabilityTracking, capabilityLocationIcons,
                capabilityTrackingOptionalAnchor, capabilityLifecycleEvents,
                capabilityInteractionEvents, capabilityMarkerEvents,
                capabilityRoadEvents,
            ],
            "sessionToken": sessionToken,
            "generation": generation,
        ]
    }
}

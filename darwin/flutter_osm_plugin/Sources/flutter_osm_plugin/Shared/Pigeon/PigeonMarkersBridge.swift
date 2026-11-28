//
//  PigeonMarkersBridge.swift
//  flutter_osm_plugin
//
//  Generated-channel host for the markers family (Pigeon channel profile).
//  This bridge is the only component that decodes generated marker calls. It
//  validates the per-map session token/generation pair, converts the degrees
//  of the generated contract to the native radians, decodes PNG bytes in
//  Dart-prepared form, then delegates to the typed marker service on the
//  shared session — the same native operations the legacy route performs,
//  keeping Apple's coordinate-based marker identity.
//

import CoreLocation
import Foundation
#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterMacOS)
import FlutterMacOS
#endif
import OSMFlutterFramework

final class PigeonMarkersBridge: NativeMapMarkersApi {

    private weak var session: MapSession?
    private let sessionToken: String
    private let generation: Int64

    init(session: MapSession) {
        self.session = session
        self.sessionToken = session.sessionToken
        self.generation = session.generation
    }

    func addMarker(
        session: NativeCameraSession,
        markerId: String,
        latitude: Double,
        longitude: Double,
        iconBytes: FlutterStandardTypedData?,
        angleDegrees: Double,
        anchor: NativeMarkerAnchor?,
        iconLogicalSize: NativeMarkerSize?
    ) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            guard !markerId.isEmpty else {
                throw PigeonError(code: "markers_not_ready", message: nil, details: nil)
            }
            let applied = try requireSession().typedAddMarker(
                id: markerId,
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                icon: iconBytes.flatMap { Self.decodeImage($0.data) },
                logicalSize: iconLogicalSize.map { [Int($0.width), Int($0.height)] },
                angleRadians: Self.radians(fromDegrees: angleDegrees),
                anchor: anchor.map { MarkerAnchor(x: $0.x, y: $0.y) },
                iconBase64ForScaleRefresh: iconBytes.map { Self.base64($0.data) })
            guard applied else {
                throw PigeonError(code: "markers_not_ready", message: nil, details: nil)
            }
        }
    }

    func addMarkers(
        session: NativeCameraSession,
        markerIds: [String],
        coordinates: FlutterStandardTypedData
    ) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            let flat = Self.doubles(coordinates)
            let applied = try requireSession().typedAddMarkers(
                ids: markerIds,
                flatCoordinates: flat,
                logicalSize: nil)
            guard applied else {
                throw PigeonError(code: "markers_not_ready", message: nil, details: nil)
            }
        }
    }

    func updateMarkerIcon(
        session: NativeCameraSession,
        markerId: String,
        iconBytes: FlutterStandardTypedData,
        iconLogicalSize: NativeMarkerSize?
    ) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            let applied = try requireSession().typedUpdateMarkerIcon(
                id: markerId,
                icon: try Self.requireImage(iconBytes.data),
                logicalSize: iconLogicalSize.map { [Int($0.width), Int($0.height)] },
                iconBase64ForScaleRefresh: Self.base64(iconBytes.data))
            guard applied else {
                throw PigeonError(code: "markers_not_ready", message: nil, details: nil)
            }
        }
    }

    func moveMarker(
        session: NativeCameraSession,
        markerId: String,
        latitude: Double,
        longitude: Double
    ) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            let applied = try requireSession().typedMoveMarker(
                id: markerId,
                to: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
            guard applied else {
                throw PigeonError(code: "markers_not_ready", message: nil, details: nil)
            }
        }
    }

    func rotateMarker(
        session: NativeCameraSession,
        markerId: String,
        angleDegrees: Double
    ) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            let applied = try requireSession().typedRotateMarker(
                id: markerId,
                angleRadians: Self.radians(fromDegrees: angleDegrees))
            guard applied else {
                throw PigeonError(code: "markers_not_ready", message: nil, details: nil)
            }
        }
    }

    func setMarkerAnchor(
        session: NativeCameraSession,
        markerId: String,
        anchor: NativeMarkerAnchor
    ) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            let applied = try requireSession().typedSetMarkerAnchor(
                id: markerId,
                anchor: MarkerAnchor(x: anchor.x, y: anchor.y))
            guard applied else {
                throw PigeonError(code: "markers_not_ready", message: nil, details: nil)
            }
        }
    }

    func setStaticPositions(
        session: NativeCameraSession,
        groupId: String,
        coordinates: FlutterStandardTypedData,
        iconBytes: FlutterStandardTypedData?,
        iconLogicalSize: NativeMarkerSize?
    ) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            // The generated contract carries degree triples; the native POI
            // angle is radians, so convert each triple at this boundary.
            let flat = Self.doubles(coordinates)
            var radians = flat
            stride(from: 2, to: flat.count, by: 3).forEach { index in
                radians[index] = Double(
                    Self.radians(fromDegrees: flat[index]))
            }
            let applied = try requireSession().typedSetStaticPositions(
                groupId: groupId,
                flatCoordinates: radians,
                icon: iconBytes.flatMap { Self.decodeImage($0.data) },
                logicalSize: iconLogicalSize.map { [Int($0.width), Int($0.height)] },
                iconBase64ForScaleRefresh: iconBytes.map { Self.base64($0.data) })
            guard applied else {
                throw PigeonError(code: "markers_not_ready", message: nil, details: nil)
            }
        }
    }

    func removeStaticPositions(session: NativeCameraSession, groupId: String) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            try requireSession().typedRemoveStaticPositions(groupId: groupId)
        }
    }

    func removeMarker(session: NativeCameraSession, markerId: String) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            let applied = try requireSession().typedRemoveMarker(id: markerId)
            guard applied else {
                throw PigeonError(code: "markers_not_ready", message: nil, details: nil)
            }
        }
    }

    func removeMarkers(session: NativeCameraSession, markerIds: [String]) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            let applied = try requireSession().typedRemoveMarkers(ids: markerIds)
            guard applied else {
                throw PigeonError(code: "markers_not_ready", message: nil, details: nil)
            }
        }
    }

    // MARK: registration

    func register(messenger: FlutterBinaryMessenger, viewId: Int64) {
        NativeMapMarkersApiSetup.setUp(
            binaryMessenger: messenger, api: self,
            messageChannelSuffix: PigeonCameraBridge.viewChannelSuffix(viewId))
    }

    /// Removes this bridge's handlers without touching legacy endpoints.
    func unregister(messenger: FlutterBinaryMessenger, viewId: Int64) {
        NativeMapMarkersApiSetup.setUp(
            binaryMessenger: messenger, api: nil,
            messageChannelSuffix: PigeonCameraBridge.viewChannelSuffix(viewId))
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

    // MARK: payload conversion

    /// Decodes PNG bytes into a platform image; nil when the bytes are not a
    /// decodable image (Dart widget capture failures stay a Dart problem).
    static func decodeImage(_ data: Data) -> OSMPlatformImage? {
        OSMPlatformImage(data: data)
    }

    /// Requires decodable image bytes for icon replacement.
    static func requireImage(_ data: Data) throws -> OSMPlatformImage {
        guard let image = decodeImage(data) else {
            throw PigeonError(code: "markers_not_ready", message: nil, details: nil)
        }
        return image
    }

    static func base64(_ data: Data) -> String {
        data.base64EncodedString()
    }

    /// Generated marker angles are degrees clockwise; the native marker
    /// configuration stores radians.
    static func radians(fromDegrees degrees: Double) -> Float {
        Float(degrees * Double.pi / 180.0)
    }

    /// Decodes a flat Float64List payload element-by-element with unaligned
    /// loads (typed data buffers are not guaranteed 8-byte aligned).
    static func doubles(_ typedData: FlutterStandardTypedData) -> [Double] {
        let count = Int(typedData.elementCount)
        guard count > 0 else {
            return []
        }
        let data = typedData.data
        return (0..<count).map { index in
            data.withUnsafeBytes { raw in
                raw.loadUnaligned(
                    fromByteOffset: index * MemoryLayout<Double>.size,
                    as: Double.self)
            }
        }
    }
}

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

    static func viewChannelSuffix(_ viewId: Int64) -> String {
        "view_\(viewId)"
    }

    /// Payload of the read-only `map#bootstrap#protocol` legacy-channel probe.
    /// Must stay in sync with the Dart bootstrap contract in
    /// flutter_osm_interface (`native_camera_bootstrap.dart`) and the Kotlin
    /// `PigeonNativeCameraBridge.bootstrapPayload`.
    static func bootstrapPayload(sessionToken: String, generation: Int64) -> [String: Any] {
        [
            "revision": nativeProtocolRevision,
            "schemaId": nativeCameraSchemaId,
            "capabilities": [capabilityCamera],
            "sessionToken": sessionToken,
            "generation": generation,
        ]
    }
}

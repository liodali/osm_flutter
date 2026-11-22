//
//  PigeonTrackingBridge.swift
//  flutter_osm_plugin
//
//  Generated-channel host for the follow-me tracking family (Pigeon
//  channel profile): enable/disable tracking. This bridge is the only
//  component that decodes generated tracking calls. It validates the
//  per-map session token/generation pair, then delegates to the shared
//  session's typed tracking methods. Enable completes exactly once
//  (idempotent; permission denial surfaces as permission_denied, provider
//  off as location_service_disabled); disable is idempotent, never
//  prompts, never fails, and preserves continuous updates and pending
//  one-shot fixes — all consumers share the location subscription and
//  reconcile through the ownership checks.
//

import CoreLocation
import Foundation
#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterMacOS)
import FlutterMacOS
#endif
import OSMFlutterFramework

@MainActor
final class PigeonTrackingBridge: NativeMapTrackingApi {

    private weak var session: MapSession?
    private let sessionToken: String
    private let generation: Int64

    init(session: MapSession) {
        self.session = session
        self.sessionToken = session.sessionToken
        self.generation = session.generation
    }

    func enableTracking(session: NativeCameraSession, configuration: NativeTrackingConfiguration) async throws {
        try await withCheckedThrowingContinuation { continuation in
            var delivered = false
            let deliver: (Result<Void, Error>) -> Void = { result in
                // Exactly-once guard: late callbacks stay no-ops.
                guard !delivered else { return }
                delivered = true
                continuation.resume(with: result)
            }
            do {
                try validate(session)
                try requireSession().typedEnableTracking(
                    stopFollowInDrag: configuration.stopFollowInDrag,
                    disableMarkerRotation: configuration.disableMarkerRotation,
                    useDirectionMarker: configuration.useDirectionMarker,
                    // Null keeps the live pivots: starting tracking must not
                    // re-center icons the application configured itself.
                    anchorX: configuration.anchor?.x,
                    anchorY: configuration.anchor?.y) { failureCode, failureMessage in
                    if let failureCode = failureCode {
                        deliver(.failure(
                            PigeonError(code: failureCode, message: failureMessage, details: nil)))
                    } else {
                        deliver(.success(()))
                    }
                }
            } catch {
                deliver(.failure(error))
            }
        }
    }

    func disableTracking(session: NativeCameraSession) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var delivered = false
            let deliver: (Result<Void, Error>) -> Void = { result in
                // Exactly-once guard: late callbacks stay no-ops.
                guard !delivered else { return }
                delivered = true
                continuation.resume(with: result)
            }
            do {
                try validate(session)
                try requireSession().typedDisableTracking()
                deliver(.success(()))
            } catch {
                deliver(.failure(error))
            }
        }
    }

    // MARK: registration

    func register(messenger: FlutterBinaryMessenger, viewId: Int64) {
        NativeMapTrackingApiSetup.setUp(
            binaryMessenger: messenger, api: self,
            messageChannelSuffix: PigeonCameraBridge.viewChannelSuffix(viewId))
    }

    /// Removes this bridge's handlers without touching legacy endpoints.
    func unregister(messenger: FlutterBinaryMessenger, viewId: Int64) {
        NativeMapTrackingApiSetup.setUp(
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
}

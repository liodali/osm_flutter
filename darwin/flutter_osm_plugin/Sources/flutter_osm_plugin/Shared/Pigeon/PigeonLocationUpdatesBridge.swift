//
//  PigeonLocationUpdatesBridge.swift
//  flutter_osm_plugin
//
//  Generated-channel host for the continuous-updates family (Pigeon
//  channel profile): start/stop location updates. This bridge is the only
//  component that decodes generated updates calls. It validates the
//  per-map session token/generation pair, then delegates to the shared
//  session's typed updates methods. Start completes exactly once
//  (idempotent; permission denial surfaces as permission_denied); stop is
//  idempotent, never prompts, never fails, and preserves pending one-shot
//  fixes and tracking. Location events keep flowing on the existing
//  event channel.
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
final class PigeonLocationUpdatesBridge: NativeMapLocationUpdatesApi {

    private weak var session: MapSession?
    private let sessionToken: String
    private let generation: Int64

    init(session: MapSession) {
        self.session = session
        self.sessionToken = session.sessionToken
        self.generation = session.generation
    }

    func startLocationUpdates(session: NativeCameraSession) async throws {
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
                try requireSession().typedStartLocationUpdates { failureCode, failureMessage in
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

    func stopLocationUpdates(session: NativeCameraSession) async throws {
        try validate(session)
        // Idempotent, never prompts, never fails: plain delegation.
        try requireSession().typedStopLocationUpdates()
    }

    // MARK: registration

    func register(messenger: FlutterBinaryMessenger, viewId: Int64) {
        NativeMapLocationUpdatesApiSetup.setUp(
            binaryMessenger: messenger, api: self,
            messageChannelSuffix: PigeonCameraBridge.viewChannelSuffix(viewId))
    }

    /// Removes this bridge's handlers without touching legacy endpoints.
    func unregister(messenger: FlutterBinaryMessenger, viewId: Int64) {
        NativeMapLocationUpdatesApiSetup.setUp(
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

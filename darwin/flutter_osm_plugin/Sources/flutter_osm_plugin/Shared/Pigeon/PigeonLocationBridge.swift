//
//  PigeonLocationBridge.swift
//  flutter_osm_plugin
//
//  Generated-channel host for the location family (Pigeon channel
//  profile): the my-location layer toggle and single-shot fixes. This
//  bridge is the only component that decodes generated location calls. It
//  validates the per-map session token/generation pair, then delegates to
//  the shared session's typed location slot — the same pending slot the
//  legacy route uses, so a legacy and a generated request can never run in
//  parallel by accident. Completion is exactly once per the schema
//  contract; the session guarantees the completion fires once and the
//  delivered flag additionally ignores any late callback. Permission
//  ownership stays with the host application.
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
final class PigeonLocationBridge: NativeMapLocationApi {

    private weak var session: MapSession?
    private let sessionToken: String
    private let generation: Int64

    init(session: MapSession) {
        self.session = session
        self.sessionToken = session.sessionToken
        self.generation = session.generation
    }

    func showMyLocation(session: NativeCameraSession) async throws {
        try validate(session)
        try requireSession().typedShowMyLocation()
    }

    func getCurrentLocation(session: NativeCameraSession) async throws -> NativeLocationFix {
        try await withCheckedThrowingContinuation { continuation in
            var delivered = false
            let deliver: (Result<NativeLocationFix, Error>) -> Void = { result in
                // Exactly-once guard: the session never repeats an outcome,
                // but a late callback must stay a no-op regardless.
                guard !delivered else { return }
                delivered = true
                continuation.resume(with: result)
            }
            do {
                try validate(session)
                try requireSession().typedRequestLocationFix { outcome in
                    switch outcome {
                    case let .fixed(latitude, longitude):
                        deliver(
                            .success(NativeLocationFix(latitude: latitude, longitude: longitude)))
                    case let .failed(code, message):
                        deliver(
                            .failure(PigeonError(code: code, message: message, details: nil)))
                    }
                }
            } catch {
                deliver(.failure(error))
            }
        }
    }

    // MARK: registration

    func register(messenger: FlutterBinaryMessenger, viewId: Int64) {
        NativeMapLocationApiSetup.setUp(
            binaryMessenger: messenger, api: self,
            messageChannelSuffix: PigeonCameraBridge.viewChannelSuffix(viewId))
    }

    /// Removes this bridge's handlers without touching legacy endpoints.
    func unregister(messenger: FlutterBinaryMessenger, viewId: Int64) {
        NativeMapLocationApiSetup.setUp(
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

//
//  PigeonLocationEventsBridge.swift
//  flutter_osm_plugin
//
//  Generated-channel native-to-Dart user-location event route (Pigeon
//  channel profile): continuous location fixes with heading.
//
//  This bridge is the only component that emits generated user-location
//  events. Every callback carries the session token/generation pair so the
//  Dart client can drop stale sessions after view replacement or disposal,
//  and the fix crosses the wire as raw doubles (position in degrees, heading
//  in degrees clockwise from true north) — the host's full precision reaches
//  the public stream without a map round-trip, exactly like the legacy
//  `receiveUserLocation` payload.
//
//  Delivery is fire-and-forget on the main actor; a missing Dart handler
//  (detached engine) is swallowed, never retried through the legacy plane —
//  exactly one delivery route is active per attachment. Emissions after
//  `close` are dropped.
//
//  The bridge owns no rate: the session forwards every location delegate
//  callback it receives, as the legacy plane always did, so the generated
//  route inherits the platform's CoreLocation rate unchanged.
//

import Foundation
#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterMacOS)
import FlutterMacOS
#endif

@MainActor
final class PigeonLocationEventsBridge {

    private let api: NativeMapLocationEventsApi
    private let sessionToken: String
    private let generation: Int64
    private var closed = false

    init(messenger: FlutterBinaryMessenger, viewId: Int64, sessionToken: String, generation: Int64) {
        self.api = NativeMapLocationEventsApi(
            binaryMessenger: messenger,
            messageChannelSuffix: PigeonCameraBridge.viewChannelSuffix(viewId))
        self.sessionToken = sessionToken
        self.generation = generation
    }

    /// One user-location fix, with full precision and the raw heading.
    func emitLocationChanged(latitude: Double, longitude: Double, heading: Double) {
        emit("location fix") {
            try await self.api.onLocationChanged(
                session: NativeCameraSession(sessionToken: self.sessionToken, generation: self.generation),
                latitude: latitude, longitude: longitude, heading: heading)
        }
    }

    private func emit(_ kind: String, _ send: @escaping @MainActor () async throws -> Void) {
        guard !closed else { return }
        Task { @MainActor [weak self] in
            guard let self, !self.closed else { return }
            do {
                try await send()
            } catch {
                // Best-effort delivery: a detached Dart side never replays
                // through the legacy plane.
            }
        }
    }

    /// Stops emissions; late callbacks are dropped, never rerouted.
    func close() {
        closed = true
    }
}

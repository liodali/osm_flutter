//
//  PigeonMarkerEventsBridge.swift
//  flutter_osm_plugin
//
//  Generated-channel native-to-Dart marker interaction event route (Pigeon
//  channel profile): marker single-press and long-press callbacks.
//
//  This bridge is the only component that emits generated marker
//  interaction events. Every callback carries the session token/generation
//  pair so the Dart client can drop stale sessions after view replacement
//  or disposal, and the marker position crosses the wire as raw doubles —
//  the host's full precision reaches the public streams without a map
//  round-trip.
//
//  Delivery is fire-and-forget on the main actor; a missing Dart handler
//  (detached engine) is swallowed, never retried through the legacy plane —
//  exactly one delivery route is active per attachment. Emissions after
//  `close` are dropped. Marker interactions are discrete: every occurrence
//  is forwarded once and repeats are never coalesced.
//

import Foundation
#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterMacOS)
import FlutterMacOS
#endif

@MainActor
final class PigeonMarkerEventsBridge {

    private let api: NativeMapMarkerEventsApi
    private let sessionToken: String
    private let generation: Int64
    private var closed = false

    init(messenger: FlutterBinaryMessenger, viewId: Int64, sessionToken: String, generation: Int64) {
        self.api = NativeMapMarkerEventsApi(
            binaryMessenger: messenger,
            messageChannelSuffix: PigeonCameraBridge.viewChannelSuffix(viewId))
        self.sessionToken = sessionToken
        self.generation = generation
    }

    /// Marker single press at the geographic coordinate, full precision.
    func emitSinglePress(latitude: Double, longitude: Double) {
        emit("marker single press") {
            try await self.api.onMarkerSinglePress(
                session: NativeCameraSession(sessionToken: self.sessionToken, generation: self.generation),
                latitude: latitude, longitude: longitude)
        }
    }

    /// Marker long press at the geographic coordinate, full precision.
    func emitLongPress(latitude: Double, longitude: Double) {
        emit("marker long press") {
            try await self.api.onMarkerLongPress(
                session: NativeCameraSession(sessionToken: self.sessionToken, generation: self.generation),
                latitude: latitude, longitude: longitude)
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

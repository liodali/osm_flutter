//
//  PigeonRoadEventsBridge.swift
//  flutter_osm_plugin
//
//  Generated-channel native-to-Dart road tap event route (Pigeon channel
//  profile).
//
//  This bridge is the only component that emits generated road tap events.
//  Every callback carries the session token/generation pair so the Dart
//  client can drop stale sessions after view replacement or disposal, and
//  the tapped road's payload mirrors the legacy `receiveRoad` message field
//  for field (key, optional distance/duration, optional encoded polyline,
//  optional instructions).
//
//  Delivery is fire-and-forget on the main actor; a missing Dart handler
//  (detached engine) is swallowed, never retried through the legacy plane —
//  exactly one delivery route is active per attachment. Emissions after
//  `close` are dropped. Road taps are discrete: every occurrence is
//  forwarded once and repeats are never coalesced.
//

import Foundation
#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterMacOS)
import FlutterMacOS
#endif

@MainActor
final class PigeonRoadEventsBridge {

    private let api: NativeMapRoadEventsApi
    private let sessionToken: String
    private let generation: Int64
    private var closed = false

    init(messenger: FlutterBinaryMessenger, viewId: Int64, sessionToken: String, generation: Int64) {
        self.api = NativeMapRoadEventsApi(
            binaryMessenger: messenger,
            messageChannelSuffix: PigeonCameraBridge.viewChannelSuffix(viewId))
        self.sessionToken = sessionToken
        self.generation = generation
    }

    /// Road tap with the legacy payload, unchanged field for field.
    func emitRoadTap(_ road: NativeTappedRoad) {
        guard !closed else { return }
        let session = NativeCameraSession(sessionToken: sessionToken, generation: generation)
        Task { @MainActor [weak self] in
            guard let self, !self.closed else { return }
            do {
                try await self.api.onRoadTap(session: session, road: road)
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

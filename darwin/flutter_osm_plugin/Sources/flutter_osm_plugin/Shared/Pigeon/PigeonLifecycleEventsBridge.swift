//
//  PigeonLifecycleEventsBridge.swift
//  flutter_osm_plugin
//
//  Generated-channel native-to-Dart lifecycle event route (Pigeon channel
//  profile): map readiness callbacks (and restoration, for hosts with a
//  restoration concept — Apple hosts never emit it).
//
//  This bridge is the only component that emits generated lifecycle events.
//  Every callback carries the session token/generation pair so the Dart
//  client can drop stale sessions after view replacement or disposal.
//
//  Delivery is fire-and-forget on the main actor: the host does not wait
//  for the Dart reply, and a missing Dart handler (detached engine) is
//  swallowed, never retried through the legacy plane — exactly one delivery
//  route is active per attachment. Emissions after `close` are dropped.
//

import Foundation
#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterMacOS)
import FlutterMacOS
#endif

@MainActor
final class PigeonLifecycleEventsBridge {

    private let api: NativeMapLifecycleEventsApi
    private let sessionToken: String
    private let generation: Int64
    private var closed = false

    init(messenger: FlutterBinaryMessenger, viewId: Int64, sessionToken: String, generation: Int64) {
        self.api = NativeMapLifecycleEventsApi(
            binaryMessenger: messenger,
            messageChannelSuffix: PigeonCameraBridge.viewChannelSuffix(viewId))
        self.sessionToken = sessionToken
        self.generation = generation
    }

    /// Readiness transition for this session (once per initialization outcome).
    func emitReady(_ isReady: Bool) {
        guard !closed else { return }
        let session = NativeCameraSession(sessionToken: sessionToken, generation: generation)
        Task { @MainActor [weak self] in
            guard let self, !self.closed else { return }
            do {
                try await self.api.onMapReady(session: session, isReady: isReady)
            } catch {
                // Best-effort delivery: a detached Dart side never replays
                // through the legacy plane.
            }
        }
    }

    /// The session restored its saved map state. Apple hosts have no
    /// Android-style restoration hook; kept for contract parity.
    func emitRestored() {
        guard !closed else { return }
        let session = NativeCameraSession(sessionToken: sessionToken, generation: generation)
        Task { @MainActor [weak self] in
            guard let self, !self.closed else { return }
            do {
                try await self.api.onMapRestored(session: session)
            } catch {
                // Best-effort delivery; see emitReady.
            }
        }
    }

    /// Stops emissions; late callbacks are dropped, never rerouted.
    func close() {
        closed = true
    }
}

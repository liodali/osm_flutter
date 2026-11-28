//
//  PigeonRegionEventsBridge.swift
//  flutter_osm_plugin
//
//  Generated-channel native-to-Dart visible-region event route (Pigeon
//  channel profile): center, bounding box and zoom of the visible region.
//
//  This bridge is the only component that emits generated region events.
//  Every callback carries the session token/generation pair so the Dart
//  client can drop stale sessions after view replacement or disposal, and
//  the region crosses the wire as raw doubles (center and bounds in
//  degrees, zoom in the camera family's `getZoom` units) — the host's full
//  precision reaches the public stream without a map round-trip.
//
//  Delivery is fire-and-forget on the main actor; a missing Dart handler
//  (detached engine) is swallowed, never retried through the legacy plane —
//  exactly one delivery route is active per attachment. Emissions after
//  `close` are dropped.
//
//  The bridge owns no rate: the session forwards every map-move callback
//  it receives, as the legacy plane always did, so the generated route
//  inherits the framework's region-event rate unchanged.
//

import Foundation
#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterMacOS)
import FlutterMacOS
#endif

@MainActor
final class PigeonRegionEventsBridge {

    private let api: NativeMapRegionEventsApi
    private let sessionToken: String
    private let generation: Int64
    private var closed = false

    init(messenger: FlutterBinaryMessenger, viewId: Int64, sessionToken: String, generation: Int64) {
        self.api = NativeMapRegionEventsApi(
            binaryMessenger: messenger,
            messageChannelSuffix: PigeonCameraBridge.viewChannelSuffix(viewId))
        self.sessionToken = sessionToken
        self.generation = generation
    }

    /// One visible-region change, with full precision.
    func emitRegionChanged(
        centerLatitude: Double, centerLongitude: Double,
        north: Double, east: Double, south: Double, west: Double,
        zoom: Double
    ) {
        emit("region change") {
            try await self.api.onRegionChanged(
                session: NativeCameraSession(sessionToken: self.sessionToken, generation: self.generation),
                centerLatitude: centerLatitude, centerLongitude: centerLongitude,
                bounds: NativeBounds(north: north, south: south, east: east, west: west),
                zoom: zoom)
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

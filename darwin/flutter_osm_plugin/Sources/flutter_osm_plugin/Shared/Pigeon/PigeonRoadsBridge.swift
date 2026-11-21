//
//  PigeonRoadsBridge.swift
//  flutter_osm_plugin
//
//  Generated-channel host for the roads family (Pigeon channel profile):
//  manual road drawing, removal by id and clearing. This bridge is the
//  only component that decodes generated road calls. It validates the
//  per-map session token/generation pair, then delegates to the typed
//  roads service on the shared session — the same native operations the
//  legacy route performs. Registration lives alongside the legacy
//  endpoints; it never replaces them.
//

import CoreLocation
import Foundation
#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterMacOS)
import FlutterMacOS
#endif
import OSMFlutterFramework

final class PigeonRoadsBridge: NativeMapRoadsApi {

    private weak var session: MapSession?
    private let sessionToken: String
    private let generation: Int64

    init(session: MapSession) {
        self.session = session
        self.sessionToken = session.sessionToken
        self.generation = session.generation
    }

    func drawRoad(
        session: NativeCameraSession,
        roadId: String,
        coordinates: FlutterStandardTypedData,
        style: NativeRoadStyle,
        zoomInto: Bool
    ) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            guard !roadId.isEmpty, let points = Self.decodeCoordinates(coordinates) else {
                throw PigeonError(code: "roads_not_ready", message: nil, details: nil)
            }
            try requireSession().typedDrawRoad(
                id: roadId,
                coordinates: points,
                roadColorArgb: style.roadColorArgb,
                roadWidth: style.roadWidth,
                borderColorArgb: style.borderColorArgb,
                borderWidth: style.borderWidth,
                dotted: style.dotted,
                zoomInto: zoomInto)
        }
    }

    func removeRoad(session: NativeCameraSession, roadId: String) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            // Removal is a silent no-op for unknown keys, mirroring the
            // legacy delete#road handler.
            try requireSession().typedRemoveRoad(id: roadId)
        }
    }

    func clearRoads(session: NativeCameraSession) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            try requireSession().typedClearRoads()
        }
    }

    /// Decodes the flat `[lat, lon, ...]` Float64 wire list.
    static func decodeCoordinates(_ data: FlutterStandardTypedData) -> [CLLocationCoordinate2D]? {
        let count = data.data.count / MemoryLayout<Double>.size
        let floats = data.data.withUnsafeBytes { raw -> [Double] in
            guard count > 0, let base = raw.baseAddress else { return [] }
            let buffer = base.assumingMemoryBound(to: Double.self)
            return Array(UnsafeBufferPointer(start: buffer, count: count))
        }
        guard floats.count >= 4, floats.count % 2 == 0 else { return nil }
        var points: [CLLocationCoordinate2D] = []
        points.reserveCapacity(floats.count / 2)
        var index = 0
        while index < floats.count {
            points.append(
                CLLocationCoordinate2D(latitude: floats[index], longitude: floats[index + 1]))
            index += 2
        }
        return points
    }

    // MARK: registration

    func register(messenger: FlutterBinaryMessenger, viewId: Int64) {
        NativeMapRoadsApiSetup.setUp(
            binaryMessenger: messenger, api: self,
            messageChannelSuffix: PigeonCameraBridge.viewChannelSuffix(viewId))
    }

    /// Removes this bridge's handlers without touching legacy endpoints.
    func unregister(messenger: FlutterBinaryMessenger, viewId: Int64) {
        NativeMapRoadsApiSetup.setUp(
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

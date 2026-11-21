//
//  PigeonShapesBridge.swift
//  flutter_osm_plugin
//
//  Generated-channel host for the shapes family (Pigeon channel profile):
//  circles and rectangles. This bridge is the only component that decodes
//  generated shape calls. It validates the per-map session token/generation
//  pair, then delegates to the typed shapes service on the shared session —
//  the same native operations the legacy route performs. Registration
//  lives alongside the legacy endpoints; it never replaces them.
//

import Foundation
#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterMacOS)
import FlutterMacOS
#endif
import OSMFlutterFramework

final class PigeonShapesBridge: NativeMapShapesApi {

    private weak var session: MapSession?
    private let sessionToken: String
    private let generation: Int64

    init(session: MapSession) {
        self.session = session
        self.sessionToken = session.sessionToken
        self.generation = session.generation
    }

    func addCircle(
        session: NativeCameraSession,
        shapeId: String,
        latitude: Double,
        longitude: Double,
        radius: Double,
        style: NativeShapeStyle
    ) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            guard !shapeId.isEmpty else {
                throw PigeonError(code: "shapes_not_ready", message: nil, details: nil)
            }
            try requireSession().typedAddCircle(
                id: shapeId,
                latitude: latitude,
                longitude: longitude,
                radiusMeters: radius,
                fillColorArgb: style.fillColorArgb,
                borderColorArgb: style.borderColorArgb,
                strokeWidth: style.strokeWidth)
        }
    }

    func addRectangle(
        session: NativeCameraSession,
        shapeId: String,
        latitude: Double,
        longitude: Double,
        distance: Double,
        style: NativeShapeStyle
    ) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            guard !shapeId.isEmpty else {
                throw PigeonError(code: "shapes_not_ready", message: nil, details: nil)
            }
            try requireSession().typedAddRectangle(
                id: shapeId,
                latitude: latitude,
                longitude: longitude,
                distanceMeters: distance,
                fillColorArgb: style.fillColorArgb,
                borderColorArgb: style.borderColorArgb,
                strokeWidth: style.strokeWidth)
        }
    }

    func removeShape(session: NativeCameraSession, shapeId: String) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            // Removal is a silent no-op for unknown ids, mirroring the
            // legacy remove#circle / remove#rect handlers.
            try requireSession().typedRemoveShape(id: shapeId)
        }
    }

    func removeCircles(session: NativeCameraSession) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            try requireSession().typedRemoveCircles()
        }
    }

    func removeRectangles(session: NativeCameraSession) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            try requireSession().typedRemoveRectangles()
        }
    }

    func clearShapes(session: NativeCameraSession) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            try requireSession().typedClearShapes()
        }
    }

    // MARK: registration

    func register(messenger: FlutterBinaryMessenger, viewId: Int64) {
        NativeMapShapesApiSetup.setUp(
            binaryMessenger: messenger, api: self,
            messageChannelSuffix: PigeonCameraBridge.viewChannelSuffix(viewId))
    }

    /// Removes this bridge's handlers without touching legacy endpoints.
    func unregister(messenger: FlutterBinaryMessenger, viewId: Int64) {
        NativeMapShapesApiSetup.setUp(
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

//
//  PigeonLayersBridge.swift
//  flutter_osm_plugin
//
//  Generated-channel host for the layers family (Pigeon channel profile):
//  tile-source selection and overlay visibility. This bridge is the only
//  component that decodes generated layer calls. It validates the per-map
//  session token/generation pair, then delegates to the typed layers
//  service on the shared session — the same native operations the legacy
//  route performs. Registration lives alongside the legacy endpoints; it
//  never replaces them.
//

import Foundation
#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterMacOS)
import FlutterMacOS
#endif
import OSMFlutterFramework

final class PigeonLayersBridge: NativeMapLayersApi {

    private weak var session: MapSession?
    private let sessionToken: String
    private let generation: Int64

    init(session: MapSession) {
        self.session = session
        self.sessionToken = session.sessionToken
        self.generation = session.generation
    }

    func changeTileLayer(session: NativeCameraSession, tile: NativeTileConfiguration?) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            try requireSession().typedChangeTile(tile)
        }
    }

    func setOverlaysVisible(session: NativeCameraSession, visible: Bool) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            try requireSession().typedSetOverlaysVisible(visible)
        }
    }

    // MARK: registration

    func register(messenger: FlutterBinaryMessenger, viewId: Int64) {
        NativeMapLayersApiSetup.setUp(
            binaryMessenger: messenger, api: self,
            messageChannelSuffix: PigeonCameraBridge.viewChannelSuffix(viewId))
    }

    /// Removes this bridge's handlers without touching legacy endpoints.
    func unregister(messenger: FlutterBinaryMessenger, viewId: Int64) {
        NativeMapLayersApiSetup.setUp(
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

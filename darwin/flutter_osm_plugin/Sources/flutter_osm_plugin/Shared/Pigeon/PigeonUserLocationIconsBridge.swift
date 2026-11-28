//
//  PigeonUserLocationIconsBridge.swift
//  flutter_osm_plugin
//
//  Generated-channel host for the user-location icon family (Pigeon channel
//  profile): person and direction icon replacement. This bridge is the only
//  component that decodes generated icon calls. It validates the per-map
//  session token/generation pair, decodes the Dart-prepared PNG bytes, then
//  delegates to the shared session's typed icon method — the same native
//  configuration the legacy `user#locationMarkers` route applies.
//
//  The call only swaps the layer icons: follow-me tracking, continuous
//  updates and pending one-shot fixes keep running untouched, and no
//  permission flow is triggered. A null icon pair restores the platform
//  default icons and the default center anchor.
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
final class PigeonUserLocationIconsBridge: NativeMapUserLocationIconsApi {

    private weak var session: MapSession?
    private let sessionToken: String
    private let generation: Int64

    init(session: MapSession) {
        self.session = session
        self.sessionToken = session.sessionToken
        self.generation = session.generation
    }

    func setUserLocationIcons(
        session: NativeCameraSession,
        icons: NativeUserLocationIcons?
    ) throws {
        try MainActor.assumeIsolated {
            try validate(session)
            let target = try requireSession()
            if let icons = icons {
                target.typedSetUserLocationIcons(
                    MapSession.UserLocationIconsRender(
                        person: try Self.render(icons.person),
                        direction: try Self.render(icons.direction)))
            } else {
                // Reset route: the icons the framework installed at view
                // creation, default center anchor included.
                target.typedSetUserLocationIcons(nil)
            }
        }
    }

    /// Converts one generated icon into a prepared render request. A nil
    /// anchor keeps the live pivot (the host must not move an active marker
    /// when only the bytes change).
    private static func render(
        _ icon: NativeUserLocationIcon
    ) throws -> MapSession.UserLocationIconRender {
        let data = icon.iconBytes.data
        guard let image = PigeonMarkersBridge.decodeImage(data) else {
            throw PigeonError(
                code: "icons_not_ready",
                message: "the prepared icon is not a decodable image",
                details: nil)
        }
        let pivot: MapSession.UserLocationIconRender.Pivot
        if let anchor = icon.anchor {
            pivot = .normalized(x: anchor.x, y: anchor.y)
        } else {
            pivot = .preserve
        }
        return MapSession.UserLocationIconRender(
            image: image,
            pngData: data,
            logicalSize: icon.logicalSize.map { [Int($0.width), Int($0.height)] },
            pivot: pivot)
    }

    // MARK: registration

    func register(messenger: FlutterBinaryMessenger, viewId: Int64) {
        NativeMapUserLocationIconsApiSetup.setUp(
            binaryMessenger: messenger, api: self,
            messageChannelSuffix: PigeonCameraBridge.viewChannelSuffix(viewId))
    }

    /// Removes this bridge's handlers without touching legacy endpoints.
    func unregister(messenger: FlutterBinaryMessenger, viewId: Int64) {
        NativeMapUserLocationIconsApiSetup.setUp(
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

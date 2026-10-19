//
//  IOSMapViewFactory.swift
//  flutter_osm_plugin
//
//  Created by Dali on 6/12/20.
//  Copyright © 2020 The Chromium Authors. All rights reserved.
//

#if canImport(Flutter)

import Flutter
import Foundation

/// iOS host: creates one independent `MapSession` per platform view and vends
/// its native `OSMView` (a `UIView`) to Flutter through the
/// `FlutterPlatformView` wrapper.
@MainActor
public class IOSMapViewFactory: NSObject, FlutterPlatformViewFactory {
    let messenger: FlutterBinaryMessenger
    let defaultPinPath: String?
    nonisolated init(messenger: FlutterBinaryMessenger, defaultPin: String?) {
        self.messenger = messenger
        self.defaultPinPath = defaultPin
    }

    public func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        let channel = FlutterMethodChannel(
            name: "plugins.dali.hamza/osmview_" + String(viewId),
            binaryMessenger: self.messenger
        )
        return IOSMapView(
            session: MapSession(
                frame, viewId: viewId, channel: channel, args: args, defaultPin: defaultPinPath))
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

/// Thin iOS `FlutterPlatformView` wrapper retaining the shared map session.
@MainActor
final class IOSMapView: NSObject, FlutterPlatformView {
    let session: MapSession

    init(session: MapSession) {
        self.session = session
    }

    public func view() -> UIView {
        return session.platformView
    }
}

#endif

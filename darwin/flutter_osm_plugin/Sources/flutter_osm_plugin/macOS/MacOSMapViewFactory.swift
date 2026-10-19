//
//  MacOSMapViewFactory.swift
//  flutter_osm_plugin
//

#if canImport(FlutterMacOS)

import AppKit
import FlutterMacOS
import Foundation

/// macOS host: creates one independent `MapSession` per platform view and
/// returns an `NSView` hosting the native `OSMView` (also an `NSView`), which
/// retains the shared session for as long as the view is displayed.
@MainActor
public class MacOSMapViewFactory: NSObject, FlutterPlatformViewFactory {
    let messenger: FlutterBinaryMessenger
    let defaultPinPath: String?
    nonisolated init(messenger: FlutterBinaryMessenger, defaultPin: String?) {
        self.messenger = messenger
        self.defaultPinPath = defaultPin
    }

    public func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
        let channel = FlutterMethodChannel(
            name: "plugins.dali.hamza/osmview_" + String(viewId),
            binaryMessenger: self.messenger
        )
        let session = MapSession(
            .zero, viewId: viewId, channel: channel, args: args, defaultPin: defaultPinPath)
        return MacOSMapHostView(frame: .zero, session: session)
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

/// Container that embeds the shared `OSMView` and keeps its `MapSession` alive
/// while Flutter displays the view. The autoresizing mask tracks container
/// bounds so the map follows window resizes and display changes; the
/// framework's `OSMView.layout` relayouts its internal map view on macOS.
@MainActor
final class MacOSMapHostView: NSView {
    let session: MapSession

    init(frame: CGRect, session: MapSession) {
        self.session = session
        super.init(frame: frame)
        let map = session.platformView
        map.frame = bounds
        map.autoresizingMask = [.width, .height]
        addSubview(map)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Re-applies scale-dependent icons (user-location markers) when the view
    /// moves to a display with a different backing scale.
    override public func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        session.handleDisplayScaleChanged()
    }

    deinit {
        // The host view is only released by the engine on the main thread.
        MainActor.assumeIsolated {
            session.dispose()
        }
    }
}

#endif

//
//  ApplePlatformUtilities.swift
//  flutter_osm_plugin
//

import Foundation
import OSMFlutterFramework

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Platform helpers shared by the iOS and macOS hosts: SF Symbol fallbacks,
/// bundled-image lookup and display-scale handling.
/// All image/color types come from the framework's `OSMPlatformImage` /
/// `OSMPlatformColor` aliases, which resolve to UIKit types on iOS and AppKit
/// types on macOS.
enum ApplePlatformUtilities {

    /// Backing scale used to convert logical marker sizes to pixels: the scale
    /// of the window hosting the map when available (`NSScreen.main` can be a
    /// different display), falling back to the main screen, then 1.0. On iOS
    /// this is the main screen scale, as before.
    static func displayScale(for view: OSMPlatformView?) -> CGFloat {
        #if os(macOS)
        return view?.window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor ?? 1.0
        #else
        return UIScreen.main.scale
        #endif
    }

    /// SF Symbol fallback used when an icon payload cannot be decoded.
    static func systemImage(named name: String) -> OSMPlatformImage? {
        #if os(macOS)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)
        #else
        return UIImage(systemName: name)
        #endif
    }

    /// Loads the bundled default pin. `name` is a file path produced by the
    /// Flutter asset lookup key (`Bundle.main.path(forResource:)`), so on macOS
    /// it must be read with `NSImage(contentsOfFile:)` — `NSImage(named:)` only
    /// matches asset-catalog names and returns nil for paths.
    static func bundledImage(named name: String) -> OSMPlatformImage? {
        #if os(macOS)
        return NSImage(contentsOfFile: name)
        #else
        return UIImage(named: name, in: Bundle.main, compatibleWith: nil)
        #endif
    }
}

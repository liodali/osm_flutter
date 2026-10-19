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

    /// Backing scale of the main display (2.0/3.0 on iOS, Retina scale on macOS).
    static var displayScale: CGFloat {
        #if os(macOS)
        return NSScreen.main?.backingScaleFactor ?? 1.0
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

    /// Image loaded by name from the application bundle, used for the bundled
    /// default pin asset.
    static func bundledImage(named name: String) -> OSMPlatformImage? {
        #if os(macOS)
        return NSImage(named: NSImage.Name(name))
        #else
        return UIImage(named: name, in: Bundle.main, compatibleWith: nil)
        #endif
    }
}

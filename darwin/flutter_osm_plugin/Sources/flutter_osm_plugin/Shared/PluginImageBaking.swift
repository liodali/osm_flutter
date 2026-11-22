//
//  PluginImageBaking.swift
//  flutter_osm_plugin
//
//  CoreGraphics helpers that bake pivot and rotation into marker textures.
//
//  The pinned POI layer rebuilds every marker configuration with
//  `angle: nil, anchor: nil`, so the plugin's my-location marker carries its
//  pivot as transparent padding and its heading as a rotation of the padded
//  canvas (about the pivot). Mirrors the drawing approach of the framework's
//  own image utilities, which stay internal to that package.
//

import Foundation
import CoreGraphics
#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterMacOS)
import FlutterMacOS
#endif
import OSMFlutterFramework

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum PluginImageBaking {

    /// Backing pixels of a platform image (RGB space, alpha preserved).
    static func cgImage(_ image: OSMPlatformImage) -> CGImage? {
        #if os(macOS)
        var rect = CGRect(origin: .zero, size: image.size)
        guard let source = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            return nil
        }
        guard let context = CGContext(
            data: nil, width: source.width, height: source.height,
            bitsPerComponent: 8, bytesPerRow: source.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            return nil
        }
        context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
        return context.makeImage()
        #else
        return image.cgImage
        #endif
    }

    /// A fully transparent 1×1 image.
    static func transparentImage() -> OSMPlatformImage {
        let pixel = CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            .makeImage()!
        return platformImage(pixel, size: CGSize(width: 1, height: 1), scale: 1)
    }

    /// Places [source] inside transparent padding (carrying the pivot) and
    /// rotates the padded canvas by [angleDegrees] clockwise about its
    /// center. Returns nil when the composition fails.
    static func padAndRotate(
        source: CGImage,
        pixelsPerPoint: CGFloat,
        layout: MapSession.BakedUserLocationMarkerLayout,
        angleDegrees: Double
    ) -> OSMPlatformImage? {
        let padded = CGSize(
            width: layout.paddedSize.width * pixelsPerPoint,
            height: layout.paddedSize.height * pixelsPerPoint)
        let content = CGSize(width: CGFloat(source.width), height: CGFloat(source.height))
        // The layout offset grows downwards from the padded canvas' top-left;
        // CoreGraphics draws with y growing upwards.
        let origin = CGPoint(
            x: padded.width / 2
                - (CGFloat(source.width) / 2 + (layout.contentOffset.x * pixelsPerPoint)),
            y: padded.height / 2
                - (layout.contentOffset.y * pixelsPerPoint + CGFloat(source.height) / 2))
        let rotated = CGSize(
            width: max(1, (layout.rotatedSize.width * pixelsPerPoint).rounded(.up)),
            height: max(1, (layout.rotatedSize.height * pixelsPerPoint).rounded(.up)))
        guard let context = CGContext(
            data: nil, width: Int(rotated.width), height: Int(rotated.height),
            bitsPerComponent: 8, bytesPerRow: Int(rotated.width) * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            return nil
        }
        context.translateBy(x: rotated.width / 2, y: rotated.height / 2)
        if angleDegrees != 0 {
            // Positive headings rotate clockwise on screen; CoreGraphics
            // rotates counter-clockwise in its y-up space.
            context.rotate(by: CGFloat(-angleDegrees * .pi / 180))
        }
        context.draw(
            source,
            in: CGRect(
                x: origin.x, y: origin.y, width: content.width, height: content.height))
        guard let baked = context.makeImage() else {
            return nil
        }
        return platformImage(baked, size: layout.rotatedSize, scale: pixelsPerPoint)
    }

    private static func platformImage(
        _ cgImage: CGImage, size: CGSize, scale: CGFloat
    ) -> OSMPlatformImage {
        #if os(macOS)
        return OSMPlatformImage(
            cgImage: cgImage, size: NSSize(width: size.width, height: size.height))
        #else
        return OSMPlatformImage(
            cgImage: cgImage, scale: max(scale, .ulpOfOne),
            orientation: .up)
        #endif
    }
}

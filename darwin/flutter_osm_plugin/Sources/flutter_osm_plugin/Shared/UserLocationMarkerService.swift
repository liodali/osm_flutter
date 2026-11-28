//
//  UserLocationMarkerService.swift
//  flutter_osm_plugin
//
//  Plugin-owned rendering of the my-location marker on Apple platforms.
//
//  Framework 0.9.1 refreshes its user-location marker destructively: any
//  `setUserLocationIcons` call sets a private flag that makes the next fix
//  REMOVE the rendered marker, re-adding it in that same pass only when
//  heading rotation runs. With heading zero or rotation disabled the marker
//  stays hidden until a later fix, which a stationary user may never receive,
//  and the framework exposes no in-place refresh for its marker layer.
//
//  Once the application configures its own person/direction icons the plugin
//  therefore renders the marker itself in the public POI icon layer. Two
//  quirks of the pinned POI implementation are handled here:
//
//  * `PoisManager.setMarkersPoi` rebuilds every marker from the icon the
//    `Poi` captured at CREATION (a `let`), so a positioning call alone would
//    revert a replaced texture to the first image. The painter therefore
//    re-applies the current icon after every positioning call.
//  * Both `setMarkersPoi` and `setOrCreateIconPoi` rebuild marker
//    configurations with `angle: nil, anchor: nil`, so pivots and heading
//    rotation are baked into the texture itself (transparent padding for
//    the pivot, rotation about the pivot for the heading).
//
//  The result is an icon-only, in-place refresh: no location consumer is
//  stopped or restarted and no extra fix is needed. The framework's own
//  marker control is turned off for that case (`controlUserMarker: false`)
//  so exactly one marker is drawn.
//
//  Sessions that never configure custom icons keep the framework's marker
//  and its existing behavior.
//

import CoreLocation
import Foundation
#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterMacOS)
import FlutterMacOS
#endif
import OSMFlutterFramework

extension MapSession {

    /// Painting surface for the plugin-rendered my-location marker. The
    /// session's renderer seam drives it; tests install a recording fake to
    /// assert the exact call sequence against the pinned POI quirks.
    protocol UserLocationMarkerPainting: AnyObject {
        /// Whether the backing marker exists (its creation freezes the icon
        /// the pinned POI rebuilds positions from).
        var isInstalled: Bool { get }

        /// Installs (or replaces) the texture of the marker's icon.
        func installIcon(id: String, image: OSMPlatformImage, size: MarkerIconSize?)

        /// Places the marker at one coordinate.
        func setPositions(id: String, location: CLLocationCoordinate2D)

        /// Removes the marker (the icon itself may stay installed).
        func removeMarker(id: String)
    }

    /// Paints the my-location marker through the framework's POI layer.
    ///
    /// The pinned `Poi` freezes its creation icon, so EVERY positioning call
    /// must be followed by an icon re-application — otherwise a replaced
    /// texture reverts to the first image on the next redraw.
    @MainActor
    final class PoisUserLocationMarkerPainter: UserLocationMarkerPainting {
        private let poisManager: PoisManager
        /// Whether the backing `Poi` exists (its creation captures the frozen
        /// icon); `clearMarkersPoi` keeps the `Poi` alive.
        private var poiCreated = false

        init(poisManager: PoisManager) {
            self.poisManager = poisManager
        }

        var isInstalled: Bool {
            poiCreated
        }

        func installIcon(id: String, image: OSMPlatformImage, size: MarkerIconSize?) {
            // Creates the `Poi` on first use, applies the icon afterwards.
            poisManager.setOrCreateIconPoi(id: id, icon: image, iconSize: size)
            poiCreated = true
        }

        func setPositions(id: String, location: CLLocationCoordinate2D) {
            guard poiCreated else {
                // `setMarkersPoi` is a no-op before the `Poi` exists.
                return
            }
            // Angle and anchor are baked into the texture (see the baking
            // below); the layer would drop them from the configuration.
            poisManager.setMarkersPoi(
                id: id,
                markers: [MarkerIconPoi(location: location, angle: nil, anchor: nil)])
        }

        func removeMarker(id: String) {
            guard poiCreated else {
                return
            }
            poisManager.clearMarkersPoi(id: id, markers: [])
        }
    }

    /// Layout of one baked marker texture.
    struct BakedUserLocationMarkerLayout: Equatable {
        /// Size of the canvas that carries the pivot, before rotation
        /// (logical units).
        var paddedSize: CGSize
        /// Offset of the content inside the padded canvas, from the top-left
        /// corner, y growing downwards (logical units).
        var contentOffset: CGPoint
        /// Size of the rotated canvas (logical units).
        var rotatedSize: CGSize
    }

    /// Computes how the pivot and the heading rotation must be baked into a
    /// marker texture.
    ///
    /// The padded canvas centers the icon's pivot: the content is offset so
    /// the pivot point lands at the canvas center, which is where the layer
    /// anchors every icon. The rotation is applied about that center (the
    /// pivot), growing the canvas to the rotated bounding box.
    nonisolated static func bakedUserLocationMarkerLayout(
        logicalSize: CGSize,
        anchorX: Double,
        anchorY: Double,
        angleDegrees: Double
    ) -> BakedUserLocationMarkerLayout {
        let ax = min(max(anchorX, 0), 1)
        let ay = min(max(anchorY, 0), 1)
        // Padding must keep the pivot at the center on both axes.
        let padded = CGSize(
            width: logicalSize.width * 2 * max(ax, 1 - ax),
            height: logicalSize.height * 2 * max(ay, 1 - ay))
        let offset = CGPoint(
            x: (padded.width - logicalSize.width) / 2 - (ax - 0.5) * logicalSize.width,
            y: (padded.height - logicalSize.height) / 2 - (ay - 0.5) * logicalSize.height)
        let radians = angleDegrees * .pi / 180
        let sinA = abs(sin(radians))
        let cosA = abs(cos(radians))
        let rotated = CGSize(
            width: padded.width * cosA + padded.height * sinA,
            height: padded.width * sinA + padded.height * cosA)
        return BakedUserLocationMarkerLayout(
            paddedSize: padded, contentOffset: offset, rotatedSize: rotated)
    }

    /// Bakes the pivot and the heading rotation of one render into its
    /// texture, and returns the texture with the logical size the layer
    /// should scale it to.
    nonisolated static func bakedUserLocationMarker(
        _ render: UserLocationMarkerRender,
        displayScale: CGFloat
    ) -> (image: OSMPlatformImage, size: MarkerIconSize) {
        let image = render.image
        // Content size: the Dart logical size when supplied, else the
        // image's own point size.
        #if os(macOS)
        let intrinsic = image.size
        #else
        let intrinsic = image.size
        #endif
        let content = CGSize(
            width: render.logicalSize.map { CGFloat($0[0]) } ?? intrinsic.width,
            height: render.logicalSize.map { CGFloat($0[1]) } ?? intrinsic.height)
        let anchor = render.anchor
        let layout = bakedUserLocationMarkerLayout(
            logicalSize: content,
            anchorX: anchor.map { Double($0.x) } ?? 0.5,
            anchorY: anchor.map { Double($0.y) } ?? 0.5,
            angleDegrees: render.angleDegrees ?? 0)
        guard let source = PluginImageBaking.cgImage(image) else {
            return (image, (
                x: max(1, Int((layout.rotatedSize.width * displayScale).rounded())),
                y: max(1, Int((layout.rotatedSize.height * displayScale).rounded()))
            ))
        }
        // Compose at source resolution so quality is preserved; the layer
        // scales the whole canvas to `size`. The density follows the LOGICAL
        // content size (not the image's own point size) so the transparent
        // padding keeps its proportion relative to the content.
        let pixelsPerPoint = max(
            CGFloat(source.width) / max(content.width, .ulpOfOne),
            CGFloat(source.height) / max(content.height, .ulpOfOne))
        let baked = PluginImageBaking.padAndRotate(
            source: source,
            pixelsPerPoint: pixelsPerPoint,
            layout: layout,
            angleDegrees: render.angleDegrees ?? 0) ?? image
        return (baked, (
            x: max(1, Int((layout.rotatedSize.width * displayScale).rounded())),
            y: max(1, Int((layout.rotatedSize.height * displayScale).rounded()))
        ))
    }

    /// The framework-facing placeholder used while the plugin owns the
    /// marker: a fully transparent pair, so a framework marker armed before
    /// the takeover disappears on its next refresh and never visibly
    /// rebuilds — without restarting any location consumer.
    nonisolated static func placeholderUserLocationIcons() -> UserLocationConfiguration {
        let placeholder = MarkerConfiguration(
            icon: PluginImageBaking.transparentImage(),
            iconSize: (x: 1, y: 1),
            angle: nil,
            anchor: nil)
        return UserLocationConfiguration(
            userIcon: placeholder, directionIcon: placeholder)
    }

    /// Reserved POI id of the plugin-rendered my-location marker. Static
    /// point ids come from the application, so this prefixed id cannot
    /// collide with them and it is never enumerated by the marker APIs.
    static let userLocationMarkerPoiId = "__osm_user_location_marker__"

    /// One user-location icon resolved for rendering.
    struct UserLocationMarkerIcon {
        let image: OSMPlatformImage
        /// Encoded bytes of the image, used as its identity when deciding
        /// whether the POI layer needs a new icon.
        let pngData: Data
        /// Logical (pre-scale) widget dimensions, if the application
        /// supplied them.
        let logicalSize: [Int]?
        /// Normalized pivot; nil keeps the image's natural (centered) pivot.
        var anchor: MarkerAnchor?
    }

    /// Person + direction icons of the plugin-rendered marker.
    struct UserLocationMarkerIcons {
        var person: UserLocationMarkerIcon
        var direction: UserLocationMarkerIcon
    }

    /// One resolved draw request for the my-location marker. The session's
    /// renderer seam consumes it, which lets tests assert the exact icon,
    /// logical size, pivot, angle and location that would be drawn.
    struct UserLocationMarkerRender {
        let location: CLLocationCoordinate2D
        let image: OSMPlatformImage
        let pngData: Data
        let logicalSize: [Int]?
        let anchor: MarkerAnchor?
        /// Rotation in degrees, clockwise; nil draws the icon unrotated.
        let angleDegrees: Double?
    }

    /// Resolves an applied icon render into the plugin's marker state.
    ///
    /// A nil render (the typed reset route) restores the platform default
    /// icons: the framework's own defaults are private, so the plugin uses
    /// the same system symbols the framework draws.
    ///
    /// A `.preserve` pivot keeps the LIVE pivot: the plugin-owned one once
    /// ownership exists, else the pivot the running tracking arm applied to
    /// the framework markers (every framework pivoting path goes through
    /// this session, so [lastTrackingAnchor] is that live pivot at
    /// takeover). Without either, the icon stays centered like the
    /// framework default.
    func resolvedUserLocationMarkerIcons(
        _ render: UserLocationIconsRender?
    ) -> UserLocationMarkerIcons {
        let current = ownedUserLocationIcons
        guard let render = render else {
            return Self.platformUserLocationMarkerIcons()
        }
        // `.preserve` keeps the live pivot. Once an owned configuration
        // EXISTS, its nil anchor means centered (e.g. after the reset route)
        // and must not fall back to an older pivot: the recorded tracking
        // anchor only seeds the very first configuration, before any owned
        // one exists.
        let seededAnchor = current == nil ? lastTrackingAnchor : nil
        return UserLocationMarkerIcons(
            person: resolvedUserLocationMarkerIcon(
                render.person,
                preservedAnchor: current?.person.anchor ?? seededAnchor),
            direction: resolvedUserLocationMarkerIcon(
                render.direction,
                preservedAnchor: current?.direction.anchor ?? seededAnchor))
    }

    /// The platform default marker icons (red pin, black direction arrow).
    static func platformUserLocationMarkerIcons() -> UserLocationMarkerIcons {
        UserLocationMarkerIcons(
            person: UserLocationMarkerIcon(
                image: ApplePlatformUtilities.systemImage(named: "mappin")
                    ?? OSMPlatformImage(),
                pngData: Data("person".utf8),
                logicalSize: nil,
                anchor: nil),
            direction: UserLocationMarkerIcon(
                image: ApplePlatformUtilities.systemImage(named: "location.north.fill")
                    ?? OSMPlatformImage(),
                pngData: Data("direction".utf8),
                logicalSize: nil,
                anchor: nil))
    }

    /// Resolves one icon's bytes, logical size and pivot.
    private func resolvedUserLocationMarkerIcon(
        _ icon: UserLocationIconRender,
        preservedAnchor: MarkerAnchor?
    ) -> UserLocationMarkerIcon {
        let anchor: MarkerAnchor?
        switch icon.pivot {
        case .preserve:
            // Keep the live pivot: replacing bytes never moves the marker.
            anchor = preservedAnchor
        case .reset:
            // Legacy parity: rebuild the configuration without a pivot.
            anchor = nil
        case .normalized(let x, let y):
            anchor = AnchorGeoPoint(anchor: (x: x, y: y)).compute()
        }
        return UserLocationMarkerIcon(
            image: icon.image,
            pngData: icon.pngData,
            logicalSize: icon.logicalSize,
            anchor: anchor)
    }

    /// Draws the my-location marker for one fix, in place.
    ///
    /// Mirrors the framework's marker semantics: the direction icon is drawn
    /// (rotated by the heading) when rotation is enabled and a heading is
    /// available, or unrotated when the application asked for a direction
    /// marker; the person icon is drawn otherwise.
    func renderOwnedUserLocationMarker(
        location: CLLocationCoordinate2D,
        heading: Double
    ) {
        guard let icons = ownedUserLocationIcons else {
            return
        }
        let rotates = heading != 0 && !trackingDisableMarkerRotation
        let icon = (rotates || trackingUseDirectionMarker) ? icons.direction : icons.person
        userLocationMarkerRenderer(
            UserLocationMarkerRender(
                location: location,
                image: icon.image,
                pngData: icon.pngData,
                logicalSize: icon.logicalSize,
                anchor: icon.anchor,
                angleDegrees: rotates ? heading : nil))
    }

    /// Re-draws the marker at the last known fix; used when the icons, their
    /// pivots or the backing scale change while tracking is armed.
    func refreshOwnedUserLocationMarker() {
        guard ownsUserLocationMarker, let location = latestUserLocation else {
            return
        }
        renderOwnedUserLocationMarker(
            location: location, heading: latestUserLocationHeading)
    }

    /// Removes the plugin-rendered marker.
    func clearOwnedUserLocationMarker() {
        guard ownsUserLocationMarker else {
            return
        }
        userLocationMarkerRenderer(nil)
    }

    /// Re-pivots both icons after a tracking anchor override, keeping the
    /// marker where it is.
    func updateOwnedUserLocationMarkerAnchor(
        x: Double, y: Double
    ) {
        guard var icons = ownedUserLocationIcons else {
            return
        }
        let anchor = AnchorGeoPoint(anchor: (x: x, y: y)).compute()
        icons.person.anchor = anchor
        icons.direction.anchor = anchor
        ownedUserLocationIcons = icons
        // The live pivot: a later icon replacement without an anchor
        // preserves it instead of re-centering.
        lastTrackingAnchor = anchor
        refreshOwnedUserLocationMarker()
    }
}

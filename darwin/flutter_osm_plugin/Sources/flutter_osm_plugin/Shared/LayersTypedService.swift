//
//  LayersTypedService.swift
//  flutter_osm_plugin
//
//  Typed main-actor layer operations on the shared `MapSession`:
//  tile-source selection and overlay visibility. This service is the reuse
//  boundary for the generated Pigeon layers host; the legacy `change#tile`
//  and `toggle#Alllayer` decoding routes through the same functions so both
//  endpoints agree on behavior.
//

import CoreLocation
import Foundation
import OSMFlutterFramework

extension MapSession {

    /// Selects the tile source, mirroring the legacy `change#tile` decoding:
    /// the framework's `CustomTiles` consumes the same legacy-shaped
    /// dictionary the Dart side builds. A nil configuration resets the
    /// default OSM tile layer (the equivalent of the Dart-side
    /// `CustomTile.osm().toMap()` fallback for Apple hosts).
    /// - Note: the framework ignores `maxZoomLevel` for raster templates
    ///   (`as? String` cast against the integer the wire form carries), so
    ///   this service reproduces the legacy wire types byte-for-byte rather
    ///   than silently changing that behavior.
    func typedChangeTile(_ tile: NativeTileConfiguration?) {
        let map: [String: Any]
        if let tile = tile {
            map = Self.legacyTileMap(from: tile)
        } else {
            map = Self.defaultOsmTileMap()
        }
        mapOSM.setCustomTile(tile: CustomTiles(map))
    }

    /// Strips a trailing `/{z}/{x}/{y}` template plus optional extension,
    /// mirroring the legacy Dart regex
    /// `r'/\{z\}/\{x\}/\{y\}(\.[a-zA-Z0-9]+)?/?$'`, and returns the
    /// stripped template together with the embedded extension it carried.
    /// The framework always re-appends the template and the configured
    /// `tileExtension`; forwarding the suffix twice would fetch
    /// `{y}.png.png`. Unlike the legacy strip (which left no trailing slash
    /// and glued the rebuilt suffix onto the path), the stripped template
    /// is normalized to end on `/`: the framework appends `{z}/{x}/{y}`
    /// without a leading slash, so only a trailing slash keeps the rebuilt
    /// suffix a real path segment.
    static func normalizedTemplate(_ url: String) -> (template: String, embeddedExtension: String?) {
        guard let regex = try? NSRegularExpression(pattern: "/\\{z\\}/\\{x\\}/\\{y\\}(\\.[a-zA-Z0-9]+)?/?$") else {
            return (url, nil)
        }
        let range = NSRange(url.startIndex..., in: url)
        guard let match = regex.firstMatch(in: url, range: range),
              let full = Range(match.range, in: url) else {
            return (url, nil)
        }
        var template = String(url[..<full.lowerBound])
        if !template.isEmpty && !template.hasSuffix("/") {
            template += "/"
        }
        let extensionRange = match.range(at: 1)
        let embedded = extensionRange.location != NSNotFound
            ? Range(extensionRange, in: url).map { String(url[$0]) }
            : nil
        return (template, embedded)
    }

    /// Applies a raw legacy `change#tile` payload: same application point
    /// as the generated route, with the historical ignore-on-null behavior
    /// for Apple hosts (Dart substitutes the OSM default map before sending).
    func typedChangeLegacyTileMap(_ map: [String: Any]) {
        mapOSM.setCustomTile(tile: CustomTiles(map))
    }

    /// Builds the legacy-shaped tile dictionary from the generated wire
    /// type. Url templates keep their `{s}` placeholders — the framework
    /// resolves them against the carried subdomains — but a trailing
    /// `{z}/{x}/{y}` template is stripped the same way the legacy Dart
    /// `TileURLs.toMapiOS()` normalizer did, because the framework always
    /// re-appends the template and the configured `tileExtension`. Template
    /// and extension are resolved together so the suffix appears exactly
    /// once: a non-empty configured extension wins (matching legacy, which
    /// stripped a differing embedded one); an empty configured extension
    /// keeps the template's embedded extension, so `…/{z}/{x}/{y}.png`
    /// keeps requesting `.png` tiles instead of losing the suffix
    /// entirely. Templates the legacy regex did not match (different
    /// placeholder order, bare hosts) pass through unchanged.
    static func legacyTileMap(from tile: NativeTileConfiguration) -> [String: Any] {
        // The framework consumes the first url's template only; resolve the
        // effective extension from it together with the configured one.
        let firstNormalized = tile.urls.first.map { Self.normalizedTemplate($0.url) }
        let configuredExtension = tile.tileExtension
        let effectiveExtension: String
        if !configuredExtension.isEmpty {
            effectiveExtension = configuredExtension
        } else if let embedded = firstNormalized?.embeddedExtension {
            effectiveExtension = embedded
        } else {
            effectiveExtension = configuredExtension
        }
        var map: [String: Any] = [
            "name": tile.sourceName,
            "urls": tile.urls.map { server -> [String: Any] in
                var entry: [String: Any] = ["url": Self.normalizedTemplate(server.url).template]
                if !server.subdomains.isEmpty {
                    entry["subdomains"] = server.subdomains
                }
                return entry
            },
            "tileSize": Int(tile.tileSize),
            "tileExtension": effectiveExtension,
            "maxZoomLevel": Int(tile.maxZoomLevel),
            "minZoomLevel": Int(tile.minZoomLevel),
        ]
        if let apiKey = tile.apiKey, let apiValue = tile.apiValue {
            map["api"] = [apiKey: apiValue]
        }
        if let styleURL = tile.styleURL {
            map["styleURL"] = styleURL
            map["isVector"] = true
        }
        return map
    }

    /// The legacy-shaped dictionary Dart sends for `CustomTile.osm()` on
    /// Apple hosts when the tile resets to the default source.
    static func defaultOsmTileMap() -> [String: Any] {
        [
            "name": "mapnik",
            "urls": [
                [
                    "url": "https://{s}.tile.openstreetmap.org/",
                    "subdomains": ["a", "b", "c"],
                ]
            ],
            "tileSize": 256,
            "tileExtension": ".png",
            "maxZoomLevel": 19,
            "minZoomLevel": 2,
        ]
    }

    /// Shows or hides the overlay layers, mirroring the legacy
    /// `toggle#Alllayer` branches.
    func typedSetOverlaysVisible(_ visible: Bool) {
        if visible {
            mapOSM.showAllLayers()
        } else {
            mapOSM.hideAllLayers()
        }
    }
}

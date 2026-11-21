//
//  RoadsTypedService.swift
//  flutter_osm_plugin
//
//  Typed main-actor road operations on the shared `MapSession`: manual
//  road drawing, removal by id and clearing. This service is the reuse
//  boundary for the generated Pigeon roads host — it reproduces exactly
//  what the legacy `drawRoad#manually` / `delete#road` / `clear#roads`
//  handlers applied, including the historical quirks (the border width is
//  pre-added to the road width before the framework adds the road width
//  again, and a missing border color falls back to `#f55b5b`). The legacy
//  handlers keep their raw map decoding and route through the same
//  manager calls. Route fetching/calculation stays asynchronous in Dart —
//  only an already-computed polyline crosses the generated channel.
//

import CoreLocation
import Foundation
import OSMFlutterFramework

extension MapSession {

    /// Draws (or replaces) one road from full-precision coordinates.
    /// `zoomInto` fits the camera to the road, mirroring the legacy
    /// `zoomIntoRegion` behavior. Colors are packed `0xAARRGGBB` ints.
    func typedDrawRoad(
        id: String,
        coordinates: [CLLocationCoordinate2D],
        roadColorArgb: Int64,
        roadWidth: Double,
        borderColorArgb: Int64?,
        borderWidth: Double?,
        dotted: Bool,
        zoomInto: Bool
    ) {
        let configuration = Self.legacyRoadConfiguration(
            roadColorArgb: roadColorArgb,
            roadWidth: roadWidth,
            borderColorArgb: borderColorArgb,
            borderWidth: borderWidth,
            dotted: dotted)
        mapOSM.roadManager.addRoad(
            id: id, polylines: coordinates, configuration: configuration)
        if zoomInto {
            let box = coordinates.toBounds()
            mapOSM.moveToByBoundingBox(bounds: box, animated: true)
        }
    }

    /// Removes one road by id and drops its stored tap metadata; unknown
    /// ids succeed without effect. The legacy `delete#road` handler keeps
    /// the same bookkeeping, so a reused key can never produce stale tap
    /// information from a removed road.
    func typedRemoveRoad(id: String) {
        mapOSM.roadManager.removeRoad(id: id)
        storedRoads.removeValue(forKey: id)
    }

    /// Removes every road and wipes the stored tap metadata, mirroring the
    /// legacy `clear#roads` manager call with synchronized bookkeeping.
    func typedClearRoads() {
        mapOSM.roadManager.removeAllRoads()
        storedRoads.removeAll()
    }

    /// Builds the framework road configuration from the generated wire
    /// style, reproducing the legacy manual-drawing conversion quirks.
    static func legacyRoadConfiguration(
        roadColorArgb: Int64,
        roadWidth: Double,
        borderColorArgb: Int64?,
        borderWidth: Double?,
        dotted: Bool
    ) -> RoadConfiguration {
        RoadConfiguration(
            width: Float(roadWidth),
            color: OSMPlatformColor(hexString: hexString(fromArgb: roadColorArgb)) ?? .blue,
            borderWidth: effectiveBorderWidth(borderWidth, roadWidth: roadWidth),
            borderColor: normalizedBorderColor(borderColorArgb),
            polylineType: dotted ? PolylineType.DOT : PolylineType.LINE)
    }

    /// The legacy serialization omits nonpositive border widths entirely
    /// (`RoadOption.empty()` carries `borderWidth = 0`), so a zero width
    /// draws borderless instead of stroking a road-width border. When
    /// present, the border width pre-adds the road width: the framework's
    /// addRoad adds the road width again when stroking the border line,
    /// reproducing the identical effective width.
    static func effectiveBorderWidth(
        _ borderWidth: Double?, roadWidth: Double
    ) -> CFloat? {
        guard let borderWidth = borderWidth, borderWidth > 0 else { return nil }
        return CFloat(borderWidth + roadWidth)
    }

    /// A missing border color keeps the legacy manual-drawing default
    /// (#f55b5b); the framework only strokes it when a border width exists
    /// and the colors differ.
    static func normalizedBorderColor(_ borderColorArgb: Int64?) -> OSMPlatformColor? {
        borderColorArgb.flatMap {
            OSMPlatformColor(hexString: hexString(fromArgb: $0))
        } ?? OSMPlatformColor(hexString: "#f55b5b")
    }

    /// Packed `0xAARRGGBB` → the legacy `#aarrggbb` hex string the Dart
    /// side sent for Apple hosts (`value.toRadixString(16)`).
    static func hexString(fromArgb argb: Int64) -> String {
        let truncated = UInt32(truncatingIfNeeded: argb)
        return "#\(String(truncated, radix: 16))"
    }
}

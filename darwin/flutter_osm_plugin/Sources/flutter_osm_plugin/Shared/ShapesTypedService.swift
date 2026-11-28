//
//  ShapesTypedService.swift
//  flutter_osm_plugin
//
//  Typed main-actor shape operations on the shared `MapSession` (circles
//  and rectangles). This service is the reuse boundary for the generated
//  Pigeon shapes host: it rebuilds the legacy-shaped dictionaries the
//  framework decoders consume, so the generated route draws exactly what
//  the legacy `draw#circle`/`draw#rect` payloads drew. The legacy handlers
//  keep their raw map decoding and route through the same manager calls.
//

import CoreLocation
import Foundation
import OSMFlutterFramework

extension MapSession {

    /// Draws (or replaces) one circle; `radiusMeters` in meters, colors as
    /// packed `0xAARRGGBB` ints.
    func typedAddCircle(
        id: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
        fillColorArgb: Int64,
        borderColorArgb: Int64?,
        strokeWidth: Double,
    ) {
        let map = Self.legacyShapeMap(
            key: id,
            latitude: latitude,
            longitude: longitude,
            sizeField: "radius",
            sizeMeters: radiusMeters,
            fillColorArgb: fillColorArgb,
            borderColorArgb: borderColorArgb,
            strokeWidth: strokeWidth,
        )
        mapOSM.shapeManager.drawShape(key: id, shape: CircleOSM.fromMap(json: map))
    }

    /// Draws (or replaces) one rectangle; `distanceMeters` is the side span
    /// in meters, colors as packed `0xAARRGGBB` ints.
    func typedAddRectangle(
        id: String,
        latitude: Double,
        longitude: Double,
        distanceMeters: Double,
        fillColorArgb: Int64,
        borderColorArgb: Int64?,
        strokeWidth: Double,
    ) {
        let map = Self.legacyShapeMap(
            key: id,
            latitude: latitude,
            longitude: longitude,
            sizeField: "distance",
            sizeMeters: distanceMeters,
            fillColorArgb: fillColorArgb,
            borderColorArgb: borderColorArgb,
            strokeWidth: strokeWidth,
        )
        mapOSM.shapeManager.drawShape(key: id, shape: RectShapeOSM.fromMap(json: map))
    }

    /// Removes one shape by id; unknown ids succeed without effect.
    func typedRemoveShape(id: String) {
        mapOSM.shapeManager.deleteShape(ckey: id)
    }

    /// Removes every circle, mirroring the keyless legacy `remove#circle`.
    func typedRemoveCircles() {
        mapOSM.shapeManager.deleteAllCircles()
    }

    /// Removes every rectangle, mirroring the keyless legacy `remove#rect`.
    func typedRemoveRectangles() {
        mapOSM.shapeManager.deleteAllRect()
    }

    /// Removes every shape of any kind, mirroring the legacy
    /// `clear#shapes`.
    func typedClearShapes() {
        mapOSM.shapeManager.deleteAllShapes()
    }

    /// Builds the legacy-shaped dictionary the framework decoders consume.
    /// The color lists reproduce the legacy Dart `toARGBList()` order
    /// (red, blue, green, alpha) that `CircleOSM.fromMap` expects; a
    /// missing border color falls back to the fill color, matching the
    /// legacy decoder default.
    static func legacyShapeMap(
        key: String,
        latitude: Double,
        longitude: Double,
        sizeField: String,
        sizeMeters: Double,
        fillColorArgb: Int64,
        borderColorArgb: Int64?,
        strokeWidth: Double,
    ) -> [String: Any] {
        var map: [String: Any] = [
            "key": key,
            "lat": latitude,
            "lon": longitude,
            "color": legacyColorList(fillColorArgb),
            "strokeWidth": strokeWidth,
            sizeField: sizeMeters,
        ]
        if let borderColorArgb = borderColorArgb {
            map["colorBorder"] = legacyColorList(borderColorArgb)
        }
        return map
    }

    /// Packed `0xAARRGGBB` → legacy wire list `[red, blue, green, alpha]`.
    static func legacyColorList(_ argb: Int64) -> [Int] {
        [
            Int((argb >> 16) & 0xFF),
            Int(argb & 0xFF),
            Int((argb >> 8) & 0xFF),
            Int((argb >> 24) & 0xFF),
        ]
    }
}

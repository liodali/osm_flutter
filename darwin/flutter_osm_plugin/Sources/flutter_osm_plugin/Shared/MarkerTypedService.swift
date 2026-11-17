//
//  MarkerTypedService.swift
//  flutter_osm_plugin
//
//  Typed main-actor marker operations on the shared `MapSession`.
//  This service is the reuse boundary for the generated Pigeon markers host
//  and the legacy method decoding: both routes end here, so both agree on
//  behavior and native state.
//
//  Apple identity stays coordinate-based: `MarkerManager` matches markers by
//  location equality. The stable Pigeon marker ids are mapped to coordinates
//  in the session registry (`typedMarkerCoordinates`), so every generated
//  command reuses the same native add/update/remove calls the legacy route
//  performs. Angles cross this boundary in radians (the native unit); the
//  Pigeon bridge converts the degrees of the generated contract.
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

    // MARK: - Stable-id registry helpers

    /// First stable id registered at the exact coordinate, matching the
    /// first-match semantics of `MarkerManager` updates and removals.
    /// Resolved through the explicit insertion-order list: dictionary
    /// iteration order is unspecified and can disagree with the native
    /// markers array.
    func typedMarkerId(at coordinate: CLLocationCoordinate2D) -> String? {
        typedMarkerOrder.first { id in
            let markerCoordinate = typedMarkerCoordinates[id]
            return markerCoordinate?.latitude == coordinate.latitude
                && markerCoordinate?.longitude == coordinate.longitude
        }
    }

    /// Every stable id registered at the exact coordinate (duplicate adds are
    /// allowed, so one coordinate can hold several markers).
    func typedMarkerIds(at coordinate: CLLocationCoordinate2D) -> [String] {
        typedMarkerCoordinates
            .filter { _, markerCoordinate in
                markerCoordinate.latitude == coordinate.latitude
                    && markerCoordinate.longitude == coordinate.longitude
            }
            .map { $0.key }
    }

    /// Registers a stable id with its coordinate in both structures.
    private func registerTypedMarker(id: String, coordinate: CLLocationCoordinate2D) {
        typedMarkerCoordinates[id] = coordinate
        typedMarkerOrder.append(id)
    }

    /// Drops a stable id from both registry structures.
    private func unregisterTypedMarker(id: String) {
        typedMarkerCoordinates.removeValue(forKey: id)
        typedMarkerOrder.removeAll { $0 == id }
    }

    /// The app-configured default icon (bundled pin), matching the legacy
    /// fallback chain of `addMarkerManually`.
    func typedDefaultMarkerIcon() -> OSMPlatformImage {
        if let defaultMarker = defaultMarker,
            let bundled = ApplePlatformUtilities.bundledImage(named: defaultMarker) {
            return bundled
        }
        if let system = ApplePlatformUtilities.systemImage(named: "mappin") {
            return system
        }
        return OSMPlatformImage()
    }

    // MARK: - Regular markers

    /// Adds one marker under a stable id. Reuses the native `addMarker` call
    /// and the coordinate-keyed scale records used by the legacy route.
    /// `logicalSize` carries pre-scale widget dimensions; the pixel
    /// `MarkerIconSize` is derived with the current display scale exactly
    /// like the legacy route. Returns false when the id is already
    /// registered or the coordinate already holds a different marker the
    /// native layer cannot disambiguate.
    func typedAddMarker(
        id: String,
        coordinate: CLLocationCoordinate2D,
        icon: OSMPlatformImage?,
        logicalSize: [Int]?,
        angleRadians: Float,
        anchor: MarkerAnchor?,
        iconBase64ForScaleRefresh: String?
    ) -> Bool {
        guard typedMarkerCoordinates[id] == nil else {
            return false
        }
        let resolvedIcon = icon ?? typedDefaultMarkerIcon()
        let configuration = MarkerConfiguration(
            icon: resolvedIcon,
            iconSize: logicalSize?.toMarkerSize(
                displayScale: ApplePlatformUtilities.displayScale(for: mapOSM)),
            angle: angleRadians,
            anchor: anchor,
            scaleType: MarkerScaleType.invariant)
        mapOSM.markerManager.addMarker(marker: Marker(
            location: coordinate, markerConfiguration: configuration))
        registerTypedMarker(id: id, coordinate: coordinate)
        #if os(macOS)
        recordMarkerScale(
            coordinate: coordinate,
            iconBase64: iconBase64ForScaleRefresh,
            logicalSize: logicalSize,
            angle: angleRadians,
            anchorArgs: anchor.map { ["x": $0.x, "y": $0.y] })
        #endif
        return true
    }

    /// Bulk-adds default-icon markers. Ids must be unique and unknown to the
    /// registry; coordinates arrive as flat [lat, lon] pairs. Returns false
    /// (without partial application) when any precondition fails.
    func typedAddMarkers(
        ids: [String],
        flatCoordinates: [Double],
        logicalSize: [Int]?
    ) -> Bool {
        guard !ids.isEmpty, flatCoordinates.count == ids.count * 2 else {
            return false
        }
        guard Set(ids).count == ids.count else {
            return false
        }
        guard ids.allSatisfy({ typedMarkerCoordinates[$0] == nil }) else {
            return false
        }
        let icon = typedDefaultMarkerIcon()
        var addedIds: [String] = []
        for (index, id) in ids.enumerated() {
            let coordinate = CLLocationCoordinate2D(
                latitude: flatCoordinates[index * 2],
                longitude: flatCoordinates[index * 2 + 1])
            if !typedAddMarker(
                id: id,
                coordinate: coordinate,
                icon: icon,
                logicalSize: logicalSize,
                angleRadians: 0,
                anchor: nil,
                iconBase64ForScaleRefresh: nil)
            {
                // Roll back the markers applied so far.
                for rolledBack in addedIds {
                    typedRemoveMarker(id: rolledBack)
                }
                return false
            }
            addedIds.append(id)
        }
        return true
    }

    /// Replaces one marker's icon. Returns false when the id is unknown or
    /// the coordinate holds several markers the native layer cannot
    /// disambiguate (updates always hit the first match).
    func typedUpdateMarkerIcon(
        id: String,
        icon: OSMPlatformImage,
        logicalSize: [Int]?,
        iconBase64ForScaleRefresh: String?
    ) -> Bool {
        guard let coordinate = unambiguousTypedCoordinate(id: id) else {
            return false
        }
        mapOSM.markerManager.updateMarker(
            oldlocation: coordinate, newlocation: coordinate,
            icon: icon,
            iconSize: logicalSize?.toMarkerSize(
                displayScale: ApplePlatformUtilities.displayScale(for: mapOSM)))
        #if os(macOS)
        updateMarkerScaleRecord(
            at: coordinate,
            iconBase64: iconBase64ForScaleRefresh,
            logicalSize: logicalSize)
        #endif
        return true
    }

    /// Combined legacy change: one native update call that moves the marker
    /// and applies the partial configuration in the same pass, then updates
    /// the registry and scale record. Resolves the id by coordinate, keeping
    /// the legacy route coordinate-addressed. Returns false when no marker
    /// is registered at `oldCoordinate`.
    func typedChangeMarker(
        at oldCoordinate: CLLocationCoordinate2D,
        to newCoordinate: CLLocationCoordinate2D,
        icon: OSMPlatformImage?,
        iconSize: MarkerIconSize?,
        angleRadians: Float?,
        anchor: MarkerAnchor?,
        iconBase64ForScaleRefresh: String?,
        logicalSizeForScaleRefresh: [Int]?
    ) -> Bool {
        guard let id = typedMarkerId(at: oldCoordinate) else {
            return false
        }
        mapOSM.markerManager.updateMarker(
            oldlocation: oldCoordinate, newlocation: newCoordinate,
            icon: icon, iconSize: iconSize, angle: angleRadians, anchor: anchor)
        typedMarkerCoordinates[id] = newCoordinate
        #if os(macOS)
        moveMarkerScaleRecord(
            from: oldCoordinate, to: newCoordinate,
            iconBase64: iconBase64ForScaleRefresh,
            logicalSize: logicalSizeForScaleRefresh,
            angle: angleRadians ?? markerScaleRecordAngle(at: oldCoordinate) ?? 0,
            // nil anchorArgs keeps the previously recorded anchor (legacy
            // change without an anchor argument keeps the native one); a
            // newly applied anchor must replace the cached one or a scale
            // refresh would revert it.
            anchorArgs: anchor.map { ["x": $0.x, "y": $0.y] })
        #endif
        return true
    }

    /// Moves one marker. Returns false when the id is unknown or its
    /// coordinate holds several markers the native layer cannot
    /// disambiguate (updates always hit the first match).
    func typedMoveMarker(id: String, to newCoordinate: CLLocationCoordinate2D) -> Bool {
        guard let oldCoordinate = unambiguousTypedCoordinate(id: id) else {
            return false
        }
        // A nil configuration keeps the current icon, size, angle and anchor;
        // only the location changes.
        mapOSM.markerManager.updateMarker(
            oldlocation: oldCoordinate, newlocation: newCoordinate,
            icon: nil, iconSize: nil)
        typedMarkerCoordinates[id] = newCoordinate
        #if os(macOS)
        moveMarkerScaleRecord(
            from: oldCoordinate, to: newCoordinate,
            iconBase64: nil, logicalSize: nil,
            angle: markerScaleRecordAngle(at: oldCoordinate) ?? 0,
            anchorArgs: nil)
        #endif
        return true
    }

    /// Replaces one marker's icon rotation. Returns false when the id is
    /// unknown or ambiguous (see `unambiguousTypedCoordinate`).
    func typedRotateMarker(id: String, angleRadians: Float) -> Bool {
        guard let coordinate = unambiguousTypedCoordinate(id: id) else {
            return false
        }
        mapOSM.markerManager.updateMarker(
            oldlocation: coordinate, newlocation: coordinate,
            icon: nil, iconSize: nil, angle: angleRadians)
        #if os(macOS)
        updateMarkerAngleScaleRecord(at: coordinate, angle: angleRadians)
        #endif
        return true
    }

    /// Replaces one marker's icon anchor. Returns false when the id is
    /// unknown or ambiguous (see `unambiguousTypedCoordinate`).
    func typedSetMarkerAnchor(id: String, anchor: MarkerAnchor) -> Bool {
        guard let coordinate = unambiguousTypedCoordinate(id: id) else {
            return false
        }
        mapOSM.markerManager.updateMarker(
            oldlocation: coordinate, newlocation: coordinate,
            icon: nil, iconSize: nil, anchor: anchor)
        #if os(macOS)
        updateMarkerAnchorScaleRecord(at: coordinate, anchor: anchor)
        #endif
        return true
    }

    /// Removes one marker. Returns false when the id is unknown or its
    /// coordinate holds several markers: native removal matches the first
    /// marker at a location, so removing a non-primary duplicate would
    /// delete the wrong marker.
    func typedRemoveMarker(id: String) -> Bool {
        guard let coordinate = unambiguousTypedCoordinate(id: id) else {
            return false
        }
        mapOSM.markerManager.removeMarker(location: coordinate)
        unregisterTypedMarker(id: id)
        #if os(macOS)
        removeMarkerScaleRecord(at: coordinate)
        #endif
        return true
    }

    /// Removes many markers. Unknown ids or ambiguous targets (multiple ids
    /// on one coordinate with only part of them removed) fail the whole
    /// command (all-or-nothing, matching the generated contract) without
    /// side effects.
    func typedRemoveMarkers(ids: [String]) -> Bool {
        guard ids.allSatisfy({ typedMarkerCoordinates[$0] != nil }) else {
            return false
        }
        // Group removal per coordinate: removing all ids of a shared
        // coordinate is unambiguous; a partial subset would let native
        // first-match removal delete the wrong marker.
        var removedIdsByCoordinate: [String: Int] = [:]
        for id in ids {
            let key = Self.typedCoordinateKey(typedMarkerCoordinates[id]!)
            removedIdsByCoordinate[key, default: 0] += 1
        }
        for (key, removedCount) in removedIdsByCoordinate {
            guard let coordinate = Self.coordinateForKey(key),
                typedMarkerIds(at: coordinate).count == removedCount else {
                return false
            }
        }
        let coordinates = ids.map { typedMarkerCoordinates[$0]! }
        mapOSM.markerManager.removeMarkers(locations: coordinates)
        ids.forEach { unregisterTypedMarker(id: $0) }
        #if os(macOS)
        coordinates.forEach { removeMarkerScaleRecord(at: $0) }
        #endif
        return true
    }

    /// Resolves a stable id to its coordinate only when the coordinate is
    /// unambiguous: the native manager mutates the first marker found at a
    /// location, so a non-primary duplicate would mutate a different marker
    /// while the registry claimed the requested one.
    private func unambiguousTypedCoordinate(id: String) -> CLLocationCoordinate2D? {
        guard let coordinate = typedMarkerCoordinates[id] else {
            return nil
        }
        guard typedMarkerId(at: coordinate) == id else {
            return nil
        }
        return coordinate
    }

    private static func typedCoordinateKey(_ coordinate: CLLocationCoordinate2D) -> String {
        "\(coordinate.latitude);\(coordinate.longitude)"
    }

    private static func coordinateForKey(_ key: String) -> CLLocationCoordinate2D? {
        let parts = key.split(separator: ";")
        guard parts.count == 2,
            let lat = Double(parts[0]), let lon = Double(parts[1]) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // MARK: - Static-position groups

    /// Creates or replaces a static-position group. The icon configuration
    /// must exist before the positions (`Poi.setMarkers` is a no-op for an
    /// unknown group), but the framework recreates positions with its
    /// immutable original icon configuration — so the requested icon is
    /// reapplied after the positions, matching the legacy workaround.
    /// Returns false when the coordinates are not flat
    /// [lat, lon, angleRadians] triples.
    func typedSetStaticPositions(
        groupId: String,
        flatCoordinates: [Double],
        icon: OSMPlatformImage?,
        logicalSize: [Int]?,
        iconBase64ForScaleRefresh: String?
    ) -> Bool {
        guard !flatCoordinates.isEmpty, flatCoordinates.count % 3 == 0 else {
            return false
        }
        let resolvedIcon = icon ?? typedDefaultMarkerIcon()
        let pixelSize = logicalSize?.toMarkerSize(
            displayScale: ApplePlatformUtilities.displayScale(for: mapOSM))
        // Create the POI (setMarkersPoi is a no-op for unknown groups).
        mapOSM.poisManager.setOrCreateIconPoi(
            id: groupId, icon: resolvedIcon, iconSize: pixelSize)
        let pois = stride(from: 0, to: flatCoordinates.count, by: 3).map {
            index -> MarkerIconPoi in
            MarkerIconPoi(
                location: CLLocationCoordinate2D(
                    latitude: flatCoordinates[index],
                    longitude: flatCoordinates[index + 1]),
                angle: Float(flatCoordinates[index + 2]),
                anchor: nil)
        }
        mapOSM.poisManager.setMarkersPoi(id: groupId, markers: pois)
        // `Poi.setMarkers` recreated every position from the immutable
        // original icon configuration; reapply the requested icon in place.
        mapOSM.poisManager.setOrCreateIconPoi(
            id: groupId, icon: resolvedIcon, iconSize: pixelSize)
        #if os(macOS)
        if let iconBase64 = iconBase64ForScaleRefresh {
            // The refresh path rebuilds the legacy call as
            // ["id": id, "bitmap": stored], so the record holds the bitmap
            // payload alone. Unknown dimensions stay absent: a missing size
            // falls back to the framework texture, while an empty array
            // would crash `toMarkerSize` on scale changes.
            var iconPayload: [String: Any] = ["icon": iconBase64]
            if let logicalSize = logicalSize {
                iconPayload["size"] = logicalSize
            }
            recordStaticPoiIcon(id: groupId, bitmapArgs: iconPayload)
        } else {
            // Keep (or fall back to) the default-pin icon; stale recorded
            // arguments would override it during scale refreshes.
            clearStaticPoiIcon(id: groupId)
        }
        #endif
        return true
    }

    /// Removes one static-position group. Idempotent for unknown groups.
    func typedRemoveStaticPositions(groupId: String) {
        mapOSM.poisManager.clearMarkersPoi(id: groupId, markers: [])
        #if os(macOS)
        clearStaticPoiIcon(id: groupId)
        #endif
    }
}

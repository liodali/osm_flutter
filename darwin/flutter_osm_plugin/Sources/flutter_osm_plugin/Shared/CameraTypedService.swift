//
//  CameraTypedService.swift
//  flutter_osm_plugin
//
//  Typed main-actor camera operations on the shared `MapSession`.
//  This service is the reuse boundary for the generated Pigeon camera host;
//  legacy method decoding routes through the same functions (C2) so both
//  endpoints agree on behavior.
//

import CoreLocation
import Foundation
import OSMFlutterFramework

extension MapSession {

    /// Current absolute zoom level (last applied, not an animation target).
    func typedZoom() -> Double {
        Double(mapOSM.zoom())
    }

    /// Sets an absolute zoom level. `animated` is accepted for schema parity;
    /// OSMView's absolute zoom setter applies immediately (same as the
    /// legacy absolute `zoomLevel` branch).
    func typedSetZoom(_ zoom: Double, animated: Bool) {
        mapOSM.setZoom(zoom: Int(zoom))
    }

    /// Moves the camera center, preserving the legacy zoom-retention and
    /// init-zoom fallback semantics.
    func typedMoveTo(latitude: Double, longitude: Double, animated: Bool) {
        var currentZoom = mapOSM.zoom()
        if currentZoom == 0 || !mapInitialized {
            currentZoom = zoomConfig.initZoom
        }
        mapOSM.moveTo(
            location: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            zoom: currentZoom,
            animated: animated)
    }

    /// Sets the map rotation in degrees, clockwise. OSMView's rotation has
    /// no animation flag; `animated` is accepted for schema parity and maps
    /// to the immediate native call.
    func typedSetRotation(_ angle: Double, animated: Bool) {
        mapOSM.setRotation(angle: angle)
        lastAppliedRotation = angle
    }

    /// Rotation previously applied through this session.
    func typedRotation() -> Double {
        lastAppliedRotation
    }

    /// Full camera snapshot: center coordinates, absolute zoom and rotation.
    /// Returns nil when the map view cannot provide its center yet.
    func typedCameraPosition() -> (
        latitude: Double, longitude: Double, zoom: Double, rotation: Double
    )? {
        let center = mapOSM.center()
        return (
            latitude: center.latitude,
            longitude: center.longitude,
            zoom: Double(mapOSM.zoom()),
            rotation: lastAppliedRotation
        )
    }

    // MARK: - Bounds and zoom configuration

    /// Visible-region bounding box in degrees; nil when the view cannot
    /// provide its visible box yet.
    func typedBounds() -> (
        north: Double, south: Double, east: Double, west: Double
    )? {
        let box = mapOSM.getBoundingBox()
        return (
            north: box.north, south: box.south, east: box.east, west: box.west
        )
    }

    /// Moves/animates the viewport to fit the degree bounding box. The
    /// legacy Apple route ignored the pixel padding (the framework has no
    /// padding parameter), so it is accepted for schema parity and unused.
    func typedZoomToBoundingBox(
        north: Double, south: Double, east: Double, west: Double,
        paddingInPixel: Int
    ) {
        let boundingBox = BoundingBox(
            north: north, west: west, east: east, south: south)
        mapOSM.moveToByBoundingBox(bounds: boundingBox, animated: true)
    }

    /// Restricts the camera to the degree bounding box area.
    func typedSetBoundsLimit(
        north: Double, east: Double, south: Double, west: Double
    ) {
        // Legacy list order: [north, east, south, west].
        mapOSM.setBoundingBox(bounds: BoundingBox(boundingBoxs: [
            north, east, south, west,
        ]))
    }

    /// Removes the camera area limit, restoring the world view.
    func typedRemoveBoundsLimit() {
        mapOSM.setBoundingBox(bounds: BoundingBox())
    }

    /// Applies the zoom configuration (OSM zoom levels), matching the
    /// legacy `config#Zoom` decode.
    func typedConfigureZoom(
        initZoom: Double, minZoomLevel: Double, maxZoomLevel: Double,
        stepZoom: Double
    ) {
        zoomConfig = ZoomConfiguration([
            "initZoom": Int(initZoom),
            "minZoomLevel": Int(minZoomLevel),
            "maxZoomLevel": Int(maxZoomLevel),
            "stepZoom": Int(stepZoom),
        ])
    }
}

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
}

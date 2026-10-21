//
//  MapDelegateProxy.swift
//  flutter_osm_plugin
//

import CoreLocation
import Foundation
@preconcurrency import OSMFlutterFramework

/// Weak-forwarding proxy for the framework delegate connections the map view
/// retains strongly.
///
/// iOS `FlutterPlatformView` has no dispose callback, so teardown relies on
/// `MapSession.deinit` running once Flutter drops the platform-view wrapper.
/// The map view's five delegate properties hold their target strongly, which
/// would keep the session (and through it the map) alive forever; routing them
/// through this proxy removes that session <-> map retain cycle.
///
/// Some framework delegate requirements are nonisolated, so every witness hops
/// to the main queue before touching the session (mirroring how the session
/// itself implements these callbacks); the FIFO queue preserves event order.
@MainActor
final class MapDelegateProxy: NSObject, OnMapGesture, OnMapMoved, MapMarkerHandler,
    OSMUserLocationHandler, PoylineHandler
{

    private weak var session: MapSession?

    init(session: MapSession) {
        self.session = session
        super.init()
    }

    nonisolated func onSingleTap(location: CLLocationCoordinate2D) {
        DispatchQueue.main.async {
            self.session?.onSingleTap(location: location)
        }
    }

    nonisolated func onLongTap(location: CLLocationCoordinate2D) {
        DispatchQueue.main.async {
            self.session?.onLongTap(location: location)
        }
    }

    nonisolated func onMove(center: CLLocationCoordinate2D, bounds: BoundingBox, zoom: Double) {
        let coordinates = [bounds.north, bounds.east, bounds.south, bounds.west]
        DispatchQueue.main.async {
            self.session?.onMove(
                center: center, bounds: BoundingBox(boundingBoxs: coordinates), zoom: zoom)
        }
    }

    nonisolated func onRotate(angle: Double) {
        DispatchQueue.main.async {
            self.session?.onRotate(angle: angle)
        }
    }

    nonisolated func onMapInteraction() {
        DispatchQueue.main.async {
            self.session?.onMapInteraction()
        }
    }

    nonisolated func onMarkerSingleTap(location: CLLocationCoordinate2D) {
        DispatchQueue.main.async {
            self.session?.onMarkerSingleTap(location: location)
        }
    }

    nonisolated func onMarkerLongPress(location: CLLocationCoordinate2D) {
        DispatchQueue.main.async {
            self.session?.onMarkerLongPress(location: location)
        }
    }

    nonisolated func locationChanged(userLocation: CLLocationCoordinate2D, heading: Double) {
        DispatchQueue.main.async {
            self.session?.locationChanged(userLocation: userLocation, heading: heading)
        }
    }

    nonisolated func handlePermission(state: LocationPermission) {
        let granted = state == .Granted
        DispatchQueue.main.async {
            self.session?.handlePermission(state: granted ? .Granted : .NotGranted)
        }
    }

    nonisolated func onTap(roadId: String) {
        DispatchQueue.main.async {
            self.session?.onTap(roadId: roadId)
        }
    }
}

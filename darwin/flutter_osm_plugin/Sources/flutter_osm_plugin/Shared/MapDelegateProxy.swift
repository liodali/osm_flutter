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
/// The framework protocols are nonisolated requirements, so every witness hops
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

    func onSingleTap(location: CLLocationCoordinate2D) {
        DispatchQueue.main.async {
            self.session?.onSingleTap(location: location)
        }
    }

    func onLongTap(location: CLLocationCoordinate2D) {
        DispatchQueue.main.async {
            self.session?.onLongTap(location: location)
        }
    }

    func onMove(center: CLLocationCoordinate2D, bounds: BoundingBox, zoom: Double) {
        DispatchQueue.main.async {
            self.session?.onMove(center: center, bounds: bounds, zoom: zoom)
        }
    }

    func onRotate(angle: Double) {
        DispatchQueue.main.async {
            self.session?.onRotate(angle: angle)
        }
    }

    func onMapInteraction() {
        DispatchQueue.main.async {
            self.session?.onMapInteraction()
        }
    }

    func onMarkerSingleTap(location: CLLocationCoordinate2D) {
        DispatchQueue.main.async {
            self.session?.onMarkerSingleTap(location: location)
        }
    }

    func onMarkerLongPress(location: CLLocationCoordinate2D) {
        DispatchQueue.main.async {
            self.session?.onMarkerLongPress(location: location)
        }
    }

    func locationChanged(userLocation: CLLocationCoordinate2D, heading: Double) {
        DispatchQueue.main.async {
            self.session?.locationChanged(userLocation: userLocation, heading: heading)
        }
    }

    func handlePermission(state: LocationPermission) {
        DispatchQueue.main.async {
            self.session?.handlePermission(state: state)
        }
    }

    func onTap(roadId: String) {
        DispatchQueue.main.async {
            self.session?.onTap(roadId: roadId)
        }
    }
}

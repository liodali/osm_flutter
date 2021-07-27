//
// Created by Dali on 5/11/21.
//

import Foundation
import TangramMap


extension GeoPointMap {
    public func setupMarker(
             on map: TGMapView
    ) -> TGMarker {

        marker = map.markerAdd()
        marker?.icon = markerIcon!
        marker?.stylingString = styleMarker
        marker?.point = coordinate

        marker?.visible = true
        return marker!
    }

    public func toMap() -> GeoPoint {
        ["lat": self.coordinate.latitude, "lon": coordinate.longitude]
    }
}

extension TGMapView {
    func addUserLocation(for userLocation: CLLocationCoordinate2D, on map: TGMapView) -> MyLocationMarker {
        let userLocationMarker = MyLocationMarker(coordinate: userLocation)

        userLocationMarker.marker = map.markerAdd()
        userLocationMarker.marker!.point = userLocationMarker.coordinate
        userLocationMarker.marker!.stylingString = userLocationMarker.styleMarker
        userLocationMarker.marker!.visible = true
        return userLocationMarker
    }

    func flyToUserLocation(for location: CLLocationCoordinate2D) {
        let cameraOption = TGCameraPosition(center: location, zoom: self.zoom, bearing: self.bearing, pitch: self.pitch)
        self.fly(to: cameraOption!, withSpeed: 50)
    }

    func removeUserLocation(for marker: TGMarker) {
        self.markerRemove(marker)
    }
}


extension StaticGeoPMarker {
    public func addStaticGeosToMapView(
            for annotation: StaticGeoPMarker, on map: TGMapView
    ) -> StaticGeoPMarker {
        annotation.marker = map.markerAdd()
        if (annotation.markerIcon != nil) {
            annotation.marker?.icon = annotation.markerIcon!
        }
        annotation.marker?.stylingString = annotation.styleMarker
        annotation.marker?.point = annotation.coordinate

        var isVisible:Bool = false
        if map.zoom > 12.0 {
              isVisible = true
        }
        annotation.marker?.visible = isVisible
        return annotation

    }
}

extension GeoPoint {
    func toLocationCoordinate() -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: self["lat"]!, longitude: self["lon"]!)
    }
}

extension RoadInformation {
    func toMap() -> [String: Double] {
        ["distance": self.distance, "duration": self.seconds]
    }
}

extension Array where Element == Int {
    func toUIColor() -> UIColor {
        UIColor.init(absoluteRed: self.first!, green: self.last!, blue: self[1], alpha: 255)
    }
}
extension CLLocationCoordinate2D: Equatable {
    static public func ==(lhs: Self, rhs: Self) -> Bool {
         lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
extension CLLocationCoordinate2D {
    func toGeoPoint() -> GeoPoint {
         ["lat":latitude,"lon":longitude]
    }
}

extension UIColor {

    /// Create color from RGB(A)
    ///
    /// Parameters:
    ///  - absoluteRed: Red value (between 0 - 255)
    ///  - green:       Green value (between 0 - 255)
    ///  - blue:        Blue value (between 0 - 255)
    ///  - alpha:       Blue value (between 0 - 255)
    ///
    /// Returns: UIColor instance.
    convenience init(absoluteRed red: Int, green: Int, blue: Int, alpha: Int = 255) {
        let normalizedRed = CGFloat(red) / 255.0
        let normalizedGreen = CGFloat(green) / 255.0
        let normalizedBlue = CGFloat(blue) / 255.0
        let normalizedAlpha = CGFloat(alpha) / 255.0

        self.init(
                red: normalizedRed,
                green: normalizedGreen,
                blue: normalizedBlue,
                alpha: normalizedAlpha
        )
    }
}
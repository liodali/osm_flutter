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
    public func changeIconMarker(on map:TGMapView) {
      let indexToUpdate =  map.markers.firstIndex { m in
            m.point == self.coordinate
        }
        if indexToUpdate != nil {
            map.markers[indexToUpdate!].icon = markerIcon!
        }
    }

    public func toMap() -> GeoPoint {
        ["lat": self.coordinate.latitude, "lon": coordinate.longitude]
    }
}

extension TGMapView {
    func addUserLocation(for userLocation: CLLocationCoordinate2D, on map: TGMapView,
                         userLocationMarkerType: UserLocationMarkerType = UserLocationMarkerType.person) -> MyLocationMarker {
        let userLocationMarker = MyLocationMarker(coordinate: userLocation,
                userLocationMarkerType: userLocationMarkerType)

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
    func removeMarkers(markers:[TGMarker]){
        for marker in markers {
            self.markerRemove(marker)
        }
    }
}

extension MyLocationMarker {
    func setDirectionArrow(personIcon: UIImage?, arrowDirection: UIImage?) {
        self.personIcon = personIcon
        arrowDirectionIcon = arrowDirection
        var iconM: UIImage? = nil
        if (arrowDirectionIcon == nil && personIcon == nil) {
            switch (self.userLocationMarkerType) {
            case .person:
                self.marker?.stylingString = "{ \(MyLocationMarker.personStyle) , angle: \(self.angle) } "
                break;
            case .arrow:
                self.marker?.stylingString = "{ \(MyLocationMarker.arrowStyle) , angle: \(angle)  } "
                break;
            }
        } else {
            if (arrowDirectionIcon != nil && self.personIcon == nil) {
                iconM = arrowDirectionIcon
            } else if (arrowDirectionIcon == nil && self.personIcon != nil) {
                iconM = self.personIcon
            } else {
                switch (userLocationMarkerType) {
                case .person:
                    iconM = self.personIcon
                    break;
                case .arrow:
                    iconM = arrowDirectionIcon
                    break;
                }
            }
            marker?.icon = iconM!
            marker?.stylingString = " { style: 'points', interactive: \(interactive),color: 'white',size: \(size)px, order: 1000, collide: false , angle : \(angle) } "
        }
    }

    func rotateMarker(angle: Int) {
        userLocationMarkerType = UserLocationMarkerType.arrow
        self.angle = angle
        if (arrowDirectionIcon == nil || personIcon == nil) {
            switch (userLocationMarkerType) {
            case .person:
                self.marker?.stylingString = "{ \(MyLocationMarker.personStyle) , angle: \(self.angle) } "
                break;
            case .arrow:
                self.marker?.stylingString = "{ \(MyLocationMarker.arrowStyle) , angle: \(self.angle)  } "
                break;
            }
        } else {
            self.marker?.stylingString = "{ style: 'points', interactive: \(interactive),color: 'white',size: \(size)px, order: 1000, collide: false , angle: \(angle)  } "
        }
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

        var isVisible: Bool = false
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
    func toMap() -> [String: Any] {
        ["distance": self.distance, "duration": self.seconds, "routePoints": self.encodedRoute]
    }
}

extension Array where Element == Int {
    func toUIColor() -> UIColor {
        UIColor.init(absoluteRed: self.first!, green: self.last!, blue: self[1], alpha: 255)
    }
}
extension  Array where Element == GeoPoint {
    func parseToPath() -> [String] {

        self.map { point -> String in
            let wayP = String(format: "%F,%F", point["lon"]!, point["lat"]!)
            return wayP
        }
    }
}

extension CLLocationCoordinate2D: Equatable {
    static public func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

extension CLLocationCoordinate2D {
    func toGeoPoint() -> GeoPoint {
        ["lat": latitude, "lon": longitude]
    }
}

extension UIImage {
    func rotate(radians: Float) -> UIImage {
        var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!

        // Move origin to middle
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width / 2, y: -self.size.height / 2, width: self.size.width, height: self.size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage ?? self
    }
}
extension String {
    var toRoadType: RoadType {
        switch self {
        case "car":
            return RoadType.car
        case "foot":
            return RoadType.foot
        case "bike":
          return   RoadType.bike
        default:
           return  RoadType.car
        }
    }
}
extension CGFloat {
    var toRadians: CGFloat {
        self * .pi / 180
    }
    var toDegrees: CGFloat {
        self * 180 / .pi
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

extension TGMapView {
    func getBounds(width: CGFloat, height: CGFloat) -> [String: Double] {
        let rect = bounds
        let size = CGPoint(x: width - (rect.minX - rect.maxX), y: height - (rect.minY - rect.maxY))
        if size == CGPoint(x: 0.0, y: 0.0) {
            return ["north": 0.0, "east": 0.0, "south": 0.0, "west": 0.0]
        }
        var positions = [CLLocationCoordinate2D]()
        positions.append(self.coordinate(fromViewPosition: CGPoint(x: rect.minX, y: rect.minY)))
        positions.append(self.coordinate(fromViewPosition: CGPoint(x: rect.minX + size.x, y: rect.minY)))
        positions.append(self.coordinate(fromViewPosition: CGPoint(x: rect.minX, y: rect.minY + size.y)))
        positions.append(self.coordinate(fromViewPosition: CGPoint(x: rect.minX + size.x, y: rect.minY + size.y)))

        var latMin: Double? = nil, latMax: Double? = nil, lonMin: Double? = nil, lonMax: Double? = nil
        for item in positions {
            let lat = Double(item.latitude)
            let lon = Double(item.longitude)
            if latMin == nil || latMin! < lat {
                latMin = lat
            }
            if latMax == nil || latMax! > lat {
                latMax = lat
            }
            if lonMin == nil || lonMin! < lon {
                lonMin = lon
            }
            if lonMax == nil || lonMax! > lon {
                lonMax = lon
            }
        }

        return ["north": latMin ?? 0.0, "east": lonMin ?? 0.0, "south": latMax ?? 0.0, "west": lonMax ?? 0.0]
    }
}

extension Array where Element == CLLocationCoordinate2D {
    func toBounds() -> TGCoordinateBounds {
        var maxLat = -85.0
        var maxLon = -180.0
        var minLat = 85.0
        var minLon = 180.0
        let locations = self
        for location in locations {
            let lat = location.latitude
            let lon = location.longitude

            minLat = Swift.min(minLat, lat)
            minLon = Swift.min(minLon, lon)
            maxLat = Swift.max(maxLat, lat)
            maxLon = Swift.max(maxLon, lon)
        }
       return  TGCoordinateBounds(sw: CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
                ne: CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon))
    }
}
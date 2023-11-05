//
// Created by Dali on 5/11/21.
//

import Foundation
import TangramMap


extension GeoPointMap {
    public func setupMarker(
            on map: TGMapView
    ) -> TGMarker {

        self.marker = map.markerAdd()
        self.marker?.icon = markerIcon.image!
        self.marker?.stylingString = self.markerStyle.toString() //styleMarker
        self.marker?.point = coordinate

        self.marker?.visible = true
        return self.marker!
    }

    public func changeIconMarker(on map: TGMapView) {
        let indexToUpdate = map.markers.firstIndex { m in
            m.point == self.coordinate
        }
        if indexToUpdate != nil {
            map.markers[indexToUpdate!].icon = markerIcon.image!
        }
    }

    public func changePositionMarker(on map: TGMapView, mPosition: CLLocationCoordinate2D) {
        let indexToUpdate = map.markers.firstIndex { m in
            return  m.point == self.coordinate
        }
        if indexToUpdate != nil {
            let oldStyleMarker = map.markers[indexToUpdate!].stylingString
            markerStyle.copyFromOldStyle(oldMarkerStyleStr: oldStyleMarker)
            let markerStyleStr = markerStyle.toString()
            map.markers[indexToUpdate!].stylingString = markerStyleStr
            map.markers[indexToUpdate!].point = mPosition
        }
    }

    public func toMap() -> GeoPoint {
        ["lat": self.coordinate.latitude, "lon": coordinate.longitude]
    }
}

extension TGMapView {
    func addUserLocation(for userLocation: CLLocationCoordinate2D, on map: TGMapView,
                         personIcon: MarkerIconData?,
                         arrowDirection: MarkerIconData?,
                         anchor:String,
                         userLocationMarkerType: UserLocationMarkerType = UserLocationMarkerType.person) -> MyLocationMarker {
        let userLocationMarker = MyLocationMarker(coordinate: userLocation,
                personIcon: personIcon, arrowDirectionIcon: arrowDirection,
                userLocationMarkerType: userLocationMarkerType,
                anchor: AnchorGeoPoint(anchor)
            )

        userLocationMarker.marker = map.markerAdd()
        userLocationMarker.marker!.point = userLocationMarker.coordinate
        userLocationMarker.setDirectionArrow(personIcon: personIcon, arrowDirection: arrowDirection)
        userLocationMarker.marker!.visible = true
        return userLocationMarker
    }
    
    func flyToUserLocation(for location: CLLocationCoordinate2D, flyEnd: ((Bool) -> Void)? = nil) {
        let cameraOption = TGCameraPosition(center: location, zoom: self.zoom, bearing: self.bearing, pitch: self.pitch)
        self.fly(to: cameraOption!, withSpeed: CGFloat(3.5), callback: flyEnd)
    }

    func removeUserLocation(for marker: TGMarker) {
        self.markerRemove(marker)
    }

    func removeMarkers(markers: [TGMarker]) {
        for marker in markers {
            self.markerRemove(marker)
        }
    }
}
extension RoadManager  {

    func hasTGMarkerPoylines() -> [RoadFolder] {
        return roads.filter({roadF in roadF.tgRouteLayer.tgMarkerPolyline != nil })
    }
    func hasTGGeoPolylinePoylines() -> [RoadFolder] {
        return roads.filter({roadF in roadF.tgRouteLayer.tgPolyline != nil })
    }
}
extension MyLocationMarker {
    
    func updateUserLocationStyle(for style: MarkerStyle) {
        print("marker stringstyling : \(style.toString())")
        self.marker!.stylingString = style.toString()
    }
    
    
    func setDirectionArrow(personIcon: MarkerIconData?, arrowDirection: MarkerIconData?) {
        self.personIcon = personIcon
        arrowDirectionIcon = arrowDirection
        var iconM: MarkerIconData? = nil
        lazy var size = defaultSizeMarker
        if (arrowDirectionIcon == nil && personIcon == nil) {
           /*
            switch (self.userLocationMarkerType) {
            case .person:
                self.marker?.stylingString = "{ \(MyLocationMarker.personStyle) , size: [\(String(describing: size.first))px,\(String(describing: size.last))px] , angle: \(self.angle) } "
                break;
            case .arrow:
                self.marker?.stylingString = "{ \(MyLocationMarker.arrowStyle) , size: [\(String(describing: size.first))px,\(String(describing: size.last))px] , angle: \(angle)  } "
                break;
            }
            */
            self.marker?.stylingString = self.markerStyle.toString()
        } else {
            if (arrowDirectionIcon != nil && userLocationMarkerType == .arrow) {
                iconM = arrowDirectionIcon
            } else if (self.personIcon != nil && userLocationMarkerType == .person) {
                iconM = self.personIcon
            }
            self.markerStyle.size = iconM!.size
            self.markerStyle.style = StyleType.points
            self.markerStyle.sprite = nil
            /*
             marker?.stylingString = " { style: 'points', interactive: false ,color: 'white',size: [\(iconM!.size.first ?? 48)px,\(iconM!.size.last ?? 48)px], order: 2000, collide: false , angle : \(angle) } "
             */
            marker?.stylingString = self.markerStyle.toString()
            marker?.icon = iconM!.image!
        }
    }

    func rotateMarker(angle: Int) {
        userLocationMarkerType = UserLocationMarkerType.arrow
        self.angle = angle
        var size = defaultSizeMarker
        self.markerStyle.angle = angle
        if (arrowDirectionIcon == nil || personIcon == nil) {
            self.markerStyle.size = size
            /*switch (userLocationMarkerType) {
                case .person:
                    self.marker?.stylingString = "{ \(MyLocationMarker.personStyle), size: [\(size.first)px,\(size.last)px] , angle: \(self.angle) } "
                    break;
                case .arrow:
                    self.marker?.stylingString = "{ \(MyLocationMarker.arrowStyle) , size: [\(size.first)px,\(size.last)px] , angle: \(self.angle)  } "
                    break;
                }
            */
            self.marker?.stylingString = self.markerStyle.toString()
        } else {
            self.markerStyle.style = StyleType.points
            /*
             self.marker?.stylingString = "{ style: 'points', interactive: \(interactive),color: 'white',size: [\(markerIcon.size.first ?? 48)px,\(markerIcon.size.last ?? 48)px], order: 1000, collide: false , angle: \(angle)  } "
            */
            self.marker?.stylingString = self.markerStyle.toString()
            if (arrowDirectionIcon != nil) {
                self.marker?.icon = arrowDirectionIcon!.image!
            }
        }
    }
}
extension UIImage {

    func imageResize (sizeChange:CGSize)-> UIImage{

        let hasAlpha = true
        let scale: CGFloat = 0.0 // Use scale factor of main screen

        UIGraphicsBeginImageContextWithOptions(sizeChange, !hasAlpha, scale)
        self.draw(in: CGRect(origin: CGPoint.zero, size: sizeChange))

        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        return scaledImage!
    }

}

extension StaticGeoPMarker {
    public func addStaticGeosToMapView(
            for annotation: StaticGeoPMarker, on map: TGMapView
    ) -> StaticGeoPMarker {
        annotation.marker = map.markerAdd()
        if (annotation.markerIcon.image != nil) {
            annotation.marker?.icon = annotation.markerIcon.image!
        }
        annotation.marker?.stylingString =  annotation.markerStyle.toString() //annotation.styleMarker
        annotation.marker?.point = annotation.coordinate

        annotation.marker?.visible = true
        return annotation

    }
}

extension GeoPoint {
    func toLocationCoordinate() -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: self["lat"]!, longitude: self["lon"]!)
    }
}

extension Road {
    func toInstruction() -> [RoadInstruction] {
        steps.map { node -> RoadInstruction in
            node.toInstruction()
        }
    }
}

extension RoadNode {
    func toInstruction() -> RoadInstruction {
        RoadInstruction(location: location, instruction: instruction)
    }
}


extension RoadInstruction {
    func toMap() -> [String: Any] {
        ["instruction": instruction, "geoPoint": location.toGeoPoint()]
    }
}

extension RoadInformation {
    func toMap(instructions: [RoadInstruction]) -> [String: Any] {
        var args: [String: Any] = ["distance": self.distance, "duration": self.seconds, "routePoints": self.encodedRoute]
        if (instructions.isEmpty) {
            args["instructions"] = [String: Any]()
        } else {
            args["instructions"] = instructions.toMap()
        }
        return args
    }
}

extension RoadFolder {
    
   
    
    func toMap() -> [String: Any] {
        ["key": self.id, "distance": self.roadInformation?.distance ?? 0.0, "duration": self.roadInformation?.seconds ?? 0.0, "routePoints": self.roadInformation?.encodedRoute ?? ""]
    }
}
extension TGPolyline {
    static let defaultToleranceInMeters = 0.1
    static let kGMSEarthRadius = 6371009.0
    
    /// Returns whether `coordinate` lies on or near this path within the specified `tolerance` in meters.
    ///
    /// The tolerance, in meters, is relative to the spherical radius of the Earth. If you need to work on a sphere of different radius,
    /// you may compute the equivalent tolerance from the desired tolerance on the sphere of radius R:
    ///   tolerance = toleranceR * (RadiusEarth / R), with RadiusEarth==6371009.
    ///
    ///   - Parameters:
    ///   - coordinate: The coordinate to inspect if it lies within this path
    ///   - geodesic: `true` if this path is described by great circle segments, otherwise, it is described by rhumb (loxodromic) segments
    ///   - tolerance: the tolerance in meters. Default value is `defaultToleranceInMeters`
    ///
    /// credit :copied from  [https://github.com/googlemaps/google-maps-ios-utils/blob/main/src/GeometryUtils/GMSPath%2BGeometryUtils.swift]
    /// and modified on our needs
    func isOnPath(coordinate: CLLocationCoordinate2D, geodesic: Bool, tolerance: Double = defaultToleranceInMeters) -> Bool {

        let coordinates = self.coordinates

        // No points
        guard let prev = coordinates.first else {
          return false
        }

        // Naming: the segment is latLng1 to latLng2 and the point is targetLatLng.
        var latLng1 = prev.latLngRadians
        let targetLatLng = coordinate.latLngRadians
        let normalizedTolerance = tolerance / TGPolyline.kGMSEarthRadius
        let havTolerance = Math.haversine(normalizedTolerance)

        // Single point
        guard coordinates.count > 1 else {
          let distance = Math.haversineDistance(latLng1, targetLatLng)
          return distance < havTolerance
        }

        // Handle geodesic
        if (geodesic) {
          for coord in coordinates {
            let latLng2 = coord.latLngRadians
            if (isOnSegmentGreatCircle(latLng1: latLng1, latLng2: latLng2, latLng3: targetLatLng, havTolerance: havTolerance)) {
              return true
            }
            latLng1 = latLng2
          }
          return false
        }

        // We project the points to mercator space, where the Rhumb segment is a straight line,
        // and compute the geodesic distance between point3 and the closest point on the segment.
        // Note that this method is an approximation, because it uses "closest" in mercator space,
        // which is not "closest" on the sphere -- but the error introduced is small as
        // `normalizedTolerance` is small.
        let minAcceptable = targetLatLng.latitude - normalizedTolerance
        let maxAcceptable = targetLatLng.latitude + normalizedTolerance

        var point1 = CartesianPoint(x: 0, y: Math.mercatorY(latitudeInRadians: latLng1.latitude))

        for coord in coordinates {
          let latLng2 = coord.latLngRadians

          guard max(latLng1.latitude, latLng2.latitude) >= minAcceptable &&
                  min(latLng1.latitude, latLng2.latitude) <= maxAcceptable else {
            continue
          }

          // The implicit x1 is always 0 because we offset longitudes by -lng1.
          let point2 = CartesianPoint(
            x: Math.wrap(value: latLng2.longitude - latLng1.longitude, min: -.pi, max: .pi),
            y: Math.mercatorY(latitudeInRadians: latLng2.latitude)
          )
          let point3 = CartesianPoint(
            x: Math.wrap(value: targetLatLng.longitude - latLng1.longitude, min: -.pi, max: .pi),
            y: Math.mercatorY(latitudeInRadians: targetLatLng.latitude)
          )

          if let closestPoint = closestPointAround(point1, point2, point3) {
            let latClosest = Math.inverseMercatorLatitudeRadians(closestPoint.y)
            let deltaLng = point3.x - closestPoint.x
            let havDistance = Math.haversineDistance(
              latitude1: targetLatLng.latitude,
              latitude2: latClosest,
              deltaLongitude: deltaLng
            )
            if (havDistance < havTolerance) {
              return true
            }
          }

          latLng1 = latLng2
          point1 = CartesianPoint(x: 0, y: point2.y)
        }

        return false
      }
      /// Returns whether or not `coordinate` is inside this path which is always considered to be closed
      /// regardless if the last point of this path equals the first or not. This path is described by great circle
      /// segments if `geodesic` is true, otherwise, it is described by rhumb (loxodromic) segments.
      ///
      /// If `coordinate` is exactly equal to one of the vertices, the result is true. A point that is not equal to a
      /// vertex is on one side or the other of any path segment—it can never be "exactly on the border".
      /// See `isOnPath(coordinate:, geodesic:, tolerance:)` for a border test with tolerance.
      ///
      /// Note: "Inside" is defined as not containing the South Pole—the South Pole is always considered outside.
      func contains(coordinate: CLLocationCoordinate2D, geodesic: Bool) -> Bool {

        let coordinates = self.coordinates

        // Naming: the segment is latLng1 to latLng2 and the point is latLng3
        guard var latLng1 = coordinates.last?.latLngRadians else {
          return false
        }
        let latLng3 = coordinate.latLngRadians

        var intersectionsCount = 0

        for coord in coordinates {
          let wrappedLng3 = Math.wrap(value: latLng3.longitude - latLng1.longitude, min: -.pi, max: .pi)

          // Special-case: coordinate equal to one of the vertices.
          if (latLng3.latitude == latLng1.latitude && wrappedLng3 == 0) {
            return true
          }

          let latLng2 = coord.latLngRadians
          let wrappedLng2 = Math.wrap(value: latLng2.longitude - latLng1.longitude, min: -.pi, max: .pi)

          if intersects (
                lat1: latLng1.latitude,
                latLng2: LatLngRadians(latitude: latLng2.latitude, longitude: wrappedLng2),
                latLng3: LatLngRadians(latitude: latLng3.latitude, longitude: wrappedLng3),
                geodesic: geodesic
          ) {
            intersectionsCount += 1
          }
          latLng1 = latLng2
        }
        return intersectionsCount % 2 == 1
      }
      /// Computes whether the vertical segment `latLng3` to South Pole intersects the
      /// segment (`lat1`, 0) to `latLng2`. Longitudes are offset by -`lng1`, the implicit
      /// lng1 becomes 0.
      private func intersects(
        lat1: LocationRadians,
        latLng2: LatLngRadians,
        latLng3: LatLngRadians,
        geodesic: Bool
      ) -> Bool {

        // Both ends on the same side of lng3 doesn't intersect
        if ((latLng3.longitude >= 0 && latLng3.longitude >= latLng2.longitude) ||
              (latLng3.longitude < 0 && latLng3.longitude < latLng2.longitude)) {
            return false
        }

        // Point is South Pole.
        if (latLng3.latitude <= -.pi / 2) {
            return false
        }

        // Any segment end is a pole.
        if (lat1 <= -.pi / 2 || latLng2.latitude <= -.pi / 2 || lat1 >= .pi / 2 || latLng2.latitude >= .pi / 2) {
            return false
        }

        if (latLng2.longitude <= -.pi) {
            return false
        }

        let linearLat = (lat1 * (latLng2.longitude - latLng3.longitude) + latLng2.latitude * latLng3.longitude) / latLng2.longitude

        // Northern hemisphere and point under lat-lng line.
        if (lat1 >= 0 && latLng2.latitude >= 0 && latLng3.latitude < linearLat) {
            return false
        }

        // Southern hemisphere and point above lat-lng line.
        if (lat1 <= 0 && latLng2.latitude <= 0 && latLng3.latitude >= linearLat) {
            return true
        }
        // North Pole.
        if (latLng3.latitude >= .pi / 2) {
            return true
        }
        // Compare lat3 with latitude on the GC/Rhumb segment corresponding to lng3.
        // Compare through a strictly-increasing function (tan() or mercator()) as convenient.
        return geodesic ?
          tan(latLng3.latitude) >= tanLatGreatCircle(lat1: lat1, latLng2: latLng2, lng3: latLng3.longitude) :
          Math.mercatorY(latitudeInRadians: latLng3.latitude) >= mercatorLatRhumb(lat1: lat1, latLng2: latLng2, lng3: latLng3.longitude)
      }

      /// Returns tan(latitude-at-lng3) on the great circle (`lat1`, 0) to `latLng2`.
    private func tanLatGreatCircle(lat1: LocationRadians, latLng2: LatLngRadians, lng3: LocationRadians) -> LocationRadians {
        return (tan(lat1) * sin(latLng2.longitude - lng3) + tan(latLng2.latitude) * sin(lng3)) / sin(latLng2.longitude)
      }

      /// Returns  mercator(latitude-at-lng3) on the Rhumb line (`lat1`, 0) to `latLng2`.
    private  func mercatorLatRhumb(lat1: LocationRadians, latLng2: LatLngRadians, lng3: LocationRadians) -> LocationRadians {
        return (
          Math.mercatorY(latitudeInRadians: lat1) * (latLng2.longitude - lng3) + Math.mercatorY(latitudeInRadians: latLng2.latitude) * lng3
        ) / latLng2.longitude
      }
    private  func isOnSegmentGreatCircle(
        latLng1: LatLngRadians,
        latLng2: LatLngRadians,
        latLng3: LatLngRadians,
        havTolerance: LocationRadians
      ) -> Bool {
        // Haversine is strictly increasing on [0, .pi]; we do some comparisons in hav space.
        // First check distance to the ends of the segment.
        let havDist13 = Math.haversineDistance(latLng1, latLng3)
        guard havDist13 > havTolerance else {
          return true
        }

        let havDist23 = Math.haversineDistance(latLng2, latLng3)
        guard havDist23 > havTolerance else {
          return true
        }

        // Compute "cross-track distance", the distance from point to the GC formed by the segment.
        let sinBearing = sinDeltaBearing(latLng1: latLng1, latLng2: latLng2, latLng3: latLng3)
        let sinDist13 = Math.sinFromHaversine(havDist13)
        let havCrossTrack = Math.haversineFromSin(sinDist13 * sinBearing)
        guard havCrossTrack <= havTolerance else {
            return false
        }

        // Check that the "projection" P of latlng3 to the GC circle formed by the segment is inside the segment.
        // We compare the alongTrack distance from both ends of the segment with the length of the
        // segment. If any of the alongTrack is larger than the segment, then the point projects outside.
        // cos(alongTrack) == cos(distance13)/cos(crossTrack), so
        // hav(alongTrack) == (havDist13 - havCrossTrack)/cos(crossTrack).
        // alongTrack > distance12 becomes:
        // hav(alongTrack) > havDist12,
        // (havDist13 - havCrossTrack)/cos(crossTrack) > havDist12 . Note cos(crossTrack) > 0 and large.
        // havDist13 > havDist12 * cos(crossTrack) + havCrossTrack.
        // cos(crossTrack) == 1 - 2*havCrossTrack. Note cos(crossTrack) is positive.
        // havDist13 > havDist12 * (1 - 2*havCrossTrack) + havCrossTrack
        // havDist13 > havDist12 + havCrossTrack * (1 - 2 * havDist12).
        let havDist12 = Math.haversineDistance(latLng1, latLng2)
        let term = havDist12 + havCrossTrack * (1 - 2 * havDist12)
        if (havDist13 > term || havDist23 > term) {
            return false;
        }

        // If both along-track distances are less than the segment, the projection may still
        // be outside only if the segment is larger than 120deg.
        if (havDist12 < 0.7) {
            return true
        }

        // We decide remaining case by comparing the sum of along-track distances to the half-circle.
        let cosCrossTrack = 1 - 2 * havCrossTrack
        let havAlongTrack13 = (havDist13 - havCrossTrack) / cosCrossTrack
        let havAlongTrack23 = (havDist23 - havCrossTrack) / cosCrossTrack
        let sinSumAlongTrack = Math.sinSumFromHaversine(havAlongTrack13, havAlongTrack23)
        return sinSumAlongTrack > 0  // Compare with half-circle == PI using sign of sin().
      }
     /// Returns the closest point on the segment [`p1`, `p2`] to candidates (`p3.x`, `p3.y`), (`p3.x - 2 * .pi`, `p3.y`),
    /// and (`p3.x + 2 * .pi`, `p3.y`) and returns the closest point.
    /// Note: `p1.x` should be 0.
    private func closestPointAround(_ p1: CartesianPoint, _ p2: CartesianPoint, _ p3: CartesianPoint) -> CartesianPoint? {
      guard p1.x == 0 else {
        return nil
      }

      var closestDistance = Double.infinity
      var result = p3
      for x in [p3.x, p3.x - 2 * .pi, p3.x + 2 * .pi] {
        let pCurrent = CartesianPoint(x: x, y: p3.y)

        // Get closest point
        let dy = p2.y - p1.y
        let len2 = p2.x * p2.x + dy * dy
        let t = (len2 <= 0) ? 0 : Math.clamp(value: (pCurrent.x * p2.x + (p3.y - p1.y) * dy) / len2, min: 0, max: 1)
        let closest = CartesianPoint(x: t * p2.x, y: p1.y + t * dy)

        let distance = ((pCurrent.x - closest.x) * (pCurrent.x - closest.x)) + ((pCurrent.y - closest.y) * (pCurrent.y - closest.y))
        if (distance < closestDistance) {
          closestDistance = distance
          result = closest
        }
      }
      return result
    }
    /// Returns sin(initial bearing from `latLng1` to `latLng3` minus initial bearing from `latLng1` to `latLng2`).
    private func sinDeltaBearing(latLng1: LatLngRadians, latLng2: LatLngRadians, latLng3: LatLngRadians) -> LocationRadians {
       // Uses sin(atan2(a,b) - atan2(c,d)) == (a*d - b*c) / sqrt((a*a + b*b) * (c*c + d*d)).
       let sinLat1 = sin(latLng1.latitude)
       let cosLat2 = cos(latLng2.latitude)
       let cosLat3 = cos(latLng3.latitude)
       let lat31 = latLng3.latitude - latLng1.latitude
       let lng31 = latLng3.longitude - latLng1.longitude
       let lat21 = latLng2.latitude - latLng1.latitude
       let lng21 = latLng2.longitude - latLng1.longitude
       let a = sin(lng31) * cosLat3
       let c = sin(lng21) * cosLat2
       let b = sin(lat31) + 2 * sinLat1 * cosLat3 * Math.haversine(lng31)
       let d = sin(lat21) + 2 * sinLat1 * cosLat2 * Math.haversine(lng21)
       let denominator = (a * a + b * b) * (c * c + d * d)
       return denominator <= 0 ? 1 : (a * d - b * c) / sqrt(denominator);
     }
}
extension TGRoute {
    func toCoordinates()->[CLLocationCoordinate2D] {
        var counter = 0
        var coordinates = [CLLocationCoordinate2D]()
        var len = tgPolyline!.tgPolyline.count
        while counter < len  {
            coordinates.append(tgPolyline!.tgPolyline.coordinates[counter])
            counter+=1
        }
        return coordinates
    }
}
extension Array where Element == RoadFolder {
    func onlyTGMarkerPoylines() -> [TGMarker] {
        let filerRoad =  self.filter({ roadF in
           return roadF.tgRouteLayer.tgMarkerPolyline != nil
       })
       return filerRoad.map({roadF in return roadF.tgRouteLayer.tgMarkerPolyline! })
    }
    func onlyTGGeoPolylinePoylines() -> [TGPolyline] {
        let filtered =  filter({roadF in roadF.tgRouteLayer.tgPolyline != nil })
        return filtered.map({roadF in roadF.tgRouteLayer.tgPolyline! })
    }
}
extension Array where Element == Int {
    func toUIColor() -> UIColor {
        UIColor.init(absoluteRed: self.first!, green: self.last!, blue: self[1], alpha: 255)
    }
}

extension Array where Element == GeoPoint {
    func parseToPath() -> [String] {

        self.map { point -> String in
            let wayP = String(format: "%F,%F", point["lon"]!, point["lat"]!)
            return wayP
        }
    }
}

extension Array where Element == RoadInstruction {
    func toMap() -> [[String: Any]] {
        map { (instruction: RoadInstruction) -> [String: Any] in
            instruction.toMap()
        }
    }
}
extension Sizes: Decodable {

    init(from array: [String]) throws {
        let sizesStrs =  array.map({$0.replacingOccurrences(of: "px", with: "")})
        var sizes = [Int]()
        sizesStrs.forEach({
            print($0)
            sizes.append(Int($0)!)
        })
        self.init(sizes)
        
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
            return RoadType.bike
        default:
            return RoadType.car
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
            return ["north": 85.0, "east": 180.0, "south": -85.0, "west": 180.0]
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

    func toBounds() -> TGCoordinateBounds {
        let locations: [String: Double] = getBounds(width: bounds.width, height: bounds.height)
        return TGCoordinateBounds(sw: CLLocationCoordinate2D(latitude: locations["south"]!, longitude: locations["west"]!),
                ne: CLLocationCoordinate2D(latitude: locations["north"]!, longitude: locations["east"]!))
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
        return TGCoordinateBounds(sw: CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
                ne: CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon))
    }
}

extension Array where Element == Double {
    func toBounds() -> TGCoordinateBounds {
        var maxLat = -85.0
        var maxLon = -180.0
        var minLat = 85.0
        var minLon = 180.0
        let locations = self
        minLat = Swift.min(minLat, locations.first!)
        minLon = Swift.min(minLon, locations[1])
        maxLat = Swift.max(maxLat, locations[2])
        maxLon = Swift.max(maxLon, locations.last!)
        print("bounds " + locations.description)
        return TGCoordinateBounds(sw: CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
                ne: CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon))
    }
}


extension TGCoordinateBounds {
    func contains(location: CLLocationCoordinate2D) -> Bool {
        var latMatch = false;
        var lonMatch = false;
        print(sw)
        print(ne)
        //FIXME there's still issues when there's multiple wrap arounds
        if (ne.latitude < sw.latitude) {
            //either more than one world/wrapping or the bounding box is wrongish
            latMatch = true;
        } else {
            //normal case
            latMatch = ((location.latitude < ne.latitude) && (location.latitude > sw.latitude));
        }


        if (ne.longitude < sw.latitude) {
            //check longitude bounds with consideration for date line with wrapping
            lonMatch = location.longitude <= ne.longitude && location.longitude >= sw.longitude;
            //lonMatch = (aLongitude >= mLonEast || aLongitude <= mLonWest);

        } else {
            lonMatch = ((location.longitude < ne.longitude) && (location.longitude > sw.longitude));
        }

        return latMatch && lonMatch;
    }

    func getBoundingBoxZoom(final pScreenWidth: Int, pScreenHeight: Int) -> Double {
        let longitudeZoom = getLongitudeZoom(pEast: ne.longitude, pWest: sw.longitude, pScreenWidth: pScreenWidth);
        let latitudeZoom = getLatitudeZoom(pNorth: ne.latitude, pSouth: sw.latitude, pScreenHeight: pScreenHeight);
        if (longitudeZoom == Double.leastNonzeroMagnitude) {
            return latitudeZoom;
        }
        if (latitudeZoom == Double.leastNonzeroMagnitude) {
            return longitudeZoom;
        }
        return min(latitudeZoom, longitudeZoom);
    }
}
extension AnchorType {
   static func fromString(anchorStr:String) -> AnchorType {
        AnchorType.allCasesValues.contains(where: {$0 == anchorStr}) ? self.init(rawValue:anchorStr)! : AnchorType.center
    }
}
func getMaxLatitude() -> Double {
    85.0
}

func getMinLatitude() -> Double {
    -85.0
}

func getMaxLongitude() -> Double {
    180.0
}

func getMinLongitude() -> Double {
    -180.0
}


func getLongitudeZoom(pEast: Double, pWest: Double, pScreenWidth: Int) -> Double {
    let x01West = getX01FromLongitude(longitude: pWest, true);
    let x01East = getX01FromLongitude(longitude: pEast, true);
    var span = x01East - x01West;
    if (span < 0) {
        span += 1;
    }
    if (span == 0) {
        return Double.leastNonzeroMagnitude;
    }
    return log(Double(pScreenWidth) / span / 256.0) / log(2);
}

func getLatitudeZoom(pNorth: Double, pSouth: Double, pScreenHeight: Int) -> Double {
    let y01North = getY01FromLatitude(latitude: pNorth, true);
    let y01South = getY01FromLatitude(latitude: pSouth, true);
    let span = y01South - y01North;
    if (span <= 0) {
        return Double.leastNonzeroMagnitude;
    }
    return log(Double(pScreenHeight) / span / 256) / log(2);
}

/**
     * Converts a longitude to its "X01" value,
     * id est a double between 0 and 1 for the whole longitude range
     *
     * @since 6.0.0
     */
func getX01FromLongitude(longitude: Double, _ wrapEnabled: Bool) -> Double {
    let _longitude = wrapEnabled ? Clip(n: longitude, minValue: getMinLongitude(), maxValue: getMaxLongitude()) : longitude;
    let result = getX01FromLongitude(pLongitude: _longitude);
    return wrapEnabled ? Clip(n: result, minValue: 0, maxValue: 1) : result;
}

/**
     * Converts a latitude to its "Y01" value,
     * id est a double between 0 and 1 for the whole latitude range
     *
     * @since 6.0.0
     */
func getY01FromLatitude(latitude: Double, _  wrapEnabled: Bool) -> Double {
    let _latitude = wrapEnabled ? Clip(n: latitude, minValue: getMinLatitude(), maxValue: getMaxLatitude()) : latitude;
    let result = getY01FromLatitude(pX01: _latitude);
    return wrapEnabled ? Clip(n: result, minValue: 0, maxValue: 1) : result;
}

func getX01FromLongitude(pLongitude: Double) -> Double {
    (pLongitude - getMinLongitude()) / (getMaxLongitude() - getMinLongitude())
}

func getY01FromLatitude(pX01: Double) -> Double {
    getMinLongitude() + (getMaxLongitude() - getMinLongitude()) * pX01
}

func Clip(n: Double, minValue: Double, maxValue: Double) -> Double {
    min(max(n, minValue), maxValue);
}

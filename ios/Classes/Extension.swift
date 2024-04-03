//
// Created by Dali on 5/11/21.
//

import Foundation
import OSMFlutterFramework
import Polyline
import MapKit

func convertImage(codeImage: String) -> UIImage? {
    let dataImage = Data(base64Encoded: codeImage)
    if dataImage == nil, #available(iOS 13.0, *){
            return UIImage(systemName: "mappin")
    }
    return UIImage(data: dataImage!)// Note it's optional. Don't force unwrap!!!
}


extension OSMRoadManager  {

    func hasPoylines() -> [RoadFolder] {
        return roads.filter({roadF in roadF.polyline.coordinates != nil })
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
        var args: [String: Any] = ["key":id,"distance": self.distance, "duration": self.seconds, "routePoints": self.encodedRoute]
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
extension Polyline {
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
        guard let prev = coordinates?.first else {
          return false
        }

        // Naming: the segment is latLng1 to latLng2 and the point is targetLatLng.
        var latLng1 = prev.latLngRadians
        let targetLatLng = coordinate.latLngRadians
        let normalizedTolerance = tolerance / Polyline.kGMSEarthRadius
        let havTolerance = Math.haversine(normalizedTolerance)

        // Single point
        guard coordinates!.count > 1 else {
          let distance = Math.haversineDistance(latLng1, targetLatLng)
          return distance < havTolerance
        }

        // Handle geodesic
        if (geodesic) {
          for coord in coordinates! {
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

        for coord in coordinates! {
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
        guard var latLng1 = coordinates!.last?.latLngRadians else {
          return false
        }
        let latLng3 = coordinate.latLngRadians

        var intersectionsCount = 0

        for coord in coordinates! {
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

extension CLLocationCoordinate2D {
    func toGeoPoint() -> GeoPoint {
        ["lat": latitude, "lon": longitude]
    }
    func toUserLocation(heading:Double = 0) -> GeoPoint {
        ["lat": latitude, "lon": longitude,"heading":heading]
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


extension Array where Element == CLLocationCoordinate2D {
    func toBounds() -> BoundingBox {
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
        return BoundingBox(north:maxLat,west: minLon, east: maxLon,south: minLat)
    }
}

extension RectShapeOSM {
    static func fromMap(json:[String:Any])->RectShapeOSM {
       let center = CLLocationCoordinate2D(latitude: json["lat"] as! Double, longitude: json["lon"] as! Double)
        let colorFilledJs = json["color"] as! [Any]
        let filledCOlor = UIColor(absoluteRed: colorFilledJs[0] as! Int, green:  colorFilledJs[2] as! Int,
                                blue:  colorFilledJs[1] as! Int, alpha:  colorFilledJs[3] as! Int)
        var borderColor = filledCOlor
        if json.keys.contains("colorBorder") {
            let colorBorderJson = json["colorBorder"] as! [Any]
            borderColor = UIColor(absoluteRed: colorBorderJson[0] as! Int, green:  colorBorderJson[2] as! Int,
                                    blue:  colorBorderJson[1] as! Int, alpha:  colorBorderJson[3] as! Int)
        }
        let borderWidth = json["strokeWidth"] as! Double
        let style = ShapeStyleConfiguration(filledColor: filledCOlor, borderColor: borderColor, borderWidth: borderWidth)
        return RectShapeOSM(center: center, distanceInMeter: json["distance"] as! Double, style: style)
    }
}
extension CircleOSM {
    static func fromMap(json:[String:Any])->CircleOSM {
       let center = CLLocationCoordinate2D(latitude: json["lat"] as! Double, longitude: json["lon"] as! Double)
        let colorFilledJs = json["color"] as! [Any]
        let filledCOlor = UIColor(absoluteRed: colorFilledJs[0] as! Int, green:  colorFilledJs[2] as! Int,
                                blue:  colorFilledJs[1] as! Int, alpha:  colorFilledJs[3] as! Int)
        var borderColor = filledCOlor
        if json.keys.contains("colorBorder") {
            let colorBorderJson = json["colorBorder"] as! [Any]
            borderColor = UIColor(absoluteRed: colorBorderJson[0] as! Int, green:  colorBorderJson[2] as! Int,
                                    blue:  colorBorderJson[1] as! Int, alpha:  colorBorderJson[3] as! Int)
        }
        let borderWidth = json["strokeWidth"] as! Double
        let style = ShapeStyleConfiguration(filledColor: filledCOlor, borderColor: borderColor, borderWidth: borderWidth)
        return CircleOSM(center: center, distanceInMeter: json["radius"] as! Double, style: style)
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
public func -(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
    return abs(lhs.latitude - rhs.latitude) >= 0.000001 && abs(lhs.longitude - rhs.longitude) >= 0.000001
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
extension Optional where Wrapped == Double {
    func toFloat()-> Float? {
        if self == nil {
            return nil
        }
        return Float(self!)
    }
 
}
extension Double {
    func toInt()-> Int {
        Int(self)
    }
}
extension Array where Element == Int {
    func toMarkerSize()-> MarkerIconSize {
        (x:Int(CGFloat(self.first!) * UIScreen.main.scale),y:Int(CGFloat(self.last!) * UIScreen.main.scale))
    }
}
extension UIColor {
    convenience init?(hexString: String?) {
        if hexString == nil {
            return nil
        }
        let r, g, b, a: CGFloat
        
        if hexString!.hasPrefix("#") {
            var start = hexString!.index(hexString!.startIndex, offsetBy: 1)
            var hexColor = String(hexString![start...])

            if hexString!.count == 9 {
                start = hexString!.index(hexString!.startIndex, offsetBy: 3)
                hexColor = String(hexString![start...])
            }
            let scanner = Scanner(string: hexColor)
            var hexNumber: UInt64 = 0
            if scanner.scanHexInt64(&hexNumber) {
                r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                b = CGFloat(hexNumber & 0x0000ff) / 255
                a = 1.0

                self.init(red: r, green: g, blue: b, alpha: a)
                return
            }
        }
        
        return nil
    }
}

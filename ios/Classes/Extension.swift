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
        marker?.icon = markerIcon.image!
        marker?.stylingString = self.markerStyle.toString() //styleMarker
        marker?.point = coordinate

        marker?.visible = true
        return marker!
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
            m.point == self.coordinate
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
                         personIcon: MarkerIconData?, arrowDirection: MarkerIconData?,
                         userLocationMarkerType: UserLocationMarkerType = UserLocationMarkerType.person) -> MyLocationMarker {
        let userLocationMarker = MyLocationMarker(coordinate: userLocation,
                personIcon: personIcon, arrowDirectionIcon: arrowDirection,
                userLocationMarkerType: userLocationMarkerType)

        userLocationMarker.marker = map.markerAdd()
        userLocationMarker.marker!.point = userLocationMarker.coordinate
        userLocationMarker.setDirectionArrow(personIcon: personIcon, arrowDirection: arrowDirection)
        userLocationMarker.marker!.visible = true
        return userLocationMarker
    }

    func flyToUserLocation(for location: CLLocationCoordinate2D, flyEnd: ((Bool) -> Void)? = nil) {
        let cameraOption = TGCameraPosition(center: location, zoom: self.zoom, bearing: self.bearing, pitch: self.pitch)
        self.fly(to: cameraOption!, withSpeed: 50, callback: flyEnd)
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

extension MyLocationMarker {
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

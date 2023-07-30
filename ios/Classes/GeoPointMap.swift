//
//  GeoPointMap.swift
//  flutter_osm_plugin
//
//  Created by Dali on 4/10/21.
//

import Foundation
import TangramMap


typealias GeoPoint = [String: Double]
struct AnchorGeoPoint {
    var anchor: AnchorType = AnchorType.center
    var offset:(Int,Int)? = nil
}

protocol GenericGeoPoint {
    var coordinate: CLLocationCoordinate2D { get set }
}

class GeoPointMap {


    let coordinate: CLLocationCoordinate2D
    //let styleMarker: String
    let markerIcon: MarkerIconData
    public var marker: TGMarker? = nil
    var interactive: Bool = true
    var anchor:AnchorGeoPoint? = nil
    var markerStyle:MarkerStyle = MarkerStyle()
    init(
            icon: MarkerIconData,
            coordinate: CLLocationCoordinate2D,
            interactive: Bool = true,
            //styleMarker: String? = nil,
            angle: Int = 0,
            anchor:AnchorGeoPoint? = nil
    ) {
        self.interactive = interactive

        self.coordinate = coordinate

        self.markerIcon = icon
        
        self.markerStyle.size = icon.size
        if anchor != nil {
            self.markerStyle.anchor = anchor!.anchor
            self.markerStyle.offset = anchor!.offset != nil ? [anchor!.offset!.0,anchor!.offset!.1] : nil
        }
        self.markerStyle.angle = angle
        self.markerStyle.interactive = interactive
        
        /*
         self.styleMarker = styleMarker ?? " { style: 'points', interactive: \(interactive), color: 'white',size: [\(icon.size.first ?? 48)px,\(icon.size.last ?? 48)px], order: 1000, collide: false , angle : \(angle) } "
         */
    }

    var location: CLLocation {
        return CLLocation(latitude: self.coordinate.latitude, longitude: self.coordinate.longitude)
    }
}

enum UserLocationMarkerType {
    case person, arrow
}

class MyLocationMarker: GeoPointMap {

    var personIcon: MarkerIconData? = nil
    var arrowDirectionIcon: MarkerIconData? = nil

    static let personStyle = "style: 'ux-location-gem-overlay',sprite: ux-current-location, interactive: false,color: 'white',order: 2000, collide: false  "
    static let arrowStyle = "style: 'ux-location-gem-overlay',sprite: ux-route-arrow, interactive: false,color: 'white',order: 2000, collide: false  "
    let  defaultSizeMarker = [48, 48]
    var userLocationMarkerType: UserLocationMarkerType = UserLocationMarkerType.person
    var angle: Int = 0

    init(
            coordinate: CLLocationCoordinate2D,
            personIcon: MarkerIconData? = nil,
            arrowDirectionIcon: MarkerIconData? = nil,
            userLocationMarkerType: UserLocationMarkerType = UserLocationMarkerType.person,
            angle: Int = 0,
            anchor:AnchorGeoPoint? = nil
    ) {
        self.angle = angle
        //var style: String? = nil
        var iconM: MarkerIconData = MarkerIconData(image: nil)
        self.userLocationMarkerType = userLocationMarkerType
        self.personIcon = personIcon
        self.arrowDirectionIcon = arrowDirectionIcon
       
        super.init(icon: iconM, coordinate: coordinate,interactive:false,angle: angle,anchor:anchor)
        self.markerStyle.style = StyleType.location
        if (arrowDirectionIcon != nil && personIcon != nil) {
            switch (userLocationMarkerType) {
            case .person:
                self.markerStyle.sprite = SpriteType.person
                break;
            case .arrow:
                self.markerStyle.sprite = SpriteType.arrow
                break;
            }
        } else {
            if (arrowDirectionIcon != nil && userLocationMarkerType == .person) {
                iconM = arrowDirectionIcon ?? MarkerIconData(image: nil)
            } else if (personIcon != nil && userLocationMarkerType == .arrow) {
                iconM = personIcon ?? MarkerIconData(image: nil)
            }
        }
        self.markerStyle.order = 2000
    }
}

class StaticGeoPMarker: GeoPointMap {

    var color: UIColor? = UIColor.white
    var angle: Int = 0

    init(
            icon: MarkerIconData,
            coordinate: CLLocationCoordinate2D,
            angle: Int = 0,
            anchor:AnchorGeoPoint? = nil
    ) {

        self.angle = angle
        super.init(icon: icon, coordinate: coordinate, interactive: true, angle: angle,anchor:anchor)

    }

}




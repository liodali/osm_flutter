//
//  GeoPointMap.swift
//  flutter_osm_plugin
//
//  Created by Dali on 4/10/21.
//

import Foundation
import TangramMap


typealias GeoPoint = [String: Double]
protocol GenericGeoPoint {
    var coordinate:CLLocationCoordinate2D { get set }

}

class GeoPointMap {


    let coordinate: CLLocationCoordinate2D
    let styleMarker:String
    let markerIcon : UIImage?
    public var marker :TGMarker? = nil
    var interactive : Bool = true
    var size:Int = 32
    init(
            icon: UIImage? ,
            coordinate: CLLocationCoordinate2D,
            size:Int = 32,
            interactive:Bool = true,
            styleMarker:String? = nil,
            angle: Int = 0
    ) {
        self.interactive = interactive
        self.size = size
        self.coordinate = coordinate

        self.markerIcon = icon

        self.styleMarker = styleMarker ?? " { style: 'points', interactive: \(interactive),color: 'white',size: \(size)px, order: 1000, collide: false , angle : \(angle) } "
    }

    var location: CLLocation {
        return CLLocation(latitude: self.coordinate.latitude, longitude: self.coordinate.longitude)
    }
}
enum UserLocationMarkerType {
    case person, arrow
}
class MyLocationMarker:GeoPointMap {

    var personIcon:UIImage? = nil
    var arrowDirectionIcon:UIImage? = nil

    static let personStyle =  "style: 'ux-location-gem-overlay',sprite: ux-current-location, interactive: false,color: 'white',size: 56px ,order: 2000, collide: false  "
    static let arrowStyle =  "style: 'ux-location-gem-overlay',sprite: ux-route-arrow, interactive: false,color: 'white',size: 56px ,order: 2000, collide: false  "

    var userLocationMarkerType : UserLocationMarkerType = UserLocationMarkerType.person
    var angle : Int = 0
    init(
            coordinate: CLLocationCoordinate2D,
            personIcon:UIImage? = nil,
            arrowDirectionIcon:UIImage? = nil,
            userLocationMarkerType:UserLocationMarkerType = UserLocationMarkerType.person,
            angle : Int = 0
    ) {
        self.angle = angle
        var style:String? = nil
        var iconM :UIImage? = nil
        self.userLocationMarkerType = userLocationMarkerType
        if(arrowDirectionIcon == nil && personIcon == nil ){
            switch (userLocationMarkerType){
            case .person:
                style = "{ \(MyLocationMarker.personStyle) , angle: \(angle) } "
                break;
            case .arrow:
                style = "{ \(MyLocationMarker.arrowStyle) , angle: \(angle)  } "
                break;
            }
        }else{
            if( arrowDirectionIcon != nil && personIcon == nil ) {
                iconM = arrowDirectionIcon
            } else if( arrowDirectionIcon == nil && personIcon != nil ) {
                iconM = personIcon
            }else{
                switch (userLocationMarkerType){
                case .person:
                    iconM = personIcon
                    break;
                case .arrow:
                    iconM = arrowDirectionIcon
                    break;
                }
            }
        }
        super.init(icon: iconM, coordinate: coordinate,styleMarker:style,angle: angle)

    }
}

class StaticGeoPMarker: GeoPointMap {

    var color: UIColor? = UIColor.white
    var angle:Int = 0
    init(
            icon: UIImage,
            coordinate: CLLocationCoordinate2D,
            angle:Int = 0
    ) {

       self.angle = angle

        super.init(icon: icon, coordinate: coordinate,size: 32,interactive: true,angle: angle)

    }

}




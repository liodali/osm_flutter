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

    init(
            icon: UIImage? ,
            coordinate: CLLocationCoordinate2D,
            size:Int = 32,
            styleMarker:String? = nil
    ) {

        self.coordinate = coordinate

        self.markerIcon = icon

        self.styleMarker = styleMarker ?? " { style: 'points', interactive: false,color: 'white',size: \(size)px, order: 1000, collide: false } "
    }

    var location: CLLocation {
        return CLLocation(latitude: self.coordinate.latitude, longitude: self.coordinate.longitude)
    }
}

class MyLocationMarker:GeoPointMap {
    init(

            coordinate: CLLocationCoordinate2D
    ) {
        super.init(icon: nil, coordinate: coordinate,styleMarker: "{ style: 'ux-location-gem-overlay',sprite: ux-current-location, interactive: false,color: 'white',size: 56px ,order: 2000, collide: false } ")

    }
}

class StaticGeoPMarker: GeoPointMap {

    var color: UIColor? = UIColor.white

    init(
            icon: UIImage,
            coordinate: CLLocationCoordinate2D
    ) {
        super.init(icon: icon, coordinate: coordinate,size: 48)

    }

}




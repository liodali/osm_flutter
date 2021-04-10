//
//  GeoPointMap.swift
//  flutter_osm_plugin
//
//  Created by Dali on 4/10/21.
//
import Foundation
import MapKit

class GeoPointMap: NSObject, MKAnnotation {
  let title: String?
  let discipline: String?
  var marker:UIImage?
  let coordinate: CLLocationCoordinate2D

  init(
    locationName: String?,
    icon:UIImage?,
    discipline: String?,
    coordinate: CLLocationCoordinate2D
  ) {
    self.title = locationName
    self.marker = icon
    self.discipline = discipline
    self.coordinate = coordinate

    super.init()
  }
    
    var location:CLLocation{
        return CLLocation(latitude: self.coordinate.latitude, longitude: self.coordinate.longitude)
    }
 
}


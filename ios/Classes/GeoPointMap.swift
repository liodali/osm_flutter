//
//  GeoPointMap.swift
//  flutter_osm_plugin
//
//  Created by Dali on 4/10/21.
//
import Foundation
import MapKit

class GeoPointMap:  MKPointAnnotation {
  //let title: String?
  //let subtitle: String?
  var marker:UIImage?
  //let coordinate: CLLocationCoordinate2D

  init(
    locationName: String?,
    icon:UIImage?,
    discipline: String?,
    coordinate: CLLocationCoordinate2D
  ) {
    super.init()
    self.title = locationName
    self.subtitle = discipline
    self.coordinate = coordinate
    self.marker = icon

  }

    var location:CLLocation{
        return CLLocation(latitude: self.coordinate.latitude, longitude: self.coordinate.longitude)
    }
 
}
extension  GeoPointMap{
  public func setupMKAnnotationView(
          for annotation:GeoPointMap,on map:MKMapView
  )-> MKAnnotationView{
    let reuseIdentifier = NSStringFromClass(GeoPointMap.self)
    let flagAnnotationView = map.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier, for: annotation)   as! MKPinAnnotationView   //MKMarkerAnnotationView

    flagAnnotationView.canShowCallout = false

    // Provide the annotation view's image.
    flagAnnotationView.image = self.marker


    return flagAnnotationView
  }
}


//
// Created by Dali on 5/11/21.
//

import Foundation
import MapKit

extension GeoPointMap {
    public func setupMKAnnotationView(
            for annotation: GeoPointMap, on map: MKMapView
    ) -> MKAnnotationView {
        let reuseIdentifier = NSStringFromClass(GeoPointMap.self)
        let flagAnnotationView = map.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier, for: annotation) as! MKPinAnnotationView   //MKMarkerAnnotationView

        flagAnnotationView.canShowCallout = false

        // Provide the annotation view's image.
        flagAnnotationView.image = marker


        return flagAnnotationView
    }
}

extension StaticGeoPMarker {
    public func setupClusterView(
            for annotation: StaticGeoPMarker, on map: MKMapView
    )->MKAnnotationView{
        let reuseIdentifier = NSStringFromClass(StaticGeoPMarker.self)
        let flagAnnotationView = map.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier, for: annotation) as! MKMarkerAnnotationView   //MKMarkerAnnotationView

        flagAnnotationView.canShowCallout = false

        // Provide the annotation view's image.
        flagAnnotationView.glyphImage = icon
        flagAnnotationView.glyphTintColor = color

        return flagAnnotationView
    }
}

extension GeoPoint
{
     func toLocationCoordinate(

    )-> CLLocationCoordinate2D {
         CLLocationCoordinate2D(latitude: self["lat"]!, longitude: self["lon"]!)
    }
}
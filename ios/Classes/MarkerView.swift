//
//  MarkerView.swift
//  flutter_osm_plugin
//
//  Created by Dali on 4/10/21.
//

import Foundation

import MapKit

@available(iOS 11.0, *)
class MarkerView: MKMarkerAnnotationView {
    override var annotation: MKAnnotation? {
        willSet {
            // 1
            guard let point = newValue as? GeoPointMap else {
                return
            }
            canShowCallout = false
            calloutOffset = CGPoint(x: -5, y: 5)
            //rightCalloutAccessoryView = UIButton(type: .detailDisclosure)

            // 2
            if (point.marker != nil) {
             //   image = point.marker
            }

        }
    }
}

struct StaticMarkerData {
    let image: UIImage
}


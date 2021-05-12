//
//  GeoPointMap.swift
//  flutter_osm_plugin
//
//  Created by Dali on 4/10/21.
//

import Foundation
import MapKit


typealias GeoPoint = [String: Double]


class GeoPointMap: MKPointAnnotation {
    //let title: String?
    //let subtitle: String?
    var marker: UIImage?

    //let coordinate: CLLocationCoordinate2D

    init(
            locationName: String?,
            icon: UIImage?,
            discipline: String?,
            coordinate: CLLocationCoordinate2D
    ) {
        super.init()
        self.title = locationName
        self.subtitle = discipline
        self.coordinate = coordinate
        self.marker = icon

    }

    var location: CLLocation {
        return CLLocation(latitude: self.coordinate.latitude, longitude: self.coordinate.longitude)
    }
}


class StaticGeoPMarker: NSObject, MKAnnotation {
    let title: String? = ""
    let subtitle: String? = ""
    let coordinate: CLLocationCoordinate2D
    var icon: UIImage? = nil
    var color: UIColor? = nil

    init(
            icon: UIImage,
            color: UIColor?,
            coordinate: CLLocationCoordinate2D
    ) {
        self.coordinate = coordinate
        self.icon = icon
        self.color = color
        super.init()
    }

    var location: CLLocation {
        return CLLocation(latitude: self.coordinate.latitude, longitude: self.coordinate.longitude)
    }
}

class ClusterMarkerAnnotation: MKClusterAnnotation {
    let id: String
    override var memberAnnotations: [MKAnnotation] {
        super.memberAnnotations
    }

    init(
            id: String,
            geos: [StaticGeoPMarker]
    ) {
        self.id = id
        super.init(memberAnnotations: geos)
    }
}

class StaticPointClusterAnnotationView: MKAnnotationView {
    static let preferredClusteringIdentifier = Bundle.main.bundleIdentifier! + ".StaticPointClusterAnnotationView"
    var pAnnotation:StaticGeoPMarker?
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = StaticPointClusterAnnotationView.preferredClusteringIdentifier
        if  annotation is StaticGeoPMarker {
            pAnnotation = annotation as? StaticGeoPMarker
            updateImage()
        }
        if #available(iOS 14.0, *) {
            collisionMode = .none
        }

    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var annotation: MKAnnotation? {
        didSet {
            clusteringIdentifier = StaticPointClusterAnnotationView.preferredClusteringIdentifier
            if annotation is StaticGeoPMarker {
                updateImage()
            }
        }
    }

    private func updateImage() {
        self.image = pAnnotation?.icon
    }

}




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
        flagAnnotationView.markerTintColor = color
        flagAnnotationView.glyphTintColor = .white

        return flagAnnotationView
    }
}

extension GeoPoint
{
     func toLocationCoordinate()-> CLLocationCoordinate2D {
         CLLocationCoordinate2D(latitude: self["lat"]!, longitude: self["lon"]!)
    }
}
extension Array where Element == Int  {
    func toUIColor()-> UIColor{
        return UIColor.init(absoluteRed: self.first!, green: self.last!, blue: self[1], alpha: 255)
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
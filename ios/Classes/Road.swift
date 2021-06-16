//
// Created by Dali on 5/16/21.
//

import Foundation
import MapKit

struct RoadInformation {
    let distance:Double
    let seconds:Double
}



struct RoadData {
    let startPoint:CLLocationCoordinate2D
    let endPoint:CLLocationCoordinate2D
    let roadColor :UIColor?
    let roadWidth : Float?
}
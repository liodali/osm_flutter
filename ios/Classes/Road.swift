//
// Created by Dali on 5/16/21.
//

import Foundation
import MapKit
import TangramMap


struct RoadInformation {
    let distance:Double
    let seconds:Double
    let encodedRoute:String
}



struct RoadData {

    var roadColor : String = "#ff0000"
    var roadWidth : String = "5px"
}

struct  Road {
    var steps:[RoadNode]
    var legs : [RoadLeg]
    var roadData : RoadData = RoadData()
    var distance : Double = 0.0
    var duration : Double = 0
    var mRouteHigh:String = ""
    init (){
        legs = []
        steps = []
    }
}
struct  RoadLeg {
    /** in km */
    var distance:Double = 0
    /** in sec */
    public var  duration:Double = 0
}
struct RoadNode {
    var location:CLLocationCoordinate2D?
    var instruction:String = ""
    var distance:Double = 0.0
    var duration:Double = 0
    var maneuver : Int = 0
    init(){

    }
}
struct RoadConfig {
    var wayPoints : [GeoPoint]
    var intersectPoints: [GeoPoint]?
    var roadData:RoadData
    var roadType:RoadType
}
struct RoadFolder {
    let id = UUID().uuidString
    var tgRouteMarker:TGMarker
    var interestPoints: [GeoPointMap]?
}
//
// Created by Dali on 6/20/21.
//

import Foundation
import Alamofire
import MapKit
import Polyline
import TangramMap

typealias ParserJson = ([String: Any?]?) -> Road
typealias RoadHandler = (Road?) -> Void


enum RoadType: String {
    case car = "routed-car"
    case bike = "routed-bike"
    case foot = "routed-foot"
}


protocol PRoadManager {


     func getRoad(wayPoints: [String], typeRoad: RoadType, handler: @escaping RoadHandler)

     func drawRoadOnMap (on road:Road,for map:TGMapView,polyLine:Polyline?, interestPoints : [GeoPointMap]?) -> TGMarker

}

class RoadManager: PRoadManager {

    public let MANEUVERS: Dictionary<String, Int> = [
        "new name": 2,
        "turn-straight": 1,
        "turn-slight right": 6,
        "turn-right": 7,
        "turn-sharp right": 8,
        "turn-uturn": 12,
        "turn-sharp left": 5,
        "turn-left": 4,
        "turn-slight left": 3,
        "depart": 24,
        "arrive": 24,
        "roundabout-1": 27,
        "roundabout-2": 28,
        "roundabout-3": 29,
        "roundabout-4": 30,
        "roundabout-5": 31,
        "roundabout-6": 31,
        "roundabout-7": 33,
        "roundabout-8": 34,
        "merge-left": 20,
        "merge-sharp left": 20,
        "merge-slight left": 20,
        "merge-right": 21,
        "merge-sharp right": 21,
        "merge-slight right": 21,
        "merge-straight": 22,
        "ramp-left": 17,
        "ramp-sharp left": 17,
        "ramp-slight left": 17,
        "ramp-right": 18,
        "ramp-sharp right": 18,
        "ramp-slight right": 18,
        "ramp-straight": 19
    ];

    private var road: Road? = nil
    private var lastMarkerRoad : RoadFolder? = nil
    private(set) var roads : [RoadFolder] = [RoadFolder]()
    init() {

    }



    public func clearRoads (for map:TGMapView) {
        if(lastMarkerRoad != nil){
            map.markerRemove(lastMarkerRoad!.tgRouteMarker)
            lastMarkerRoad = nil
        }
        if !roads.isEmpty {
            roads.forEach { folder in
                map.markerRemove(folder.tgRouteMarker)
                if folder.interestPoints != nil && !folder.interestPoints!.isEmpty {
                   let mPoints = folder.interestPoints!.filter { p  in
                        p.marker != nil
                    }.map { p in
                               p.marker!
                    }
                    map.removeMarkers(markers: mPoints)
                }
            }

        }
    }
    func removeRoadFolder(folder:RoadFolder,for map:TGMapView){
        map.markerRemove(folder.tgRouteMarker)
        if folder.interestPoints != nil && !folder.interestPoints!.isEmpty {
            let mPoints = folder.interestPoints!.filter { p  in
                        p.marker != nil
                    }.map { p in
                        p.marker!
                    }
            map.removeMarkers(markers: mPoints)
        }
    }

    public  func drawRoadOnMap(on road: Road, for map: TGMapView,polyLine:Polyline? = nil,interestPoints : [GeoPointMap]? = nil) -> TGMarker {
        if(lastMarkerRoad != nil){
           removeRoadFolder(folder: lastMarkerRoad!, for: map)
        }
        let marker = map.markerAdd()
        marker.stylingString = "{ style: 'lines',interactive: false, color: '\(road.roadData.roadColor)', width: \(road.roadData.roadWidth), order: 1500 }"

        var route = polyLine
        if(route  == nil){
           route = Polyline(encodedPolyline: road.mRouteHigh, precision: 1e5)
        }
        let tgPolyline = TGGeoPolyline(coordinates: route!.coordinates!,count: UInt(route!.coordinates!.count))
        marker.polyline = tgPolyline
        lastMarkerRoad = RoadFolder(tgRouteMarker: marker, interestPoints: interestPoints)
        return marker
    }
    public  func drawMultiRoadsOnMap(on roads: [Road], for map: TGMapView)  {
        clearRoads(for: map)
        for road in roads {
            let marker = map.markerAdd()
            marker.stylingString = "{ style: 'lines',interactive: false, color: '\(road.roadData.roadColor)', width: \(road.roadData.roadWidth), order: 1500 }"
            let route = Polyline(encodedPolyline: road.mRouteHigh, precision: 1e5)
            let tgPolyline = TGGeoPolyline(coordinates: route.coordinates!,count: UInt(route.coordinates!.count))
            marker.polyline = tgPolyline
            self.roads.append(RoadFolder(tgRouteMarker: marker, interestPoints: nil))
        }
        /*
        lastMarkerRoad = marker */
    }

      func getRoad(wayPoints: [String], typeRoad: RoadType, handler: @escaping RoadHandler) {
        let serverURL = buildURL(wayPoints, typeRoad.rawValue)
       DispatchQueue.global(qos : .background).async{
           self.httpCall(url: serverURL) { json in
               if json != nil {
                  let road = self.parserRoad(json: json!)
                   DispatchQueue.main.async {
                       self.road = road
                       handler(road)
                   }
               } else {
                   DispatchQueue.main.async {
                       handler(nil)
                   }
               }
           }
       }
    }


      func buildURL(_ waysPoints: [String], _ typeRoad: String, alternative: Bool = false) -> String {
        let serverBaseURL = "https://routing.openstreetmap.de/\(typeRoad)/route/v1/driving/"
        let points = waysPoints.reduce("") { (result, s) in
            "\(result);\(s)"
        }
          var stringWayPoint = points
                stringWayPoint.removeFirst()


        return "\(serverBaseURL)\(stringWayPoint)?alternatives=\(alternative)&overview=full&steps=true"
    }

    private  func httpCall(url: String, parseHandler: @escaping (_ json: [String:Any?]?)->Void) {
        AF.request(url, method: .get).responseJSON { response in
            if response.data != nil {
                let data = response.value as? [String: Any?]
                 parseHandler(data!)
            }else {
                parseHandler(nil)
            }
        }
    }

    private  func parserRoad(json: [String: Any?]) -> Road {
        var road: Road = Road()
        json.forEach { key, value in
            let routes = json["routes"] as! [[String: Any?]]
            routes.forEach { route in
                road.distance = (route["distance"] as! Double) / 1000
                road.duration = route["duration"] as! Double
                road.mRouteHigh = route["geometry"] as! String
                let jsonLegs = route["legs"] as! [[String: Any]]
                jsonLegs.forEach { jLeg in
                    var legR: RoadLeg = RoadLeg()
                    legR.distance = (jLeg["distance"] as! Double) / 1000
                    legR.duration = jLeg["duration"] as! Double

                    let jsonSteps = jLeg["steps"] as! [[String: Any?]]
                    var lastName = ""
                    var lastNode :RoadNode? = nil
                    jsonSteps.forEach { step in
                        var node = RoadNode()
                        let maneuver = (step["maneuver"] as! [String: Any?])
                        let location = maneuver["location"] as! [Double]
                        node.location = CLLocationCoordinate2D(latitude: (location)[1],
                                longitude: (location)[0])
                        node.distance = (step["distance"] as! Double) / 1000
                        node.duration = step["duration"] as! Double
                        var direction = maneuver["type"] as! String
                        var modifierDirection = ""
                        if(maneuver.contains { k,v in k == "modifier"}){
                            modifierDirection = maneuver["modifier"] as! String
                        }

                        switch (direction) {
                        case "turn", "ramp", "merge":
                            if(!modifierDirection.isEmpty) {
                                direction += "-" + modifierDirection
                            }
                            break;
                        case "roundabout":
                            direction += "-" + "\(maneuver["exit"] as! Int)"
                            break;
                        case "rotary":
                            let exit = maneuver["exit"] as! Int
                            direction = "roundabout-\(exit)"
                        default:
                            break
                        }
                        ///TODO add direction instruction
                        node.maneuver =  0
                        if Array(MANEUVERS.keys).contains(direction) {
                            node.maneuver = MANEUVERS[direction]!
                        }
                        var name  = ""
                         if step["name"] as? String? != nil {
                           name =  step["name"] as! String
                        }

                        if lastNode != nil && node.maneuver != 2 && lastName == name {
                            lastNode?.duration += node.duration
                            lastNode?.distance += node.distance
                        }else{
                            road.steps.append(node)
                            lastNode = node
                            lastName = name
                        }


                    }

                }
            }
        }
        return road

    }
}

extension RoadManager {
    /**
	 * mapping from OSRM StepManeuver types to MapQuest maneuver IDs:
	 */



//From: Project-OSRM-Web / WebContent / localization / OSRM.Locale.en.js
// driving directions
// %s: road name
// %d: direction => removed
// <*>: will only be printed when there actually is a road name
    static let DIRECTIONS:[Int: String] = [
        1: "", 2: "", 3: "",
    ]

}

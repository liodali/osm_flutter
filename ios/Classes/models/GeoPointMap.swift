//
//  GeoPointMap.swift
//  flutter_osm_plugin
//
//  Created by Dali on 4/10/21.
//

import Foundation


typealias GeoPoint = [String: Double]


struct MarkerIconData {
    let image: UIImage?
    var size: [Int]? = nil
}

struct CartesianPoint {
  static var zero: CartesianPoint = CartesianPoint(x: 0, y: 0)

  var x: Double
  var y: Double
}
struct AnchorGeoPoint {
    var anchor: (x:Double,y:Double)
    var offset:(x:Double,y:Double) = (x:0.0,y:0.0)
    
    init(anchor: (x:Double,y:Double), offset: (x:Double, y:Double)? = nil) {
        self.anchor = anchor
        self.offset = offset ?? (0.0,0.0)
    }
    init(anchorMap: [String:Any]) {
        self.anchor = (x:anchorMap["x"] as! Double,y:anchorMap["y"] as! Double)
        if anchorMap.contains(where: { $0.key == "offset" }) {
            let offsetMap = anchorMap["offset"] as? [String:Double]
            self.offset = (x:offsetMap?["x"] ?? 0.0,y:offsetMap?["y"] ?? 0.0)
         }else {
            self.offset = (0,0)
         }
    }
    func compute()-> (x:Double,y:Double) {
        return (x:self.anchor.x + self.offset.x,y: self.anchor.y + self.offset.y)
    }
}



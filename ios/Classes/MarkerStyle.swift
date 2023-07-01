//
//  MarkerSytle.swift
//  flutter_osm_plugin
//
//  Created by Dali Hamza on 28.06.23.
//

import Foundation

enum StyleType:String{
    case points   = "points"
    case lines    = "lines"
    case location = "ux-location-gem-overlay"
}
enum SpriteType : String{
    case person   = "ux-current-location"
    case arrow    = "ux-route-arrow"
}

/// { style: 'points', interactive: \(interactive), color: 'white',size: [\(icon.size.first ?? 48)px,\(icon.size.last ?? 48)px], order: 1000, collide: false , angle : \(angle) }
struct MarkerStyle {
    var style:StyleType = StyleType.points;
    var angle :Int = 0;
    var order :Int = 1000;
    var size :[Int] = [48,48];
    var sprite : SpriteType? ;
    var color :String = "white";
    var interactive :Bool = true ;
    var collide :Bool = false ;
    var offset: [Int]? = nil
}
extension MarkerStyle {
    func toString() -> String {
        var styleStr = "{style: '\(style.rawValue)',interactive: \(interactive),color: '\(color)',size: [\(String(describing: size.first!))px,\(String(describing: size.last!))px],order: \(order),collide: \(collide),angle: \(angle)"
        if let sprite = sprite {
            print(sprite)
            styleStr = "\(styleStr),sprite: '\(sprite.rawValue)'"
        }
        if offset != nil {
            styleStr = "\(styleStr),offset: [\(String(describing: offset!.first!))px,\(String(describing: offset!.last!))px],anchor: center"
        }
        styleStr = "\(styleStr)}"

        return styleStr;
    }
}

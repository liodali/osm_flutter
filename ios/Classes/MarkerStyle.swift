//
//  MarkerSytle.swift
//  flutter_osm_plugin
//
//  Created by Dali Hamza on 28.06.23.
//

import Foundation

enum StyleType{
    case points   = "points"
    case lines    = "lines"
    case location = "ux-location-gem-overlay"
}

/// { style: 'points', interactive: \(interactive), color: 'white',size: [\(icon.size.first ?? 48)px,\(icon.size.last ?? 48)px], order: 1000, collide: false , angle : \(angle) }
protocol MarkerStyle {
    var style:StyleType = StyleType.points { get set }
    var angle :Int = 0 { get set }
    var order :Int = 1000 { get  }
    var size :[Int] = [48,48] { get set }
    var sprite : String? = nil { get set }
    var color :String = "white" {get}
    var interactive :Bool = true { get set }
    var collide :Bool = false { get }
    var anchor: [Int]? = nil
}
extension MarkerStyle {
    func toString():String {
        var styleStr = "{ style:\(style) ,interactive: \(interactive), color: \(color),size: [\(size.first)px,\(size.last)px], order: \(order), collide: \(collide) , angle : \(angle) "
        if let sprite = sprite {
            styleStr = "\(styleStr) ,"
        }
        styleStr = "\(styleStr) }"
    }
}

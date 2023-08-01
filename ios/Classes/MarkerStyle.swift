//
//  MarkerSytle.swift
//  flutter_osm_plugin
//
//  Created by Dali Hamza on 28.06.23.
//

import Foundation
import Yams

typealias Sizes = [Int]
typealias SizesStrs = [String]

enum StyleType:String,Codable{
    case points   = "points"
    case lines    = "lines"
    case location = "ux-location-gem-overlay"
}
enum SpriteType : String,Codable{
    case person   = "ux-current-location"
    case arrow    = "ux-route-arrow"
}
enum AnchorType : String,Codable {
    case center        = "center"
    case left          = "left"
    case right         = "right"
    case top           = "top"
    case bottom        = "bottom"
    case top_left      = "top-left"
    case top_right     = "top-right"
    case bottom_left   = "bottom-left"
    case bottom_right  = "bottom-right"
    
    static var allCasesValues: [String] {
            return [
                AnchorType.center.rawValue, AnchorType.left.rawValue, AnchorType.right.rawValue,
                AnchorType.top.rawValue,AnchorType.bottom.rawValue, AnchorType.top_left.rawValue,
                AnchorType.top_right.rawValue,AnchorType.bottom_left.rawValue,AnchorType.bottom_right.rawValue
            ]
        }
}


/// { style: 'points', interactive: \(interactive), color: 'white',size: [\(icon.size.first ?? 48)px,\(icon.size.last ?? 48)px], order: 1000, collide: false , angle : \(angle) }
struct MarkerStyle: Codable {
    var style:StyleType = StyleType.points;
    var angle :Int? = nil;
    var order :Int = 1000;
    var size :Sizes = [48,48];
    var sprite : SpriteType? ;
    var color :String = "white";
    var interactive :Bool = true ;
    var collide :Bool = false ;
    var offset: [Int]? = nil;
    var anchor: AnchorType? = nil
    init(){}
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.style = try container.decode(StyleType.self, forKey: .style)
        self.angle = try container.decodeIfPresent(Int.self, forKey: .angle)
        self.order = try container.decode(Int.self, forKey: .order)
        self.size = try Sizes.init(from: try container.decode(SizesStrs.self, forKey: .size))
        self.sprite = try container.decodeIfPresent(SpriteType.self, forKey: .sprite)
        self.color = try container.decode(String.self, forKey: .color)
        self.interactive = try container.decode(Bool.self, forKey: .interactive)
        self.collide = try container.decode(Bool.self, forKey: .collide)
        self.offset = try container.decodeIfPresent([Int].self, forKey: .offset)
        self.anchor = try container.decodeIfPresent(AnchorType.self, forKey: .anchor)
    }
    mutating func copyFromOldStyle(oldMarkerStyleStr:String) {
        let oldMarkerStyleYaml = try? YAMLDecoder().decode(MarkerStyle.self, from: oldMarkerStyleStr)
        if let oldMarkerStyle = oldMarkerStyleYaml {
            if self.angle == nil && oldMarkerStyle.angle != nil  && oldMarkerStyle.angle != 0 {
                self.angle = oldMarkerStyle.angle
            }
            if  self.anchor == nil && oldMarkerStyle.anchor != nil {
                self.anchor = oldMarkerStyle.anchor
            }
            if self.offset == nil && oldMarkerStyle.offset != nil  {
                self.offset = oldMarkerStyle.offset
            }
        }
    }
}
extension MarkerStyle {
    func toString() -> String {
        var styleStr = "{style: '\(style.rawValue)',interactive: \(interactive),color: '\(color)',size: [\(String(describing: size.first!))px,\(String(describing: size.last!))px],order: \(order),collide: \(collide)"
        if angle != nil {
            styleStr = "\(styleStr),angle: \(angle!)"
        }
        if let sprite = sprite {
            styleStr = "\(styleStr),sprite: '\(sprite.rawValue)'"
        }
        if anchor != nil  {
            styleStr = "\(styleStr),anchor: \(anchor!.rawValue)"
        }
        if offset != nil  {
            styleStr = "\(styleStr),offset: [\(String(describing: offset!.first!))px,\(String(describing: -1*offset!.last!))px]"
        }
        styleStr = "\(styleStr)}"

        return styleStr;
    }
}

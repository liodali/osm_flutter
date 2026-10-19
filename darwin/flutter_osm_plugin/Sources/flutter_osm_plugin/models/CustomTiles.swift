//
// Created by Dali Hamza on 13.11.22.
//

import Foundation

class MyCustomTiles {
    var tileURL: String
    var subDomains: String
    var tileSize: String
    var maxZoom: String

    init(_ mapTile: [String: Any]) {
        let tiles = (mapTile["urls"] as! [[String: Any]]).first
        tileURL = (tiles!["url"] as! String) + "{z}/{x}/{y}" + (mapTile["tileExtension"] as! String)
        subDomains = (tiles!["subdomains"] as? [String])?.description ?? ""
        tileSize = (mapTile["tileSize"] as? Int)?.description ?? "256"

        if mapTile.keys.contains("api") {
            let mapApi = (mapTile["api"] as! [String: String])
            tileURL = tileURL + "?\(mapApi.keys.first!)=\(mapApi.values.first ?? "")"
        }
        maxZoom = mapTile["maxZoomLevel"] as? String ?? "19"
    }
}

//
//  osm_map.swift
//  flutter_osm_plugin
//
//  Created by Dali Hamza on 19.11.23.
//

import Foundation
import OSMFlutterFramework
import CoreLocation

class MapCoreOSMView : UIView, FlutterPlatformView, CLLocationManagerDelegate,OnMapGesture,LocationHandler{
   
    
  
    let mapOSM: OSMView
    var customTiles: CustomTiles? = nil
    var boundingbox: BoundingBox? = nil
    let channel: FlutterMethodChannel
    var zoomConfig:ZoomConfiguration = ZoomConfiguration(initZoom: 8,minZoom: 2,maxZoom: 19,step: 1)
    init(_ frame: CGRect, viewId: Int64, channel: FlutterMethodChannel, args: Any?,defaultPin:String?) {
        var initLocation:CLLocationCoordinate2D?
        if (args as? [String: Any]) != nil {
            if ((args as! [String: Any]).keys.contains("customTile")) {
                customTiles = CustomTiles(((args as! [String: Any])["customTile"] as? [String: Any])!)

            }
            if ((args as! [String: Any]).keys.contains("bounds")) {
                let boundArgs = (args as! [String: Any])["bounds"] as? [Double]
                boundingbox = BoundingBox(boundingBoxs: boundArgs!)
            }
            if ((args as! [String: Any]).keys.contains("zoomOption")) {
                let zoomArgs = (args as! [String: Any])["zoomOption"] as? [String:Int]
                self.zoomConfig = ZoomConfiguration(zoomArgs!)
            }
            if ((args as! [String: Any]).keys.contains("location")) {
                let locationArgs = (args as! [String: Any])["location"] as? [String:Double]
                initLocation = CLLocationCoordinate2D(latitude: (locationArgs!["lat"])!, longitude: locationArgs!["lon"]!)
            }

            /*if ((args as! [String: Any]).keys.contains("enableRotationGesture")) {
                enableRotationGesture = (args as! [String: Any])["enableRotationGesture"] as! Bool
            }*/
        }
        let configuration = OSMMapConfiguration(zoomLevelScaleFactor:1,adaptScaleToScreen: false)
        self.mapOSM = OSMView(rect: frame, location: initLocation,zoomConfig: self.zoomConfig,mapTileConfiguration: configuration)
        self.channel = channel
        super.init(frame: frame)
        addSubview(self.mapOSM.view)
        channel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) ->
                    Void in
            self.onListenMethodChannel(call: call, result: result)
        })
        self.mapOSM.onMapGestureDelegate = self
        self.mapOSM.getMarkerManager().locationHandlerDelegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
 
    
    public func view() -> UIView {
        //let view = UIStackView(arrangedSubviews: [mapView])
        return self.mapOSM.view
    }
    
    private func onListenMethodChannel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        print(call.method)
        switch call.method {
        case "init#ios#map":
            
            //channel.invokeMethod("map#init", arguments: true)
            self.mapOSM.initOSMMap(tile:customTiles)
            channel.invokeMethod("map#init#ios", arguments: true)
            result(200)
            break
        case "change#tile":
            let args = call.arguments as! [String: Any]?
            
            if let customTileArgs = args {
                let tile = CustomTiles(customTileArgs)
                self.mapOSM.setCustomTile(tile: tile)

            }

            result(200)
            break;
        case "initMap":
            initPosition(args: call.arguments, result: result)
            break;
        case "config#Zoom":
            configZoomMap(call: call)
            result(200)
            break;
        case "limitArea":
            setCameraAreaLimit(call: call)
            result(200)
            break;
        case "remove#limitArea":
            removeCameraAreaLimit(result: result)
            result(200)
            break;
        case "changePosition":
            changePosition(args: call.arguments, result: result)
            result(200)
            break;
        case "currentLocation":
            result(200)
            break;
        case "map#center":
            result(200)
            break;
        case "trackMe":
          
            result(200)
            break;
        case "user#position":
            result(200)
            break;
        case "goto#position":
            break;
        case "map#bounds":
            result(200)
            break;
        /*case "user#pickPosition":
            //let frameV = UIView()
            methodCall = call
            resultFlutter = result
            break;*/
        case "user#removeMarkerPosition":
            result(200)
            break;
        case "deactivateTrackMe":
           
            result(200)
            break;
        case "Zoom":
            changeMapZoom(call.arguments)
            result(200)
            break;
        case "get#Zoom":
            result(self.mapOSM.zoom())
            break;
        case "change#stepZoom":
            
            result(200)
            break;
        case "zoomToRegion":
           // zoomMapToBoundingBox(call: call)
            result(200)
            break;
        case "marker#icon":
            result(200)
            break;
        case "staticPosition#IconMarker":
           
            result(200)
            break;
        case "staticPosition":
            
            result(200)
            break;
        case "road":
            result(200)
            //result(["distance": 0, "duration": 0])
            break;
        case "draw#multi#road":
            result(200)
            break;
        case "drawRoad#manually":
            result(200)
            break;
        case "delete#road":            
            break;
        case "clear#roads":
            result(200)
            break;
        case "advancedPicker#marker#icon":
            result(200)
            break;
        case "advanced#selection":
            result(200)
            break;
        case "get#position#advanced#selection":
            result(200)
            break;
        case "confirm#advanced#selection":
            result(200)
            break;
        case "cancel#advanced#selection":
           
            result(200)
            break;
        case "map#orientation":
           
            result(200)
            break;
        case "user#locationMarkers":
         
            result(200)
            break;
        case "add#Marker":
            addMarkerManually(call: call)
            result(200)
            break;
        case "update#Marker":
            
            result(200)
            break;
        case "change#Marker":
            changePositionMarker(call: call)
            result(200)
            break;
        case "delete#markers":
           
            result(200)
            break;
        case "get#geopoints":
            result(200)
            break;
        default:
            result(nil)
            break;
        }
    }
    
    func initMap( result: @escaping FlutterResult){
        self.mapOSM.initOSMMap(tile: customTiles)
        self.mapOSM.moveTo(location: CLLocationCoordinate2D(latitude: 0, longitude: 0), zoom: 2, animated: false)

        result(200)
    }
    func initPosition(args: Any?, result: @escaping FlutterResult){
        let pointInit = args as! Dictionary<String, Double>
        //print(pointInit)
        //let initZoom =
        let location = CLLocationCoordinate2D(latitude: pointInit["lat"]!, longitude: pointInit["lon"]!)
        self.mapOSM.moveTo(location: location, zoom: 8, animated: false)
        channel.invokeMethod("map#init", arguments: true)
        result(200)
    }
    private func addMarkerManually(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        if (args.keys.contains("icon")) {
            let iconArg = args["icon"] as! [String: Any]
            let icon = convertImage(codeImage: iconArg["icon"] as! String)
            let point = args["point"] as! GeoPoint
            let coordinate = point.toLocationCoordinate()
            let sizeIcon = iconArg["size"] as? [Int]
            var angle = 0
            var anchor:AnchorGeoPoint? = nil
            if let _angle = point["angle"] {
                angle = Int(CGFloat(_angle).toDegrees)
            }
            if let _anchor = args["iconAnchor"]{
                let anchorStr = (_anchor  as! [String:Any] )["anchor"] as! String
                //let anchorType = AnchorType.fromString(anchorStr: anchorStr)
                var x = NSNumber(value: 0)
                var y = NSNumber(value: 0)
                var offset:(Int,Int)? = nil
                if (_anchor  as! [String:Any]).contains(where: { $0.key == "offset" }) {
                    x = ((_anchor  as! [String:Any])["offset"] as! [String:Any])["x"] as! NSNumber
                    y = ((_anchor  as! [String:Any])["offset"] as! [String:Any])["y"] as! NSNumber
                    offset = (Int(CGFloat(truncating: x)),Int(CGFloat(truncating: y)))
                }
                anchor = AnchorGeoPoint(anchorStr,offset: offset)
            }
           //GeoPointMap(icon: icon, coordinate: coordinate, angle: angle, anchor: anchor)
            let configuration = MarkerConfiguration(icon: icon!,iconSize: nil , angle: Float(angle ), anchor: nil,scaleType: MarkerScaleType.invariant)
            let marker = Marker(location: coordinate, markerConfiguration: configuration)
            self.mapOSM.getMarkerManager().addMarker(marker: marker)
        }
    }
    private func changePositionMarker(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        let coordinate_old = (args["old_location"] as! GeoPoint).toLocationCoordinate()
        let coordinate_new = (args["new_location"] as! GeoPoint).toLocationCoordinate()
        var icon: UIImage? = nil
        var iconSize: MarkerIconSize? = nil
        var angle = 0
        var anchor:AnchorGeoPoint? = nil
        if let iconStr = args["new_icon"] as? [String: Any] {
            icon =  convertImage(codeImage: iconStr["icon"] as! String)
            iconSize = (x:(iconStr["size"] as? [Int])!.first!,y:(iconStr["size"] as? [Int])!.last!)
        }
        if let _angle = args["angle"] as? Double {
            angle = Int(CGFloat(_angle).toDegrees)
        }
        if let _anchor = args["iconAnchor"]{
            let anchorStr = (_anchor  as! [String:Any] )["anchor"] as! String
            let anchorType = AnchorType.fromString(anchorStr: anchorStr)
            var x = NSNumber(value: 0)
            var y = NSNumber(value: 0)
            var offset:(Int,Int)? = nil
            if (_anchor  as! [String:Any]).contains(where: { $0.key == "offset" }) {
                x = ((_anchor  as! [String:Any])["offset"] as! [String:Any])["x"] as! NSNumber
                y = ((_anchor  as! [String:Any])["offset"] as! [String:Any])["y"] as! NSNumber
                offset = (Int(CGFloat(truncating: x)),Int(CGFloat(truncating: y)))
            }
            anchor = AnchorGeoPoint(anchor:anchorType,offset: offset)
        }
        print("changePositionMarker:\(coordinate_old)")
        self.mapOSM.getMarkerManager().updateMarker(oldlocation: coordinate_old, newlocation: coordinate_new, 
                                                    icon: icon,
                                                    iconSize: nil,
                                                    angle: Float(angle), anchor: nil)
        //(x:sizeIcon?.first,y:sizeIcon?.last) as? MarkerIconSize
    }
    func changePosition(args: Any?, result: @escaping FlutterResult){
        result(200)
    }
    func changeMapZoom(_ args:Any?){
        let args = args as! [String: Any]
        if (args.keys.contains("stepZoom")) {
            let stepZ = args["stepZoom"] as! Double
            if (stepZ > 0) {
                self.mapOSM.zoomIn(step: Int(stepZ))
            }else if (stepZ == 0) {
                self.mapOSM.zoomIn(step: nil)
                
            }else if stepZ == -1 {
                self.mapOSM.zoomOut(step: nil)
            }else if stepZ < -1 {
                self.mapOSM.zoomOut(step: Int(stepZ))
            }

        } else {
            let levelZoom = args["zoomLevel"] as! Double

            self.mapOSM.setZoom(zoom: Int(levelZoom))

        }

    }
    func configZoomMap(call: FlutterMethodCall){
        
    }
    func setCameraAreaLimit(call: FlutterMethodCall){
        
    }
    func removeCameraAreaLimit(result: @escaping FlutterResult){
        result(200)
    }
    
    func onTap(location: CLLocationCoordinate2D) {
        channel.invokeMethod("receiveGeoPoint", arguments: location.toGeoPoint())
    }
    
    func onSingleTap(location: CLLocationCoordinate2D) {
        channel.invokeMethod("receiveSinglePress", arguments: location.toGeoPoint())
    }
    
    func onLongTap(location: CLLocationCoordinate2D) {
        channel.invokeMethod("receiveLongPress", arguments: location.toGeoPoint())
    }
}

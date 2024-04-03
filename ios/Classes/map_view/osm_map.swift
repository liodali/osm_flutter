//
//  osm_map.swift
//  flutter_osm_plugin
//
//  Created by Dali Hamza on 19.11.23.
//

import Foundation
import OSMFlutterFramework
import CoreLocation
import Polyline

class MapCoreOSMView : NSObject, FlutterPlatformView, CLLocationManagerDelegate,OnMapGesture,OnMapMoved, MapMarkerHandler,OSMUserLocationHandler,PoylineHandler {
   
    
    let mapOSM: OSMView
    var homeMarker:UIImage? = nil
    var customTiles: CustomTiles? = nil
    var boundingbox: BoundingBox? = nil
    let channel: FlutterMethodChannel
    var zoomConfig:ZoomConfiguration = ZoomConfiguration(initZoom: 8,minZoom: 2,maxZoom: 19,step: 1)
    lazy var roadManager: OSMRoadManager = OSMRoadManager()
    let roadColor: String = "#ff0000ff"
    var lastRoadKey:String? = nil
    var resultFlutter:FlutterResult? = nil
    var storedRoads:[String:StoredRoad] = [:]
    var isMovedToLocation:Bool = false
    var canSkipFollow: Bool = false
    var userLocationWithoutControl: Bool = false
    var mapInitialized: Bool = false
    private(set) var latestUserLocation:CLLocationCoordinate2D? = nil
    //let containerMapView:MapViewUIView
    init(_ frame: CGRect, viewId: Int64, channel: FlutterMethodChannel, args: Any?,defaultPin:String?) {
        var initLocation:CLLocationCoordinate2D?
        var  enableRotationGesture = false
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

            if ((args as! [String: Any]).keys.contains("enableRotationGesture")) {
                enableRotationGesture = (args as! [String: Any])["enableRotationGesture"] as! Bool
                
            }
        }
        let configuration = OSMMapConfiguration(zoomLevelScaleFactor:0.65,adaptScaleToScreen: true)
        self.mapOSM = OSMView(rect: frame, location: initLocation,zoomConfig: self.zoomConfig,mapTileConfiguration: configuration)
        self.channel = channel
        //containerMapView = MapViewUIView(frame: frame)
        //controllerMainView = MapViewUIVController(frame: frame, map: self.mapOSM)
        super.init()
        //controllerMainView.view.addSubview(self.mapOSM)
        //self.addSubview(self.mapOSM)
        self.mapOSM.enableRotation(enable: enableRotationGesture)
        channel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) ->
                    Void in
            self.onListenMethodChannel(call: call, result: result)
        })
        self.mapOSM.onMapGestureDelegate = self
        self.mapOSM.mapHandlerDelegate = self
        self.mapOSM.userLocationDelegate = self
        self.mapOSM.roadTapHandlerDelegate = self
        self.mapOSM.onMapMove = self
        self.mapOSM.enableRotation(enable: enableRotationGesture)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    
    public func view() -> UIView {
        return mapOSM
    }
    
    private func onListenMethodChannel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        print(call.method)
        switch call.method {
        case "init#ios#map":
            
            //channel.invokeMethod("map#init", arguments: true)
            //self.mapOSM.initOSMMap(tile:customTiles)
            mapOSM.setZoom(zoom: 1)
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
            mapInitialized = true
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
            // @deprecated
           // changePosition(args: call.arguments, result: result)
            result(200)
            break;
        case "currentLocation":
            self.mapOSM.locationManager.requestEnableLocation()
            result(200)
            break;
        case "map#center":
            result(self.mapOSM.center().toGeoPoint())
            result(200)
            break;
        case "trackMe":
            let args = call.arguments as! [Any]
            startTrackUser(args:args)
            result(200)
            break;
        case "user#position":
            self.mapOSM.locationManager.requestSingleLocation()
            resultFlutter = result
            break;
        case "moveTo#position":
            moveToSpecificLocation(call: call, result: result)
            break;
        case "map#bounds":
            getMapBounds(result: result)
            break;
        case "user#removeMarkerPosition":
            deleteMarker(call: call)
            result(200)
            break;
        case "deactivateTrackMe":
            stopTracking()
            result(200)
            break;
        case "startLocationUpdating":
            userLocationWithoutControl = true
            self.mapOSM.locationManager.toggleTracking(configuration: TrackConfiguration(moveMap: false,controlUserMarker: false))
            result(200)
            break;
        case "stopLocationUpdating":
            userLocationWithoutControl = false
            stopTracking()
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
           zoomMapToBoundingBox(call: call)
            result(200)
            break;
        case "marker#icon":
            let args = call.arguments as! [String: Any]
            homeMarker = convertImage(codeImage: args["icon"] as! String)
            result(200)
            break;
        case "staticPosition#IconMarker":
            setMarkerStaticGeoPIcon(call: call)
            result(200)
            break;
        case "staticPosition":
            setStaticGeoPoint(call: call)
            result(200)
            break;
        case "road":
            drawRoadMCOSM(call: call) { [unowned self] roadInfo, road, roadData, boundingbox,polyline, error in
                if (error != nil) {
                    result(FlutterError(code: "400", message: "error to draw road", details: nil))
                } else {
                    lastRoadKey = roadInfo?.id
                    let roadConfiguration = RoadConfiguration(width: Float(roadData?.roadWidth ?? 5),
                                                              color: UIColor(hexString: roadData?.roadColor ?? roadColor) ?? .green,
                                                              borderWidth: roadData?.roadBorderWidth.toFloat(),
                                                              borderColor: UIColor(hexString: roadData?.roadBorderColor),
                                                              lineCap: LineCapType.ROUND
                                                              
                    )
                    let coordinates = polyline?.coordinates
                    self.mapOSM.roadManager.addRoad(id: lastRoadKey!, polylines: coordinates!, configuration: roadConfiguration)

                    if let bounding = boundingbox {
                        self.mapOSM.moveToByBoundingBox(bounds: bounding, animated: true)
                    }
                    let instructions = road?.toInstruction() ?? [RoadInstruction]()
                    storedRoads[roadInfo!.id] = StoredRoad(id: roadInfo!.id, roadInformation: roadInfo, instructions: instructions)
                    result(roadInfo!.toMap(instructions: instructions))
                }

            }
            //result(["distance": 0, "duration": 0])
            break;
        case "draw#multi#road":
            drawMultiRoad(call: call) { [unowned self] roadInfos, roadsAndRoadData, error in
                if (roadInfos.isEmpty && roadsAndRoadData.isEmpty) {
                    result(FlutterError(code: "400", message: "error to draw multiple road", details: nil))
                } else {
                    let roads = roadsAndRoadData.filter { road in
                                road != nil
                            }
                            .map { roadAndRoadData -> (String, Road) in

                                var road = roadAndRoadData!.1
                                road.roadData = roadAndRoadData!.2
                                return (roadAndRoadData!.0, road)
                            }
                    roads.forEach { road in
                        let roadData = road.1.roadData
                        let polyline = Polyline(encodedPolyline: road.1.mRouteHigh,precision: 1e5)
                        let roadConfig = RoadConfiguration(width: roadData.roadBorderWidth.toFloat()!,
                                                           color: UIColor(hexString: roadData.roadColor) ?? .green,
                                                           borderWidth: roadData.roadBorderWidth.toFloat(),
                                                           borderColor: UIColor(hexString: roadData.roadBorderColor)
                        )
                        self.mapOSM.roadManager.addRoad(id: road.0, polylines: polyline.coordinates!, configuration: roadConfig)
                    }
                    let infos = roadInfos.filter { info in
                                info != nil
                            }
                            .enumerated()
                            .map { (index, info) -> [String: Any] in
                                let instructions = roads[index].1.toInstruction()
                                return  info!.toMap(instructions: instructions)
                            }
                    result(infos)
                }

            }
          
            break;
        case "drawRoad#manually":
            drawRoadManually(call: call, result: result)
            break;
        case "delete#road": 
            deleteRoad(call: call, result: result)
            break;
        case "clear#roads":
            self.mapOSM.roadManager.removeAllRoads()
            result(200)
            break;
        case "map#orientation":
            rotateMap(call: call)
            result(200)
            break;
        case "user#locationMarkers":
            configureUserLocation(call:call)
            result(200)
            break;
        case "add#Marker":
            addMarkerManually(call: call)
            result(200)
            break;
        case "update#Marker":
            updateMarkerIcon(call: call)
            result(200)
            break;
        case "change#Marker":
            changePositionMarker(call: call)
            result(200)
            break;
        case "delete#markers":
            deleteMarkers(call: call)
            result(200)
            break;
        case "get#geopoints":
            getGeoPoints(result)
            break;
        case "toggle#Alllayer":
            let isVisible = call.arguments as! Bool
            if isVisible {
                self.mapOSM.showAllLayers()
            }else {
                self.mapOSM.hideAllLayers()
            }
        case "draw#rect":
            drawShape(args:call.arguments, result: result,shapeType: ShapeTypes.Rect)
            break;
        case "draw#circle":
            drawShape(args:call.arguments, result: result,shapeType: ShapeTypes.Circle)
            break;
        case "remove#cirlce":
            let key = call.arguments
            if key == nil {
                self.mapOSM.shapeManager.deleteAllCircles()
            }else{
                self.mapOSM.shapeManager.deleteShape(ckey: key as! String)
            }
            result(200)
            break;
        case "remove#rect":
            let key = call.arguments
            if key == nil {
                self.mapOSM.shapeManager.deleteAllRect()
            }else{
                self.mapOSM.shapeManager.deleteShape(ckey: key as! String)
            }
            result(200)
            break;
        case "clear#shapes":
            self.mapOSM.shapeManager.deleteAllShapes()
            break;
        default:
            result(nil)
            break;
        }
    }
    
    /*func initMap( result: @escaping FlutterResult){
        //self.mapOSM.initOSMMap(tile: customTiles)
        self.mapOSM.moveTo(location: CLLocationCoordinate2D(latitude: 0, longitude: 0), zoom: 2, animated: false)

        result(200)
    }*/
    func initPosition(args: Any?, result: @escaping FlutterResult){
        let pointInit = args as! Dictionary<String, Double>
        //print(pointInit)
        //let initZoom =
        let location = CLLocationCoordinate2D(latitude: pointInit["lat"]!, longitude: pointInit["lon"]!)
        self.mapOSM.moveTo(location: location, zoom: zoomConfig.initZoom, animated: false)
        self.channel.invokeMethod("map#init", arguments: true)
        result(200)
        
    }
     func moveToSpecificLocation(call: FlutterMethodCall, result: FlutterResult) {
         let args = call.arguments as! [String:Any]
         let point = CLLocationCoordinate2D(latitude: args["lat"] as! Double, longitude: args["lon"] as! Double)
        let animate = args["animate"] as! Bool? ?? false
        var currentZoom = self.mapOSM.zoom()
         if currentZoom == 0 || !mapInitialized {
             currentZoom = zoomConfig.initZoom
         }
        self.mapOSM.moveTo(location: point, zoom: currentZoom, animated: animate)
        result(200)
    }
    func rotateMap(call:FlutterMethodCall){
        let angle = call.arguments as! Double
        self.mapOSM.setRotation(angle: angle)
    }
    private func addMarkerManually(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        if (args.keys.contains("icon")) {
            let iconArg = args["icon"] as! [String: Any]
            let icon = convertImage(codeImage: iconArg["icon"] as! String)
            let point = args["point"] as! GeoPoint
            let coordinate = point.toLocationCoordinate()
            let iconSizeArg = iconArg["size"] as? [Int]
            let sizeIcon = iconSizeArg!.toMarkerSize()
            var angle = Float(0.0)
            var anchor:AnchorGeoPoint? = nil
            if let _angle = point["angle"] {
                angle = Float(_angle)
            }
            if let _anchor = args["iconAnchor"]{
                anchor = AnchorGeoPoint(anchorMap: _anchor as! [String:Any])
            }
           //GeoPointMap(icon: icon, coordinate: coordinate, angle: angle, anchor: anchor)
            let configuration = MarkerConfiguration(icon: icon!,iconSize: sizeIcon , angle: angle, anchor: anchor?.compute(),scaleType: MarkerScaleType.invariant)
            let marker = Marker(location: coordinate, markerConfiguration: configuration)
            self.mapOSM.markerManager.addMarker(marker: marker)
        }
    }
    private func changePositionMarker(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        let coordinate_old = (args["old_location"] as! GeoPoint).toLocationCoordinate()
        let coordinate_new = (args["new_location"] as! GeoPoint).toLocationCoordinate()
        var icon: UIImage? = nil
        var iconSize: MarkerIconSize? = nil
        var angle = Float(0.0)
        var anchor:AnchorGeoPoint? = nil
        if let iconStr = args["new_icon"] as? [String: Any] {
            icon =  convertImage(codeImage: iconStr["icon"] as! String)
            iconSize = (iconStr["size"] as? [Int])!.toMarkerSize()
        }
        if let _angle = args["angle"] as? Double {
            angle = Float(_angle)
        }
        if let _anchor = args["iconAnchor"]{
            anchor = AnchorGeoPoint(anchorMap: _anchor as! [String:Any])
        }
        self.mapOSM.markerManager.updateMarker(oldlocation: coordinate_old, newlocation: coordinate_new,
                                                    icon: icon,
                                                    iconSize: iconSize,
                                               angle: Float(angle), anchor: anchor?.compute())
        //(x:sizeIcon?.first,y:sizeIcon?.last) as? MarkerIconSize
    }
    func updateMarkerIcon(call:FlutterMethodCall){
        let args = call.arguments as! [String: Any]
        var icon:UIImage?
        var iconSize:MarkerIconSize?
        if (args.keys.contains("icon")) {
            let iconArg = args["icon"] as! [String: Any]
             icon = convertImage(codeImage: iconArg["icon"] as! String)
            // MarkerIconData(image: , size:)
            iconSize = (iconArg["size"] as? [Int])!.toMarkerSize()
            
        }
        let coordinate = (args["point"] as! GeoPoint).toLocationCoordinate()
        self.mapOSM.markerManager.updateMarker(oldlocation: coordinate,newlocation: coordinate ,icon: icon,iconSize: iconSize)
    }
    func deleteMarkers(call:FlutterMethodCall){
        let geoPoints = (call.arguments as! [GeoPoint]).map { point -> CLLocationCoordinate2D in
            point.toLocationCoordinate()
        }
        geoPoints.forEach { location in
            self.mapOSM.markerManager.removeMarker(location: location)
        }
    }
    func deleteMarker(call:FlutterMethodCall){
        let location = (call.arguments as! GeoPoint).toLocationCoordinate()
        self.mapOSM.markerManager.removeMarker(location: location)
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
                self.mapOSM.zoomIn(step: 1)
                
            }else if stepZ == -1 {
                self.mapOSM.zoomOut(step: 1)
            }else if stepZ < -1 {
                self.mapOSM.zoomOut(step: Int(stepZ))
            }

        } else {
            let levelZoom = args["zoomLevel"] as! Double

            self.mapOSM.setZoom(zoom: Int(levelZoom))

        }
    }
    func configZoomMap(call: FlutterMethodCall){
        let zoomArgs = (call.arguments as! [String:Double]).mapValues(Int.init)
        self.zoomConfig = ZoomConfiguration(zoomArgs)
    }
    func getMapBounds(result: @escaping FlutterResult){
        let boundingBox = self.mapOSM.getBoundingBox()
        result(["north":boundingBox.north,"south":boundingBox.south,"east":boundingBox.east,"west":boundingBox.west])
    }
    func zoomMapToBoundingBox(call: FlutterMethodCall){
        let bbox = call.arguments as! [String: Double]
        let boundingBox = BoundingBox(north: bbox["north"]!,west: bbox["west"]!, east: bbox["east"]!, south: bbox["south"]!)
        self.mapOSM.moveToByBoundingBox(bounds: boundingBox, animated: true)
    }
    func setCameraAreaLimit(call: FlutterMethodCall){
        let bbox = call.arguments as! [Double]
        self.mapOSM.setBoundingBox(bounds: BoundingBox(boundingBoxs: bbox))
    }
    func removeCameraAreaLimit(result: @escaping FlutterResult){
        self.mapOSM.setBoundingBox(bounds: BoundingBox())
        result(200)
    }
    private func setMarkerStaticGeoPIcon(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        let id = args["id"] as! String
        let bitmapArg = args["bitmap"] as! [String: Any]
        let icon = convertImage(codeImage: bitmapArg["icon"] as! String)
        let iconSize = (bitmapArg["size"] as? [Int])?.toMarkerSize()
        self.mapOSM.poisManager.setOrCreateIconPoi(id: id, icon: icon!,iconSize: iconSize )
    }


    private func setStaticGeoPoint(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        let id = args["id"] as! String

        let listPois: [MarkerIconPoi] = (args["point"] as! [GeoPoint]).map { point -> MarkerIconPoi in
            var angle = Float(0)
            if (point.keys.contains("angle")) {
                angle = Float(point["angle"]! as Double)
            }
            let location = point.toLocationCoordinate()

            return MarkerIconPoi(location: location, angle: angle, anchor: nil)
        }

        self.mapOSM.poisManager.setMarkersPoi(id: id, markers: listPois)


    }
    func configureUserLocation (call:FlutterMethodCall){
        let args = call.arguments as! [String: Any]
        var personMarkerIcon:UIImage = UIImage()
        var directionMarkerIcon:UIImage?
        var personIconConfig:MarkerConfiguration!
        if let personIconString = args["personIcon"] {
            let iconArg = personIconString as! [String: Any]
            personMarkerIcon = convertImage(codeImage: iconArg["icon"] as! String) ?? UIImage()
            let personIconSize = (iconArg["size"] as? [Int])?.toMarkerSize()
            personIconConfig =  MarkerConfiguration(icon: personMarkerIcon, iconSize: personIconSize, angle: nil, anchor: nil)
            
        }
        var directionMarkerConfiguration:MarkerConfiguration? = nil
        if let arrowDirectionIconString = args["arrowDirectionIcon"] {
            let iconArg = arrowDirectionIconString as! [String: Any]
            directionMarkerIcon = convertImage(codeImage: iconArg["icon"] as! String)
            let directionIconSize = (iconArg["size"] as? [Int])?.toMarkerSize()
            directionMarkerConfiguration = MarkerConfiguration(icon: directionMarkerIcon!,
                                                               iconSize: directionIconSize,
                                                               angle: nil,
                                                               anchor: nil)
        }
        let userLocationConfig = UserLocationConfiguration(userIcon: personIconConfig,directionIcon: directionMarkerConfiguration )
        self.mapOSM.locationManager.setUserLocationIcons(userLocationIcons:userLocationConfig)
        
    }
    func startTrackUser(args:[Any]){
        let enableStopFollowInDrag = args.first as? Bool ?? false
        if(!enableStopFollowInDrag){
            canSkipFollow = false
            self.mapOSM.locationManager.requestEnableLocation()
        }
        let disableRotation = args[1] as? Bool ?? false
        let useDirectionMarker = args[2] as? Bool ?? false
        let anchor = args[3] as? [Double] ?? [0.5,0.5]
        
        let markerAnchor = AnchorGeoPoint(anchor: (x:anchor.first!,y:anchor.last!)).compute()
        let userIconLoc = self.mapOSM.locationManager.userLocationIconConfiguration.userIcon
        let directionIconLoc = self.mapOSM.locationManager.userLocationIconConfiguration.directionIcon
        let userLocConfig = self.mapOSM.locationManager.userLocationIconConfiguration.copyWith(
            userIcon: userIconLoc.copyWith(
                anchor: markerAnchor
            ),
            directionIcon: directionIconLoc?.copyWith(
                anchor: markerAnchor
            )
        )
        self.mapOSM.locationManager.setUserLocationIcons(userLocationIcons: userLocConfig)
        //self.mapOSM.enableRotation(enable: !disableRotation)
        if(!self.mapOSM.locationManager.isTrackingEnabled()) {
            self.mapOSM.locationManager.toggleTracking(configuration: TrackConfiguration(moveMap:  true,
                                        useDirectionMarker: useDirectionMarker,
                                        disableMarkerRotation: disableRotation
                                ))
        }
    }
    func stopTracking(){
        self.mapOSM.locationManager.toggleTracking(configuration: TrackConfiguration())
        self.mapOSM.locationManager.stopLocation()
    }
    private func getGeoPoints(_ result: FlutterResult) {
        let list: [GeoPoint] = self.mapOSM.markerManager.getAllMarkers().map { location in
            location.toGeoPoint()
        }
        result(list)
    }
    func drawShape(args: Any?, result: @escaping FlutterResult,shapeType:ShapeTypes){
        let rectJson = args as! [String:Any]
        //print(pointInit)
        //let initZoom =
        let key = rectJson["key"] as! String
        let shape:PShape
        switch (shapeType)  {
            case .Rect:
                shape =  RectShapeOSM.fromMap(json: rectJson)
            case .Circle:
                shape = RectShapeOSM.fromMap(json: rectJson)
            default:
                shape =  RectShapeOSM.fromMap(json: rectJson)
        }
        mapOSM.shapeManager.drawShape(key: key, shape: shape)
        result(200)
    }
    func onTap(roadId: String) {
        let roadSelected = storedRoads[roadId]
        if let road = roadSelected {
            var mapInfo = road.roadInformation?.toMap(instructions: road.instructions) ?? [:]
            mapInfo["key"] = roadId
            DispatchQueue.main.async {
                self.channel.invokeMethod("receiveRoad", arguments: mapInfo)
            }
            
        }else {
            DispatchQueue.main.async {
                self.channel.invokeMethod("receiveRoad", arguments: ["key":roadId])
            }
            
        }
    }
    func onMove(center: CLLocationCoordinate2D, bounds: BoundingBox, zoom: Double) {
        let data: [String: Any] = ["center": center.toGeoPoint(), "bounding": bounds.toMap()]
        if self.mapOSM.locationManager.isTrackingEnabled() && !isMovedToLocation
            && latestUserLocation != nil && latestUserLocation! - center {
            isMovedToLocation = true
        }
        DispatchQueue.main.async {
            self.channel.invokeMethod("receiveRegionIsChanging", arguments: data)
        }
    }
    
    func onRotate(angle: Double) {
        
    }
    func onMapInteraction() {
         if self.mapOSM.locationManager.isTrackingEnabled() && isMovedToLocation
                && latestUserLocation != nil && !canSkipFollow && !userLocationWithoutControl  {
             canSkipFollow = true
            self.mapOSM.stopCamera()
        }
    }
    
    func locationChanged(userLocation: CLLocationCoordinate2D, heading: Double) {
        let geoMap = userLocation.toUserLocation(heading: heading)
        latestUserLocation = userLocation
        channel.invokeMethod("receiveUserLocation", arguments: geoMap)
        if ((!isMovedToLocation || !canSkipFollow) && !userLocationWithoutControl && mapInitialized) {
            self.mapOSM.locationManager.moveToUserLocation(animated: true)
        }
        
        if let result = resultFlutter {
            result(geoMap)
            resultFlutter = nil
        }
    }
    
    func handlePermission(state: OSMFlutterFramework.LocationPermission) {
        
    }
    
    func onTap(location: CLLocationCoordinate2D) {
        DispatchQueue.main.async {
            self.channel.invokeMethod("receiveGeoPoint", arguments: location.toGeoPoint())
        }
       
    }
    
    func onSingleTap(location: CLLocationCoordinate2D) {
        DispatchQueue.main.async {
            self.channel.invokeMethod("receiveSinglePress", arguments: location.toGeoPoint())
        }
        
    }
    
    func onLongTap(location: CLLocationCoordinate2D) {
        DispatchQueue.main.async {
            self.channel.invokeMethod("receiveLongPress", arguments: location.toGeoPoint())
        }
       
    }
}
extension MapCoreOSMView {
    func drawRoadMCOSM(call: FlutterMethodCall, completion: @escaping (_ roadInfo: RoadInformation?, _ road: Road?, _ roadData: RoadData?, _ boundingBox: BoundingBox?,_ polyline: Polyline?, _ error: Error?) -> ()) {
        let args = call.arguments as! [String: Any]
        var points = args["wayPoints"] as! [GeoPoint]
        var roadType = RoadType.car
        switch args["roadType"] as! String {
        case "car":
            roadType = RoadType.car
            break
        case "bike":
            roadType = RoadType.bike
            break
        case "foot":
            roadType = RoadType.foot
            break
        default:
            roadType = RoadType.car
            break
        }
        let key = args["key"] as? String
        /// insert middle point between start point and end point
        var intersectPoint = [GeoPoint]()
        if (args.keys.contains("middlePoints")) {
            intersectPoint = args["middlePoints"] as! [GeoPoint]
            points.insert(contentsOf: intersectPoint, at: 1)
        }
         var roadColor = self.roadColor
        if (args.keys.contains("roadColor")) {
            roadColor = args["roadColor"] as! String
        }
        var roadBorderColor:String? = nil
        if (args.keys.contains("roadBorderColor")) {
            roadBorderColor = args["roadBorderColor"] as! String?
        }
         var roadWidth = 5.0
        if (args.keys.contains("roadWidth")) {
            roadWidth = args["roadWidth"] as! Double
        }
         var roadBorderWidth = 0.0
        if (args.keys.contains("roadBorderWidth")) {
            roadBorderWidth = args["roadBorderWidth"] as! Double
        }

        let waysPoint = points.map { point -> String in
            let wayP = String(format: "%F,%F", point["lon"]!, point["lat"]!)
            return wayP
        }

        let zoomInto = args["zoomIntoRegion"] as! Bool

        roadManager.getRoad(wayPoints: waysPoint, typeRoad: roadType) { road in
            var error: Error? = nil
            if road == nil {
                error = NSError()
                completion(nil, nil, nil, nil,nil, error)

            }
            let roadInfo = RoadInformation(id:key!,distance: road!.distance, seconds: road!.duration, encodedRoute: road!.mRouteHigh)
            let route: Polyline = Polyline(encodedPolyline: road!.mRouteHigh, precision: 1e5)

            var box: BoundingBox? = nil
            if (zoomInto) {
                box = route.coordinates?.toBounds()
            }
            let roadData = RoadData(roadColor: roadColor, roadWidth: roadWidth, 
                                    roadBorderWidth: roadBorderWidth, roadBorderColor: roadBorderColor)
            completion(roadInfo, road,roadData , box,route, nil)

        }

    }

    func drawRoadManually(call: FlutterMethodCall, result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let roadEncoded = args["road"] as! String

        var roadColor = "#ff0000"
        if (args.keys.contains("roadColor")) {
            roadColor = args["roadColor"] as! String
        }
        var roadWidth = 5.0
        if (args.keys.contains("roadWidth")) {
            roadWidth = args["roadWidth"] as! Double
        }
        let zoomInto = args["zoomIntoRegion"] as! Bool

        var road = Road()
        road.mRouteHigh = roadEncoded
        road.roadData = RoadData(roadColor: roadColor, roadWidth: roadWidth)
        let route: Polyline = Polyline(encodedPolyline: road.mRouteHigh, precision: 1e5)
        let roadKey = args["key"] as! String
        if route.coordinates != nil {
            let roadConfiguration = RoadConfiguration(width: Float(roadWidth), color: UIColor(hexString: roadColor) ?? .blue, borderColor: nil)
            self.mapOSM.roadManager.addRoad(id: roadKey, polylines: route.coordinates!, configuration: roadConfiguration)
            if (zoomInto) {
                let box = route.coordinates!.toBounds()
                self.mapOSM.moveToByBoundingBox(bounds: box, animated: true)
            }
        }
        result(200)
    }

    func drawMultiRoad(call: FlutterMethodCall, completion: @escaping (_ roadsInfo: [RoadInformation?], _ roads: [(String, Road, RoadData)?], Any?) -> ()) {
        let args = call.arguments as! [[String: Any]]
        var roadConfigs = [(String, RoadConfig)]()

        for item in args {
            var roadColor = roadColor
            if (item.keys.contains("roadColor")) {
                roadColor = item["roadColor"] as! String
            }
            var roadWidth = 5.0
            if (item.keys.contains("roadWidth")) {
                roadWidth = item["roadWidth"] as! Double
            }
            let conf = RoadConfig(wayPoints: (item["wayPoints"] as! [GeoPoint]),
                    intersectPoints: item["middlePoints"] as! [GeoPoint]?,
                    roadData: RoadData(roadColor: roadColor, roadWidth: roadWidth),
                    roadType: (item["roadType"] as! String).toRoadType)
            roadConfigs.append((item["key"] as! String, conf))
        }

        let group = DispatchGroup()
        var results = [(String, Road?)]()
        for (key, config) in roadConfigs {
            var wayPoints = config.wayPoints
            if config.intersectPoints != nil && !config.intersectPoints!.isEmpty {
                wayPoints.insert(contentsOf: config.intersectPoints!, at: 1)
            }
            group.enter()
            roadManager.getRoad(wayPoints: wayPoints.parseToPath(), typeRoad: config.roadType) { road in
                results.append((key, road))
                group.leave()
            }
        }
        group.notify(queue: .main) {
            var information = [RoadInformation?]()
            var roads = [(String, Road, RoadData)?]()
            for (index, res) in results.enumerated() {
                var roadInfo: RoadInformation? = nil
                var routeToDraw: (String, Road, RoadData)? = nil
                if let road = res.1 {
                    routeToDraw = (res.0, road, roadConfigs[index].1.roadData)
                    roadInfo = RoadInformation(id:res.0 ,distance: road.distance, seconds: road.duration, encodedRoute: road.mRouteHigh)
                }
                information.append(roadInfo)
                roads.append(routeToDraw)
            }
            completion(information, roads, nil)
        }

    }
    private func deleteRoad(call: FlutterMethodCall, result: FlutterResult) {

        let roadKey = call.arguments as! String?
        if roadKey == nil && lastRoadKey != nil {
            self.mapOSM.roadManager.removeRoad(id: lastRoadKey!)
            self.storedRoads.removeValue(forKey: lastRoadKey!)
        }
        if let key = roadKey {
            self.mapOSM.roadManager.removeRoad(id: key)
            self.storedRoads.removeValue(forKey: key)
        }
        result(200)
    }

}
class MapViewUIView:UIView{
    public override init(frame:CGRect){
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func layoutSubviews() {

        super.layoutSubviews()
    }
}

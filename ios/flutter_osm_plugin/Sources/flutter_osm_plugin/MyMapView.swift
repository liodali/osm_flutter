//
//  MyMapView.swift
//  Runner
//
//  Created by Dali on 6/12/20.
//  Copyright © 2020 The Chromium Authors. All rights reserved.
//


/*
 import Foundation
 import UIKit
 import MapKit
 import Flutter
 import Polyline
 
public class MyMapView: NSObject, FlutterPlatformView, CLLocationManagerDelegate, TGMapViewDelegate, TGRecognizerDelegate {
    
    
   


    let frame: CGRect
    let viewId: Int64
    let channel: FlutterMethodChannel
    let mapView: TGMapView
    let locationManager: CLLocationManager = CLLocationManager()
    let defaultMarker: MarkerIconData
    var markerIcon: MarkerIconData? = nil
    var personMarkerIcon: MarkerIconData? = nil
    var arrowDirectionIcon: MarkerIconData? = nil
    var isFollowUserLocation: Bool = false
    var canGetLastUserLocation = false
    var canTrackUserLocation = false
    var retrieveLastUserLocation = false
    var isAdvancedPicker = false
    var userLocation: MyLocationMarker? = nil
    var dictClusterAnnotation: [String: [StaticGeoPMarker]] = [String: [StaticGeoPMarker]]()
    var dictIconClusterAnnotation = [String: MarkerIconData]()

    var pickedLocationSingleTap: CLLocationCoordinate2D? = nil
    var roadPicked: RoadFolder? = nil
    var colorRoad: String = "#ff0000"
    var homeMarker: TGMarker? = nil
    var resultFlutter: FlutterResult? = nil
    var methodCall: FlutterMethodCall? = nil
    var uiSingleTapEventMap: UILongPressGestureRecognizer = UILongPressGestureRecognizer()
    lazy var roadManager: RoadManager = RoadManager()

    let mainView: UIStackView
    var pickerMarker: UIImageView? = nil
    var cacheMarkers: [TGMarker] = [TGMarker]()

    // var tileRenderer:MKTileOverlayRenderer!

    var stepZoom = 1.0
    var initZoom = 10.0
    var customTiles: [String: Any]? = nil
    var oldCustomTile: MyCustomTiles? = nil
    var bounds: [Double]? = nil
    var enableStopFollowInDrag: Bool = false
    var disableRotation: Bool = false
    var canSkipFollow: Bool = false
    var enableRotationGesture: Bool = false
    let urlStyle = "https://github.com/liodali/osm_flutter/raw/dc7424dacd77f4eced626abf64486d70fd03240d/assets/dynamic-styles.zip"
    var fromAsset = true
    var dynamicOSMPath:String? = nil
    var cameraUserLocationIsMoving:Bool = false
    var sceneID:Int32? = nil
    init(_ frame: CGRect, viewId: Int64, channel: FlutterMethodChannel, args: Any?,dynamicOSM:String?,defaultPin:String?) {
        self.frame = frame
        self.viewId = viewId
        self.channel = channel
        if(dynamicOSM == nil ){
            fromAsset = false
        }else {
            self.dynamicOSMPath = dynamicOSM
        }
        mapView = TGMapView()
        mapView.frame = frame
        mainView = UIStackView(arrangedSubviews: [mapView])
        if (args as? [String: Any]) != nil {
            if ((args as! [String: Any]).keys.contains("customTile")) {
                customTiles = (args as! [String: Any])["customTile"] as? [String: Any]

            }
            if ((args as! [String: Any]).keys.contains("bounds")) {
                bounds = (args as! [String: Any])["bounds"] as? [Double]
            }

            if ((args as! [String: Any]).keys.contains("enableRotationGesture")) {
                enableRotationGesture = (args as! [String: Any])["enableRotationGesture"] as! Bool
            }
        }
        let defaultIcon = UIImage(contentsOfFile: defaultPin!)!.imageResize(sizeChange: CGSize(width: 32, height: 48))
        self.defaultMarker = MarkerIconData(image: defaultIcon,
                                            size:[Int(defaultIcon.size.width),Int(defaultIcon.size.height)])
        self.markerIcon = defaultMarker
        //mapview.mapType = MKMapType.standard
        //mapview.isZoomEnabled = true
        //mapview.isScrollEnabled = true
        super.init()


        /// affect delegation
        mapView.mapViewDelegate = self

        mapView.gestureDelegate = self


        locationManager.delegate = self
        //
        //self.setupTileRenderer()
        // mapView.register(MKPinAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(GeoPointMap.self))
        // mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(StaticGeoPMarker.self))
        //mapView.register(StaticPointClusterAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(StaticGeoPMarker.self) )

        channel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) ->
                    Void in
            self.onListenMethodChannel(call: call, result: result)
        })
    }

    private func onListenMethodChannel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        //print(call.method)
        switch call.method {
        case "init#ios#map":
            // mapView.loadSceneAsync(from:URL.init(string: "https://drive.google.com/uc?export=download&id=1F67AW3Yaj5N7MEmMSd0OgeEK1bD69_CM")!, with: nil)
            // "https://firebasestorage.googleapis.com/v0/b/osm-resources.appspot.com/o/osm-style.zip?alt=media&token=30e0c9fe-af0b-4994-8a73-2d31057014d4"
            // mapView.requestRender()
            var sceneUpdates = [TGSceneUpdate]()
            //var urlStyle = "https://github.com/liodali/osm_flutter/raw/0.40.0/assets/osm-style.zip"

            if (customTiles != nil) {
                let tile = MyCustomTiles(customTiles!)
                if oldCustomTile == nil {
                    oldCustomTile = tile
                }
                sceneUpdates.append(TGSceneUpdate(path: "global.url", value: tile.tileURL))
                sceneUpdates.append(TGSceneUpdate(path: "global.url_subdomains", value: tile.subDomains))
                sceneUpdates.append(TGSceneUpdate(path: "global.tile_size", value: tile.tileSize))
                sceneUpdates.append(TGSceneUpdate(path: "global.max_zoom", value: tile.maxZoom))
                //sceneUpdates.append(TGSceneUpdate(path: "global.bounds", value: ""))
            }
            /*if(bounds != nil && bounds != [-180.0, 85, 180, -85]){
                //urlStyle = "https://firebasestorage.googleapis.com/v0/b/osm-resources.appspot.com/o/dynamic-styles2.zip?alt=media&token=73f812ac-129f-477f-8a5b-942a5d9f325a"
                urlStyle = "https://firebasestorage.googleapis.com/v0/b/osm-resources.appspot.com/o/dynamic-styles2.zip?alt=media&token=e54cd48e-537a-4586-a801-26cf6ce6af96"
                //let sBounds = "["+bounds!.map {"\($0)"}.reduce(",") { $0 + $1 }+"]"
                //sceneUpdates.append(TGSceneUpdate(path: "global.bounds", value: "[5.9559113, 45.817995, 10.4922941, 47.8084648]"))//bounds!.description))
            }*/

            // let sceneUpdates = [TGSceneUpdate(path: "global.sdk_api_key", value: "qJz9K05vRu6u_tK8H3LmzQ")]
            // let sceneUrl = URL(string: "https://www.nextzen.org/carto/bubble-wrap-style/9/bubble-wrap-style.zip")!
            if (fromAsset){
                //let urlRes = URL(resource: URLResource(name: dynamicOSMPath!))!
                let url = Bundle.main.url(forAuxiliaryExecutable: dynamicOSMPath!)!
                //(forResource: dynamicOSMPath!,withExtension: "yaml")!
                mapView.loadScene(from: url,with: sceneUpdates)
                //mapView.loadScene(from: url,with: sceneUpdates)
                
            }else {
                let sceneUrl = URL(string: urlStyle)! // "https://dl.dropboxusercontent.com/s/25jzvtghx0ac2rk/osm-style.zip?dl=0")!
                mapView.loadScene(from: sceneUrl, with: sceneUpdates)
           }
            
        
            //channel.invokeMethod("map#init", arguments: true)
            result(200)
            break
        case "change#tile":
            let args = call.arguments as! [String: Any]?
            let url =  if (fromAsset){
                Bundle.main.url(forAuxiliaryExecutable: dynamicOSMPath!)!
            } else {
                URL(string: urlStyle)!
            }
            if args == nil && oldCustomTile != nil {
                mapView.updateOrResetScene(customTile: nil, url: url)
                oldCustomTile = nil
            }
            if let customTileArgs = args {
                let tile = MyCustomTiles(customTileArgs)
                if oldCustomTile == nil || (oldCustomTile != nil && oldCustomTile?.tileURL != tile.tileURL) {
                    mapView.updateOrResetScene(customTile: tile, url: url)
                    oldCustomTile = tile
                }

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
            bounds = nil
            result(200)
            break;
        case "changePosition":
            changePosition(args: call.arguments, result: result)
            break;
        case "currentLocation":
            currentUserLocation()
            result(200)
            break;
        case "map#center":
            result(mapView.position.toGeoPoint())
            break;
        case "trackMe":
            let args = call.arguments as! [Any]
            enableStopFollowInDrag = args.first as? Bool ?? false
            disableRotation = args[1] as? Bool ?? false
            let anchorArgs = args.last as? String ?? "center"
            MyLocationMarker.defaultAnchorStr = anchorArgs
            trackUserLocation()
            result(200)
            break;
        case "user#position":
            checkLocationPermission { [self] in
                retrieveLastUserLocation = true
                resultFlutter = result
            }
            break;
        case "goto#position":
            goToSpecificLocation(call: call, result: result)
            break;
        case "map#bounds":
            getMapBounds(result: result)
            break;
        /*case "user#pickPosition":
            //let frameV = UIView()
            methodCall = call
            resultFlutter = result
            break;*/
        case "user#removeMarkerPosition":
            removeMarkerFromMap(call: call)
            result(200)
            break;
        case "deactivateTrackMe":
            deactivateTrackMe()
            result(200)
            break;
        case "Zoom":
            let args = call.arguments! as! [String: Any]
            var step = stepZoom
            if (args.keys.contains("stepZoom")) {
                let stepZ = args["stepZoom"] as! Double
                if (stepZ == 0 || stepZ == -1) {
                    if (stepZ == -1) {
                        step = -step
                    }
                } else {
                    step = stepZ
                }

                zoomMap(step, nil)
            } else {
                let levelZoom = args["zoomLevel"] as! Double

                zoomMap(nil, levelZoom)

            }

            result(nil)
            break;
        case "get#Zoom":
            result(getZoom())
            break;
        case "change#stepZoom":
            stepZoom = call.arguments! as! Double
            result(200)
            break;
        case "zoomToRegion":
            zoomMapToBoundingBox(call: call)
            result(200)
            break;
        case "marker#icon":
            let args = call.arguments as! [String: Any]
            let image = convertImage(codeImage: args["icon"] as! String)
            markerIcon = MarkerIconData(image: image, size: args["size"] as? [Int])
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
            drawRoad(call: call) { [unowned self] roadInfo, road, roadData, box, error in
                if (error != nil) {
                    result(FlutterError(code: "400", message: "error to draw road", details: nil))
                } else {
                    var newRoad = road
                    newRoad?.roadData = roadData!
                    let roadKey = (call.arguments as! [String: Any])["key"] as! String
                    _ = roadManager.drawRoadOnMap(roadKey: roadKey, on: newRoad!, for: mapView, roadInfo: roadInfo, polyLine: nil)
                    if let bounding = box {
                        mapView.cameraPosition = mapView.cameraThatFitsBounds(bounding, withPadding: UIEdgeInsets.init(top: 25.0, left: 25.0, bottom: 25.0, right: 25.0))
                    }
                    let instructions = road?.toInstruction() ?? [RoadInstruction]()
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
                    roadManager.drawMultiRoadsOnMap(on: roads, for: mapView)
                    let infos = roadInfos.filter { info in
                                info != nil
                            }
                            .enumerated()
                            .map { (index, info) -> [String: Any] in
                                let instructions = roads[index].1.toInstruction()
                                return info!.toMap(instructions: instructions)
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
            roadManager.clearRoads(for: mapView)
            result(200)
            break;
        case "advancedPicker#marker#icon":
            setCustomIconMarker(call: call, result: result)
            break;
        case "advanced#selection":
            startAdvancedPicker(call: call, result: result)
            break;
        case "get#position#advanced#selection":
            getCenterSelection(call: call, result: result)
            break;
        case "confirm#advanced#selection":
            getCenterSelection(call: call, result: result, isFinished: true)
            break;
        case "cancel#advanced#selection":
            cancelAdvancedPickerMarker()
            result(200)
            break;
        case "map#orientation":
            rotateMap(call: call)
            result(200)
            break;
        case "user#locationMarkers":
            setUserLocationMarker(call: call)
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
        default:
            result(nil)
            break;
        }
    }


    public func view() -> UIView {
        //let view = UIStackView(arrangedSubviews: [mapView])
        return mainView
    }


    private func getGeoPoints(_ result: FlutterResult) {
        let list: [TGMarker] = mapView.markers.filter { marker in
            marker.stylingString.contains("points") && dictClusterAnnotation.values.filter { (v: [StaticGeoPMarker]) in
                        v.map { (staticMarker: StaticGeoPMarker) -> CLLocationCoordinate2D in
                                    staticMarker.coordinate
                                }
                                .contains(marker.point)
                    }
                    .isEmpty
        }
        let points = list.map { marker in
            marker.point.toGeoPoint()
        }
        result(points)
    }

    private func setCameraAreaLimit(call: FlutterMethodCall) {
        let bbox = call.arguments as! [Double]
        bounds = bbox
        let bounds = TGCoordinateBounds(sw: CLLocationCoordinate2D(latitude: bbox[2], longitude: bbox[3]),
                ne: CLLocationCoordinate2D(latitude: bbox[0], longitude: bbox[1]))
        mapView.cameraThatFitsBounds(bounds, withPadding: UIEdgeInsets.init(top: 3.0, left: 3.0, bottom: 3.0, right: 3.0))
        //mapView.bounds
        //mapView.bounds = bounds

    }

    private func zoomMapToBoundingBox(call: FlutterMethodCall) {
        let bbox = call.arguments as! [String: Any]
        let bounds = TGCoordinateBounds(sw: CLLocationCoordinate2D(latitude: bbox["south"] as! Double, longitude: bbox["west"] as! Double),
                ne: CLLocationCoordinate2D(latitude: bbox["north"] as! Double, longitude: bbox["east"] as! Double))
        let padding = CGFloat(bbox["padding"] as! Int)
        mapView.cameraPosition = mapView.cameraThatFitsBounds(bounds, withPadding: UIEdgeInsets.init(top: padding, left: padding, bottom: padding, right: padding))
        //mapView.bounds
        //mapView.bounds = bounds

    }

    private func initPosition(args: Any?, result: @escaping FlutterResult) {
        let pointInit = args as! Dictionary<String, Double>
        //print(pointInit)
        let location = CLLocationCoordinate2D(latitude: pointInit["lat"]!, longitude: pointInit["lon"]!)
        //print("location : \(location)")
        mapView.cameraPosition = TGCameraPosition(center: location, zoom: CGFloat(initZoom), bearing: 0, pitch: 0)
        channel.invokeMethod("map#init", arguments: true)
        //mapView.fly(to: TGCameraPosition(center: location, zoom: CGFloat(initZoom), bearing: 0, pitch: 0), withDuration: 1.5)
        /*{ finish in
            self.
            // let marker = self.mapView.markerAdd()
            //self.mapView.markerRemove(marker)
            result(200)
        }*/
        result(200)
    }


    private func getMapBounds(result: FlutterResult) {
        let bounds = mapView.getBounds(width: mainView.bounds.width, height: mainView.bounds.height)
        result(bounds)
    }

    private func rotateMap(call: FlutterMethodCall) {
        let angle = call.arguments as! Double
        let cameraAngle = mapView.cameraPosition.bearing
        if (angle >= 0.0) {
            mapView.setCameraPosition(TGCameraPosition(center: mapView.position, zoom: mapView.zoom, bearing: CLLocationDirection(CGFloat(angle)), pitch: 0.0), withDuration: 0.2, easeType: TGEaseType.sine)
        }
    }

    private func changePosition(args: Any?, result: @escaping FlutterResult) {
        let pointInit = args as! Dictionary<String, Double>
        if (homeMarker != nil) {
            mapView.markerRemove(homeMarker!)
            mapView.requestRender()
            homeMarker = nil
        }
        let location = CLLocationCoordinate2D(latitude: pointInit["lat"]!, longitude: pointInit["lon"]!)
        mapView.fly(to: TGCameraPosition(center: location, zoom: mapView.zoom, bearing: 0, pitch: 0), withDuration: 0.2) { finish in
            if finish {
                let geoMarker = GeoPointMap(icon: self.markerIcon ?? self.defaultMarker, coordinate: location)
                _ = geoMarker.setupMarker(on: self.mapView)
                self.homeMarker = geoMarker.marker
            }
            result(200)
        }

        //result(200)
    }

    private func goToSpecificLocation(call: FlutterMethodCall, result: FlutterResult) {
        let point = call.arguments as! GeoPoint
        mapView.fly(to: TGCameraPosition(center: point.toLocationCoordinate(), zoom: mapView.zoom, bearing: 0, pitch: 0),
                withDuration: 0.2)
        result(200)
    }

    private func addMarkerManually(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        if (args.keys.contains("icon")) {
            let iconArg = args["icon"] as! [String: Any]
            let icon = MarkerIconData(image: convertImage(codeImage: iconArg["icon"] as! String), size: iconArg["size"] as? [Int])
            let coordinate = (args["point"] as! GeoPoint).toLocationCoordinate()
            let point = args["point"] as! GeoPoint
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
           _ = GeoPointMap(icon: icon, coordinate: coordinate, angle: angle, anchor: anchor).setupMarker(on: mapView)
        }
    }

    private func changePositionMarker(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        let coordinate_old = (args["old_location"] as! GeoPoint).toLocationCoordinate()
        let coordinate_new = (args["new_location"] as! GeoPoint).toLocationCoordinate()
        var icon: MarkerIconData = MarkerIconData(image: nil)
        var angle = 0
        var anchor:AnchorGeoPoint? = nil
        if let iconStr = args["new_icon"] as? [String: Any] {
            icon = MarkerIconData(image: convertImage(codeImage: iconStr["icon"] as! String), size: iconStr["size"] as? [Int])
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
        GeoPointMap(icon: icon, coordinate: coordinate_old, angle: angle,anchor: anchor)
                .changePositionMarker(on: mapView, mPosition: coordinate_new)
    }

    private func updateMarkerIcon(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        var icon = markerIcon
        if (args.keys.contains("icon")) {
            let iconArg = args["icon"] as! [String: Any]
            icon = MarkerIconData(image: convertImage(codeImage: iconArg["icon"] as! String), size: iconArg["size"] as? [Int])
        }
        let coordinate = (args["point"] as! GeoPoint).toLocationCoordinate()
        GeoPointMap(icon: icon!, coordinate: coordinate).changeIconMarker(on: mapView)
    }

    private func removeMarkerFromMap(call: FlutterMethodCall) {
        let point = call.arguments as! GeoPoint
        let markers = mapView.markers.filter { m in
            m.point == point.toLocationCoordinate()
        }
        markers.forEach { m in
            mapView.markerRemove(m)
        }
    }

    private func deleteMarkers(call: FlutterMethodCall) {
        let geoPoints = (call.arguments as! [GeoPoint]).map { point -> LocationCoordinate2D in
            point.toLocationCoordinate()
        }
        let markers = mapView.markers.filter { m in
            geoPoints.contains(m.point)
        }
        markers.forEach { m in
            mapView.markerRemove(m)
        }
    }

    private func currentUserLocation() {
        checkLocationPermission { [self] in
            canGetLastUserLocation = true
        }

    }

   

    

    private func zoomMap(_ step: Double?, _ level: Double?) {
        var zoomLvl: CGFloat? = nil
        if (step != nil) {
            zoomLvl = mapView.zoom + CGFloat(step!)
            if (zoomLvl! < mapView.minimumZoomLevel || zoomLvl! > mapView.maximumZoomLevel) {
                return;
            }
        } else {
            zoomLvl = CGFloat(level!)
        }
        let cameraPos = TGCameraPosition(center: mapView.position, zoom: zoomLvl!, bearing: mapView.bearing, pitch: mapView.pitch)!
        mapView.fly(to: cameraPos, withDuration: 0.2)


    }
    private func trackUserLocation() {
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        canTrackUserLocation = true
        if(!enableStopFollowInDrag){
            canSkipFollow = false
        }
    }
    private func deactivateTrackMe() {
        canTrackUserLocation = false
        canSkipFollow = false
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        if userLocation != nil && userLocation!.marker != nil {
            mapView.removeUserLocation(for: userLocation!.marker!)
        }
        userLocation = nil
        //mapView.showsUserLocation = false
    }

    private func setCustomIconMarker(call: FlutterMethodCall, result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let iconSize = args["size"] as! [Double]
        if args.keys.contains("icon") {
            let image = convertImage(codeImage: args["icon"] as! String) ?? defaultMarker.image
            
            pickerMarker = UIImageView(image: image)
            pickerMarker?.frame.size = CGSize(width: iconSize.first!, height: iconSize.last!)
        }else {
            pickerMarker = UIImageView(image: defaultMarker.image)
            pickerMarker?.frame.size = CGSize(width: 32, height: 48)

        }
        
        pickerMarker?.sizeThatFits(CGSize(width: iconSize.first!, height: iconSize.last!))
        result(200)
    }

    private func setUserLocationMarker(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        if let personIconString = args["personIcon"] {
            let iconArg = personIconString as! [String: Any]
            let icon = convertImage(codeImage: iconArg["icon"] as! String)
            personMarkerIcon = MarkerIconData(image: icon, size: iconArg["size"] as? [Int])
        }
        if let arrowDirectionIconString = args["arrowDirectionIcon"] {
            let iconArg = arrowDirectionIconString as! [String: Any]
            let icon = convertImage(codeImage: iconArg["icon"] as! String)
            arrowDirectionIcon = MarkerIconData(image: icon, size: iconArg["size"] as? [Int])
        }
    }


    private func setMarkerStaticGeoPIcon(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        let id = args["id"] as! String
        let bitmapArg = args["bitmap"] as! [String: Any]
        let icon = convertImage(codeImage: bitmapArg["icon"] as! String)
        dictIconClusterAnnotation[id] = MarkerIconData(image: icon!, size: bitmapArg["size"] as? [Int])
    }


    private func setStaticGeoPoint(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        let id = args["id"] as! String

        if (dictClusterAnnotation.keys.contains(id)) {
            dictClusterAnnotation[id]?.forEach { staticMarkers in
                if (staticMarkers.marker != nil) {
                    staticMarkers.marker?.visible = false
                    mapView.markerRemove(staticMarkers.marker!)
                }
            }
        }

        let listGeos: [StaticGeoPMarker] = (args["point"] as! [GeoPoint]).map { point -> StaticGeoPMarker in
            var angle = 0
            if (point.keys.contains("angle")) {
                angle = Int(CGFloat(point["angle"]! as Double).toDegrees)
            }
            let geo = StaticGeoPMarker(icon: dictIconClusterAnnotation[id]!,
                    coordinate: point.toLocationCoordinate(), angle: angle)

            return geo.addStaticGeosToMapView(for: geo, on: mapView)
        }

        dictClusterAnnotation[id] = listGeos


    }

    public func startAdvancedPicker(call: FlutterMethodCall, result: FlutterResult) {
        if (!isAdvancedPicker) {
            isAdvancedPicker = true
            // cacheMarkers.append(contentsOf: mapView.markers)
            // mapView.markerRemoveAll()
            for marker in mapView.markers {
                marker.visible = false
            }
            if (canTrackUserLocation) {
                deactivateTrackMe()
            }
            mapView.gestureDelegate = nil

//             if (pickerMarker == nil) {
//                 var image = UIImage(systemName: "markLocation")
//                 image = image?.withTintColor(.red)
//                 pickerMarker = UIImageView(image: image)
//             }
            //pickerMarker?.frame = CGRect(x: frame.width/2,y: frame.height/2,width: 32,height: 32)
            pickerMarker?.center = mainView.center
            if pickerMarker?.image == nil {
                pickerMarker?.image =  defaultMarker.image
            }
            mainView.addSubview(pickerMarker!)
            result(200)
        }
    }

    private func getCenterSelection(call: FlutterMethodCall, result: FlutterResult, isFinished: Bool = false) {
        if (isAdvancedPicker) {
            let coordinate = mapView.coordinate(fromViewPosition: mapView.center)
            result(["lat": coordinate.latitude, "lon": coordinate.longitude])
            if (isFinished) {

                if (homeMarker != nil) {
                    homeMarker?.visible = false
                    let isExist = mapView.markers.contains(homeMarker!)
                    if (isExist) {
                        mapView.markerRemove(homeMarker!)
                    }
                    homeMarker = nil
                }
                let geoMarker = GeoPointMap(icon: markerIcon!, coordinate: coordinate)
                homeMarker = geoMarker.setupMarker(on: mapView)
                cancelAdvancedPickerMarker()
                isAdvancedPicker = false
            }
        }
    }

    private func cancelAdvancedPickerMarker() {
        if (isAdvancedPicker) {
            /// remove picker from parent view
            pickerMarker?.removeFromSuperview()
            //pickerMarker = nil
            for marker in mapView.markers {
                marker.visible = true
            }
            /* cacheMarkers.forEach { marker in
                let m = mapView.markerAdd()
                m.stylingString = marker.stylingString
                if (marker.stylingString.contains("points")) {
                    m.point = marker.point

                }
                m.icon = marker.icon
                if (marker.stylingString.contains("lines")) {
                    m.polyline = marker.polyline
                }
                m.visible = marker.visible
            } */
            mapView.gestureDelegate = self
            cacheMarkers = [TGMarker]()
            isAdvancedPicker = false
        }
    }

    private func drawMultiRoad(call: FlutterMethodCall, completion: @escaping (_ roadsInfo: [RoadInformation?], _ roads: [(String, Road, RoadData)?], Any?) -> ()) {
        let args = call.arguments as! [[String: Any]]
        var roadConfigs = [(String, RoadConfig)]()

        for item in args {
            var roadColor = colorRoad
            if (item.keys.contains("roadColor")) {
                roadColor = item["roadColor"] as! String
            }
            var roadWidth = "5px"
            if (item.keys.contains("roadWidth")) {
                roadWidth = item["roadWidth"] as! String
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
                    roadInfo = RoadInformation(distance: road.distance, seconds: road.duration, encodedRoute: road.mRouteHigh)
                }
                information.append(roadInfo)
                roads.append(routeToDraw)
            }
            completion(information, roads, nil)
        }

    }

    private func drawRoad(call: FlutterMethodCall, completion: @escaping (_ roadInfo: RoadInformation?, _ road: Road?, _ roadData: RoadData?, _ boundingBox: TGCoordinateBounds?, _ error: Error?) -> ()) {
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

        /// insert middle point between start point and end point
        var intersectPoint = [GeoPoint]()
        if (args.keys.contains("middlePoints")) {
            intersectPoint = args["middlePoints"] as! [GeoPoint]
            points.insert(contentsOf: intersectPoint, at: 1)
        }
        var roadColor = colorRoad
        if (args.keys.contains("roadColor")) {
            roadColor = args["roadColor"] as! String
        }
        var roadBorderColor = roadColor
        if (args.keys.contains("roadBorderColor")) {
            roadBorderColor = args["roadBorderColor"] as! String
        }
        var roadWidth = "5px"
        if (args.keys.contains("roadWidth")) {
            roadWidth = args["roadWidth"] as! String
        }
        var roadBorderWidth = "0px"
        if (args.keys.contains("roadBorderWidth")) {
            roadBorderWidth = args["roadBorderWidth"] as! String
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
                completion(nil, nil, nil, nil, error)

            }
            let roadInfo = RoadInformation(distance: road!.distance, seconds: road!.duration, encodedRoute: road!.mRouteHigh)

            var box: TGCoordinateBounds? = nil
            if (zoomInto) {
                let route: Polyline = Polyline(encodedPolyline: road!.mRouteHigh, precision: 1e5)
                box = route.coordinates?.toBounds()
            }

            completion(roadInfo, road, RoadData(roadColor: roadColor, roadWidth: roadWidth, roadBorderWidth: roadBorderWidth, roadBorderColor: roadBorderColor), box, nil)

        }

    }

    private func drawRoadManually(call: FlutterMethodCall, result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let roadEncoded = args["road"] as! String

        var roadColor = "#ff0000"
        if (args.keys.contains("roadColor")) {
            roadColor = args["roadColor"] as! String
        }
        var roadWidth = "5px"
        if (args.keys.contains("roadWidth")) {
            roadWidth = args["roadWidth"] as! String
        }
        let zoomInto = args["zoomIntoRegion"] as! Bool

        var road = Road()
        road.mRouteHigh = roadEncoded
        road.roadData = RoadData(roadColor: roadColor, roadWidth: roadWidth)
        let route: Polyline = Polyline(encodedPolyline: road.mRouteHigh, precision: 1e5)
        let roadKey = args["key"] as! String
        let roadLayer = roadManager.drawRoadOnMap(roadKey: roadKey, on: road, for: mapView, roadInfo: nil, polyLine: route)
        if (zoomInto) {
            let box = route.coordinates!.toBounds()
            mapView.cameraPosition = mapView.cameraThatFitsBounds(box, withPadding: UIEdgeInsets.init(top: 25.0, left: 25.0, bottom: 25.0, right: 25.0))
        }
        result(nil)
    }


    private func deleteRoad(call: FlutterMethodCall, result: FlutterResult) {

        let roadKey = call.arguments as! String?
        if roadKey == nil {
            roadManager.removeLastRoad(for: mapView)
        }
        if let key = roadKey {
            roadManager.removeRoadByKey(key: key, for: mapView)
        }
        result(200)
    }


    // ------- delegation func ----

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if (canGetLastUserLocation || canTrackUserLocation) {
            if let location = locations.last?.coordinate {
                //mapView.setRegion(region, animated: true)
                if (canTrackUserLocation) {
                    if (userLocation == nil) {
                        userLocation = mapView.addUserLocation(
                            for: location, on: mapView,
                            personIcon: personMarkerIcon,
                            arrowDirection: arrowDirectionIcon,
                            anchor: MyLocationMarker.defaultAnchorStr
                        )
                        //userLocation?.setDirectionArrow(personIcon: personMarkerIcon, arrowDirection: arrowDirectionIcon)
                    }
                    if (userLocation?.anchor?.anchor.rawValue != MyLocationMarker.defaultAnchorStr) {
                        // setAnchor should be done after adding user location marker
                        userLocation?.setAnchorLocation(MyLocationMarker.defaultAnchorStr)
                    }
                    if (!disableRotation) {
                        let angle = CGFloat(manager.heading?.trueHeading ?? 0.0).toDegrees
                        if (angle != 0) {
                            userLocation?.rotateMarker(angle: Int(angle))
                        }
                    }
                    userLocation?.marker?.point = location
                    
                }
                let geoMap = ["lon": location.longitude, "lat": location.latitude]
                channel.invokeMethod("receiveUserLocation", arguments: geoMap)
                
                if (canGetLastUserLocation) {
                    canGetLastUserLocation = false
                }
                if !canSkipFollow {
                    cameraUserLocationIsMoving = true
                    mapView.flyToUserLocation(for: location) { [self] end in
                            //canSkipFollow = true
                            cameraUserLocationIsMoving = false

                    }
                }


            }
        } else if (retrieveLastUserLocation) {
            if let location = locations.last?.coordinate {
                let geoMap = ["lon": location.longitude, "lat": location.latitude]
                resultFlutter!(geoMap)
                retrieveLastUserLocation = false
                resultFlutter = nil
            } else {
                resultFlutter!(nil)
            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {

        if status == CLAuthorizationStatus.authorizedWhenInUse {
            manager.requestLocation()
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
    }
    
    
   
    
    public func mapView(_ mapView: TGMapView,
                        didSelectMarker markerPickResult: TGMarkerPickResult?,
                        atScreenPosition position: CGPoint) {
        //print("marker picked")
        //print("receive pick  x: \(position.x) y: \(position.y)")
        if let marker = markerPickResult?.marker {
            let points = mapView.markers.filter { m in
                m.stylingString.contains("points")
            }
            let lines = mapView.markers.filter { m in
                m.stylingString.contains("lines")
            }
            let isExist = points.contains { m in
                m.point == marker.point
            }
            let isExistLineInteractive = lines.contains { line in
                line.polyline == marker.polyline
            }
            if isExist {
                channel.invokeMethod("receiveGeoPoint", arguments: marker.point.toGeoPoint())
            }
            if isExistLineInteractive {
                //marker.
                let road = roadManager.hasTGMarkerPoylines()
                    .first(where: { road in road.tgRouteLayer.tgMarkerPolyline! == marker.polyline  })
                channel.invokeMethod("receiveRoad", arguments: road?.toMap() ?? [])
            }

        } else {
            let point = pickedLocationSingleTap!// mapView.coordinate(fromViewPosition: position)

            channel.invokeMethod("receiveSinglePress", arguments: point.toGeoPoint())
            pickedLocationSingleTap = nil

        }
    }
    public func mapView(_ mapView: TGMapView, didSelectFeature feature: [String : String]?, atScreenPosition position: CGPoint) {
       /* if feature != nil && feature!["type"] == "lines" {
            print(feature?.description)
            //
        }*/
        if let road = roadPicked {
            channel.invokeMethod("receiveRoad", arguments: road.toMap())
            roadPicked = nil
        }
    }

    public func mapView(_ view: TGMapView!, recognizer: UIGestureRecognizer!, shouldRecognizeRotationGesture location: CGPoint) -> Bool {
        enableRotationGesture
    }

    public func mapView(_ view: TGMapView!, recognizer: UIGestureRecognizer!, shouldRecognizePanGesture displacement: CGPoint) -> Bool {

        //let location = view.coordinate(fromViewPosition: displacement)
        if canTrackUserLocation && userLocation != nil {
            canSkipFollow = true
            mapView.notifyGestureDidEnd()
        }
        /*if let bound = bounds {
            let contain = bound.toBounds().contains(location: location)
            if !contain {
                view.notifyGestureDidEnd()
            }
            return contain
        }*/
        return true
    }


    public func mapView(_ mapView: TGMapView, regionDidChangeAnimated animated: Bool) {

       
        let point = mapView.coordinate(fromViewPosition: mapView.center).toGeoPoint()
        let bounding = mapView.getBounds(width: mainView.bounds.width, height: mainView.bounds.width)
        let data: [String: Any] = ["center": point, "bounding": bounding]
        channel.invokeMethod("receiveRegionIsChanging", arguments: data)

    }


    public func mapView(_ view: TGMapView!, recognizer: UIGestureRecognizer!,
                        didRecognizeSingleTapGesture location: CGPoint) {
       
        pickedLocationSingleTap = view.coordinate(fromViewPosition: location)
        if userLocation != nil && cameraUserLocationIsMoving {
            mapView.notifyGestureDidEnd()
            cameraUserLocationIsMoving = false
        }else{
            if roadManager.roads.isEmpty {
                mapView.setPickRadius(56)
                mapView.pickMarker(at: location)
            }else {
                
                var road:RoadFolder? = roadManager.roadContainCLLocationCoordinate2D(location: pickedLocationSingleTap!)
                if road != nil {
                    channel.invokeMethod("receiveRoad", arguments: road?.toMap() ?? [String: Any]())
                }else {
                    mapView.setPickRadius(56)
                    //print("pick  x: \(location.x) y: \(location.y)")
                    mapView.pickMarker(at: location)
                }
            }
        }
    }

    public func mapView(_ view: TGMapView!, recognizer: UIGestureRecognizer!,
                        didRecognizeLongPressGesture location: CGPoint) {
        let point = mapView.coordinate(fromViewPosition: location).toGeoPoint()
        channel.invokeMethod("receiveLongPress", arguments: point)

    }


    public func mapView(_ view: TGMapView!, recognizer: UIGestureRecognizer!,
                        shouldRecognizeDoubleTapGesture location: CGPoint) -> Bool {
        let locationMap = view.coordinate(fromViewPosition: location)
        view.fly(to: TGCameraPosition(center: locationMap, zoom: view.zoom + CGFloat(stepZoom), bearing: view.bearing, pitch: view.pitch), withDuration: 0.2)
        return true
    }
    public func mapView(_ mapView: TGMapView, didLoadScene sceneID: Int32, withError sceneError: Error?) {
        if self.sceneID == nil {
            channel.invokeMethod("map#init#ios", arguments: true)
            self.sceneID = sceneID
        }
    }
}

private extension MyMapView {
    func configZoomMap(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        stepZoom = args["stepZoom"] as! Double
        initZoom = args["initZoom"] as! Double
        mapView.minimumZoomLevel = CGFloat(args["minZoomLevel"] as! Double)
        mapView.maximumZoomLevel = CGFloat(args["maxZoomLevel"] as! Double)
    }

    func getZoom() -> Double {
        Double(mapView.zoom)
    }

    func checkLocationPermission(preCheck: (() -> Void)?) {
        if preCheck != nil {
            preCheck!()
        }
        if #available(iOS 14.0, *) {
            if locationManager.authorizationStatus == CLAuthorizationStatus.authorizedAlways ||
                       locationManager.authorizationStatus == CLAuthorizationStatus.authorizedWhenInUse {
                locationManager.requestLocation()
            } else {
                locationManager.requestWhenInUseAuthorization()
            }
        } else {
            if CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedAlways ||
                       CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedWhenInUse {
                locationManager.requestLocation()
            } else {
                locationManager.requestWhenInUseAuthorization()
            }
        }
    }
}

extension TGMapView {
    func updateOrResetScene(customTile: MyCustomTiles?, url: URL) {
        var sceneUpdates = [TGSceneUpdate]()
        if customTile != nil {
            sceneUpdates.append(TGSceneUpdate(path: "global.url", value: customTile!.tileURL))
            sceneUpdates.append(TGSceneUpdate(path: "global.url_subdomains", value: customTile!.subDomains))
            sceneUpdates.append(TGSceneUpdate(path: "global.tile_size", value: customTile!.tileSize))
            sceneUpdates.append(TGSceneUpdate(path: "global.max_zoom", value: customTile!.maxZoom))
            sceneUpdates.append(TGSceneUpdate(path: "global.bounds", value: ""))
        }
        
        //let sceneUrl = URL(string: urlStyle)!
        let markers = markers
        let zoomLevel = zoom
        loadScene(from: url, with: sceneUpdates)
        for oldMarker in markers {
            let marker = markerAdd()
            marker.stylingString = oldMarker.stylingString
            marker.point = oldMarker.point
            marker.icon = oldMarker.icon
            if (marker.stylingString.contains("lines")) {
                marker.polyline = oldMarker.polyline
            }
        }
        zoom = zoomLevel
    }
}
*/

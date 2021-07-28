//
//  MyMapView.swift
//  Runner
//
//  Created by Dali on 6/12/20.
//  Copyright © 2020 The Chromium Authors. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import Flutter
import TangramMap

public class MyMapView: NSObject, FlutterPlatformView, CLLocationManagerDelegate, TGMapViewDelegate, TGRecognizerDelegate {


    let frame: CGRect
    let viewId: Int64
    let channel: FlutterMethodChannel
    let mapView: TGMapView
    let locationManager: CLLocationManager = CLLocationManager()
    var markerIcon: UIImage? = nil
    var isFollowUserLocation: Bool = false
    var canGetLastUserLocation = false
    var canTrackUserLocation = false
    var retrieveLastUserLocation = false
    var isAdvancedPicker = false
    var userLocation: MyLocationMarker? = nil
    var dictClusterAnnotation = [String: [StaticGeoPMarker]]()
    var dictIconClusterAnnotation = [String: StaticMarkerData]()
    var roadMarkerPolyline: TGMarker? = nil
    lazy var markersIconsRoadPoint : [String:UIImage] = [String:UIImage]()
    var markerRoadPoint: [TGMarker] = []
    var colorRoad:String = "#ff0000"
    var homeMarker: TGMarker? = nil
    var resultFlutter: FlutterResult? = nil
    var methodCall: FlutterMethodCall? = nil
    var uiSingleTapEventMap: UILongPressGestureRecognizer = UILongPressGestureRecognizer()
    lazy var roadManager: RoadManager = RoadManager()

    let mainView: UIStackView
    var pickerMarker: UIImageView? = nil
    var cacheMarkers: [TGMarker] = [TGMarker]()

    // var tileRenderer:MKTileOverlayRenderer!

    var span = MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
    var zoomDefault = 0.9

    init(_ frame: CGRect, viewId: Int64, channel: FlutterMethodChannel, args: Any?) {
        self.frame = frame
        self.viewId = viewId
        self.channel = channel

        mapView = TGMapView()
        mapView.frame = frame
        mainView = UIStackView(arrangedSubviews: [mapView])
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
        print(call.method)
        switch call.method {
        case "init#ios#map":
            //mapView.loadSceneAsync(from:URL.init(string: "https://drive.google.com/uc?export=download&id=1F67AW3Yaj5N7MEmMSd0OgeEK1bD69_CM")!, with: nil)
            // mapView.requestRender()

            let sceneUpdates = [TGSceneUpdate(path: "global.sdk_api_key", value: "qJz9K05vRu6u_tK8H3LmzQ")]
            let sceneUrl = URL(string: "https://www.nextzen.org/carto/bubble-wrap-style/9/bubble-wrap-style.zip")!
           //var sceneUrl = URL(string: "https://download1490.mediafire.com/79k6g435fjgg/7wmbaskfom9undp/osm-style.zip")
            mapView.loadSceneAsync(from: sceneUrl, with: sceneUpdates)

            //channel.invokeMethod("map#init", arguments: true)
            result(200)
            break
        case "initMap":
            initPosition(args: call.arguments, result: result)
            break;
        case "limitArea":
            setCameraAreaLimit(call:call)
            result(200)
            break;
        case "remove#limitArea":
            break;
        case "changePosition":
            changePosition(args: call.arguments, result: result)
            break;
        case "currentLocation":
            currentUserLocation()
            result(200)
            break;
        case "trackMe":
            trackUserLocation()
            result(200)
            break;
        case "user#position":
            retrieveLastUserLocation = true
            resultFlutter = result
            locationManager.requestLocation()
            break;
        case "goto#position":
            goToSpecificLocation(call: call, result: result)
            break;
        case "user#pickPosition":
            //let frameV = UIView()
            methodCall = call
            resultFlutter = result
            break;
        case "deactivateTrackMe":
            deactivateTrackMe()
            result(200)
            break;
        case "Zoom":
            let levelZoom = call.arguments! as! Double
            if (levelZoom == 0 || levelZoom == -1) {
                var alpha: Double = -1
                if levelZoom == 0 {
                    alpha = 1
                }
                zoomMap(zoomDefault * alpha)
            } else {
                zoomMap(levelZoom)
            }
            result(nil)
            break;
        case "defaultZoom":
            zoomDefault = call.arguments! as! Double
            result(200)
            break;
        case "marker#icon":
            markerIcon = convertImage(codeImage: call.arguments as! String)!
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
        case "road#markers":
            setRoadMarkersIcon(call:call,result:result)
            break;
        case "road#color":
            colorRoad = call.arguments as! String
            result(200)
            break;
        case "road":
            drawRoad(call: call) { [unowned self] roadInfo, road, roadData, error in
                if (error != nil) {
                    result(FlutterError(code: "400", message: "error to draw road", details: nil))
                } else {
                    var newRoad = road
                    newRoad?.roadData = roadData!
                    roadManager.drawRoadOnMap(on: newRoad!, for: mapView)


                    result(roadInfo!.toMap())
                }

            }
            //result(["distance": 0, "duration": 0])
            break;
        case "drawRoad#manually":
            drawRoadManually(call: call, result: result)
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
        default:
            result(nil)
            break;
        }
    }




    private func setCameraAreaLimit(call: FlutterMethodCall) {
       let  bbox = call.arguments as! [Double]
        let bounds = TGCoordinateBounds(sw: CLLocationCoordinate2D(latitude: bbox[2], longitude: bbox[3]),
                ne: CLLocationCoordinate2D(latitude: bbox[0], longitude: bbox[1]))
        mapView.cameraThatFitsBounds(bounds, withPadding: UIEdgeInsets.init(top: 3.0, left: 3.0, bottom: 3.0, right: 3.0))
        //mapView.bounds
        //mapView.bounds = bounds

    }

    public func view() -> UIView {
        if #available(iOS 11.0, *) {
            /*  mapView.register(
                      MarkerView.self,
                      forAnnotationViewWithReuseIdentifier:
                      MKMapViewDefaultAnnotationViewReuseIdentifier)*/

        }
        //let view = UIStackView(arrangedSubviews: [mapView])

        return mainView
    }

    private func initPosition(args: Any?, result: @escaping FlutterResult) {
        let pointInit = args as! Dictionary<String, Double>
        print(pointInit)
        let location = CLLocationCoordinate2D(latitude: pointInit["lat"]!, longitude: pointInit["lon"]!)

        // mapView.cameraPosition = TGCameraPosition(center: location, zoom: CGFloat(11), bearing: 0, pitch: 0)
        channel.invokeMethod("map#init", arguments: true)
        mapView.fly(to: TGCameraPosition(center: location, zoom: 10.0, bearing: 0, pitch: 0),
                withDuration: 0.2)
        /*{ finish in
            self.
            // let marker = self.mapView.markerAdd()
            //self.mapView.markerRemove(marker)
            result(200)
        }*/
        result(200)
    }

    private func changePosition(args: Any?, result: @escaping FlutterResult) {
        let pointInit = args as! Dictionary<String, Double>
        if (homeMarker != nil) {
            mapView.markerRemove(homeMarker!)
            mapView.requestRender()
            homeMarker = nil
        }
        let location = CLLocationCoordinate2D(latitude: pointInit["lat"]!, longitude: pointInit["lon"]!)
        mapView.fly(to: TGCameraPosition(center: location, zoom: mapView.zoom, bearing: 0, pitch: 0), withDuration:0.2) { finish in
            let geoMarker = GeoPointMap(icon: self.markerIcon!,coordinate: location)
            geoMarker.setupMarker( on: self.mapView)
            self.homeMarker = geoMarker.marker
            result(200)
        }

        //result(200)
    }
    private func goToSpecificLocation(call: FlutterMethodCall, result: FlutterResult) {
        let point = call.arguments as! GeoPoint
        mapView.fly(to: TGCameraPosition(center: point.toLocationCoordinate(), zoom: mapView.zoom, bearing: 0, pitch: 0),
                 withDuration:0.2)

        result(200)

    }

    private func currentUserLocation() {
        locationManager.requestLocation()
        canGetLastUserLocation = true
    }

    private func trackUserLocation() {
        locationManager.startUpdatingLocation()
        canTrackUserLocation = true
    }

    private func convertImage(codeImage: String) -> UIImage? {
        let dataImage = Data(base64Encoded: codeImage)
        return UIImage(data: dataImage!)// Note it's optional. Don't force unwrap!!!
    }

    private func zoomMap(_ level: Double) {
        if (level > 0) {
            let cameraPos = TGCameraPosition(center: mapView.position, zoom: mapView.zoom + CGFloat(abs(level)), bearing: 0, pitch: 0)!
            mapView.fly(to: cameraPos, withDuration:0.2)
        } else {
            let cameraPos = TGCameraPosition(center: mapView.position, zoom: mapView.zoom - CGFloat(abs(level)), bearing: 0, pitch: 0)!
            mapView.fly(to: cameraPos, withDuration:0.2)

        }
    }

    private func setupTileRenderer() {}

    private func deactivateTrackMe() {
        canTrackUserLocation = false
        locationManager.stopUpdatingLocation()
        if userLocation != nil && userLocation!.marker != nil {
            mapView.removeUserLocation(for: userLocation!.marker!)
        }
        userLocation = nil
        //mapView.showsUserLocation = false
    }

    private func setCustomIconMarker(call: FlutterMethodCall, result: FlutterResult) {
        let image = convertImage(codeImage: call.arguments as! String)
        pickerMarker = UIImageView(image: image)
        result(200)
    }


    private func setMarkerStaticGeoPIcon(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        let id = args["id"] as! String
        let icon = convertImage(codeImage: args["bitmap"] as! String)
        dictIconClusterAnnotation[id] = StaticMarkerData(image: icon!)
    }


    private func setStaticGeoPoint(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        let id = args["id"] as! String


        let listGeos: [StaticGeoPMarker] = (args["point"] as! [GeoPoint]).map { point -> StaticGeoPMarker in
            let geo = StaticGeoPMarker(icon: dictIconClusterAnnotation[id]!.image,coordinate: point.toLocationCoordinate())

            return geo.addStaticGeosToMapView(for: geo, on: mapView)
        }

        dictClusterAnnotation[id] = listGeos


        // let clusterAnnotation = ClusterMarkerAnnotation(id: id,geos: listGeos)
        //mapView.addAnnotations(listGeos)
        // mapView.addAnnotation(clusterAnnotation)

    }

    public func startAdvancedPicker(call: FlutterMethodCall, result: FlutterResult) {
        if (!isAdvancedPicker) {
            isAdvancedPicker = true
            cacheMarkers += mapView.markers
            mapView.markerRemoveAll()
            if (canTrackUserLocation) {
                deactivateTrackMe()
            }

            if (pickerMarker == nil) {
                var image = UIImage(systemName: "markLocation")
                image = image?.withTintColor(.red)
                pickerMarker = UIImageView(image: image)
            }
            //pickerMarker?.frame = CGRect(x: frame.width/2,y: frame.height/2,width: 32,height: 32)
            pickerMarker?.center = mainView.center
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
                   let index = cacheMarkers.index(of:homeMarker!)
                    if(index != nil) {
                        cacheMarkers.remove(at: index!)
                    }
                    homeMarker = nil
                }
                let geoMarker = GeoPointMap(icon: markerIcon!, coordinate: coordinate)
                geoMarker.setupMarker(on: mapView)
                homeMarker = geoMarker.marker
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
            cacheMarkers.forEach { marker in
                let m = mapView.markerAdd()
                m.stylingString = marker.stylingString
                if(marker.stylingString.contains("points")) {
                    m.point = marker.point

                }
                m.icon = marker.icon
                if( marker.stylingString.contains("lines")){
                    m.polyline = marker.polyline
                }
                m.visible = marker.visible
            }
            cacheMarkers = [TGMarker]()
            isAdvancedPicker = false
        }
    }


    private func drawRoad(call: FlutterMethodCall, completion: @escaping (_ roadInfo: RoadInformation?, _ road: Road?, _ roadData: RoadData?, _ error: Error?) -> ()) {
        let args = call.arguments as! [String: Any]
        var points = args["wayPoints"] as! [GeoPoint]
        points.forEach { p in
            let markers = mapView.markers.filter { m in
                m.point == p.toLocationCoordinate()
            }
            markers.forEach { m in
                mapView.markerRemove(m)
            }
        }
        if(!markerRoadPoint.isEmpty){
           markerRoadPoint.forEach{ m in
               mapView.markerRemove(m)
           }
        }
        if(roadMarkerPolyline != nil ) {
            mapView.markerRemove(roadMarkerPolyline!)
            roadMarkerPolyline = nil
        }
        var intersectPoint = [GeoPoint]()
        if (args.keys.contains("middlePoint")) {
            intersectPoint = args["middlePoint"] as! [GeoPoint]
            points.insert(contentsOf: intersectPoint, at: 1)
        }
        var roadColor = colorRoad
        if (args.keys.contains("roadColor")) {
            roadColor = args["roadColor"] as! String
        }
        var roadWidth = "5px"
        if (args.keys.contains("roadWidth")) {
            roadWidth = args["roadWidth"] as! String
        }

        let waysPoint = points.map { point -> String in
            let wayP = String(format: "%F,%F", point["lon"]!, point["lat"]!)
            return wayP
        }
        roadManager.getRoad(wayPoints: waysPoint, typeRoad: RoadType.car) { road in
            var error: Error? = nil
            if road == nil {
                error = NSError()
                completion(nil, nil, nil, error)

            }
            let roadInfo = RoadInformation(distance: road!.distance, seconds: road!.duration)

            completion(roadInfo, road, RoadData(roadColor: roadColor, roadWidth: roadWidth), nil)
            if let showMarkerInPOI = args["showMarker"] as? Bool {
                if(showMarkerInPOI){
                    if let start = self.markersIconsRoadPoint["start"]{
                        let geoStartM = GeoPointMap(icon: start, coordinate: CLLocationCoordinate2D(latitude: points.first!["lat"]!, longitude: points.first!["lon"]!))
                        geoStartM.marker = geoStartM.setupMarker(on: self.mapView)
                        self.markerRoadPoint.append(geoStartM.marker!)
                    }
                    if let end = self.markersIconsRoadPoint["end"]{
                        let geoStartM = GeoPointMap(icon: end, coordinate: CLLocationCoordinate2D(latitude: points.last!["lat"]!, longitude: points.last!["lon"]!))
                        geoStartM.marker =  geoStartM.setupMarker(on: self.mapView)
                        self.markerRoadPoint.append(geoStartM.marker!)
                    }
                }

            }
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
            roadWidth = "\(args["roadWidth"] as! Double)px"
        }
        if(roadMarkerPolyline != nil ) {
            mapView.markerRemove(roadMarkerPolyline!)
            roadMarkerPolyline = nil
        }
        var road = Road()
        road.mRouteHigh = roadEncoded
        road.roadData = RoadData(roadColor: roadColor, roadWidth: roadWidth)

        let markerRoad = roadManager.drawRoadOnMap(on: road, for: mapView)
        roadMarkerPolyline = markerRoad
        result(nil)
    }

    private func setRoadMarkersIcon(call: FlutterMethodCall, result: FlutterResult) {
        let iconsBase64 = call.arguments as![String:String]
        if let startPointIconRoad = iconsBase64["START"] {
            markersIconsRoadPoint["start"] = convertImage(codeImage: startPointIconRoad)
        }
        if let startPointIconRoad = iconsBase64["MIDDLE"] {
            markersIconsRoadPoint["middle"] = convertImage(codeImage: startPointIconRoad)
        }
        if let startPointIconRoad = iconsBase64["END"] {
            markersIconsRoadPoint["end"] = convertImage(codeImage: startPointIconRoad)
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
                        userLocation = mapView.addUserLocation(for: location, on: mapView)
                    }
                    userLocation?.marker?.point = location
                    //userLocation?.marker?.point = location

                    //  mapView.showsUserLocation = true
                    let geoMap = ["lon": location.longitude, "lat": location.latitude]
                    channel.invokeMethod("receiveUserLocation", arguments: geoMap)
                }
                if (canGetLastUserLocation) {
                    canGetLastUserLocation = false
                }
                mapView.flyToUserLocation(for: location)

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

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
    }

    public func mapView(_ mapView: TGMapView, didSelectMarker markerPickResult: TGMarkerPickResult?, atScreenPosition position: CGPoint) {
        //print("marker picked")
        if let marker = markerPickResult?.marker{
            let  staticMarkers =  dictClusterAnnotation.map { k,  markers in  markers }
            if staticMarkers.contains {markers in markers.contains { staticMarker in staticMarker.marker?.point == marker.point} } {
                channel.invokeMethod("receiveGeoPoint", arguments: marker.point.toGeoPoint())
            }
        }else{
            let point = mapView.coordinate(fromViewPosition: position)

            channel.invokeMethod("receiveSinglePress", arguments: point.toGeoPoint())

        }
    }

    public func mapView(_ mapView: TGMapView, regionDidChangeAnimated animated: Bool) {
        if (!dictClusterAnnotation.isEmpty) {
            for gStaticMarker in dictClusterAnnotation {
                for (i, staticMarker) in gStaticMarker.value.enumerated() {
                    let m = staticMarker
                    if (mapView.zoom > 12) {
                        m.marker?.visible = true
                    } else {
                        m.marker?.visible = false
                    }
                    dictClusterAnnotation[gStaticMarker.key]![i] = m
                }
            }
        }
    }


    public func mapView(_ view: TGMapView!, recognizer: UIGestureRecognizer!,
                        didRecognizeSingleTapGesture location: CGPoint) {
        if (resultFlutter != nil && methodCall != nil && methodCall?.method == "user#pickPosition") {
            var iconM = markerIcon
            let dict: [String: Any] = methodCall?.arguments as! [String: Any]
            if let icon = dict["icon"] {
                iconM = convertImage(codeImage: icon as! String)
            }
            let coordinate = view.coordinate(fromViewPosition: location)
            let geoP = GeoPointMap(icon: iconM!, coordinate: coordinate)
            geoP.setupMarker( on: view)
            resultFlutter!(geoP.toMap())
            methodCall = nil
        }else{
            mapView.setPickRadius(48)
            mapView.pickMarker(at: location)

        }
    }

    public func mapView(_ view: TGMapView!, recognizer: UIGestureRecognizer!,
                        didRecognizeLongPressGesture location: CGPoint) {
        let point = mapView.coordinate(fromViewPosition: location)
        channel.invokeMethod("receiveLongPress", arguments: ["lat":point.latitude,"lon":point.longitude])

    }

    public func mapView(_ view: TGMapView!, recognizer: UIGestureRecognizer!,
                        shouldRecognizeDoubleTapGesture location: CGPoint) -> Bool {
        let locationMap = view.coordinate(fromViewPosition: location)
        view.fly(to: TGCameraPosition(center: locationMap, zoom: view.zoom + CGFloat(zoomDefault), bearing: view.bearing, pitch: view.pitch),withDuration:0.2)
        return true
    }

    public func mapView(_ view: TGMapView, recognizer: UIGestureRecognizer,
                        shouldRecognizeShoveGesture displacement: CGPoint) -> Bool {
        true
    }


}

private extension MKMapView {
    func centerToLocation(
            _ location: CLLocation,
            regionRadius: CLLocationDistance = 1000
    ) {
        let coordinateRegion = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: regionRadius,
                longitudinalMeters: regionRadius

        )
        setRegion(coordinateRegion, animated: true)
    }
}

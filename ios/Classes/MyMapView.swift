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
import Polyline

public class MyMapView: NSObject, FlutterPlatformView, CLLocationManagerDelegate, TGMapViewDelegate, TGRecognizerDelegate {


    let frame: CGRect
    let viewId: Int64
    let channel: FlutterMethodChannel
    let mapView: TGMapView
    let locationManager: CLLocationManager = CLLocationManager()
    var markerIcon: UIImage? = nil
    var personMarkerIcon: UIImage? = nil
    var arrowDirectionIcon: UIImage? = nil
    var isFollowUserLocation: Bool = false
    var canGetLastUserLocation = false
    var canTrackUserLocation = false
    var retrieveLastUserLocation = false
    var isAdvancedPicker = false
    var userLocation: MyLocationMarker? = nil
    var dictClusterAnnotation : [String: [StaticGeoPMarker]] = [String: [StaticGeoPMarker]]()
    var dictIconClusterAnnotation = [String: StaticMarkerData]()
    var roadMarkerPolyline: TGMarker? = nil
    lazy var markersIconsRoadPoint: [String: UIImage] = [String: UIImage]()
    var defaultIcon : UIImage?
    var pickedLocationSingleTap: CLLocationCoordinate2D? = nil
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

            let sceneUpdates = [TGSceneUpdate]()
            // let sceneUpdates = [TGSceneUpdate(path: "global.sdk_api_key", value: "qJz9K05vRu6u_tK8H3LmzQ")]
            // let sceneUrl = URL(string: "https://www.nextzen.org/carto/bubble-wrap-style/9/bubble-wrap-style.zip")!
            let sceneUrl = URL(string: "https://dl.dropboxusercontent.com/s/25jzvtghx0ac2rk/osm-style.zip?dl=0")!
            mapView.loadSceneAsync(from: sceneUrl, with: sceneUpdates)

            //channel.invokeMethod("map#init", arguments: true)
            result(200)
            break
        case "setDefaultIOSIcon":
            defaultIcon = convertImage(codeImage: call.arguments as! String)
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
        case "user#pickPosition":
            //let frameV = UIView()
            methodCall = call
            resultFlutter = result
            break;
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
            setRoadMarkersIcon(call: call, result: result)
            break;
        case "road#color":
            colorRoad = call.arguments as! String
            result(200)
            break;
        case "road":
            drawRoad(call: call) { [unowned self] roadInfo, road, roadData, box,interestPoints, error in
                if (error != nil) {
                    result(FlutterError(code: "400", message: "error to draw road", details: nil))
                } else {
                    var newRoad = road
                    newRoad?.roadData = roadData!
                    roadManager.drawRoadOnMap(on: newRoad!, for: mapView,polyLine: nil,interestPoints: interestPoints)
                    if let bounding = box {
                        mapView.cameraPosition = mapView.cameraThatFitsBounds(bounding, withPadding: UIEdgeInsets.init(top: 25.0, left: 25.0, bottom: 25.0, right: 25.0))
                    }
                    result(roadInfo!.toMap())
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
                            .map { roadAndRoadData -> Road in

                                var road = roadAndRoadData!.0
                                road.roadData = roadAndRoadData!.1
                                return road

                            }
                    roadManager.drawMultiRoadsOnMap(on: roads, for: mapView)
                    let infos = roadInfos.filter { info in
                                info != nil
                            }
                            .map { info -> [String: Any] in
                                info!.toMap()
                            }
                    result(infos)
                }

            }
            break;
        case "drawRoad#manually":
            drawRoadManually(call: call, result: result)
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
        case "get#geopoints":
            getGeoPoints(result)
            break;
        default:
            result(nil)
            break;
        }
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

    private func getGeoPoints(_ result: FlutterResult) {
        let list :[TGMarker] = mapView.markers.filter { marker in
            marker.stylingString.contains("points")  && dictClusterAnnotation.values.filter { (v: [StaticGeoPMarker]) in
                        v.map { (staticMarker: StaticGeoPMarker) -> CLLocationCoordinate2D in
                                    staticMarker.coordinate
                                }.contains(marker.point)
                    }.isEmpty
        }
        let points =  list.map { marker in
            marker.point.toGeoPoint()
        }
        result(points)
    }

    private func setCameraAreaLimit(call: FlutterMethodCall) {
        let bbox = call.arguments as! [Double]
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
        print("location : \(location)")
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
        if (angle > 0.0) {
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
            let geoMarker = GeoPointMap(icon: self.markerIcon!, coordinate: location)
            geoMarker.setupMarker(on: self.mapView)
            self.homeMarker = geoMarker.marker
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
        var icon = markerIcon
        if (args.keys.contains("icon")) {
            icon = convertImage(codeImage: args["icon"] as! String)
        }
        let coordinate = (args["point"] as! GeoPoint).toLocationCoordinate()
        GeoPointMap(icon: icon, coordinate: coordinate).setupMarker(on: mapView)
    }

    private func updateMarkerIcon(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        var icon = markerIcon
        if (args.keys.contains("icon")) {
            icon = convertImage(codeImage: args["icon"] as! String)
        }
        let coordinate = (args["point"] as! GeoPoint).toLocationCoordinate()
        GeoPointMap(icon: icon, coordinate: coordinate).changeIconMarker(on: mapView)
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

    private func currentUserLocation() {
        checkLocationPermission { [self] in
            canGetLastUserLocation = true
        }

    }

    private func trackUserLocation() {
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        canTrackUserLocation = true
    }

    private func convertImage(codeImage: String) -> UIImage? {
        let dataImage = Data(base64Encoded: codeImage)
        return UIImage(data: dataImage!)// Note it's optional. Don't force unwrap!!!
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

    private func setupTileRenderer() {
    }

    private func deactivateTrackMe() {
        canTrackUserLocation = false
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
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

    private func setUserLocationMarker(call: FlutterMethodCall) {
        let args = call.arguments as! [String: String]
        if let personIconString = args["personIcon"] {
            personMarkerIcon = convertImage(codeImage: personIconString)
        }
        if let arrowDirectionIconString = args["arrowDirectionIcon"] {
            arrowDirectionIcon = convertImage(codeImage: arrowDirectionIconString)
        }
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
                angle = Int(CGFloat(point["angle"] as! Double).toDegrees)
            }
            let geo = StaticGeoPMarker(icon: dictIconClusterAnnotation[id]!.image,
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

    private func drawMultiRoad(call: FlutterMethodCall, completion: @escaping (_ roadsInfo: [RoadInformation?], _ roads: [(Road, RoadData)?], Any?) -> ()) {
        let args = call.arguments as! [[String: Any]]
        var roadConfigs = [RoadConfig]()

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
            roadConfigs.append(conf)
        }

        let group = DispatchGroup()
        var results = [Road?]()
        for config in roadConfigs {
            var wayPoints = config.wayPoints
            if config.intersectPoints != nil && !config.intersectPoints!.isEmpty {
                wayPoints.insert(contentsOf: config.intersectPoints!, at: 1)
            }
            group.enter()
            roadManager.getRoad(wayPoints: wayPoints.parseToPath(), typeRoad: config.roadType) { road in
                results.append(road)
                group.leave()
            }
        }
        group.notify(queue: .main) {
            var informations = [RoadInformation?]()
            var roads = [(Road, RoadData)?]()
            for (index, res) in results.enumerated() {
                var roadInfo: RoadInformation? = nil
                var routeToDraw: (Road, RoadData)? = nil
                if let road = res {
                    routeToDraw = (road, roadConfigs[index].roadData)
                    roadInfo = RoadInformation(distance: road.distance, seconds: road.duration, encodedRoute: road.mRouteHigh)
                }
                informations.append(roadInfo)
                roads.append(routeToDraw)
            }
            completion(informations, roads, nil)
        }

    }

    private func drawRoad(call: FlutterMethodCall, completion: @escaping (_ roadInfo: RoadInformation?, _ road: Road?, _ roadData: RoadData?, _ boundingBox: TGCoordinateBounds?,_ interestPoinst:[GeoPointMap]?, _ error: Error?) -> ()) {
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
        points.forEach { p in
            let markers = mapView.markers.filter { m in
                m.point == p.toLocationCoordinate()
            }
            markers.forEach { m in
                mapView.markerRemove(m)
            }
        }
        if (!roadManager.roads.isEmpty) {
            roadManager.roads.forEach { folder in
                roadManager.removeRoadFolder(folder: folder, for: mapView)
            }
        }
        if (roadMarkerPolyline != nil) {
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

        let zoomInto = args["zoomIntoRegion"] as! Bool

        roadManager.getRoad(wayPoints: waysPoint, typeRoad: roadType) { road in
            var error: Error? = nil
            if road == nil {
                error = NSError()
                completion(nil, nil, nil, nil,nil, error)

            }
            let roadInfo = RoadInformation(distance: road!.distance, seconds: road!.duration, encodedRoute: road!.mRouteHigh)

            var box: TGCoordinateBounds? = nil
            if (zoomInto) {
                let route: Polyline = Polyline(encodedPolyline: road!.mRouteHigh, precision: 1e5)
                box = route.coordinates?.toBounds()
            }
            var interestGeoPoints:[GeoPointMap]? = nil
            if let showMarkerInPOI = args["showMarker"] as? Bool {
                if (showMarkerInPOI) {
                    interestGeoPoints = [GeoPointMap]()
                    let start = self.markersIconsRoadPoint["start"] ?? self.defaultIcon
                    let geoStartM = GeoPointMap(icon: start, coordinate: points.first!.toLocationCoordinate())
                    geoStartM.marker = geoStartM.setupMarker(on: self.mapView)
                    interestGeoPoints!.append(geoStartM)

                    if(points.count > 2 ){
                       let interestPs = points[1..<points.endIndex-1]
                        interestPs.forEach { p in
                            let icon = self.markersIconsRoadPoint["middle"]
                            let geoStartM = GeoPointMap(icon: icon, coordinate: p.toLocationCoordinate())
                            geoStartM.marker = geoStartM.setupMarker(on: self.mapView)
                            interestGeoPoints!.append(geoStartM)
                        }
                    }
                    let end = self.markersIconsRoadPoint["end"] ?? self.defaultIcon
                    let geoEndM = GeoPointMap(icon: end, coordinate:points.last!.toLocationCoordinate())
                    geoEndM.marker = geoEndM.setupMarker(on: self.mapView)
                    interestGeoPoints!.append(geoEndM)
                }

            }
            completion(roadInfo, road, RoadData(roadColor: roadColor, roadWidth: roadWidth), box,interestGeoPoints, nil)

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
        let zoomInto = args["zoomInto"] as! Bool
        let removeLastRoad = args["clearPreviousRoad"] as! Bool
        let iconMarker = args["iconInterestPoints"] as! String?
        if (removeLastRoad && roadMarkerPolyline != nil) {
            mapView.markerRemove(roadMarkerPolyline!)
            roadMarkerPolyline = nil
        }
        var road = Road()
        road.mRouteHigh = roadEncoded
        road.roadData = RoadData(roadColor: roadColor, roadWidth: roadWidth)
        let route : Polyline = Polyline(encodedPolyline: road.mRouteHigh, precision: 1e5)


        var interestGeoPoints:[GeoPointMap]? = nil

        if let encodedPoints = args["interestPoints"] as? String {
            var interestPoints  = Polyline(encodedPolyline: encodedPoints, precision: 1e5).coordinates!
            if (!interestPoints.isEmpty) {
                interestGeoPoints = [GeoPointMap]()
                    var start = markersIconsRoadPoint["start"] ?? defaultIcon


                    let geoStartM = GeoPointMap(icon: start, coordinate: route.coordinates!.first!)
                    geoStartM.marker = geoStartM.setupMarker(on: mapView)
                    interestGeoPoints!.append(geoStartM)

                if interestPoints.first == route.coordinates!.first! {
                    interestPoints.removeFirst()
                }
                if interestPoints.last == route.coordinates!.last! {
                    interestPoints.removeLast()
                }
                interestPoints.forEach{ p in
                    var icon = markersIconsRoadPoint["middle"] ?? defaultIcon
                    if iconMarker != nil {
                        icon = convertImage(codeImage: iconMarker!)
                    }
                    let geoMiddle = GeoPointMap(icon: icon, coordinate: p)
                    geoMiddle.marker = geoMiddle.setupMarker(on: mapView)
                    interestGeoPoints!.append(geoMiddle)
                }

                var end = markersIconsRoadPoint["end"] ?? defaultIcon
                if end == nil {
                    end = convertImage(codeImage: iconMarker!)
                }
                let geoEndM = GeoPointMap(icon: end, coordinate: route.coordinates!.last!)
                geoEndM.marker = geoEndM.setupMarker(on: mapView)
                interestGeoPoints!.append(geoEndM)
            }

        }
        let markerRoad = roadManager.drawRoadOnMap(on: road, for: mapView,polyLine: route,interestPoints: interestGeoPoints)
        roadMarkerPolyline = markerRoad
        if (zoomInto) {
            let box = route.coordinates!.toBounds()
            mapView.cameraPosition = mapView.cameraThatFitsBounds(box, withPadding: UIEdgeInsets.init(top: 25.0, left: 25.0, bottom: 25.0, right: 25.0))
        }


        result(nil)
    }

    private func setRoadMarkersIcon(call: FlutterMethodCall, result: FlutterResult) {
        let iconsBase64 = call.arguments as! [String: String]
        if let startPointIconRoad = iconsBase64["START"] {
            markersIconsRoadPoint["start"] = convertImage(codeImage: startPointIconRoad)
        }
        if let middlePointIcon = iconsBase64["MIDDLE"] {
            markersIconsRoadPoint["middle"] = convertImage(codeImage: middlePointIcon)
        }
        if let endPointIcon = iconsBase64["END"] {
            markersIconsRoadPoint["end"] = convertImage(codeImage: endPointIcon)
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
                        userLocation?.setDirectionArrow(personIcon: personMarkerIcon, arrowDirection: arrowDirectionIcon)
                    }
                    let angle = CGFloat(manager.heading?.trueHeading ?? 0.0).toDegrees
                    if (angle != 0) {
                        userLocation?.rotateMarker(angle: Int(angle))
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

    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print(status)
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
        print("receive pick  x: \(position.x) y: \(position.y)")
        if let marker = markerPickResult?.marker {
            let staticMarkers = mapView.markers.filter { m in
                m.stylingString.contains("points")
            }
            let isExist = staticMarkers.contains { m in
                m.point == marker.point
            }
            if isExist {
                channel.invokeMethod("receiveGeoPoint", arguments: marker.point.toGeoPoint())
            }
        } else {
            let point = pickedLocationSingleTap!// mapView.coordinate(fromViewPosition: position)

            channel.invokeMethod("receiveSinglePress", arguments: point.toGeoPoint())
            pickedLocationSingleTap = nil

        }
    }

    public func mapView(_ mapView: TGMapView, regionDidChangeAnimated animated: Bool) {
        if (!dictClusterAnnotation.isEmpty && !isAdvancedPicker) {
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
        if !canTrackUserLocation {
            let point = mapView.coordinate(fromViewPosition: mapView.center).toGeoPoint()
            let bounding = mapView.getBounds(width: mainView.bounds.width, height: mainView.bounds.width)
            let data: [String: Any] = ["center": point, "bounding": bounding]
            channel.invokeMethod("receiveRegionIsChanging", arguments: data)
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
            geoP.setupMarker(on: view)
            resultFlutter!(geoP.toMap())
            methodCall = nil
        } else {
            pickedLocationSingleTap = view.coordinate(fromViewPosition: location)
            mapView.setPickRadius(56)
            print("pick  x: \(location.x) y: \(location.y)")
            mapView.pickMarker(at: location)

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

    public func mapView(_ view: TGMapView, recognizer: UIGestureRecognizer,
                        shouldRecognizeShoveGesture displacement: CGPoint) -> Bool {
        true
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

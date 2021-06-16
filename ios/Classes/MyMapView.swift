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
    var userLocation:MyLocationMarker? = nil
    var dictClusterAnnotation = [String: [StaticGeoPMarker]]()
    var dictIconClusterAnnotation = [String: StaticMarkerData]()
    var resultFlutter: FlutterResult? = nil
    var methodCall: FlutterMethodCall? = nil
    var uiSingleTapEventMap: UILongPressGestureRecognizer = UILongPressGestureRecognizer()
    // var tileRenderer:MKTileOverlayRenderer!

    var span = MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
    var zoomDefault = 0.9

    init(_ frame: CGRect, viewId: Int64, channel: FlutterMethodChannel, args: Any?) {
        self.frame = frame
        self.viewId = viewId
        self.channel = channel

        mapView = TGMapView()
        mapView.frame = frame
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

            mapView.loadSceneAsync(from: sceneUrl, with: sceneUpdates)
            result(200)
            break
        case "initPosition":
            initPosition(args: call.arguments, result: result)
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
            break;
        case "user#pickPosition":
            //let frameV = UIView()
            methodCall = call
            resultFlutter = result
            /* uiSingleTapEventMap.addTarget(mapView, action: #selector(singleTapGesture))
             uiSingleTapEventMap.minimumPressDuration = 0.3
             print(uiSingleTapEventMap.isEnabled)
             mapView.addGestureRecognizer(uiSingleTapEventMap)*/
            //mapView.addSubview(frameV)
            break;
        case "deactivateTrackMe":
            // deactivateTrackMe()
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
        case "road":
            drawRoad(call: call) { [unowned self] roadInfo, route, error in
                if (error != nil) {
                    result(FlutterError(code: "400", message: "error to draw road", details: nil))
                }
                showRoute(with: route)
                result(roadInfo.toMap())
            }
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

        return mapView
    }

    private func initPosition(args: Any?, result: FlutterResult) {
        let pointInit = args as! Dictionary<String, Double>
        print(pointInit)
        let location = CLLocationCoordinate2D(latitude: pointInit["lat"]!, longitude: pointInit["lon"]!)
        mapView.fly(to: TGCameraPosition(center: location, zoom: CGFloat(zoomDefault), bearing: 0, pitch: 0)) { finish in
            let marker = self.mapView.markerAdd()
            marker.icon = self.markerIcon!
            marker.point = location
            marker.visible = true
            marker.stylingString = "{ style: points, interactive: false,color: white, order: 5000, collide: false }"
        }

        //   let geoPoint = GeoPointMap(locationName: "init location", icon: markerIcon, discipline: nil, coordinate: location)
        //        let span = MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2)
        //    let region = MKCoordinateRegion(center: location, span: span)

        //self.mapView.centerToLocation(geoPoint.location)
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
            mapView.fly(to: cameraPos, withSpeed: 25.0)
        } else {
            let cameraPos = TGCameraPosition(center: mapView.position, zoom: mapView.zoom - CGFloat(abs(level)), bearing: 0, pitch: 0)!
            mapView.fly(to: cameraPos, withSpeed: 25.0)

        }
        /*   var region = MKCoordinateRegion(center: mapView.region.center, span: mapView.region.span)

           if (level > 0) {
               region.span.latitudeDelta /= level
               region.span.longitudeDelta /= level
           } else if (level < 0) {
               let pLevel = abs(level)
               region.span.latitudeDelta = min(region.span.latitudeDelta * pLevel, 100.0)
               region.span.longitudeDelta = min(region.span.longitudeDelta * pLevel, 100.0)
           }
           mapView.setRegion(region, animated: true)*/
    }

    private func setupTileRenderer() {

        let template = "https://a.tile.openstreetmap.fr/osm/fr/{z}/{x}/{y}.png"

        let overlay = MKTileOverlay(urlTemplate: template)
        overlay.canReplaceMapContent = true
        //self.mapView.addOverlay(overlay, level: .aboveLabels)
        // self.tileRenderer = MKTileOverlayRenderer(tileOverlay: overlay)
    }

    private func deactivateTrackMe() {
        canTrackUserLocation = false
        locationManager.stopUpdatingLocation()
        if userLocation != nil && userLocation!.marker != nil {
            mapView.removeUserLocation(for: userLocation!.marker!)
        }
        userLocation = nil
        //mapView.showsUserLocation = false
    }

    private func setMarkerStaticGeoPIcon(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        let id = args["id"] as! String
        let rgbList: [Int] = (args["color"] as! [Int])
        let icon = convertImage(codeImage: args["bitmap"] as! String)
        let iconColor = rgbList.toUIColor()//UIColor.init(absoluteRed: rgbList.first!, green: rgbList.last!, blue: rgbList[1])
        dictIconClusterAnnotation[id] = StaticMarkerData(image: icon!, color: iconColor)
    }

    private func setStaticGeoPoint(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        let id = args["id"] as! String


        let listGeos: [StaticGeoPMarker] = (args["point"] as! [GeoPoint]).map { point -> StaticGeoPMarker in
            let geo = StaticGeoPMarker(icon: dictIconClusterAnnotation[id]!.image, color: dictIconClusterAnnotation[id]!.color, coordinate: point.toLocationCoordinate())

            return geo.addStaticGeosToMapView(for: geo, on: mapView)
        }

        if dictClusterAnnotation.keys.contains(id) {
            // mapView.removeAnnotations(dictClusterAnnotation[id]!)
            dictClusterAnnotation[id] = listGeos
        } else {
            dictClusterAnnotation[id] = listGeos
        }

        // let clusterAnnotation = ClusterMarkerAnnotation(id: id,geos: listGeos)
        //mapView.addAnnotations(listGeos)
        // mapView.addAnnotation(clusterAnnotation)

    }

    private func drawRoad(call: FlutterMethodCall, completion: @escaping (_ roadInfo: RoadInformation, _ polyLine: MKPolyline, _ error: Error?) -> ()) {
        let args = call.arguments as! [String: Any]
        let points = args["wayPoints"] as! [GeoPoint]

        let roadData = RoadData(startPoint: points.first!.toLocationCoordinate(),
                endPoint: points.last!.toLocationCoordinate(),
                roadColor: (args["roadColor"] as? [Int]?)??.toUIColor(),
                roadWidth: args["roadWidth"] as! Float?)

        let directionRequest = MKDirections.Request()
        directionRequest.source = MKMapItem(placemark: MKPlacemark(coordinate: roadData.startPoint))
        directionRequest.destination = MKMapItem(placemark: MKPlacemark(coordinate: roadData.endPoint))
        directionRequest.transportType = [.automobile]
        directionRequest.requestsAlternateRoutes = false
        // Calculate the direction
        let directions = MKDirections(request: directionRequest)

        directions.calculate { response, error in
            guard let response = response else {
                if let error = error {
                    print("Error: \(error)")
                    //throw Error("")
                }
                return
            }
            let route = response.routes.first!
            let distance = route.distance.rounded() / 1000
            let second = route.expectedTravelTime

            completion(RoadInformation(distance: distance, seconds: second), route.polyline, error)
            //result(["distance": distance, "duration": second])
        }

    }

    private func showRoute(with: MKPolyline) {
        //DispatchQueue.main.async {
        // self.mapView.addOverlay(with)//,level: MKOverlayLevel.aboveRoads)
        // let rect = with.boundingMapRect
        //self.mapView.setVisibleMapRect(rect, animated: true)
        //}
    }


    // ------- delegation func ----
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if (canGetLastUserLocation || canTrackUserLocation) {
            if let location = locations.last?.coordinate {
                //mapView.setRegion(region, animated: true)
                if (canTrackUserLocation) {
                    if(userLocation != nil ){
                        userLocation = mapView.addUserLocation(for: location, on: mapView)
                    }
                        userLocation?.marker?.point = location
                    userLocation?.marker?.point = location
                    //  mapView.showsUserLocation = true
                    let geoMap = ["lon": location.longitude, "lat": location.latitude]
                    channel.invokeMethod("receiveUserLocation", arguments: geoMap)
                }
                if (canGetLastUserLocation) {
                    canGetLastUserLocation = false
                }
                mapView.flyToUserLocation(for: location)

            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
    }

    public func mapView(_ mapView: TGMapView, regionDidChangeAnimated animated: Bool) {
        if( dictClusterAnnotation != nil && !dictClusterAnnotation.isEmpty){
           for  gStaticMarker in  dictClusterAnnotation {
               for (i,staticMarker) in gStaticMarker.value.enumerated() {
                   let m = staticMarker
                   if(mapView.zoom>12) {
                       m.marker?.visible = true
                   }else{
                       m.marker?.visible = false
                   }
                   dictClusterAnnotation[gStaticMarker.key]![i] = m
               }
           }
        }
    }

    public func mapView(_ view: TGMapView!, recognizer: UIGestureRecognizer!,
                        didRecognizeLongPressGesture location: CGPoint) {
        if(resultFlutter != nil && methodCall != nil){
            var iconM = markerIcon
            let dict:[String:Any] = methodCall?.arguments as! [String:Any]
            if let icon = dict["icon"] {
               iconM =  convertImage(codeImage: icon as! String)
            }
            let coordinate = view.coordinate(fromViewPosition: location)
            let geoP = GeoPointMap(icon: iconM!,coordinate: coordinate)
            geoP.setupMarker(for: geoP, on: view)
            resultFlutter!(200)
            methodCall = nil
        }

    }

    public func mapView(_ view: TGMapView!, recognizer: UIGestureRecognizer!,
                        shouldRecognizeDoubleTapGesture location: CGPoint) -> Bool {
        let locationMap = view.coordinate(fromViewPosition: location)
        view.fly(to: TGCameraPosition(center: locationMap, zoom: view.zoom + CGFloat(zoomDefault), bearing: view.bearing, pitch: view.pitch))
        return true
    }

    public func mapView(_ view: TGMapView, recognizer: UIGestureRecognizer,
                        shouldRecognizeShoveGesture displacement: CGPoint) -> Bool {
        true
    }

    /*  public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
          if (annotation is MKUserLocation) {
              return nil
          }
          var viewAnnotation: MKAnnotationView?
          if let annotationM = annotation as? GeoPointMap {
              viewAnnotation = annotationM.setupMKAnnotationView(for: annotationM, on: mapView)
          } else if let staticPoint = annotation as? StaticGeoPMarker {
              viewAnnotation = staticPoint.setupClusterView(for: staticPoint, on: mapView)
          }

          return viewAnnotation
      }*/

    /* public func mapView(
             _ mapView: MKMapView,
             rendererFor overlay: MKOverlay
     ) -> MKOverlayRenderer {
         if let roadOverlay = overlay as? MKPolyline {
             let renderer = MKPolylineRenderer(overlay: roadOverlay)

             renderer.strokeColor = .red

             renderer.lineWidth = 15.0

             return renderer
         }

         guard   let tileOverlay = overlay as? MKTileOverlay else {
             return MKOverlayRenderer(overlay: overlay)
         }
         return MKTileOverlayRenderer(tileOverlay: tileOverlay)


     }*/
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

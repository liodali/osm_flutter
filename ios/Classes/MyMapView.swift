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

public class MyMapView: NSObject, FlutterPlatformView, MKMapViewDelegate, CLLocationManagerDelegate {


    let frame: CGRect
    let viewId: Int64
    let channel: FlutterMethodChannel
    let mapView: MKMapView
    let locationManager: CLLocationManager = CLLocationManager()
    var markerIcon: UIImage? = nil
    var isFollowUserLocation: Bool = false
    var canGetLastUserLocation = false
    var canTrackUserLocation = false
    var dictClusterAnnotation = [String: [StaticGeoPMarker]]()
    var dictIconClusterAnnotation = [String: UIImage]()
    // var tileRenderer:MKTileOverlayRenderer!

    var span = MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
    var zoomDefault = 0.9

    init(_ frame: CGRect, viewId: Int64, channel: FlutterMethodChannel, args: Any?) {
        self.frame = frame
        self.viewId = viewId
        self.channel = channel

        let mapview = MKMapView()

        mapview.frame = frame
        mapview.mapType = MKMapType.standard
        mapview.isZoomEnabled = true
        mapview.isScrollEnabled = true
        mapView = mapview
        super.init()

        /// affect delegation
        mapView.delegate = self
        locationManager.delegate = self;

        //self.setupTileRenderer()
        mapView.register(MKPinAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(GeoPointMap.self))
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(StaticGeoPMarker.self))
        //mapView.register(StaticPointClusterAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(StaticGeoPMarker.self) )

        channel.setMethodCallHandler({
            (call: FlutterMethodCall, result: FlutterResult) ->
                    Void in
            self.onListenMethodChannel(call: call, result: result)


        })
    }

    private func onListenMethodChannel(call: FlutterMethodCall, result: FlutterResult) {
        print(call.method)
        switch call.method {
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
        default:
            result(nil)
            break;
        }
    }

    public func view() -> UIView {
        if #available(iOS 11.0, *) {
            mapView.register(
                    MarkerView.self,
                    forAnnotationViewWithReuseIdentifier:
                    MKMapViewDefaultAnnotationViewReuseIdentifier)

        }

        return mapView
    }

    private func initPosition(args: Any?, result: FlutterResult) {
        let pointInit = args as! Dictionary<String, Double>
        print(pointInit)
        let location = CLLocationCoordinate2D(latitude: pointInit["lat"]!, longitude: pointInit["lon"]!)

        let geoPoint = GeoPointMap(locationName: "init location", icon: markerIcon, discipline: nil, coordinate: location)

//        let span = MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2)
        let region = MKCoordinateRegion(center: location, span: span)

        mapView.setRegion(region, animated: true)

        mapView.addAnnotation(geoPoint)
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
        var region = MKCoordinateRegion(center: mapView.region.center, span: mapView.region.span)

        if (level > 0) {
            region.span.latitudeDelta /= level
            region.span.longitudeDelta /= level
        } else if (level < 0) {
            let pLevel = abs(level)
            region.span.latitudeDelta = min(region.span.latitudeDelta * pLevel, 100.0)
            region.span.longitudeDelta = min(region.span.longitudeDelta * pLevel, 100.0)
        }
        mapView.setRegion(region, animated: true)
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
        mapView.showsUserLocation = false
    }

    private func setMarkerStaticGeoPIcon(call: FlutterMethodCall) {
        let args = call.arguments as! [String: String]
        let icon = convertImage(codeImage: args["bitmap"]!)
        dictIconClusterAnnotation[args["id"]!] = icon!
    }

    private func setStaticGeoPoint(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        let id = args["id"] as! String


        let listGeos = (args["point"] as! [GeoPoint]).map { point -> StaticGeoPMarker in
            StaticGeoPMarker(icon: dictIconClusterAnnotation[id]!, color: nil, coordinate: point.toLocationCoordinate())
        } as [StaticGeoPMarker]
        if dictClusterAnnotation.keys.contains(id) {
            mapView.removeAnnotations(dictClusterAnnotation[id]!)
            dictClusterAnnotation[id] = listGeos
        } else {
            dictClusterAnnotation[id] = listGeos
        }
        let clusterAnnotation = ClusterMarkerAnnotation(
                id: id,
                geos: listGeos
        )
        mapView.addAnnotations(listGeos)
        //mapView.addAnnotation(clusterAnnotation)

    }

    // ------- delegation func ----
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if (canGetLastUserLocation || canTrackUserLocation) {
            if let location = locations.last?.coordinate {
                let region = MKCoordinateRegion.init(center: location, latitudinalMeters: 4000, longitudinalMeters: 4000)
                mapView.setRegion(region, animated: true)
                if (canTrackUserLocation) {
                    mapView.showsUserLocation = true
                    let geoMap = ["lon": location.longitude, "lat": location.latitude]
                    channel.invokeMethod("receiveUserLocation", arguments: geoMap)
                }
                if (canGetLastUserLocation) {
                    canGetLastUserLocation = false
                }

            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
    }

    public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
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
    }

    public func mapView(
            _ mapView: MKMapView,
            rendererFor overlay: MKOverlay
    ) -> MKOverlayRenderer {
        guard let tileOverlay = overlay as? MKTileOverlay else {
            return MKOverlayRenderer(overlay: overlay)
        }
        return MKTileOverlayRenderer(tileOverlay: tileOverlay)
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

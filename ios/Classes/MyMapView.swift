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

public class MyMapView: NSObject, FlutterPlatformView, MKMapViewDelegate,FlutterStreamHandler {


    let frame: CGRect
    let viewId: Int64
    let channel: FlutterMethodChannel
    let mapView: MKMapView
    let locationManager : CLLocationManager  = CLLocationManager()
    var markerIcon: UIImage? = nil
    var isFollowUserLocation : Bool = false
    var eventSink: FlutterEventSink? = nil
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
        self.mapView = mapview
        super.init()
        self.mapView.delegate = self

        self.setupTileRenderer()
        self.mapView.register(MKPinAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(GeoPointMap.self))

        channel.setMethodCallHandler({
            (call: FlutterMethodCall, result: FlutterResult) ->
                    Void in
            switch call.method {
            case "initPosition":
                self.initPosition(args: call.arguments, result: result)
                break;
            case "trackMe":
                break;
            case "user#position":
                break;
            case "currentLocation ":
                break;
            case "Zoom":
                let levelZoom = call.arguments! as! Double
                if (levelZoom == 0 || levelZoom == -1) {
                    var alpha = levelZoom
                    if levelZoom == 0 {
                        alpha = 1
                    }
                    self.zoomMap(self.zoomDefault * alpha)
                } else {
                    self.zoomMap(levelZoom)
                }
                result(nil)
                break;
            case "defaultZoom":
                self.zoomDefault = call.arguments! as! Double

                result(200)
                break;
            case "marker#icon":
                print("marker")
                self.markerIcon = self.convertImage(codeImage: call.arguments as! String)!
                result(200)
                break;
            default:
                result(nil)
                break;
            }


        })
    }

    public func view() -> UIView {
        if #available(iOS 11.0, *) {
            self.mapView.register(
                    MarkerView.self,
                    forAnnotationViewWithReuseIdentifier:
                    MKMapViewDefaultAnnotationViewReuseIdentifier)

        }

        return self.mapView
    }

    private func initPosition(args: Any?, result: FlutterResult) {
        let pointInit = args as! Dictionary<String, Double>
        print(pointInit)
        let location = CLLocationCoordinate2D(latitude: pointInit["lat"]!, longitude: pointInit["lon"]!)

        let geoPoint = GeoPointMap(locationName: "init location", icon: self.markerIcon, discipline: nil, coordinate: location)

//        let span = MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2)
        let region = MKCoordinateRegion(center: location, span: self.span)

        self.mapView.setRegion(region, animated: true)

        self.mapView.addAnnotation(geoPoint)
        //self.mapView.centerToLocation(geoPoint.location)
        result(200)
    }


    public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if (annotation is MKUserLocation) {
            return nil
        }
        var viewAnnotation: MKAnnotationView?
        if let annotationM = annotation as? GeoPointMap {
            viewAnnotation = annotationM.setupMKAnnotationView(for: annotationM, on: mapView)
        }

        return viewAnnotation
    }
   private func currentUserLocation() {
       if let location = locationManager.location?.coordinate {
           let region = MKCoordinateRegion.init(center: location, latitudinalMeters: 4000, longitudinalMeters: 4000)
           mapView.setRegion(region, animated: true)
       }
   }



    private func convertImage(codeImage: String) -> UIImage? {


        let dataImage = Data(base64Encoded: codeImage)
        return UIImage(data: dataImage!)// Note it's optional. Don't force unwrap!!!
    }

    private func zoomMap(_ level: Double) {
        var region = MKCoordinateRegion(center: self.mapView.region.center, span: self.mapView.region.span)

        if (level > 0) {
            region.span.latitudeDelta /= level
            region.span.longitudeDelta /= level
        } else if (level < 0) {
            let pLevel = abs(level)
            region.span.latitudeDelta = min(region.span.latitudeDelta * pLevel, 100.0)
            region.span.longitudeDelta = min(region.span.longitudeDelta * pLevel, 100.0)
        }
        self.mapView.setRegion(region, animated: true)
    }

    private func setupTileRenderer() {

        let template = "https://a.tile.openstreetmap.fr/osm/fr/{z}/{x}/{y}.png"

        let overlay = MKTileOverlay(urlTemplate: template)
        overlay.canReplaceMapContent = true
        //self.mapView.addOverlay(overlay, level: .aboveLabels)
        // self.tileRenderer = MKTileOverlayRenderer(tileOverlay: overlay)
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
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

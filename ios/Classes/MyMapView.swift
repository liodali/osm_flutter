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

public class MyMapView: NSObject, FlutterPlatformView,  MKMapViewDelegate {
    let frame: CGRect
    let viewId: Int64
    let channel: FlutterMethodChannel
    let mapView: MKMapView
    var markerIcon:UIImage? = nil

    var span = MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)

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

        self.mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(GeoPointMap.self))

        channel.setMethodCallHandler({
            (call: FlutterMethodCall, result: FlutterResult) ->
                    Void  in switch call.method {
            case "initPosition":
                self.initPosition(args:call.arguments,result:result)
                break;
            case "trackMe":
                break;
            case "user#position":
                break;
            case "defaultZoom":
                result(200)
                break;
            case "marker#icon":
                print("marker")
                self.markerIcon=self.convertImage(codeImage: call.arguments as! String)!
                result(200)
                break;
            default:
                result(nil)
                break;
            }


        })
    }
    public func view() -> UIView {
        if  #available(iOS 11.0,*) {
            self.mapView.register(
                    MarkerView.self,
                    forAnnotationViewWithReuseIdentifier:
                    MKMapViewDefaultAnnotationViewReuseIdentifier)
            self.mapView.delegate = self
        }


        return self.mapView
    }
    public func initPosition(args:Any?,  result:FlutterResult){
        let pointInit = args as! Dictionary<String,Double>
        print(pointInit)
        let location = CLLocationCoordinate2D(latitude: pointInit["lat"]!, longitude: pointInit["lon"]!  )

        let geoPoint = GeoPointMap(locationName: "init location",icon: self.markerIcon , discipline: nil, coordinate: location)

        let span = MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2)
        let region = MKCoordinateRegion(center: location, span: span)

        self.mapView.setRegion(region, animated: true)

        self.mapView.addAnnotation(geoPoint)
        //self.mapView.centerToLocation(geoPoint.location)
        result(200)
    }

    public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if(annotation is MKUserLocation){
            return nil
        }
        var viewAnnotation:MKAnnotationView?
        if let annotationM = annotation as? GeoPointMap {
            viewAnnotation = annotationM.setupMKAnnotationView(for: annotationM, on: mapView)
        }

        return viewAnnotation
    }

    private func convertImage(codeImage:  String) -> UIImage? {


        let dataImage = Data(base64Encoded: codeImage)
        return UIImage(data: dataImage!)// Note it's optional. Don't force unwrap!!!
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

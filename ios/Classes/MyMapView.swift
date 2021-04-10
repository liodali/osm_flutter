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
    var markerIcon:UIImage?=nil
    
    init(_ frame: CGRect, viewId: Int64, channel: FlutterMethodChannel, args: Any?) {
        self.frame = frame
        self.viewId = viewId
        self.channel = channel
        
        let mapview = MKMapView()
        
        mapview.frame=frame
        mapview.mapType = MKMapType.standard
        mapview.isZoomEnabled = true
        mapview.isScrollEnabled = true
        self.mapView = mapview

        super.init()
        
        channel.setMethodCallHandler({
            (call: FlutterMethodCall, result: FlutterResult) ->
              Void  in switch call.method {
                case "initPosition":
                self.initPosition(args:call.arguments,result:result)
                    break;
              case "marker#icon":
                print("marker")
                self.markerIcon=self.converteImage(cadenaImagen: call.arguments as! String)!
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
        }
       
        
        return self.mapView
    }
    
    public func initPosition(args:Any?,  result:FlutterResult){
        let pointInit = args as! Dictionary<String,Double>
        print(pointInit)
        let location = CLLocationCoordinate2D(latitude: pointInit.values.first!, longitude: pointInit["lon"]!  )
        let geoPoint=GeoPointMap(locationName: nil,icon: self.markerIcon , discipline: nil, coordinate: location)
        
        let span = MKCoordinateSpan(latitudeDelta: 0.0, longitudeDelta: 0)
        let region = MKCoordinateRegion(center: location, span: span)
        self.mapView.setRegion(region, animated: true)

        
        self.mapView.addAnnotation(geoPoint)
        self.mapView.centerToLocation(geoPoint.location)
        result(200)
    }
    
    private func converteImage(cadenaImagen:  String) -> UIImage? {
        
        
        let dataImage=Data(base64Encoded: cadenaImagen)
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
      longitudinalMeters: regionRadius)
    setRegion(coordinateRegion, animated: true)
  }
}

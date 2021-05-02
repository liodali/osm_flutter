//
//  MapViewFactory.swift
//  Runner
//
//  Created by Dali on 6/12/20.
//  Copyright © 2020 The Chromium Authors. All rights reserved.
//

import Foundation
import Flutter

public class MapviewFactory : NSObject, FlutterPlatformViewFactory {
    let controller: FlutterViewController
    let messenger : FlutterBinaryMessenger
    init(controller: FlutterViewController,messenger:FlutterBinaryMessenger) {
        self.controller = controller
        self.messenger = messenger
    }
    
    public func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
       let channel = FlutterMethodChannel(
            name: "plugins.dali.hamza/osmview_"+String(viewId),
            binaryMessenger: self.messenger
        )
        return MyMapView(frame, viewId: viewId, channel: channel, args: args)
    }
}

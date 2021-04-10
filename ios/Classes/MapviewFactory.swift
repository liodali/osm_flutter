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
    
    init(controller: FlutterViewController) {
        self.controller = controller
    }
    
    public func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        let channel = FlutterMethodChannel(
            name: String(viewId),
            binaryMessenger: controller.binaryMessenger
        )
        return MyMapView(frame, viewId: viewId, channel: channel, args: args)
    }
}

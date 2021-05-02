import Flutter
import UIKit


public class SwiftFlutterOsmPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let window = UIApplication.shared.delegate?.window
        let controller = window??.rootViewController as! FlutterViewController


        //let channel = FlutterMethodChannel(name: "flutter_osm_plugin", binaryMessenger: registrar.messenger())
        //let instance = SwiftFlutterOsmPlugin()
        //registrar(forPlugin:"plugins.dali.hamza/osmview")
        //.register(mapViewFactory, withId: "plugins.dali.hamza/osmview")

        let mapViewFactory = MapviewFactory(controller: controller, messenger: controller.binaryMessenger)

        registrar.register(mapViewFactory, withId: "plugins.dali.hamza/osmview")

        // registrar.addMethodCallDelegate(instance, channel: channel)
    }

/* public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
   result("iOS " + UIDevice.current.systemVersion)
 }*/
}

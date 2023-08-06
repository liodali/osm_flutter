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
        let keyDynamicOSM = controller.lookupKey(forAsset: "packages/flutter_osm_plugin/assets/dynamic-styles.yaml")
        let mainBundle = Bundle.main
        let pathDynamicOSM = mainBundle.path(forResource: keyDynamicOSM, ofType: nil)
        let mapViewFactory = MapviewFactory(controller: controller, messenger: controller.binaryMessenger,dynamicOSM: pathDynamicOSM)

        registrar.register(mapViewFactory, withId: "plugins.dali.hamza/osmview")
        
        // registrar.addMethodCallDelegate(instance, channel: channel)
    }

/* public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
   result("iOS " + UIDevice.current.systemVersion)
 }*/
}

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
        let keyDefaultPin = controller.lookupKey(forAsset: "packages/flutter_osm_plugin/assets/default_pin.png")
        let mainBundle = Bundle.main
        let pathDefaultPin = mainBundle.path(forResource: keyDefaultPin, ofType: nil)
        let mapViewFactory = MapviewFactory(
            controller: controller,
            messenger: controller.binaryMessenger,
            defaultPin: pathDefaultPin
        )

        registrar.register(mapViewFactory, withId: "plugins.dali.hamza/osmview")
        
        // registrar.addMethodCallDelegate(instance, channel: channel)
    }

/* public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
   result("iOS " + UIDevice.current.systemVersion)
 }*/
}

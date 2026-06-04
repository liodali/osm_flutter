import Flutter
import UIKit

nonisolated public class FlutterOsmPlugin: NSObject, FlutterPlugin {
 
  nonisolated public static func register(with registrar: FlutterPluginRegistrar) {
    let window = UIApplication.shared.delegate?.window

    let keyDefaultPin = registrar.lookupKey(
      forAsset: "packages/flutter_osm_plugin/assets/default_pin.png")
    let mainBundle = Bundle.main
    let pathDefaultPin = mainBundle.path(forResource: keyDefaultPin, ofType: nil)
    let mapViewFactory = MapviewFactory(
      messenger: registrar.messenger(),
      defaultPin: pathDefaultPin
    )

    registrar.register(mapViewFactory, withId: "plugins.dali.hamza/osmview")

  }
  /* public static func register(with registrar: FlutterPluginRegistrar) {
     let channel = FlutterMethodChannel(name: "flutter_osm_plugin", binaryMessenger: registrar.messenger())
     let instance = FlutterOsmPlugin()
     registrar.addMethodCallDelegate(instance, channel: channel)
   }

   public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
     switch call.method {
     case "getPlatformVersion":
       result("iOS " + UIDevice.current.systemVersion)
     default:
       result(FlutterMethodNotImplemented)
     }
   }*/
}

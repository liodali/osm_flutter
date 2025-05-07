import Flutter
import UIKit


public class SwiftFlutterOsmPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let window = UIApplication.shared.delegate?.window

        let keyDefaultPin = registrar.lookupKey(forAsset: "packages/flutter_osm_plugin/assets/default_pin.png")
        let mainBundle = Bundle.main
        let pathDefaultPin = mainBundle.path(forResource: keyDefaultPin, ofType: nil)
        let mapViewFactory = MapviewFactory(
            messenger: registrar.messenger(),
            defaultPin: pathDefaultPin
        )

        registrar.register(mapViewFactory, withId: "plugins.dali.hamza/osmview")
        
    }

}

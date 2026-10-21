//
//  FlutterOsmPlugin.swift
//  flutter_osm_plugin
//

// Import the correct Flutter module for each platform.
#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterMacOS)
import FlutterMacOS
#endif
import Foundation

nonisolated public class FlutterOsmPlugin: NSObject, FlutterPlugin {

  nonisolated public static func register(with registrar: FlutterPluginRegistrar) {
    MainActor.assumeIsolated {
      // The registrar's `messenger` is a method on iOS and a property on macOS.
      #if canImport(Flutter)
      let messenger = registrar.messenger()
      #else
      let messenger = registrar.messenger
      #endif

      let keyDefaultPin = registrar.lookupKey(
        forAsset: "packages/flutter_osm_plugin/assets/default_pin.png")
      let mainBundle = Bundle.main
      let pathDefaultPin = mainBundle.path(forResource: keyDefaultPin, ofType: nil)
      #if canImport(Flutter)
      let mapViewFactory = IOSMapViewFactory(messenger: messenger, defaultPin: pathDefaultPin)
      #else
      let mapViewFactory = MacOSMapViewFactory(messenger: messenger, defaultPin: pathDefaultPin)
      #endif

      registrar.register(mapViewFactory, withId: "plugins.dali.hamza/osmview")
    }
  }
}

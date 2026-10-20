import Cocoa
import FlutterMacOS
#if DEBUG
import CoreLocation
#endif

class MainFlutterWindow: NSWindow {
  #if DEBUG
  private var acceptanceChannel: FlutterMethodChannel?
  private var observedSessions: [WeakAcceptanceSession] = []
  #endif
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    #if DEBUG
    acceptanceChannel = FlutterMethodChannel(
      name: "osm_example/manual_checks", binaryMessenger: flutterViewController.engine.binaryMessenger)
    acceptanceChannel?.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "snapshot": result(self.acceptanceSnapshot())
      case "activate":
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        result(nil)
      case "refreshBacking":
        self.mapHosts().forEach { $0.viewDidChangeBackingProperties() }
        result(self.acceptanceSnapshot())
      case "resize":
        let args = call.arguments as? [String: Double] ?? [:]
        self.setContentSize(NSSize(width: args["width"] ?? 1000, height: args["height"] ?? 700))
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
    #endif

    super.awakeFromNib()
  }

  #if DEBUG
  // Debug example instrumentation only. Weak references allow the acceptance
  // screen to verify native session release without retaining maps itself.
  private func mapHosts() -> [NSView] {
    func descendants(_ view: NSView) -> [NSView] {
      [view] + view.subviews.flatMap { descendants($0) }
    }
    return contentView.map { descendants($0).filter {
      String(describing: type(of: $0)) == "MacOSMapHostView"
    }} ?? []
  }

  private func field(_ name: String, of value: Any) -> Any? {
    Mirror(reflecting: value).children.first { $0.label == name }?.value
  }

  private func unwrap(_ value: Any?) -> Any? {
    guard let value else { return nil }
    let mirror = Mirror(reflecting: value)
    return mirror.displayStyle == .optional ? mirror.children.first?.value : value
  }

  private func iconSummary(_ configuration: Any?) -> [String: Any] {
    guard let configuration else { return [:] }
    var output: [String: Any] = [:]
    if let size = unwrap(field("iconSize", of: configuration)) {
      output["size"] = Mirror(reflecting: size).children.compactMap { $0.value as? Int }
    }
    if let anchor = unwrap(field("anchor", of: configuration)) {
      output["anchor"] = Mirror(reflecting: anchor).children.compactMap { $0.value as? Double }
    }
    return output
  }

  private func acceptanceSnapshot() -> [String: Any] {
    let hosts = mapHosts()
    let maps: [[String: Any]] = hosts.compactMap { host in
      guard let session = field("session", of: host) as? NSObject,
        let map = field("mapOSM", of: session) else { return nil }
      if !observedSessions.contains(where: { $0.value === session }) {
        observedSessions.append(WeakAcceptanceSession(session))
      }
      var summary: [String: Any] = [
        "width": host.bounds.width, "height": host.bounds.height,
        "scale": host.window?.backingScaleFactor ?? 0,
      ]
      if let manager = field("markerManager", of: map),
        let markers = field("markers", of: manager) {
        summary["markers"] = Mirror(reflecting: markers).children.map {
          iconSummary(field("markerConfiguration", of: $0.value))
        }
      }
      if let manager = field("poisManager", of: map), let pois = field("pois", of: manager) {
        summary["pois"] = Mirror(reflecting: pois).children.flatMap { entry -> [[String: Any]] in
          let pair = Array(Mirror(reflecting: entry.value).children)
          guard pair.count == 2, let markers = field("markerPois", of: pair[1].value) else { return [] }
          return Mirror(reflecting: markers).children.map {
            iconSummary(field("configuration", of: $0.value))
          }
        }
      }
      if let manager = field("locationManager", of: map),
        let config = field("userLocationIconConfiguration", of: manager) {
        summary["userIcon"] = iconSummary(field("userIcon", of: config))
      }
      return summary
    }
    return [
      "hosts": hosts.count, "maps": maps,
      "liveSessions": observedSessions.filter { $0.value != nil }.count,
      "permission": CLLocationManager().authorizationStatus.rawValue,
      "windowScale": backingScaleFactor,
      "active": NSApp.isActive,
    ]
  }
  #endif
}

#if DEBUG
private final class WeakAcceptanceSession {
  weak var value: NSObject?
  init(_ value: NSObject) { self.value = value }
}
#endif

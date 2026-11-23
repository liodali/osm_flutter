//
//  MapSession.swift
//  flutter_osm_plugin
//
//  Created by Dali Hamza on 19.11.23.
//

import CoreLocation
#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterMacOS)
import FlutterMacOS
#endif
import Foundation
@preconcurrency import OSMFlutterFramework

import Polyline

/// Shared per-map session: owns the native `OSMView`, the method channel,
/// the map state and the forwarding of framework events to Dart.
///
/// The iOS `FlutterPlatformView` wrapper and the macOS `NSView` host each
/// retain exactly one session, so every created map stays independent.
@MainActor
class MapSession: NSObject {

    let mapOSM: OSMView
    var isStaticMap: Bool = false
    var homeMarker: OSMPlatformImage? = nil
    var customTiles: CustomTiles? = nil
    var boundingbox: BoundingBox? = nil
    let channel: FlutterMethodChannel
    /// Factory-provided messenger retained for generated-route registration.
    let binaryMessenger: FlutterBinaryMessenger
    /// Platform view id (also used to derive per-map generated channel suffixes).
    let viewId: Int64
    /// Minted per session; guards generated routes against reused view ids.
    let sessionToken: String = UUID().uuidString
    /// Bumped when the underlying view is replaced; C1 keeps it at 0.
    let generation: Int64 = 0
    /// Last rotation applied through the typed service or legacy decode.
    /// OSMView exposes no rotation getter, so the session tracks its own.
    var lastAppliedRotation: Double = 0
    /// Generated camera route living alongside the legacy channel handler.
    private(set) var cameraBridge: PigeonCameraBridge?
    /// Generated markers route living alongside the legacy channel handler.
    private(set) var markersBridge: PigeonMarkersBridge?
    private(set) var layersBridge: PigeonLayersBridge?
    private(set) var shapesBridge: PigeonShapesBridge?
    private(set) var roadsBridge: PigeonRoadsBridge?
    private(set) var locationBridge: PigeonLocationBridge?
    private(set) var locationUpdatesBridge: PigeonLocationUpdatesBridge?
    private(set) var trackingBridge: PigeonTrackingBridge?
    /// Generated user-location icon route living alongside the legacy
    /// channel handler.
    private(set) var userLocationIconsBridge: PigeonUserLocationIconsBridge?
    /// Generated lifecycle event route (readiness/restoration callbacks)
    /// living alongside the legacy event plane.
    private(set) var lifecycleEventsBridge: PigeonLifecycleEventsBridge?
    /// Generated interaction event route (single/long-press callbacks)
    /// living alongside the legacy event plane.
    private(set) var interactionEventsBridge: PigeonInteractionEventsBridge?
    /// Generated marker interaction event route (marker single/long-press
    /// callbacks) living alongside the legacy event plane.
    private(set) var markerEventsBridge: PigeonMarkerEventsBridge?
    /// Generated road tap event route living alongside the legacy event
    /// plane.
    private(set) var roadEventsBridge: PigeonRoadEventsBridge?
    /// Frozen lifecycle delivery route for this attachment: false keeps the
    /// legacy `map#init` event plane (the default); true delivers readiness
    /// through the generated Pigeon callbacks. Switched only by the
    /// validated pre-initialization selection, never by a map command.
    private var lifecycleEventsUsePigeon = false
    /// Frozen interaction delivery route for this attachment: false keeps
    /// the legacy `receiveSinglePress` / `receiveLongPress` event plane (the
    /// default, and the only route JNI attachments ever use); true delivers
    /// presses through the generated Pigeon callbacks. Switched only by the
    /// validated pre-initialization selection, never by a map command.
    /// Interactions are discrete user events that can only occur after
    /// initialization, so no pre-selection buffering is needed.
    private var interactionEventsUsePigeon = false
    /// Frozen marker interaction delivery route for this attachment, with
    /// the same contract as the interaction route.
    private var markerEventsUsePigeon = false
    /// Frozen road tap delivery route for this attachment, with the same
    /// contract as the interaction route.
    private var roadEventsUsePigeon = false
    var zoomConfig: ZoomConfiguration = ZoomConfiguration(
        initZoom: 8, minZoom: 2, maxZoom: 19, step: 1)
    lazy var roadManager: OSMRoadManager = OSMRoadManager()
    let roadColor: String = "#ff0000ff"
    var lastRoadKey: String? = nil
    var resultFlutter: FlutterResult? = nil
    @MainActor
    var storedRoads: [String: StoredRoad] = [:]

    // MARK: - Typed location state (shared slot with the legacy request)

    /// Outcome of one pending location request; completes exactly once.
    enum LocationFixOutcome {
        case fixed(latitude: Double, longitude: Double)
        case failed(code: String, message: String?)
    }

    typealias LocationFixCompletion = (LocationFixOutcome) -> Void

    /// Pending generated fix request. Mutual exclusion with the legacy
    /// `resultFlutter` slot: a legacy and a generated request can never run
    /// in parallel by accident.
    var pendingLocationFixCompletion: LocationFixCompletion?

    var locationFixTimeoutWorkItem: DispatchWorkItem?

    /// Parity with the Android manager's `LOCATION_FIX_TIMEOUT_MILLIS`.
    var locationFixTimeoutSeconds: Double = 15.0

    /// Pending continuous-updates start completion: only armed around the
    /// synchronous toggleTracking call so a denial reported through the
    /// permission callback routes to the start completion, not to a fix.
    var startingUpdatesCompletion: LocationCommandCompletion?

    /// Test seam over the framework updates toggle. The default closure
    /// drives the real CLLocationManager; session tests install a recorder
    /// so no authorization prompt is ever raised and no live GPS is used —
    /// simulated fixes arrive at fixed coordinates through locationChanged.
    internal(set) lazy var locationUpdatesToggle: (Bool) -> Void = { [weak self] start in
        guard let self = self else { return }
        if start {
            if !self.mapOSM.locationManager.isTrackingEnabled() {
                self.mapOSM.locationManager.toggleTracking(
                    configuration: TrackConfiguration(moveMap: true, controlUserMarker: false))
            } else {
                // The framework is already armed by follow-me tracking:
                // reconcile updates semantics (no framework marker
                // control) through the stop-and-retoggle cycle instead of
                // skipping configuration entirely.
                let updatesConfiguration = TrackConfiguration(
                    moveMap: true, controlUserMarker: false)
                self.mapOSM.locationManager.toggleTracking(
                    configuration: updatesConfiguration)
                self.mapOSM.locationManager.toggleTracking(
                    configuration: updatesConfiguration)
            }
        } else {
            self.mapOSM.locationManager.stopLocation()
        }
    }

    /// Test seam over the framework single-shot request. Default drives
    /// the real CLLocationManager; tests install a no-op.
    internal(set) lazy var locationSingleShotRequest: () -> Void = { [weak self] in
        self?.mapOSM.locationManager.requestSingleLocation()
    }

    /// Test seam over the framework enable-location entry (authorization
    /// prompt + my-location layer). Default drives the real
    /// CLLocationManager; tests install a no-op.
    internal(set) lazy var locationEnableRequest: () -> Void = { [weak self] in
        self?.mapOSM.locationManager.requestEnableLocation()
    }

    /// Tracking configuration captured by the typed start; the framework
    /// toggle seam reads it when it arms tracking.
    var trackingDisableMarkerRotation = false
    var trackingUseDirectionMarker = false

    // MARK: - User-location icons (typed and legacy routes)

    /// One prepared icon render request: the decoded image, the encoded
    /// bytes it came from (identity, so repeated identical requests are
    /// dropped), the logical (pre-scale) widget dimensions and the pivot
    /// policy.
    struct UserLocationIconRender {
        /// Normalized pivot handling for one icon.
        enum Pivot {
            /// Keep the live configuration's pivot, so replacing icon bytes
            /// never moves an active marker (typed route, null anchor).
            case preserve
            /// Rebuild the configuration without a pivot, exactly like the
            /// legacy `user#locationMarkers` decode.
            case reset
            /// Apply an explicit normalized pivot.
            case normalized(x: Double, y: Double)
        }

        let image: OSMPlatformImage
        let pngData: Data
        let logicalSize: [Int]?
        let pivot: Pivot
    }

    /// Person + direction icon pair prepared in Dart.
    struct UserLocationIconsRender {
        let person: UserLocationIconRender
        let direction: UserLocationIconRender
    }

    /// Icons the framework installed at view creation, restored by the
    /// typed reset route. The framework keeps its defaults private, so the
    /// session captures them once instead of rebuilding them.
    private(set) var defaultUserLocationIcons: UserLocationConfiguration?

    /// Last configuration applied by the plugin, used to drop repeated
    /// identical requests (an unnecessary redraw of the marker).
    private var appliedUserLocationIcons: AppliedUserLocationIcons?

    /// What was last applied: the platform defaults or a prepared pair.
    private enum AppliedUserLocationIcons {
        case defaults
        case icons(UserLocationIconsRender)
    }

    /// Icons of the plugin-rendered my-location marker. Non-nil once the
    /// application configured its own icons: from then on the plugin draws
    /// the marker in place (see `UserLocationMarkerService`) and the
    /// framework's destructively refreshed marker stays off.
    internal(set) var ownedUserLocationIcons: UserLocationMarkerIcons?

    /// True while the plugin, not the framework, renders the marker. Drives
    /// the framework's `controlUserMarker` flag so exactly one is drawn.
    var ownsUserLocationMarker: Bool {
        ownedUserLocationIcons != nil
    }

    /// True while the framework's user-icon configuration holds the
    /// transparent placeholder (the plugin owns the marker, so the
    /// framework's own marker must stay invisible).
    internal(set) var frameworkIconConfigIsPlaceholder = false

    /// Last anchor a tracking arm applied to the FRAMEWORK markers. Every
    /// framework pivoting path goes through this session, so at an ownership
    /// takeover this is the live pivot `.preserve` must keep — the
    /// framework's configuration fields are not readable from the plugin.
    internal(set) var lastTrackingAnchor: MarkerAnchor? = nil

    /// Heading of the last delivered fix, retained so a redraw keeps the
    /// marker's rotation.
    private(set) var latestUserLocationHeading: Double = 0

    /// Test seam over the framework user-location icon configuration. The
    /// default closure applies the prepared configuration (or restores the
    /// captured defaults for a nil render); session tests install a
    /// recorder.
    ///
    /// While the plugin owns the marker this configuration is unused by the
    /// framework (`controlUserMarker` is off for new arms), so a fully
    /// transparent placeholder is installed instead: a framework marker
    /// armed before the takeover disappears on its next refresh and never
    /// visibly rebuilds — no location consumer is restarted.
    internal(set) lazy var userLocationIconsRenderer: (UserLocationIconsRender?) -> Void = {
        [weak self] render in
        guard let self = self else { return }
        if self.frameworkIconConfigIsPlaceholder {
            self.mapOSM.locationManager.setUserLocationIcons(
                userLocationIcons: Self.placeholderUserLocationIcons())
            return
        }
        guard let render = render else {
            if let defaults = self.defaultUserLocationIcons {
                self.mapOSM.locationManager.setUserLocationIcons(
                    userLocationIcons: defaults)
            }
            return
        }
        let live = self.mapOSM.locationManager.userLocationIconConfiguration
        let person = Self.markerConfiguration(
            for: render.person, live: live.userIcon, displayScale: self.displayScale)
        let direction = Self.markerConfiguration(
            for: render.direction, live: live.directionIcon, displayScale: self.displayScale)
        self.mapOSM.locationManager.setUserLocationIcons(
            userLocationIcons: UserLocationConfiguration(
                userIcon: person, directionIcon: direction))
    }

    /// Test seam over the painting surface of the plugin-owned marker. The
    /// default painter drives the framework POI layer; session tests install
    /// a recording fake to assert the pinned-POI call sequence.
    internal(set) lazy var userLocationMarkerPainter: UserLocationMarkerPainting =
        PoisUserLocationMarkerPainter(poisManager: self.mapOSM.poisManager)

    /// Test seam over the plugin-owned marker layer. The default closure
    /// bakes the pivot and heading into the texture and paints it in place;
    /// session tests install a recorder to assert the render intent.
    internal(set) lazy var userLocationMarkerRenderer: (UserLocationMarkerRender?) -> Void = {
        [weak self] render in
        guard let self = self else { return }
        let painter = self.userLocationMarkerPainter
        let poiId = MapSession.userLocationMarkerPoiId
        guard let render = render else {
            painter.removeMarker(id: poiId)
            return
        }
        let baked = Self.bakedUserLocationMarker(render, displayScale: self.displayScale)
        // Create the marker on first use, then position and RE-APPLY the
        // icon: the pinned POI rebuilds its markers from the icon frozen at
        // creation, so a positioning call alone would revert a replaced
        // texture to the first image — on every redraw, not just the first.
        if !painter.isInstalled {
            painter.installIcon(id: poiId, image: baked.image, size: baked.size)
        }
        painter.setPositions(id: poiId, location: render.location)
        painter.installIcon(id: poiId, image: baked.image, size: baked.size)
    }

    /// Current backing scale of the hosting view.
    var displayScale: CGFloat {
        ApplePlatformUtilities.displayScale(for: mapOSM)
    }

    /// Resolves one prepared icon against the live configuration.
    private static func markerConfiguration(
        for icon: UserLocationIconRender,
        live: MarkerConfiguration?,
        displayScale: CGFloat
    ) -> MarkerConfiguration {
        let size = icon.logicalSize?.toMarkerSize(displayScale: displayScale)
        switch icon.pivot {
        case .preserve:
            if let live = live {
                // `copyWith` keeps the live pivot when the anchor is nil.
                return live.copyWith(icon: icon.image, iconSize: size)
            }
            return MarkerConfiguration(
                icon: icon.image, iconSize: size, angle: nil, anchor: nil)
        case .reset:
            return MarkerConfiguration(
                icon: icon.image, iconSize: size, angle: nil, anchor: nil)
        case .normalized(let x, let y):
            let anchor = AnchorGeoPoint(anchor: (x: x, y: y)).compute()
            if let live = live {
                return live.copyWith(icon: icon.image, iconSize: size, anchor: anchor)
            }
            return MarkerConfiguration(
                icon: icon.image, iconSize: size, angle: nil, anchor: anchor)
        }
    }

    /// Applies a prepared icon pair (typed route) or restores the platform
    /// defaults when [icons] is nil.
    ///
    /// Only the rendered icons change: the shared subscription, the follow
    /// flag and pending one-shot fixes keep running, so tracking and
    /// continuous updates survive an icon swap and no permission flow is
    /// triggered.
    func typedSetUserLocationIcons(_ icons: UserLocationIconsRender?) {
        applyUserLocationIcons(icons, force: false)
    }

    /// Hands [icons] to the framework and bookkeeps the marker refresh.
    ///
    /// [force] re-applies an identical configuration (the backing-scale
    /// refresh) instead of dropping it. Repeated identical requests are
    /// dropped on purpose: the framework's refresh is destructive, so every
    /// re-application costs one hidden marker pass.
    func applyUserLocationIcons(_ icons: UserLocationIconsRender?, force: Bool) {
        if !force && isAppliedUserLocationIcons(icons) {
            return
        }
        // Ownership first: the framework configuration seam must already see
        // it (it installs the transparent placeholder for the takeover).
        ownedUserLocationIcons = resolvedUserLocationMarkerIcons(icons)
        frameworkIconConfigIsPlaceholder = ownsUserLocationMarker
        userLocationIconsRenderer(icons)
        appliedUserLocationIcons = icons.map(AppliedUserLocationIcons.icons) ?? .defaults
        if trackMeActive {
            // Pure in-place redraw: the plugin has owned the marker since
            // the first tracking start (default icons), so replacing the
            // icons touches nothing but the marker itself — no location
            // start/stop, no extra fix, no second renderer.
            refreshOwnedUserLocationMarker()
        }
        #if os(macOS)
        recordUserLocationIconsRender(icons)
        #endif
    }

    /// True when [icons] matches what the framework already holds.
    private func isAppliedUserLocationIcons(_ icons: UserLocationIconsRender?) -> Bool {
        switch (appliedUserLocationIcons, icons) {
        case (.defaults, nil):
            return true
        case (.icons(let applied), .some(let requested)):
            return Self.sameUserLocationIcon(applied.person, requested.person)
                && Self.sameUserLocationIcon(applied.direction, requested.direction)
        default:
            return false
        }
    }

    private static func sameUserLocationIcon(
        _ lhs: UserLocationIconRender, _ rhs: UserLocationIconRender
    ) -> Bool {
        lhs.pngData == rhs.pngData && lhs.logicalSize == rhs.logicalSize
            && sameUserLocationPivot(lhs.pivot, rhs.pivot)
    }

    private static func sameUserLocationPivot(
        _ lhs: UserLocationIconRender.Pivot, _ rhs: UserLocationIconRender.Pivot
    ) -> Bool {
        switch (lhs, rhs) {
        case (.preserve, .preserve), (.reset, .reset):
            return true
        case let (.normalized(lx, ly), .normalized(rx, ry)):
            return lx == rx && ly == ry
        default:
            return false
        }
    }

    /// Draws the plugin-owned marker for one delivered fix.
    ///
    /// A pending one-shot fix is skipped: the framework does not update its
    /// marker for those passes either, so the marker keeps its last position
    /// until a tracking update arrives.
    private func updateOwnedUserLocationMarker(userLocation: CLLocationCoordinate2D, heading: Double) {
        guard ownsUserLocationMarker, trackMeActive, !hasPendingLocationRequest else {
            return
        }
        renderOwnedUserLocationMarker(location: userLocation, heading: heading)
    }

    /// Test seam over the framework tracking toggle. The default closure
    /// drives the real CLLocationManager with the captured tracking
    /// configuration; session tests install a recorder/stateful fake so
    /// no authorization prompt is ever raised and no live GPS is used.
    /// The stop side reconciles consumers: continuous updates and pending
    /// one-shot fixes keep the manager running (shared subscription).
    internal(set) lazy var trackingToggle: (Bool) -> Void = { [weak self] start in
        guard let self = self else { return }
        if start {
            if !self.mapOSM.locationManager.isTrackingEnabled() {
                self.mapOSM.locationManager.toggleTracking(
                    configuration: TrackConfiguration(
                        moveMap: true,
                        useDirectionMarker: self.trackingUseDirectionMarker,
                        disableMarkerRotation: self.trackingDisableMarkerRotation,
                        // The plugin renders the my-location marker itself;
                        // the framework arm never takes marker control.
                        controlUserMarker: false))
            } else {
                // The framework is already armed by continuous updates.
                // Its marker fields are private and toggleTracking
                // early-outs (stops) while armed, so the only
                // reconfiguration surface is a stop-and-retoggle cycle:
                // the first call stops the stream, the second restarts it
                // (authorization is guaranteed - the framework was
                // armed) applying tracking's marker configuration.
                let trackingConfiguration = TrackConfiguration(
                    moveMap: true,
                    useDirectionMarker: self.trackingUseDirectionMarker,
                    disableMarkerRotation: self.trackingDisableMarkerRotation,
                    controlUserMarker: false)
                self.mapOSM.locationManager.toggleTracking(
                    configuration: trackingConfiguration)
                self.mapOSM.locationManager.toggleTracking(
                    configuration: trackingConfiguration)
            }
        } else {
            if self.updatesActive {
                // Continuous updates keep the stream: restore their
                // marker semantics (no direction marker, no framework
                // marker control) through the same stop-and-retoggle
                // cycle instead of stopping the subscription outright.
                let updatesConfiguration = TrackConfiguration(
                    moveMap: true, controlUserMarker: false)
                self.mapOSM.locationManager.toggleTracking(
                    configuration: updatesConfiguration)
                self.mapOSM.locationManager.toggleTracking(
                    configuration: updatesConfiguration)
            } else if !self.hasPendingLocationRequest {
                self.mapOSM.locationManager.stopLocation()
            }
        }
    }

    /// Continuous-updates consumer ownership (typed and legacy routes).
    /// The framework's tracking flag cannot distinguish this consumer from
    /// follow-me tracking, so ownership is tracked here.
    var updatesActive = false

    /// Follow-me (trackMe) consumer ownership.
    var trackMeActive = false

    /// Monotonic identity of the current location request. Deadline work
    /// items capture the epoch they were armed for and become no-ops when
    /// a newer request owns the slot, so a stale timer can never expire a
    /// newer request prematurely. Internal set: tests simulate stale
    /// timers by rewinding the epoch.
    internal(set) var locationRequestEpoch = 0
    var isMovedToLocation: Bool = false
    var canSkipFollow: Bool = false
    var userLocationWithoutControl: Bool = false
    var mapInitialized: Bool = false
    let defaultMarker: String?
    private(set) var latestUserLocation: CLLocationCoordinate2D? = nil
    private var isDisposed: Bool = false
    /// Stable marker id → current coordinate for the typed markers route.
    /// Legacy additions mint UUID ids here too, so both routes share one
    /// identity registry while the native view keeps matching markers by
    /// coordinate equality (Apple's coordinate-based identity).
    var typedMarkerCoordinates: [String: CLLocationCoordinate2D] = [:]
    /// Registration order of the stable ids. Dictionary iteration order is
    /// unspecified, but the native `MarkerManager` matches markers by array
    /// order (first inserted wins), so "first id at a coordinate" must be
    /// resolved through this list to stay consistent with the native view.
    var typedMarkerOrder: [String] = []
    /// Results of in-flight road commands; completed exactly once and failed
    /// collectively on disposal so the Dart futures can never hang.
    private var outstandingRoadResults: [(id: String, result: FlutterResult)] = []
    #if os(macOS)
    /// Last user-location icon render, replayed when the hosting window moves
    /// between displays: `logicalSize` is pre-scale, so re-applying the render
    /// recomputes pixel sizes at the new backing scale while keeping the icon,
    /// pivot and the rest of the live configuration. Both the typed and the
    /// legacy route feed it; a typed reset drops it (the restored defaults
    /// carry no Dart-side sizes).
    private(set) var lastUserLocationIconsRender: UserLocationIconsRender? = nil
    /// Retains the last render for the backing-scale refresh.
    func recordUserLocationIconsRender(_ render: UserLocationIconsRender?) {
        lastUserLocationIconsRender = render
    }
    /// Logical (Dart-side, pre-scale) data retained to re-apply pixel sizes
    /// of regular markers when the hosting window moves between displays.
    /// The dictionary key is only a rounded lookup key; the exact coordinate
    /// lives in the record so refreshes and deletions never move a marker.
    private struct MarkerScaleRecord {
        var coordinate: CLLocationCoordinate2D
        var iconBase64: String?
        var logicalSize: [Int]?
        var angle: Float
        var anchorArgs: [String: Any]?
    }
    private var markerScaleRecords: [String: MarkerScaleRecord] = [:]
    /// Bitmap arguments of the last `staticPosition#IconMarker` call per POI id.
    private var staticPoiIconArgs: [String: [String: Any]] = [:]

    private static func markerScaleKey(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%F;%F", coordinate.latitude, coordinate.longitude)
    }

    func recordMarkerScale(
        coordinate: CLLocationCoordinate2D, iconBase64: String?, logicalSize: [Int]?,
        angle: Float, anchorArgs: [String: Any]?
    ) {
        markerScaleRecords[Self.markerScaleKey(coordinate)] = MarkerScaleRecord(
            coordinate: coordinate, iconBase64: iconBase64, logicalSize: logicalSize,
            angle: angle, anchorArgs: anchorArgs)
    }

    func moveMarkerScaleRecord(
        from oldCoordinate: CLLocationCoordinate2D, to newCoordinate: CLLocationCoordinate2D,
        iconBase64: String?, logicalSize: [Int]?, angle: Float, anchorArgs: [String: Any]?
    ) {
        let existing = markerScaleRecords.removeValue(
            forKey: Self.markerScaleKey(oldCoordinate))
        markerScaleRecords[Self.markerScaleKey(newCoordinate)] = MarkerScaleRecord(
            coordinate: newCoordinate,
            iconBase64: iconBase64 ?? existing?.iconBase64,
            logicalSize: logicalSize ?? existing?.logicalSize,
            angle: angle,
            anchorArgs: anchorArgs ?? existing?.anchorArgs)
    }

    func updateMarkerScaleRecord(
        at coordinate: CLLocationCoordinate2D, iconBase64: String?, logicalSize: [Int]?
    ) {
        let key = Self.markerScaleKey(coordinate)
        guard var record = markerScaleRecords[key] else {
            return
        }
        if let iconBase64 = iconBase64 {
            record.iconBase64 = iconBase64
        }
        if let logicalSize = logicalSize {
            record.logicalSize = logicalSize
        }
        markerScaleRecords[key] = record
    }

    func removeMarkerScaleRecord(at coordinate: CLLocationCoordinate2D) {
        markerScaleRecords.removeValue(forKey: Self.markerScaleKey(coordinate))
    }

    /// Exact record for a coordinate (never reconstructed from the key).
    private func storedMarkerScaleRecord(at coordinate: CLLocationCoordinate2D) -> MarkerScaleRecord? {
        markerScaleRecords[Self.markerScaleKey(coordinate)]
    }

    /// Reads the recorded angle of the marker at a coordinate, keeping the
    /// scale record consistent when a typed move preserves the angle.
    func markerScaleRecordAngle(at coordinate: CLLocationCoordinate2D) -> Float? {
        storedMarkerScaleRecord(at: coordinate)?.angle
    }

    /// Reads the recorded anchor arguments of the marker at a coordinate.
    func markerScaleRecordAnchorArgs(at coordinate: CLLocationCoordinate2D) -> [String: Any]? {
        storedMarkerScaleRecord(at: coordinate)?.anchorArgs
    }

    func recordStaticPoiIcon(id: String, bitmapArgs: [String: Any]) {
        staticPoiIconArgs[id] = bitmapArgs
    }

    func storedStaticPoiIconArgs(id: String) -> [String: Any]? {
        staticPoiIconArgs[id]
    }

    func clearStaticPoiIcon(id: String) {
        staticPoiIconArgs.removeValue(forKey: id)
    }

    /// Records a typed rotation into the existing scale record so display
    /// refreshes re-apply the new angle (the rest of the record is kept).
    func updateMarkerAngleScaleRecord(at coordinate: CLLocationCoordinate2D, angle: Float) {
        let key = Self.markerScaleKey(coordinate)
        guard var record = markerScaleRecords[key] else {
            return
        }
        record.angle = angle
        markerScaleRecords[key] = record
    }

    /// Records a typed anchor into the existing scale record.
    func updateMarkerAnchorScaleRecord(at coordinate: CLLocationCoordinate2D, anchor: MarkerAnchor) {
        let key = Self.markerScaleKey(coordinate)
        guard var record = markerScaleRecords[key] else {
            return
        }
        record.anchorArgs = ["x": anchor.x, "y": anchor.y]
        markerScaleRecords[key] = record
    }
    #endif

    /// The native view to embed: a `UIView` on iOS, an `NSView` on macOS.
    var platformView: OSMPlatformView {
        mapOSM
    }

    init(
        _ frame: CGRect, viewId: Int64, channel: FlutterMethodChannel,
        binaryMessenger: FlutterBinaryMessenger, args: Any?,
        defaultPin: String?
    ) {
        self.binaryMessenger = binaryMessenger
        var initLocation: CLLocationCoordinate2D?
        var enableRotationGesture = false
        defaultMarker = defaultPin
        if (args as? [String: Any]) != nil {
            if (args as! [String: Any]).keys.contains("customTile") {
                customTiles = CustomTiles(
                    ((args as! [String: Any])["customTile"] as? [String: Any])!)

            }
            if (args as! [String: Any]).keys.contains("bounds") {
                let boundArgs = (args as! [String: Any])["bounds"] as? [Double]
                boundingbox = BoundingBox(boundingBoxs: boundArgs!)
            }
            if (args as! [String: Any]).keys.contains("zoomOption") {
                let zoomArgs = (args as! [String: Any])["zoomOption"] as? [String: Int]
                self.zoomConfig = ZoomConfiguration(zoomArgs!)
            }
            if (args as! [String: Any]).keys.contains("location") {
                let locationArgs = (args as! [String: Any])["location"] as? [String: Double]
                initLocation = CLLocationCoordinate2D(
                    latitude: (locationArgs!["lat"])!, longitude: locationArgs!["lon"]!)
            }

            if (args as! [String: Any]).keys.contains("enableRotationGesture") {
                enableRotationGesture = (args as! [String: Any])["enableRotationGesture"] as! Bool

            }
        }
        isStaticMap = (args as! [String: Any])["isStaticMap"] as? Bool ?? false

        let configuration = OSMMapConfiguration(
            zoomLevelScaleFactor: 0.65, adaptScaleToScreen: true)
        self.mapOSM = OSMView(
            rect: frame, location: initLocation, zoomConfig: self.zoomConfig,
            mapTileConfiguration: configuration)
        self.channel = channel
        self.viewId = viewId
        super.init()
        // Capture the framework's user-location icons before any route can
        // replace them: the typed reset route restores exactly these.
        self.defaultUserLocationIcons = self.mapOSM.locationManager.userLocationIconConfiguration
        self.mapOSM.enableRotation(enable: enableRotationGesture)
        // Generated camera and markers endpoints live alongside the legacy
        // channel handler; they never replace it.
        let bridge = PigeonCameraBridge(session: self)
        bridge.register(messenger: binaryMessenger, viewId: viewId)
        cameraBridge = bridge
        let markers = PigeonMarkersBridge(session: self)
        markers.register(messenger: binaryMessenger, viewId: viewId)
        markersBridge = markers
        let layers = PigeonLayersBridge(session: self)
        layers.register(messenger: binaryMessenger, viewId: viewId)
        layersBridge = layers
        let shapes = PigeonShapesBridge(session: self)
        shapes.register(messenger: binaryMessenger, viewId: viewId)
        shapesBridge = shapes
        let roads = PigeonRoadsBridge(session: self)
        roads.register(messenger: binaryMessenger, viewId: viewId)
        roadsBridge = roads
        let location = PigeonLocationBridge(session: self)
        location.register(messenger: binaryMessenger, viewId: viewId)
        locationBridge = location
        let updates = PigeonLocationUpdatesBridge(session: self)
        updates.register(messenger: binaryMessenger, viewId: viewId)
        locationUpdatesBridge = updates
        let tracking = PigeonTrackingBridge(session: self)
        tracking.register(messenger: binaryMessenger, viewId: viewId)
        trackingBridge = tracking
        let userLocationIcons = PigeonUserLocationIconsBridge(session: self)
        userLocationIcons.register(messenger: binaryMessenger, viewId: viewId)
        userLocationIconsBridge = userLocationIcons
        // Generated lifecycle callbacks (readiness) live alongside the
        // legacy event plane; delivery switches only after the validated
        // pre-initialization route selection.
        lifecycleEventsBridge = PigeonLifecycleEventsBridge(
            messenger: binaryMessenger, viewId: viewId,
            sessionToken: sessionToken, generation: generation)
        // Generated interaction callbacks (single/long presses) live
        // alongside the legacy event plane; delivery switches only after
        // the validated pre-initialization route selection.
        interactionEventsBridge = PigeonInteractionEventsBridge(
            messenger: binaryMessenger, viewId: viewId,
            sessionToken: sessionToken, generation: generation)
        // Generated marker interaction callbacks live alongside the legacy
        // event plane; delivery switches only after the validated
        // pre-initialization route selection.
        markerEventsBridge = PigeonMarkerEventsBridge(
            messenger: binaryMessenger, viewId: viewId,
            sessionToken: sessionToken, generation: generation)
        // Generated road tap callbacks likewise.
        roadEventsBridge = PigeonRoadEventsBridge(
            messenger: binaryMessenger, viewId: viewId,
            sessionToken: sessionToken, generation: generation)
        channel.setMethodCallHandler({ [weak self]
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            // The default Flutter channel uses the platform thread. Assert that
            // contract before accessing the isolated session.
            MainActor.assumeIsolated {
                self?.onListenMethodChannel(call: call, result: result)
            }
        })
        // Route every framework delegate through a weak proxy so the map view
        // never retains the session directly (see MapDelegateProxy).
        let delegateProxy = MapDelegateProxy(session: self)
        self.mapOSM.onMapGestureDelegate = delegateProxy
        self.mapOSM.mapHandlerDelegate = delegateProxy
        self.mapOSM.userLocationDelegate = delegateProxy
        self.mapOSM.roadTapHandlerDelegate = delegateProxy
        self.mapOSM.onMapMove = delegateProxy
        self.mapOSM.enableRotation(enable: enableRotationGesture)
        if self.isStaticMap {
            self.mapOSM.disableTouch()
        }
    }

    /// Wraps a road-command result so it is completed exactly once: either by
    /// the normal command flow or with a disposal error when the map goes away
    /// before the routing request finishes.
    func trackRoadResult(id: String, _ result: @escaping FlutterResult) -> FlutterResult {
        outstandingRoadResults.append((id, result))
        return { [weak self] reply in
            self?.completeRoadResult(id: id, reply: reply)
        }
    }

    private func completeRoadResult(id: String, reply: Any?) {
        guard let index = outstandingRoadResults.firstIndex(where: { $0.id == id }) else {
            // Already completed (or failed during disposal).
            return
        }
        let entry = outstandingRoadResults.remove(at: index)
        entry.result(reply)
    }

    /// macOS hook invoked by the hosting view when its backing properties
    /// (display scale, color space) change: re-applies every scale-dependent
    /// icon at the new backing scale — user-location markers (sizes only,
    /// preserving the icon, angle and anchor of the live configuration, e.g.
    /// the tracking anchor applied by `startTrackUser`), static POI icons, and
    /// regular markers (updated in place at their location).
    func handleDisplayScaleChanged() {
        #if os(macOS)
        guard !isDisposed else {
            return
        }
        let displayScale = ApplePlatformUtilities.displayScale(for: mapOSM)

        // 1. User-location icons: replay the last render so the pre-scale
        //    logical sizes are recomputed at the new backing scale, keeping the
        //    icons, pivots and the rest of the live configuration. Both routes
        //    feed this record.
        if let render = lastUserLocationIconsRender {
            // Forced: the render is identical but the pixel sizes it
            // resolves to depend on the new backing scale.
            applyUserLocationIcons(render, force: true)
        }
        // The plugin-rendered marker re-derives its pixel size from the new
        // scale; the framework marker takes the replayed configuration.
        refreshOwnedUserLocationMarker()

        // 2. Static POI icons: `setOrCreateIconPoi` updates existing POIs
        //    in place, so replaying the stored icon arguments is enough.
        for (id, bitmapArg) in staticPoiIconArgs {
            setMarkerStaticGeoPIcon(
                call: FlutterMethodCall(
                    methodName: "staticPosition#IconMarker",
                    arguments: ["id": id, "bitmap": bitmapArg]))
        }

        // 3. Regular markers: refresh icon size in place, using the exact
        //    stored coordinate (never reconstructed from the lookup key, so
        //    the marker location — and later deletions — are unaffected).
        for record in markerScaleRecords.values {
            let coordinate = record.coordinate
            var icon = record.iconBase64.flatMap { convertImage(codeImage: $0) }
            if icon == nil {
                if let defaultMarker = defaultMarker {
                    icon = ApplePlatformUtilities.bundledImage(named: defaultMarker)
                        ?? ApplePlatformUtilities.systemImage(named: "mappin")
                } else {
                    icon = ApplePlatformUtilities.systemImage(named: "mappin")
                }
            }
            let anchor = record.anchorArgs.map { AnchorGeoPoint(anchorMap: $0).compute() }
            mapOSM.markerManager.updateMarker(
                oldlocation: coordinate, newlocation: coordinate,
                icon: icon,
                iconSize: record.logicalSize?.toMarkerSize(displayScale: displayScale),
                angle: record.angle,
                anchor: anchor)
        }
        #endif
    }

    /// Emits one readiness transition through the attachment's single
    /// negotiated delivery route: the generated Pigeon callbacks when the
    /// pre-initialization selection switched this session, the legacy
    /// `map#init` event plane otherwise.
    func emitMapReady(_ isReady: Bool) {
        if lifecycleEventsUsePigeon, let bridge = lifecycleEventsBridge {
            bridge.emitReady(isReady)
        } else {
            channel.invokeMethod("map#init", arguments: isReady)
        }
    }

    /// Attach-time lifecycle event route selection. Validates the session
    /// identity so a stale selection can never switch another attachment's
    /// delivery route. Returns nil on success, a typed error code otherwise.
    func selectLifecycleEventRoute(
        sessionToken: String, generation: Int64, route: String
    ) -> String? {
        if isDisposed { return "disposed" }
        if sessionToken != self.sessionToken || generation != self.generation {
            return "stale_session"
        }
        switch route {
        case "pigeon":
            lifecycleEventsUsePigeon = true
            return nil
        case "legacy":
            lifecycleEventsUsePigeon = false
            return nil
        default:
            return "invalid_route"
        }
    }

    /// Attach-time interaction event route selection. Validates the session
    /// identity so a stale selection can never switch another attachment's
    /// delivery route. Returns nil on success, a typed error code otherwise.
    func selectInteractionEventRoute(
        sessionToken: String, generation: Int64, route: String
    ) -> String? {
        if isDisposed { return "disposed" }
        if sessionToken != self.sessionToken || generation != self.generation {
            return "stale_session"
        }
        switch route {
        case "pigeon":
            interactionEventsUsePigeon = true
            return nil
        case "legacy":
            interactionEventsUsePigeon = false
            return nil
        default:
            return "invalid_route"
        }
    }

    /// Attach-time marker event route selection. Validates the session
    /// identity so a stale selection can never switch another attachment's
    /// delivery route. Returns nil on success, a typed error code otherwise.
    func selectMarkerEventRoute(
        sessionToken: String, generation: Int64, route: String
    ) -> String? {
        if isDisposed { return "disposed" }
        if sessionToken != self.sessionToken || generation != self.generation {
            return "stale_session"
        }
        switch route {
        case "pigeon":
            markerEventsUsePigeon = true
            return nil
        case "legacy":
            markerEventsUsePigeon = false
            return nil
        default:
            return "invalid_route"
        }
    }

    /// Attach-time road event route selection. Same contract as the marker
    /// selection, scoped to road taps.
    func selectRoadEventRoute(
        sessionToken: String, generation: Int64, route: String
    ) -> String? {
        if isDisposed { return "disposed" }
        if sessionToken != self.sessionToken || generation != self.generation {
            return "stale_session"
        }
        switch route {
        case "pigeon":
            roadEventsUsePigeon = true
            return nil
        case "legacy":
            roadEventsUsePigeon = false
            return nil
        default:
            return "invalid_route"
        }
    }

    /// Tears down the session: stops the method-channel handler, detaches every
    /// framework delegate, stops location work and fails any pending result.
    /// Safe to call more than once (from the platform wrapper and from deinit).
    func dispose() {
        guard !isDisposed else {
            return
        }
        isDisposed = true
        cameraBridge?.unregister(messenger: binaryMessenger, viewId: viewId)
        cameraBridge = nil
        markersBridge?.unregister(messenger: binaryMessenger, viewId: viewId)
        markersBridge = nil
        layersBridge?.unregister(messenger: binaryMessenger, viewId: viewId)
        layersBridge = nil
        shapesBridge?.unregister(messenger: binaryMessenger, viewId: viewId)
        shapesBridge = nil
        roadsBridge?.unregister(messenger: binaryMessenger, viewId: viewId)
        roadsBridge = nil
        locationBridge?.unregister(messenger: binaryMessenger, viewId: viewId)
        locationBridge = nil
        locationUpdatesBridge?.unregister(messenger: binaryMessenger, viewId: viewId)
        locationUpdatesBridge = nil
        trackingBridge?.unregister(messenger: binaryMessenger, viewId: viewId)
        trackingBridge = nil
        userLocationIconsBridge?.unregister(messenger: binaryMessenger, viewId: viewId)
        userLocationIconsBridge = nil
        lifecycleEventsBridge?.close()
        lifecycleEventsBridge = nil
        interactionEventsBridge?.close()
        interactionEventsBridge = nil
        markerEventsBridge?.close()
        markerEventsBridge = nil
        roadEventsBridge?.close()
        roadEventsBridge = nil
        channel.setMethodCallHandler(nil)
        mapOSM.onMapGestureDelegate = nil
        mapOSM.mapHandlerDelegate = nil
        mapOSM.userLocationDelegate = nil
        mapOSM.roadTapHandlerDelegate = nil
        mapOSM.onMapMove = nil
        mapOSM.locationManager.stopLocation()
        // Disposal completes any pending location request (typed or
        // legacy) exactly once; deferred stops are moot afterwards.
        stopUpdatesWhenFixCompletes = false
        stopTrackingWhenFixCompletes = false
        updatesActive = false
        trackMeActive = false
        startingUpdatesCompletion = nil
        startingTrackingCompletion = nil
        failPendingLocationRequest(code: "disposed", message: "map was disposed")
        let pendingRoads = outstandingRoadResults
        outstandingRoadResults.removeAll()
        for entry in pendingRoads {
            entry.result(
                FlutterError(
                    code: "disposed", message: "map was disposed before the road completed",
                    details: nil))
        }
    }

    deinit {
        // MapSession references are only dropped by the engine on the main
        // thread (platform-view teardown), so main-actor isolation holds here.
        MainActor.assumeIsolated {
            self.dispose()
        }
    }

    // MARK: - Framework event forwarding

    func onTap(roadId: String) {
        // Exactly one delivery route per attachment: the negotiated road
        // route owns road taps and carries the legacy payload field for
        // field; every other attachment keeps the legacy plane.
        if roadEventsUsePigeon, let bridge = roadEventsBridge {
            let roadSelected = storedRoads[roadId]
            let tappedRoad: NativeTappedRoad
            if let road = roadSelected {
                tappedRoad = NativeTappedRoad(
                    key: roadId,
                    distance: road.roadInformation?.distance,
                    duration: road.roadInformation?.seconds,
                    routePoints: road.roadInformation?.encodedRoute,
                    instructions: road.instructions.map { instruction in
                        NativeRoadInstruction(
                            instruction: instruction.instruction,
                            latitude: instruction.location.latitude,
                            longitude: instruction.location.longitude)
                    })
            } else {
                // Unknown road: the legacy plane sent only the key, and the
                // typed payload mirrors that (all optional fields null).
                tappedRoad = NativeTappedRoad(
                    key: roadId, distance: nil, duration: nil,
                    routePoints: nil, instructions: nil)
            }
            bridge.emitRoadTap(tappedRoad)
            return
        }
        DispatchQueue.main.async {
            let roadSelected = self.storedRoads[roadId]
            if let road = roadSelected {
                var mapInfo = road.roadInformation?.toMap(instructions: road.instructions) ?? [:]
                mapInfo["key"] = roadId
                self.channel.invokeMethod("receiveRoad", arguments: mapInfo)
            } else {
                self.channel.invokeMethod("receiveRoad", arguments: ["key": roadId])
            }
        }

    }

    func onMove(center: CLLocationCoordinate2D, bounds: BoundingBox, zoom: Double) {
        let data: [String: Any] = [
            "center": center.toGeoPoint(), "bounding": bounds.toMap(), "zoomLevel": zoom,
        ]
        if self.mapOSM.locationManager.isTrackingEnabled() && !isMovedToLocation
            && latestUserLocation != nil && latestUserLocation! - center
        {
            isMovedToLocation = true
        }
        DispatchQueue.main.async {
            self.channel.invokeMethod("receiveRegionIsChanging", arguments: data)
        }
    }

    func onRotate(angle: Double) {

    }

    func onMapInteraction() {
        if self.mapOSM.locationManager.isTrackingEnabled() && isMovedToLocation
            && latestUserLocation != nil && !canSkipFollow && !userLocationWithoutControl
        {
            canSkipFollow = true
            self.mapOSM.stopCamera()
        }
    }

    func locationChanged(userLocation: CLLocationCoordinate2D, heading: Double) {
        let geoMap = userLocation.toUserLocation(heading: heading)
        latestUserLocation = userLocation
        channel.invokeMethod("receiveUserLocation", arguments: geoMap)
        latestUserLocationHeading = heading
        updateOwnedUserLocationMarker(userLocation: userLocation, heading: heading)
        if (!isMovedToLocation || !canSkipFollow) && !userLocationWithoutControl && mapInitialized {
            self.mapOSM.locationManager.moveToUserLocation(animated: true)
        }

        // A pending generated fix wins the single location slot; the
        // legacy pending result keeps its own completion otherwise.
        if pendingLocationFixCompletion != nil {
            completeLocationFix(.fixed(latitude: userLocation.latitude, longitude: userLocation.longitude))
            return
        }
        if let result = resultFlutter {
            // Success cancels the request's deadline; an armed timer left
            // behind could otherwise expire a newer request prematurely.
            locationFixTimeoutWorkItem?.cancel()
            locationFixTimeoutWorkItem = nil
            result(geoMap)
            resultFlutter = nil
            endDeferredUpdatesStopIfNeeded()
            endDeferredTrackingStopIfNeeded()
        }
    }

    func handlePermission(state: OSMFlutterFramework.LocationPermission) {
        if state == LocationPermission.NotGranted {
            // Authorization denied or restricted: complete any pending
            // fix request exactly once with a permission error so
            // `myLocation()` — and the withUserPosition initialization
            // waiting on it — fails clearly instead of hanging forever.
            // Permission denial is handled independently per consumer:
            //
            // 1. An in-flight updates start (synchronous framework denial)
            //    completes with permission_denied and rolls back its
            //    ownership.
            // 2. Any pending one-shot fix fails with its own denial code.
            // 3. Updates ownership resets unconditionally: updates cannot
            //    run without permission, so a denial of the authorization
            //    prompt - which arrives after an initiated start already
            //    completed - still resets ownership and a retry genuinely
            //    re-attempts instead of reporting stale success.
            // 4. The framework's tracking flag resets too (through the
            //    toggle seam): a start that reached toggleTracking arms it,
            //    and a stale armed flag makes the native retry skip the
            //    toggle and report success without running updates.
            updatesActive = false
            userLocationWithoutControl = false
            if let startCompletion = startingUpdatesCompletion {
                startingUpdatesCompletion = nil
                startCompletion("permission_denied", "location permission was not granted")
            }
            // 3b. An in-flight tracking start completes with
            //     permission_denied and rolls back its ownership;
            //     tracking ownership resets unconditionally because
            //     permission is a prerequisite for tracking at all.
            trackMeActive = false
            if let trackingStart = startingTrackingCompletion {
                startingTrackingCompletion = nil
                trackingStart("permission_denied", "location permission was not granted")
            }
            failPendingLocationRequest(
                code: "permission_denied",
                message: "location permission was not granted",
                legacyCode: "permission")
            // The framework tracking state resets through the toggle
            // seam (shared flag for updates and tracking): a stale armed
            // flag makes any native retry skip the toggle and report
            // success without running updates or following.
            locationUpdatesToggle(false)
        }
    }

    // MARK: - Typed location operations

    /// Enables the my-location layer, mirroring the legacy
    /// `currentLocation` handler: fire-and-forget enable; the framework
    /// prompts when authorization requires it. Denial surfaces through the
    /// permission callback, not as a hang.
    func typedShowMyLocation() {
        mapOSM.locationManager.requestEnableLocation()
    }

    /// Whether a location request is pending, typed or legacy. One guard
    /// owns both slots: they can never be occupied at the same time.
    var hasPendingLocationRequest: Bool {
        pendingLocationFixCompletion != nil || resultFlutter != nil
    }

    /// Single-shot current position. Completes exactly once — on fix,
    /// permission denial, timeout, disposal; overlapping requests (typed
    /// or legacy) fail immediately instead of overwriting the pending
    /// slot.
    func typedRequestLocationFix(completion: @escaping LocationFixCompletion) {
        if hasPendingLocationRequest {
            completion(.failed(code: "location_request_in_progress", message: nil))
            return
        }
        pendingLocationFixCompletion = completion
        locationRequestEpoch += 1
        scheduleLocationFixTimeout()
        locationSingleShotRequest()
    }

    /// Legacy `user#position` shares the single ownership guard and the
    /// deadline with the generated route: an overlapping request fails
    /// immediately (its FlutterResult receives the error verbatim), the
    /// stash happens only after the guard passes, and the timeout covers
    /// legacy waits exactly like typed ones.
    func beginLegacyLocationFix(_ result: @escaping FlutterResult) {
        if hasPendingLocationRequest {
            result(
                FlutterError(
                    code: "location_request_in_progress",
                    message: "Another location request is already pending for this map.",
                    details: nil))
            return
        }
        resultFlutter = result
        locationRequestEpoch += 1
        scheduleLocationFixTimeout()
        locationSingleShotRequest()
    }

    /// Fails whichever pending location request exists (typed or legacy)
    /// exactly once, cancels the deadline, and ignores late calls. The
    /// legacy route keeps its historical error code when one is provided.
    @discardableResult
    func failPendingLocationRequest(
        code: String, message: String?, legacyCode: String? = nil
    ) -> Bool {
        if pendingLocationFixCompletion != nil {
            completeLocationFix(.failed(code: code, message: message))
            return true
        }
        if let result = resultFlutter {
            resultFlutter = nil
            locationFixTimeoutWorkItem?.cancel()
            locationFixTimeoutWorkItem = nil
            result(
                FlutterError(
                    code: legacyCode ?? code,
                    message: message ?? "",
                    details: nil))
            endDeferredUpdatesStopIfNeeded()
            endDeferredTrackingStopIfNeeded()
            return true
        }
        return false
    }

    /// Arms the single-shot deadline. Exposed separately so tests can
    /// exercise the timeout without touching the real location manager.
    func scheduleLocationFixTimeout() {
        let armedEpoch = locationRequestEpoch
        let workItem = DispatchWorkItem { [weak self] in
            // Request-identity binding: a timer armed for an older request
            // must never fail a newer one.
            guard let self = self, self.locationRequestEpoch == armedEpoch else { return }
            _ = self.failPendingLocationRequest(
                code: "location_timeout",
                message: "timed out waiting for a location fix")
        }
        locationFixTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + locationFixTimeoutSeconds, execute: workItem)
    }

    /// Outcome callback for location commands that can only fail. A nil
    /// failure code means success; the callback fires exactly once.
    typealias LocationCommandCompletion = (String?, String?) -> Void

    /// Starts continuous user-location updates without follow control.
    /// Idempotent; completes exactly once. When authorization is already
    /// denied, the framework reports it synchronously through the
    /// permission callback and the completion carries `permission_denied`;
    /// when a prompt is required, the completion reports the initiated
    /// flow and the outcome keeps flowing on the existing channels.
    func typedStartLocationUpdates(completion: @escaping LocationCommandCompletion) {
        // Idempotent: the updates consumer already owns updates.
        if updatesActive {
            completion(nil, nil)
            return
        }
        // Updates mode owns the camera on two levels: the session skips
        // its recenter (userLocationWithoutControl), and the framework
        // skips its own recenter — its controlMapFromOutSide knob is
        // configured from moveMap, so updates mode arms it with true.
        // (The pinned framework recenters on every update when the knob
        // is false, independently of userLocationWithoutControl.)
        userLocationWithoutControl = true
        updatesActive = true
        startingUpdatesCompletion = completion
        locationUpdatesToggle(true)
        // A synchronous denial was routed by handlePermission and cleared
        // the slot; otherwise the flow is initiated.
        if let pending = startingUpdatesCompletion {
            startingUpdatesCompletion = nil
            pending(nil, nil)
        }
    }

    /// Pending tracking start completion: only armed around the
    /// synchronous toggle call so a denial reported through the
    /// permission callback routes to the start completion, not to a fix.
    var startingTrackingCompletion: LocationCommandCompletion?

    /// Starts follow-me tracking. Idempotent; completes exactly once.
    /// Mirrors legacy `trackMe`: without stop-follow-on-drag the gesture
    /// skip resets and the enable-location entry runs (authorization
    /// prompt included), both user and direction icons take the requested
    /// anchor when one is supplied, and the framework toggle arms the
    /// captured configuration. A synchronous denial routes through the
    /// permission callback and the completion carries `permission_denied`;
    /// a prompt flow reports initiated.
    func typedEnableTracking(
        stopFollowInDrag: Bool,
        disableMarkerRotation: Bool,
        useDirectionMarker: Bool,
        anchorX: Double?,
        anchorY: Double?,
        completion: @escaping LocationCommandCompletion
    ) {
        // Idempotent: tracking already owns the manager.
        if trackMeActive {
            completion(nil, nil)
            return
        }
        if !stopFollowInDrag {
            canSkipFollow = false
            locationEnableRequest()
        }
        // The plugin renders the my-location marker from this arm on, with
        // the platform default icons until the application configures its
        // own. The framework arm therefore never takes marker control, so a
        // later icon replacement is an in-place redraw — never a renderer
        // handoff.
        if !ownsUserLocationMarker {
            ownedUserLocationIcons = resolvedUserLocationMarkerIcons(nil)
        }
        // No override keeps the pivots the icons were configured with (or
        // the platform default), so configured per-icon anchors survive the
        // tracking start.
        if let anchorX = anchorX, let anchorY = anchorY {
            updateOwnedUserLocationMarkerAnchor(x: anchorX, y: anchorY)
        }
        trackingDisableMarkerRotation = disableMarkerRotation
        trackingUseDirectionMarker = useDirectionMarker
        trackMeActive = true
        startingTrackingCompletion = completion
        trackingToggle(true)
        // A synchronous denial was routed by handlePermission and cleared
        // the slot; otherwise the flow is initiated.
        if let pending = startingTrackingCompletion {
            startingTrackingCompletion = nil
            pending(nil, nil)
        }
        // Draw once the arm holds (a denial rolled tracking back, so no
        // marker appears); the first fix paints it otherwise.
        if trackMeActive {
            refreshOwnedUserLocationMarker()
        }
    }

    /// Whether a typed tracking stop is waiting behind a pending one-shot
    /// fix. The fix keeps the manager running to deliver its result; the
    /// now-unowned tracking ends when the request completes.
    var stopTrackingWhenFixCompletes = false

    /// Ends follow-me tracking. Idempotent, never prompts, never fails.
    /// Continuous updates and pending one-shot fixes keep the manager
    /// running: while a fix is pending the stop is deferred until it
    /// completes or cancels, and updates keep the framework armed.
    func typedDisableTracking() {
        trackMeActive = false
        clearOwnedUserLocationMarker()
        if hasPendingLocationRequest {
            stopTrackingWhenFixCompletes = true
        } else {
            trackingToggle(false)
        }
    }

    /// Finishes a deferred tracking stop once the preserved request has
    /// completed. Late calls and re-owned managers are no-ops.
    func endDeferredTrackingStopIfNeeded() {
        guard stopTrackingWhenFixCompletes else { return }
        stopTrackingWhenFixCompletes = false
        if !updatesActive && !trackMeActive && !hasPendingLocationRequest {
            trackingToggle(false)
        }
    }

    /// Whether a typed stop is waiting behind a pending one-shot fix.
    /// The fix keeps the manager running to deliver its fix; the
    /// now-unowned updates end when the request completes.
    var stopUpdatesWhenFixCompletes = false

    /// Ends the continuous-updates consumer. Idempotent, never prompts,
    /// never fails; pending one-shot fixes and tracking keep running.
    /// Reconciliation uses session consumer ownership, not the framework
    /// tracking flag: start arms the framework flag for updates mode too,
    /// so it can never distinguish the consumers.
    func typedStopLocationUpdates() {
        userLocationWithoutControl = false
        updatesActive = false
        if hasPendingLocationRequest {
            // Preserve the pending one-shot; the subscription ends when
            // the request completes.
            stopUpdatesWhenFixCompletes = true
        } else if !trackMeActive {
            locationUpdatesToggle(false)
        }
    }

    /// Finishes a deferred updates stop once the preserved request has
    /// completed. Late calls and re-owned managers are no-ops.
    func endDeferredUpdatesStopIfNeeded() {
        guard stopUpdatesWhenFixCompletes else { return }
        stopUpdatesWhenFixCompletes = false
        if !updatesActive && !trackMeActive && !hasPendingLocationRequest {
            locationUpdatesToggle(false)
        }
    }

    /// Completes the pending generated fix exactly once and cancels the
    /// timeout. Late calls are ignored.
    func completeLocationFix(_ outcome: LocationFixOutcome) {
        guard let completion = pendingLocationFixCompletion else { return }
        pendingLocationFixCompletion = nil
        locationFixTimeoutWorkItem?.cancel()
        locationFixTimeoutWorkItem = nil
        completion(outcome)
        endDeferredUpdatesStopIfNeeded()
        endDeferredTrackingStopIfNeeded()
    }

    func onMarkerSingleTap(location: CLLocationCoordinate2D) {
        // Exactly one delivery route per attachment: the negotiated marker
        // route owns marker presses and forwards the host's raw doubles;
        // every other attachment keeps the legacy plane.
        if markerEventsUsePigeon, let bridge = markerEventsBridge {
            bridge.emitSinglePress(latitude: location.latitude, longitude: location.longitude)
            return
        }
        DispatchQueue.main.async {
            self.channel.invokeMethod("receiveGeoPoint", arguments: location.toGeoPoint())
        }
    }

    func onMarkerLongPress(location: CLLocationCoordinate2D) {
        if markerEventsUsePigeon, let bridge = markerEventsBridge {
            bridge.emitLongPress(latitude: location.latitude, longitude: location.longitude)
            return
        }
        DispatchQueue.main.async {
            self.channel.invokeMethod("receiveGeoPointLongPress", arguments: location.toGeoPoint())
        }
    }

    func onSingleTap(location: CLLocationCoordinate2D) {
        // Exactly one delivery route per attachment: the negotiated
        // interaction route owns presses and forwards the host's raw
        // doubles (full precision, no map round-trip); every other
        // attachment (JNI, opt-out) keeps the legacy plane.
        if interactionEventsUsePigeon, let bridge = interactionEventsBridge {
            bridge.emitSinglePress(latitude: location.latitude, longitude: location.longitude)
            return
        }
        DispatchQueue.main.async {
            self.channel.invokeMethod("receiveSinglePress", arguments: location.toGeoPoint())
        }

    }

    func onLongTap(location: CLLocationCoordinate2D) {
        if interactionEventsUsePigeon, let bridge = interactionEventsBridge {
            bridge.emitLongPress(latitude: location.latitude, longitude: location.longitude)
            return
        }
        DispatchQueue.main.async {
            self.channel.invokeMethod("receiveLongPress", arguments: location.toGeoPoint())
        }

    }
}

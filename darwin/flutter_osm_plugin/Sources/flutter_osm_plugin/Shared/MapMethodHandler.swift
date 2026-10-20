//
//  MapMethodHandler.swift
//  flutter_osm_plugin
//
//  Command dispatch and command implementations for the shared `MapSession`.
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

extension MapSession {

    func onListenMethodChannel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        print(call.method)
        switch call.method {
        case "init#ios#map":
            //channel.invokeMethod("map#init", arguments: true)
            if let tile = customTiles {
                mapOSM.setCustomTile(tile: tile)
            }
            mapOSM.setZoom(zoom: 1)
            channel.invokeMethod("map#init#ios", arguments: true)
            result(200)
            break
        case "change#tile":
            let args = call.arguments as! [String: Any]?

            if let customTileArgs = args {
                let tile = CustomTiles(customTileArgs)
                self.mapOSM.setCustomTile(tile: tile)
            }

            result(200)
            break
        case "initMap":
            initPosition(args: call.arguments, result: result)
            mapInitialized = true
            break
        case "config#Zoom":
            configZoomMap(call: call)
            result(200)
            break
        case "limitArea":
            setCameraAreaLimit(call: call)
            result(200)
            break
        case "remove#limitArea":
            removeCameraAreaLimit(result: result)
            result(200)
            break
        case "changePosition":
            // @deprecated
            // changePosition(args: call.arguments, result: result)
            result(200)
            break
        case "currentLocation":
            self.mapOSM.locationManager.requestEnableLocation()
            result(200)
            break
        case "map#center":
            result(self.mapOSM.center().toGeoPoint())
            break
        case "trackMe":
            let args = call.arguments as! [Any]
            startTrackUser(args: args)
            result(200)
            break
        case "user#position":
            self.mapOSM.locationManager.requestSingleLocation()
            resultFlutter = result
            break
        case "moveTo#position":
            moveToSpecificLocation(call: call, result: result)
            break
        case "map#bounds":
            getMapBounds(result: result)
            break
        case "user#removeMarkerPosition":
            deleteMarker(call: call)
            result(200)
            break
        case "deactivateTrackMe":
            stopTracking()
            result(200)
            break
        case "startLocationUpdating":
            userLocationWithoutControl = true
            if !self.mapOSM.locationManager.isTrackingEnabled() {
                self.mapOSM.locationManager.toggleTracking(
                    configuration: TrackConfiguration(moveMap: false, controlUserMarker: false))
            }
            result(200)
            break
        case "stopLocationUpdating":
            userLocationWithoutControl = false
            stopTracking()
            result(200)
            break
        case "Zoom":
            changeMapZoom(call.arguments)
            result(200)
            break
        case "get#Zoom":
            result(self.mapOSM.zoom())
            break
        case "change#stepZoom":

            result(200)
            break
        case "zoomToRegion":
            zoomMapToBoundingBox(call: call)
            result(200)
            break
        case "marker#icon":
            let args = call.arguments as! [String: Any]
            homeMarker = convertImage(codeImage: args["icon"] as! String)
            result(200)
            break
        case "staticPosition#IconMarker":
            setMarkerStaticGeoPIcon(call: call)
            result(200)
            break
        case "staticPosition":
            setStaticGeoPoint(call: call)
            result(200)
            break
        case "road":
            let roadKey = ((call.arguments as? [String: Any])?["key"] as? String) ?? UUID().uuidString
            let trackedResult = trackRoadResult(id: roadKey, result)
            drawRoadMCOSM(call: call) {
                [weak self] roadInfo, road, roadData, boundingbox, polyline, error in
                guard let self else {
                    // Dispose already failed the tracked result.
                    return
                }
                if error != nil {
                    trackedResult(FlutterError(code: "400", message: "error to draw road", details: nil))
                } else {
                    lastRoadKey = roadInfo?.id
                    let roadConfiguration = roadData.toRoadConfiguration()
                    let coordinates = polyline?.coordinates
                    self.mapOSM.roadManager.addRoad(
                        id: lastRoadKey!, polylines: coordinates!, configuration: roadConfiguration)

                    if let bounding = boundingbox {
                        self.mapOSM.moveToByBoundingBox(bounds: bounding, animated: true)
                    }
                    let instructions = road?.toInstruction() ?? [RoadInstruction]()
                    storedRoads[roadInfo!.id] = StoredRoad(
                        id: roadInfo!.id, roadInformation: roadInfo, instructions: instructions)
                    trackedResult(roadInfo!.toMap(instructions: instructions))
                }

            }
            //result(["distance": 0, "duration": 0])
            break
        case "draw#multi#road":
            let trackedResult = trackRoadResult(id: "multi-" + UUID().uuidString, result)
            drawMultiRoad(call: call) { [weak self] roadInfos, roadsAndRoadData, error in
                guard let self else {
                    // Dispose already failed the tracked result.
                    return
                }
                if roadInfos.isEmpty && roadsAndRoadData.isEmpty {
                    trackedResult(
                        FlutterError(
                            code: "400", message: "error to draw multiple road", details: nil))
                } else {
                    let roads = roadsAndRoadData.filter { road in
                        road != nil
                    }
                    .map { roadAndRoadData -> (String, Road) in

                        var road = roadAndRoadData!.1
                        road.roadData = roadAndRoadData!.2
                        return (roadAndRoadData!.0, road)
                    }
                    roads.forEach { road in
                        let roadData = road.1.roadData
                        let polyline = Polyline(encodedPolyline: road.1.mRouteHigh, precision: 1e5)
                        let roadConfig = RoadConfiguration(
                            width: roadData.roadWidth.toFloat(),
                            color: OSMPlatformColor(hexString: roadData.roadColor) ?? .green,
                            borderWidth: roadData.roadBorderWidth.toFloat(),
                            borderColor: OSMPlatformColor(hexString: roadData.roadBorderColor)
                        )
                        self.mapOSM.roadManager.addRoad(
                            id: road.0, polylines: polyline.coordinates!, configuration: roadConfig)
                    }
                    let infos = roadInfos.filter { info in
                        info != nil
                    }
                    .enumerated()
                    .map { (index, info) -> [String: Any] in
                        let instructions = roads[index].1.toInstruction()
                        return info!.toMap(instructions: instructions)
                    }
                    trackedResult(infos)
                }

            }

            break
        case "drawRoad#manually":
            drawRoadManually(call: call, result: result)
            break
        case "delete#road":
            deleteRoad(call: call, result: result)
            break
        case "clear#roads":
            self.mapOSM.roadManager.removeAllRoads()
            result(200)
            break
        case "map#orientation":
            rotateMap(call: call)
            result(200)
            break
        case "user#locationMarkers":
            configureUserLocation(call: call)
            result(200)
            break
        case "add#Marker":
            addMarkerManually(call: call)
            result(200)
            break
        case "update#Marker":
            updateMarkerIcon(call: call)
            result(200)
            break
        case "change#Marker":
            changePositionMarker(call: call)
            result(200)
            break
        case "delete#markers":
            deleteMarkers(call: call)
            result(200)
            break
        case "get#geopoints":
            getGeoPoints(result)
            break
        case "toggle#Alllayer":
            let isVisible = call.arguments as! Bool
            if isVisible {
                self.mapOSM.showAllLayers()
            } else {
                self.mapOSM.hideAllLayers()
            }
        case "draw#rect":
            drawShape(args: call.arguments, result: result, shapeType: ShapeTypes.Rect)
            break
        case "draw#circle":
            drawShape(args: call.arguments, result: result, shapeType: ShapeTypes.Circle)
            break
        case "remove#circle":
            let key = call.arguments
            if key == nil {
                self.mapOSM.shapeManager.deleteAllCircles()
            } else {
                self.mapOSM.shapeManager.deleteShape(ckey: key as! String)
            }
            result(200)
            break
        case "remove#rect":
            let key = call.arguments
            if key == nil {
                self.mapOSM.shapeManager.deleteAllRect()
            } else {
                self.mapOSM.shapeManager.deleteShape(ckey: key as! String)
            }
            result(200)
            break
        case "clear#shapes":
            self.mapOSM.shapeManager.deleteAllShapes()
            break
        default:
            result(nil)
            break
        }
    }

    func initPosition(args: Any?, result: @escaping FlutterResult) {
        let pointInit = args as! [String: Double]
        let location = CLLocationCoordinate2D(
            latitude: pointInit["lat"]!, longitude: pointInit["lon"]!)
        self.mapOSM.moveTo(location: location, zoom: zoomConfig.initZoom, animated: false)
        self.channel.invokeMethod("map#init", arguments: true)
        result(200)

    }
    func moveToSpecificLocation(call: FlutterMethodCall, result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let point = CLLocationCoordinate2D(
            latitude: args["lat"] as! Double, longitude: args["lon"] as! Double)
        let animate = args["animate"] as! Bool? ?? false
        var currentZoom = self.mapOSM.zoom()
        if currentZoom == 0 || !mapInitialized {
            currentZoom = zoomConfig.initZoom
        }
        self.mapOSM.moveTo(location: point, zoom: currentZoom, animated: animate)
        result(200)
    }
    func rotateMap(call: FlutterMethodCall) {
        let angle = call.arguments as! Double
        self.mapOSM.setRotation(angle: angle)
    }
    private func addMarkerManually(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        var iconSizeArg: [Int]? = [32, 32]
        var icon: OSMPlatformImage? = nil
        if args.keys.contains("icon") {
            let iconArg = args["icon"] as! [String: Any]
            iconSizeArg = iconArg["size"] as? [Int]
            icon = convertImage(codeImage: iconArg["icon"] as! String)

        }
        if defaultMarker != nil && icon == nil {
            icon =
                ApplePlatformUtilities.bundledImage(named: defaultMarker!)
                ?? ApplePlatformUtilities.systemImage(named: "mappin")
        } else if defaultMarker == nil && icon == nil {
            icon = ApplePlatformUtilities.systemImage(named: "mappin")
        }

        let point = args["point"] as! GeoPoint
        let coordinate = point.toLocationCoordinate()

        let sizeIcon = iconSizeArg!.toMarkerSize(displayScale: ApplePlatformUtilities.displayScale(for: mapOSM))
        var angle = Float(0.0)
        var anchor: AnchorGeoPoint? = nil
        if let _angle = point["angle"] {
            angle = Float(_angle)
        }
        if let _anchor = args["iconAnchor"] {
            anchor = AnchorGeoPoint(anchorMap: _anchor as! [String: Any])
        }
        let configuration = MarkerConfiguration(
            icon: icon!, iconSize: sizeIcon, angle: angle, anchor: anchor?.compute(),
            scaleType: MarkerScaleType.invariant)
        let marker = Marker(location: coordinate, markerConfiguration: configuration)
        self.mapOSM.markerManager.addMarker(marker: marker)
        #if os(macOS)
        recordMarkerScale(
            coordinate: coordinate,
            iconBase64: (args["icon"] as? [String: Any])?["icon"] as? String,
            logicalSize: iconSizeArg,
            angle: angle,
            anchorArgs: args["iconAnchor"] as? [String: Any])
        #endif
    }
    private func changePositionMarker(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        let coordinate_old = (args["old_location"] as! GeoPoint).toLocationCoordinate()
        let coordinate_new = (args["new_location"] as! GeoPoint).toLocationCoordinate()
        var icon: OSMPlatformImage? = nil
        var iconSize: MarkerIconSize? = nil
        var angle = Float(0.0)
        var anchor: AnchorGeoPoint? = nil
        if let iconStr = args["new_icon"] as? [String: Any] {
            icon = convertImage(codeImage: iconStr["icon"] as! String)
            iconSize = (iconStr["size"] as? [Int])!.toMarkerSize(displayScale: ApplePlatformUtilities.displayScale(for: mapOSM))
        }
        if let _angle = args["angle"] as? Double {
            angle = Float(_angle)
        }
        if let _anchor = args["iconAnchor"] {
            anchor = AnchorGeoPoint(anchorMap: _anchor as! [String: Any])
        }
        self.mapOSM.markerManager.updateMarker(
            oldlocation: coordinate_old, newlocation: coordinate_new,
            icon: icon,
            iconSize: iconSize,
            angle: Float(angle), anchor: anchor?.compute())
        #if os(macOS)
        let newIconArg = args["new_icon"] as? [String: Any]
        moveMarkerScaleRecord(
            from: coordinate_old, to: coordinate_new,
            iconBase64: newIconArg?["icon"] as? String,
            logicalSize: newIconArg?["size"] as? [Int],
            angle: Float(args["angle"] as? Double ?? 0),
            anchorArgs: args["iconAnchor"] as? [String: Any])
        #endif
    }
    func updateMarkerIcon(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        var icon: OSMPlatformImage?
        var iconSize: MarkerIconSize?
        if args.keys.contains("icon") {
            let iconArg = args["icon"] as! [String: Any]
            icon = convertImage(codeImage: iconArg["icon"] as! String)
            iconSize = (iconArg["size"] as? [Int])!.toMarkerSize(displayScale: ApplePlatformUtilities.displayScale(for: mapOSM))

        }
        let coordinate = (args["point"] as! GeoPoint).toLocationCoordinate()
        self.mapOSM.markerManager.updateMarker(
            oldlocation: coordinate, newlocation: coordinate, icon: icon, iconSize: iconSize)
        #if os(macOS)
        let iconArg = args["icon"] as? [String: Any]
        updateMarkerScaleRecord(
            at: coordinate,
            iconBase64: iconArg?["icon"] as? String,
            logicalSize: iconArg?["size"] as? [Int])
        #endif
    }
    func deleteMarkers(call: FlutterMethodCall) {
        let geoPoints = (call.arguments as! [GeoPoint]).map { point -> CLLocationCoordinate2D in
            point.toLocationCoordinate()
        }
        self.mapOSM.markerManager.removeMarkers(locations: geoPoints)
        #if os(macOS)
        geoPoints.forEach { removeMarkerScaleRecord(at: $0) }
        #endif
    }
    func deleteMarker(call: FlutterMethodCall) {
        let location = (call.arguments as! GeoPoint).toLocationCoordinate()
        self.mapOSM.markerManager.removeMarker(location: location)
        #if os(macOS)
        removeMarkerScaleRecord(at: location)
        #endif
    }
    func changePosition(args: Any?, result: @escaping FlutterResult) {
        result(200)
    }
    func changeMapZoom(_ args: Any?) {
        let args = args as! [String: Any]
        if args.keys.contains("stepZoom") {
            let stepZ = args["stepZoom"] as! Double
            if stepZ > 0 {
                self.mapOSM.zoomIn(step: Int(stepZ))
            } else if stepZ == 0 {
                self.mapOSM.zoomIn(step: 1)

            } else if stepZ == -1 {
                self.mapOSM.zoomOut(step: 1)
            } else if stepZ < -1 {
                self.mapOSM.zoomOut(step: Int(stepZ))
            }

        } else {
            let levelZoom = args["zoomLevel"] as! Double

            self.mapOSM.setZoom(zoom: Int(levelZoom))

        }
    }
    func configZoomMap(call: FlutterMethodCall) {
        let zoomArgs = (call.arguments as! [String: Double]).mapValues(Int.init)
        self.zoomConfig = ZoomConfiguration(zoomArgs)
    }
    func getMapBounds(result: @escaping FlutterResult) {
        let boundingBox = self.mapOSM.getBoundingBox()
        result([
            "north": boundingBox.north, "south": boundingBox.south, "east": boundingBox.east,
            "west": boundingBox.west,
        ])
    }
    func zoomMapToBoundingBox(call: FlutterMethodCall) {
        let bbox = call.arguments as! [String: Double]
        let boundingBox = BoundingBox(
            north: bbox["north"]!, west: bbox["west"]!, east: bbox["east"]!, south: bbox["south"]!)
        self.mapOSM.moveToByBoundingBox(bounds: boundingBox, animated: true)
    }
    func setCameraAreaLimit(call: FlutterMethodCall) {
        let bbox = call.arguments as! [Double]
        let bounds = BoundingBox(boundingBoxs: bbox)
        self.mapOSM.setBoundingBox(bounds: bounds)
    }
    func removeCameraAreaLimit(result: @escaping FlutterResult) {
        self.mapOSM.setBoundingBox(bounds: BoundingBox())
        result(200)
    }
    func setMarkerStaticGeoPIcon(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        let id = args["id"] as! String
        let bitmapArg = args["bitmap"] as! [String: Any]
        let icon = convertImage(codeImage: bitmapArg["icon"] as! String)
        let iconSize = (bitmapArg["size"] as? [Int])?.toMarkerSize(displayScale: ApplePlatformUtilities.displayScale(for: mapOSM))
        self.mapOSM.poisManager.setOrCreateIconPoi(id: id, icon: icon!, iconSize: iconSize)
        #if os(macOS)
        recordStaticPoiIcon(id: id, bitmapArgs: bitmapArg)
        #endif
    }

    private func setStaticGeoPoint(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        let id = args["id"] as! String

        let listPois: [MarkerIconPoi] = (args["point"] as! [GeoPoint]).map {
            point -> MarkerIconPoi in
            var angle = Float(0)
            if point.keys.contains("angle") {
                angle = Float(point["angle"]! as Double)
            }
            let location = point.toLocationCoordinate()

            return MarkerIconPoi(location: location, angle: angle, anchor: nil)
        }

        self.mapOSM.poisManager.setMarkersPoi(id: id, markers: listPois)
        #if os(macOS)
        // `Poi.setMarkers` recreates every marker from the icon configuration
        // captured when the Poi was created (`markerIcon` is immutable and
        // `setIconMarker` cannot update it), so positions replaced after a
        // display-scale change would revert to the stale size. Re-apply the
        // last icon arguments to redraw at the current scale.
        if let bitmapArg = storedStaticPoiIconArgs(id: id) {
            setMarkerStaticGeoPIcon(
                call: FlutterMethodCall(
                    methodName: "staticPosition#IconMarker",
                    arguments: ["id": id, "bitmap": bitmapArg]))
        }
        #endif

    }
    func configureUserLocation(call: FlutterMethodCall) {
        let args = call.arguments as! [String: Any]
        #if os(macOS)
        // Remember the arguments to re-apply the icons when the window moves
        // between displays with a different backing scale.
        lastUserLocationMarkersArgs = args
        #endif
        var personMarkerIcon: OSMPlatformImage = OSMPlatformImage()
        var directionMarkerIcon: OSMPlatformImage?
        var personIconConfig: MarkerConfiguration!
        if let personIconString = args["personIcon"] {
            let iconArg = personIconString as! [String: Any]
            personMarkerIcon = convertImage(codeImage: iconArg["icon"] as! String) ?? OSMPlatformImage()
            let personIconSize = (iconArg["size"] as? [Int])?.toMarkerSize(displayScale: ApplePlatformUtilities.displayScale(for: mapOSM))
            personIconConfig = MarkerConfiguration(
                icon: personMarkerIcon, iconSize: personIconSize, angle: nil, anchor: nil)

        }
        var directionMarkerConfiguration: MarkerConfiguration? = nil
        if let arrowDirectionIconString = args["arrowDirectionIcon"] {
            let iconArg = arrowDirectionIconString as! [String: Any]
            directionMarkerIcon = convertImage(codeImage: iconArg["icon"] as! String)
            let directionIconSize = (iconArg["size"] as? [Int])?.toMarkerSize(displayScale: ApplePlatformUtilities.displayScale(for: mapOSM))
            directionMarkerConfiguration = MarkerConfiguration(
                icon: directionMarkerIcon!,
                iconSize: directionIconSize,
                angle: nil,
                anchor: nil)
        }
        let userLocationConfig = UserLocationConfiguration(
            userIcon: personIconConfig, directionIcon: directionMarkerConfiguration)
        self.mapOSM.locationManager.setUserLocationIcons(userLocationIcons: userLocationConfig)

    }
    func startTrackUser(args: [Any]) {
        let enableStopFollowInDrag = args.first as? Bool ?? false
        if !enableStopFollowInDrag {
            canSkipFollow = false
            self.mapOSM.locationManager.requestEnableLocation()
        }
        let disableRotation = args[1] as? Bool ?? false
        let useDirectionMarker = args[2] as? Bool ?? false
        let anchor = args[3] as? [Double] ?? [0.5, 0.5]

        let markerAnchor = AnchorGeoPoint(anchor: (x: anchor.first!, y: anchor.last!)).compute()
        let userIconLoc = self.mapOSM.locationManager.userLocationIconConfiguration.userIcon
        let directionIconLoc = self.mapOSM.locationManager.userLocationIconConfiguration
            .directionIcon
        let userLocConfig = self.mapOSM.locationManager.userLocationIconConfiguration.copyWith(
            userIcon: userIconLoc.copyWith(
                anchor: markerAnchor
            ),
            directionIcon: directionIconLoc?.copyWith(
                anchor: markerAnchor
            )
        )
        self.mapOSM.locationManager.setUserLocationIcons(userLocationIcons: userLocConfig)
        //self.mapOSM.enableRotation(enable: !disableRotation)
        if !self.mapOSM.locationManager.isTrackingEnabled() {
            self.mapOSM.locationManager.toggleTracking(
                configuration: TrackConfiguration(
                    moveMap: true,
                    useDirectionMarker: useDirectionMarker,
                    disableMarkerRotation: disableRotation
                ))
        }
    }
    func stopTracking() {
        self.mapOSM.locationManager.stopLocation()
    }
    private func getGeoPoints(_ result: FlutterResult) {
        let list: [GeoPoint] = self.mapOSM.markerManager.getAllMarkers().map { location in
            location.toGeoPoint()
        }
        result(list)
    }
    func drawShape(args: Any?, result: @escaping FlutterResult, shapeType: ShapeTypes) {
        let rectJson = args as! [String: Any]
        let key = rectJson["key"] as! String
        let shape: PShape
        switch shapeType {
        case .Rect:
            shape = RectShapeOSM.fromMap(json: rectJson)
        case .Circle:
            shape = CircleOSM.fromMap(json: rectJson)
        default:
            shape = RectShapeOSM.fromMap(json: rectJson)
        }
        mapOSM.shapeManager.drawShape(key: key, shape: shape)
        result(200)
    }

    // MARK: - Roads

    func drawRoadMCOSM(
        call: FlutterMethodCall,
        completion:
            @escaping (
                _ roadInfo: RoadInformation?, _ road: Road?, _ roadData: RoadData,
                _ boundingBox: BoundingBox?, _ polyline: Polyline?, _ error: Error?
            ) -> Void
    ) {
        let args = call.arguments as! [String: Any]
        var points = args["wayPoints"] as! [GeoPoint]
        var roadType = RoadType.car
        switch args["roadType"] as! String {
        case "car":
            roadType = RoadType.car
            break
        case "bike":
            roadType = RoadType.bike
            break
        case "foot":
            roadType = RoadType.foot
            break
        default:
            roadType = RoadType.car
            break
        }
        let key = args["key"] as? String
        /// insert middle point between start point and end point
        var intersectPoint = [GeoPoint]()
        if args.keys.contains("middlePoints") {
            intersectPoint = args["middlePoints"] as! [GeoPoint]
            points.insert(contentsOf: intersectPoint, at: 1)
        }
        let roadData = RoadData(json: args)

        let waysPoint = points.map { point -> String in
            let wayP = String(format: "%F,%F", point["lon"]!, point["lat"]!)
            return wayP
        }

        let zoomInto = args["zoomIntoRegion"] as! Bool

        roadManager.getRoad(wayPoints: waysPoint, typeRoad: roadType) { road in
            var error: Error? = nil
            if road == nil {
                error = NSError()
                completion(nil, nil, RoadData(), nil, nil, error)

            }
            let roadInfo = RoadInformation(
                id: key!, distance: road!.distance, seconds: road!.duration,
                encodedRoute: road!.mRouteHigh)
            let route: Polyline = Polyline(encodedPolyline: road!.mRouteHigh, precision: 1e5)

            var box: BoundingBox? = nil
            if zoomInto {
                box = route.coordinates?.toBounds()
            }

            completion(roadInfo, road, roadData, box, route, nil)

        }

    }

    func drawRoadManually(call: FlutterMethodCall, result: FlutterResult) {
        let args = call.arguments as! [String: Any]
        let roadEncoded = args["road"] as! String
        var roadType = PolylineType.LINE
        var roadColor = "#ff0000"
        if args.keys.contains("roadColor") {
            roadColor = args["roadColor"] as! String
        }
        var roadWidth = 5.0
        if args.keys.contains("roadWidth") {
            roadWidth = args["roadWidth"] as! Double
        }
        let zoomInto = args["zoomIntoRegion"] as! Bool
        let isDotted = args["isDotted"] as? Bool ?? false
        if isDotted {
            roadType = PolylineType.DOT
        }
        var roadBoardColor: OSMPlatformColor? = OSMPlatformColor(hexString: "#f55b5b")
        if let borderColor = args["roadBorderColor"] as? String {
            roadBoardColor = OSMPlatformColor(hexString: borderColor)
        }
        var roadBoardWidth: CFloat? = nil
        if let borderWidth = args["roadBorderWidth"] as? Double {
            roadBoardWidth = CFloat(borderWidth + roadWidth)
        }
        var road = Road()
        road.mRouteHigh = roadEncoded
        road.roadData = RoadData(roadColor: roadColor, roadWidth: roadWidth)
        let route: Polyline = Polyline(encodedPolyline: road.mRouteHigh, precision: 1e5)
        let roadKey = args["key"] as! String
        if route.coordinates != nil {
            let roadConfiguration = RoadConfiguration(
                width: Float(roadWidth), color: OSMPlatformColor(hexString: roadColor) ?? .blue,
                borderWidth: roadBoardWidth, borderColor: roadBoardColor, polylineType: roadType)
            self.mapOSM.roadManager.addRoad(
                id: roadKey, polylines: route.coordinates!, configuration: roadConfiguration)
            if zoomInto {
                let box = route.coordinates!.toBounds()
                self.mapOSM.moveToByBoundingBox(bounds: box, animated: true)
            }
        }
        result(200)
    }

    func drawMultiRoad(
        call: FlutterMethodCall,
        completion:
            @escaping (_ roadsInfo: [RoadInformation?], _ roads: [(String, Road, RoadData)?], Any?)
            -> Void
    ) {
        let args = call.arguments as! [[String: Any]]
        var roadConfigs = [(String, RoadConfig)]()

        for item in args {
            var roadColor = roadColor
            if item.keys.contains("roadColor") {
                roadColor = item["roadColor"] as! String
            }
            var roadWidth = 5.0
            if item.keys.contains("roadWidth") {
                roadWidth = item["roadWidth"] as! Double
            }
            let conf = RoadConfig(
                wayPoints: (item["wayPoints"] as! [GeoPoint]),
                intersectPoints: item["middlePoints"] as! [GeoPoint]?,
                roadData: RoadData(roadColor: roadColor, roadWidth: roadWidth),
                roadType: (item["roadType"] as! String).toRoadType)
            roadConfigs.append((item["key"] as! String, conf))
        }

        let group = DispatchGroup()
        var results = [(String, Road?)]()
        for (key, config) in roadConfigs {
            var wayPoints = config.wayPoints
            if config.intersectPoints != nil && !config.intersectPoints!.isEmpty {
                wayPoints.insert(contentsOf: config.intersectPoints!, at: 1)
            }
            group.enter()
            roadManager.getRoad(wayPoints: wayPoints.parseToPath(), typeRoad: config.roadType) {
                road in
                results.append((key, road))
                group.leave()
            }
        }
        group.notify(queue: .main) {
            var information = [RoadInformation?]()
            var roads = [(String, Road, RoadData)?]()
            for (index, res) in results.enumerated() {
                var roadInfo: RoadInformation? = nil
                var routeToDraw: (String, Road, RoadData)? = nil
                if let road = res.1 {
                    routeToDraw = (res.0, road, roadConfigs[index].1.roadData)
                    roadInfo = RoadInformation(
                        id: res.0, distance: road.distance, seconds: road.duration,
                        encodedRoute: road.mRouteHigh)
                }
                information.append(roadInfo)
                roads.append(routeToDraw)
            }
            completion(information, roads, nil)
        }

    }
    private func deleteRoad(call: FlutterMethodCall, result: FlutterResult) {

        let roadKey = call.arguments as! String?
        if roadKey == nil && lastRoadKey != nil {
            self.mapOSM.roadManager.removeRoad(id: lastRoadKey!)
            self.storedRoads.removeValue(forKey: lastRoadKey!)
        }
        if let key = roadKey {
            self.mapOSM.roadManager.removeRoad(id: key)
            self.storedRoads.removeValue(forKey: key)
        }
        result(200)
    }

}

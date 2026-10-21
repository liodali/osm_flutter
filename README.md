<p align="center">
  <img src="https://raw.githubusercontent.com/liodali/osm_flutter/0.70.1/.github/OSM%20Flutter%20Logo.png?sanitize=true" width="500px">
</p>

# flutter_osm_plugin

![pub](https://img.shields.io/badge/pub-v2.1.0+1-blue)

## Platform Support

|           Android            |                           iOS                           |             macOS              |             Web              |
| :--------------------------: | :-----------------------------------------------------: | :----------------------------: | :--------------------------: |
| supported :heavy_check_mark: | supported :heavy_check_mark: (min iOS supported : 15.6) | supported :heavy_check_mark: (min macOS supported : 12.0) | supported :heavy_check_mark: |

> **macOS (native):** runs on the shared Darwin implementation with iOS (SPM
> package `darwin/flutter_osm_plugin`, `OSMFlutterFramework` 0.9.1). See
> [macOS Integration](#macos-integration) for requirements, host-app setup and
> the current capability limits.

<b>osm plugin for flutter apps </b>

- current position (Android/iOS/web)
- change position (Android/iOS/web)
- create Marker manually (Android/iOS/web)
- tracking user location (Android/iOS/web)
- customize Icon Marker (Android/iOS/web)
- customize user Marker (Android/iOS/web)
- assisted selection position (Android/iOS)
- set BoundingBox (Android/iOS/Web)
- zoom into region (Android/iOS/web)
- draw Road (Android/iOS/web)
- draw dotted Road (Android/iOS/web)
- recuperate information (instruction/duration/distance) of the current road (Android/iOS/web)
- draw Road manually (Android/iOS/web)
- draw multiple Roads (Android/iOS/web)
- ClickListener on Marker (Android/iOS/web)
- ClickListener on Map (Android/iOS/web)
- calculate distance between 2 points
- address suggestion
- draw shapes (Android/iOS/web)
- simple dialog location picker (Android/iOS)
- listen to region change (Android/iOS/Web)
- set custom tiles (Android/iOS/Web)
- satellite tiles preset (Android/iOS/Web)
- vector tiles support via styleURL (Android/iOS/Web)
- external tracking control (Android/iOS/Web)


## Screenshots

| Feature | Feature |
|:---:|:---:|
| <img src="https://pub-beed1fbf56b445158e95110d87549d14.r2.dev/osm_screenshots/showcase_04_road_basic.png" width="270" alt="Draw roads with distance and duration"> | <img src="https://pub-beed1fbf56b445158e95110d87549d14.r2.dev/osm_screenshots/showcase_05_vector_tiles.png" width="270" alt="Vector map tiles"> |
| **Draw Roads** — routes with distance & duration | **Vector Maps** — OpenFreeMap styles |
| <img src="https://pub-beed1fbf56b445158e95110d87549d14.r2.dev/osm_screenshots/showcase_02_satellite_tiles.png" width="270" alt="Satellite tile layer"> | <img src="https://pub-beed1fbf56b445158e95110d87549d14.r2.dev/osm_screenshots/showcase_06_cycle_tiles.png" width="270" alt="Custom cycle tile layer"> |
| **Satellite View** — ArcGIS World Imagery | **Custom Tiles** — cycle, transport, your own |
| <img src="https://pub-beed1fbf56b445158e95110d87549d14.r2.dev/osm_screenshots/showcase_08_search_suggestions.png" width="270" alt="Address search suggestions"> | <img src="https://pub-beed1fbf56b445158e95110d87549d14.r2.dev/osm_screenshots/showcase_03_road.png" width="270" alt="Route over satellite imagery"> |
| **Address Search** — live OSM suggestions | **Routes Anywhere** — plan over satellite |

## Contents

- [Platform Support](#platform-support)
- [Screenshots](#screenshots)
- [Installing](#installing)
- [Android Integration](#android-integration) (endorsed package, typed controller, JNI opt-in)
- [Integration with Hooks](#integration-with-hooks)
- [Migrations](#migration-to-210) (2.1.0, 2.0.0)
- [Web Integration](#web-integration) (PointerInterceptor)
- [Simple Usage](#simple-usage)
- [MapController](#mapcontroller) — initialisation, layers, markers, roads, shapes, listeners
- [OSMFlutter / OSMOption / ZoomOption](#osmflutter)
- [Custom Controller](#custom-controller)
- [Static Map](#static-map)
- [Static Methods](#static-methods) (distance, address suggestions)
- [Location pickers](#show-dialog-picker) (dialog + custom)
- [Notice](#notice) (HTTP cleartext, OSM copyright)

## Installing

Add the following to your `pubspec.yaml` file:

    dependencies:
      flutter_osm_plugin: ^2.1.0

> **Android (from 2.1.0):** the Android implementation ships as the endorsed
> package `flutter_osm_android` and is pulled in automatically — no extra
> dependency or code change is required. Native plugin class, channels and the
> platform view type are unchanged. See [Android Integration](#android-integration)
> for the optional typed controller and the experimental JNI transport.

> **iOS (CocoaPods deprecated):** `OSMFlutterFramework` suspended CocoaPods
> distribution at 0.9.0 (MapCore 4.0.0), so the plugin podspec is frozen on the
> legacy **0.8.x** engine (maps-core 3.7.x) and **will not be updated anymore**.
> The plugin is **SPM-only** going forward — the native iOS integration ships
> via `darwin/flutter_osm_plugin/Package.swift` (shared Darwin source, pinned to
> `OSMMapCoreIOSFramework` 0.9.1). The frozen podspec and a never-edit source
> snapshot remain under `ios/` for legacy CocoaPods consumers (see
> `ios/README.md`); they should plan a migration to Swift Package Manager.

## Android Integration

### Endorsed Android package

Since `2.1.0` the Android implementation lives in the endorsed package
[`flutter_osm_android`](https://pub.dev/packages/flutter_osm_android). Flutter
resolves it automatically from the `flutter_osm_plugin` dependency — there is
nothing to add, and migration is transparent (plugin class, Android package
name, platform view type and channel names are unchanged).

### Typed `AndroidMapController` (opt-in)

The classic `MapController` keeps working unchanged. For a typed, lower-level
Android API you can opt into `AndroidMapController`:

```dart
import 'package:flutter_osm_plugin/android.dart';

final controller = AndroidMapController.withPosition(
  initPosition: GeoPoint(latitude: 48.8566, longitude: 2.3522),
);
```

By default it uses the **MethodChannel** transport — no extra package is needed.
Commands complete from native acknowledgements, and map/user-location events are
exposed as typed streams (`controller.events`).

> **Throttling:** region-change events are delivered at most once every
> **100 ms** and user-location events at most once every **1 s** (newest value
> wins) — including on the classic controller path.

### Experimental JNI transport (optional)

For lower-latency command dispatch you can add the experimental
[`flutter_osm_android_jni`](https://pub.dev/packages/flutter_osm_android_jni)
add-on. It routes typed map commands (markers, shapes, roads, camera, tiles)
through generated JNI bindings into the Kotlin bridge of the Android host.
Events, acknowledgements, location and lifecycle stay on MethodChannel.

```yaml
dependencies:
  flutter_osm_plugin: ^2.1.0
  flutter_osm_android_jni: ^0.1.0
```

```dart
import 'package:flutter_osm_android_jni/flutter_osm_android_jni.dart';
import 'package:flutter_osm_plugin/android.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

final controller = AndroidMapController.withPosition(
  initPosition: GeoPoint(latitude: 48.8566, longitude: 2.3522),
  backend: AndroidMapBackend.auto,
  transportFactory: createAndroidJniTransportFactory(
    fallback: createDefaultAndroidMapTransport,
  ),
);
```

Notes:

- Android-only; on iOS/web keep using the default transports.
- JNI fallback is **attach-only**: once initialization starts on a backend,
  commands are never replayed through another backend.
- Requesting the JNI backend without `flutter_osm_android_jni` installed throws
  a clear `UnsupportedError`.

## Integration with Hooks

> To use our map library with `Flutter_Hooks` library use our new extension library
> https://pub.dev/packages/osm_flutter_hooks
> many thanks for @ben-xD

### Migration to `2.1.0`

> Transparent: the Android implementation moved to the endorsed
> `flutter_osm_android` package and is resolved automatically from the
> `flutter_osm_plugin` dependency. No code or configuration changes are
> needed — see [Android Integration](#android-integration).

### Migration to `2.0.0`

> **Breaking**: Android map engine switched from osmdroid to mapscore (openmobilemaps).
> iOS minimum version raised to 15.6.

**Android:**

- `compileSdk` must be **36**
- `minSdk` must be **32**
- Kotlin Gradle Plugin (KGP) is now required
- The map rendering engine is now [mapscore](https://github.com/ecmwf/openmobilemaps) (openmobilemaps) instead of osmdroid
- Custom tiles, markers, roads, and shapes are now handled by the new `MapscoreFlutterOsmView`

**iOS:**

- Minimum iOS version is now **15.6**
- Swift Package Manager (SPM) is the supported dependency manager — CocoaPods
  support is deprecated: the podspec is frozen on the legacy 0.8.x engine and
  future releases are SPM-only (see [Installing](#installing))
- The `OSMMapCoreIOSFramework` dependency has been updated to the latest revision

**What's new:**

- `MapController.satelliteLayer` — named constructor with ArcGIS World Imagery satellite tiles
- `CustomTile.satellite` — preset for satellite tiles
- `CustomTile.openFreeMap` — preset for OpenFreeMap vector tiles with `styleURL`
- `styleURL` and `isVector` fields on `CustomTile` for vector tile support (Android/iOS/Web)
- `useExternalTracking` parameter on all `MapController` constructors for external location control
- Dotted road style and border customization in `drawRoadManually` (iOS)
- Improved location permission handling with explicit checks and user-friendly errors
- `myLocation()` now requests location permission on Android if not granted

## macOS Integration

`flutter_osm_plugin` supports native macOS through the **same shared Darwin
implementation as iOS** (`darwin/flutter_osm_plugin`, Swift Package Manager,
`OSMFlutterFramework` 0.9.1 / MapCore 4.0.0). Commands, payloads and events are
identical to the iOS wire protocol.

**Requirements**

- Flutter 3.47.0 or newer (validated with 3.47.1)
- macOS 12.0 or newer
- Xcode 26+ / Swift 6.2+ (the pinned framework uses `swift-tools-version:6.2`)
- Swift Package Manager integration (the default in current Flutter);
  CocoaPods is not supported

**Host app setup**

Permissions live in the host app — the plugin package ships none:

- outbound network (`com.apple.security.network.client`) for tile and routing
  requests
- optional location features need `NSLocationUsageDescription` and
  `NSLocationWhenInUseUsageDescription` plus the
  `com.apple.security.personal-information.location` sandbox entitlement;
  authorization is requested by the native implementation when tracking
  starts, and a denied permission fails `myLocation()` with a `permission`
  error instead of hanging

See `example/macos` for a complete setup; the example app exercises tiles,
markers, roads, shapes, camera controls, static maps and the picker flows.
Host applications own permission UX and live-location availability. macOS uses
the native permission check/request path, like iOS.

Run regression tests locally with `flutter test` in the root and
`flutter_osm_interface` packages. From `example/`, validate the Apple hosts with
`flutter build macos --debug` and `flutter build ios --simulator --debug`.

**Verified behavior** (Apple silicon, Xcode 26.5 / Swift 6.3.2,
Flutter 3.47.1): map startup and readiness, raster tile loading, camera moves
and zoom, and the shared marker/road/shape/picker command paths.

**Known limits** (upstream MapCore AppKit adapter in the pinned framework):

- no heading/compass data: user-location updates report heading `0` and the
  direction marker is disabled on macOS
- native rotation gestures, hover and long-press are not provided by the
  pinned MapCore AppKit adapter; programmatic rotation (`map#orientation`) is
  unverified on macOS
- Intel/AMD GPU rendering and mixed-display scale changes are unverified until
  checked on suitable hardware (the plugin already re-applies marker, POI and
  user-location icon sizes when the hosting window changes displays)

## Web Integration

#### Technical Issue: Event Capture in Web

On web platforms, UI elements above the map cannot receive click events. This occurs because the OSM map renders as an `HtmlElementView` that captures all pointer events before they reach Flutter widgets.

#### Common Issues

- Dialogs appear but buttons are unclickable
- UI elements over the map don't receive click events
- The map's "grab" cursor shows even when hovering over your UI elements

**Solution: Add pointer_interceptor**

```yaml
dependencies:
  pointer_interceptor: ^0.10.1+2
```

#### Example: Basic Marker Click Handling with PointerInterceptor

```dart
      body: OSMFlutter(
        controller: mapController,
        osmOption: OSMOption(
          zoomOption: ZoomOption(initZoom: 12),
        ),
        onGeoPointLongPressed:(point){
          print("long press on $point");
        },
        onGeoPointClicked: (point) {
          // When a marker is clicked, show a popup with PointerInterceptor
          showDialog(
            context: context,
            builder: (context) => PointerInterceptor(
              // The PointerInterceptor is crucial here for web platforms
              child: AlertDialog(
                title: Text('Marker Clicked'),
                content: Text('Location: ${point.latitude}, ${point.longitude}'),
                actions: [
                  TextButton(
                    // This button will work on web thanks to PointerInterceptor
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
```

Without the `PointerInterceptor` wrapping the dialog, the buttons would be unresponsive on web platforms because the map underneath would capture all the click events before they reach your UI elements.

## Simple Usage

#### Creating a basic `OSMFlutter` :

```dart
OSMFlutter(
  controller: MapController(
    initPosition: GeoPoint(latitude: 47.4358055, longitude: 8.4737324),
    areaLimit: const BoundingBox(
      east: 10.4922941,
      north: 47.8084648,
      south: 45.817995,
      west: 5.9559113,
    ),
  ),
  osmOption: OSMOption(
    userTrackingOption: const UserTrackingOption(
      enableTracking: true,
      unFollowUser: false,
    ),
    zoomOption: const ZoomOption(
      initZoom: 8,
      minZoomLevel: 3,
      maxZoomLevel: 19,
      stepZoom: 1.0,
    ),
    userLocationMarker: UserLocationMaker(
      personMarker: const MarkerIcon(
        icon: Icon(
          Icons.location_history_rounded,
          color: Colors.red,
          size: 48,
        ),
      ),
      directionArrowMarker: const MarkerIcon(
        icon: Icon(
          Icons.double_arrow,
          size: 48,
        ),
      ),
    ),
    roadConfiguration: const RoadOption(
      roadColor: Colors.yellowAccent,
    ),
  ),
)
```

## MapController

> Declare `MapController` to control OSM map

<b>1) Initialisation </b>

> **Note**
> using the default constructor, you should use `initMapWithUserPosition` or `initPosition`
> if you want the map to initialize using static position use the named constructor `withPosition`
> or if you want to initialize the map with user position use `withUserPosition`

```dart
// default constructor
 MapController controller = MapController(
                            initPosition: GeoPoint(latitude: 47.4358055, longitude: 8.4737324),
                            areaLimit: BoundingBox(
                                east: 10.4922941,
                                north: 47.8084648,
                                south: 45.817995,
                                west:  5.9559113,
                      ),
            );
// or set manually init position
 final controller = MapController.withPosition(
            initPosition: GeoPoint(
              latitude: 47.4358055,
              longitude: 8.4737324,
          ),
);
// init the position using the user location
final controller = MapController.withUserPosition(
        trackUserLocation: UserTrackingOption(
           enableTracking: true,
           unFollowUser: false,
        )
)

// init the position using the user location and control map from outside
final controller = MapController.withUserPosition(
        trackUserLocation: UserTrackingOption(
           enableTracking: true,
           unFollowUser: false,
        ),
         useExternalTracking: true
)
```

<b>2) Dispose </b>

```dart
     controller.dispose();
```

<b> 3) Properties of default `MapController` </b>

> `MapController` has named constructors: `MapController.withPosition`, `MapController.withUserPosition`, `MapController.customLayer`, `MapController.cyclOSMLayer`, `MapController.publicTransportationLayer`, `MapController.satelliteLayer` to control initialization of the Map

| Properties                | Description                                                                                                                               |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `initMapWithUserPosition` | (UserTrackingOption?) initialize map with user position                                                                                   |
| `initPosition`            | (GeoPoint) if it isn't null, the map will be pointed at this position                                                                     |
| `areaLimit`               | (Bounding) set area limit of the map (default BoundingBox.world())                                                                        |
| `customLayer`             | (CustomTile) set custom layer using different osm server , this attribute used only with named constructor `customLayer`                 |
| `useExternalTracking`     | (bool) if true, we will disable our logic to show userLocation marker or to move to the user position, only receive user location updates |

<b> 3.1) Custom Layers with `MapController` </b>

- To change the tile source in OSMFlutter, you should used our named constructor `customLayer`, see the example below

```dart

controller = MapController.customLayer(
      initPosition: GeoPoint(
        latitude: 47.4358055,
        longitude: 8.4737324,
      ),
      customTile: CustomTile(
        sourceName: "opentopomap",
        tileExtension: ".png",
        minZoomLevel: 2,
        maxZoomLevel: 19,
        urlsServers: [
         TileURLs(
            //"https://tile.opentopomap.org/{z}/{x}/{y}"
            url: "https://tile.opentopomap.org/",
            subdomains: [],
          )
        ],
        tileSize: 256,
      ),
    )

```

- also,you can use our predefined custom tiles like
- `cyclOSMLayer` constructor for cycling tiles
- `publicTransportationLayer` constructor for transport tiles ,it's public osm server
- we support full server path like `("https://tile.opentopomap.org/{z}/{x}/{y}")`

* `satelliteLayer` constructor for satellite tiles (ArcGIS World Imagery)
* `openFreeMap` constructor for vector tiles with styleURL

For more example see our example in `home_example.dart`
<br>
<br>
<b> 3.1.1) Satellite Layer </b>

```dart
controller = MapController.satelliteLayer(
      initPosition: GeoPoint(
        latitude: 47.4358055,
        longitude: 8.4737324,
      ),
)
```

<b> 3.1.2) Vector Tiles (OpenFreeMap) </b>

```dart
controller = MapController.customLayer(
      initPosition: GeoPoint(
        latitude: 47.4358055,
        longitude: 8.4737324,
      ),
      customTile: CustomTile.openFreeMap(),
)
```

> When `styleURL` is set in `CustomTile`, the tile is treated as a vector tile (`isVector: true` is sent to the platform).

<br>
<b> 3.2) Change Layers in runtime </b>

```dart
 await controller.changeTileLayer(tileLayer: CustomTile(...));
```

<b>4) Set map on user current location </b>

```dart
 await controller.currentLocation();

```

<b> 5) Zoom IN </b>

```dart
 await controller.setZoom(stepZoom: 2);
 // or
 await controller.zoomIn();
```

<b> 5.1) Zoom Out </b>

```dart
 await controller.setZoom(stepZoom: -2);
 // or
 await controller.zoomOut();

```

<b> 5.2) change zoom level </b>

> `zoomLevel` should be between `minZoomLevel` and `maxZoomLevel`

```dart
 await controller.setZoom(zoomLevel: 8);
```

<b> 5.3) zoom to specific bounding box </b>

```dart
await controller.zoomToBoundingBox(BoundingBox(),paddingInPixel:0)
```

##### Note :

- For the box attribute ,If you don't have bounding box,you can use list of geopoint like this `BoundingBox.fromGeoPoints`

<b> 6) get current zoom level </b>

```dart
await controller.getZoom();
```

<b> 7) BoundingBox </b>

> set bounding box in the map

```dart
await controller.limitAreaMap(BoundingBox( east: 10.4922941, north: 47.8084648, south: 45.817995, west: 5.9559113,));
```

> remove bounding box in the map

```dart
await controller.removeLimitAreaMap();
```

<b> 8) Track user current position </b>

> for iOS,you should add those line in your info.plist file

```text
   <key>NSLocationWhenInUseUsageDescription</key>
	<string>any text you want</string>
	<key>NSLocationAlwaysUsageDescription</key>
	<string>any text you want</string>
```

> from version 0.40.0 we can call only `enableTracking` will animate to user location
> without need to call `currentLocation`

> when `enableStopFollow` is true,map will not be centered if the user location changed

> you can disable rotation of personIcon using [disableUserMarkerRotation] (default: false)

```dart
 await controller.enableTracking(enableStopFollow:false,);
```

or

> use this method below if you want to control the map(move to the user location and show the marker) while receiving the user location

```dart
 await controller.startLocationUpdating();
```

<b> 9) Disable tracking user position </b>

```dart
 await controller.disabledTracking();
```

or

> use this method below if you already used `startLocationUpdating`

```dart
 await controller.stopLocationUpdating();
```

<b>10) update the location </b>

> Change the location without create marker

```dart
 await controller.moveTo(GeoPoint(latitude: 47.35387, longitude: 8.43609),animate:true);
```

<b> 11) recuperation current position </b>

```dart
 GeoPoint geoPoint = await controller.myLocation();
```

<b> 12) get center map </b>

```dart
GeoPoint centerMap = await controller.centerMap;
```

<b> 12.1) get geoPoint in the map </b>

- recuperate geoPoint of marker add it by user except static points

```dart
List<GeoPoint> geoPoints = await controller.geopoints;
```

<b> 13) get bounding box map </b>

```dart
BoundingBox bounds = await controller.bounds;
```

<b> 14) Map Listener </b>

> Get GeoPoint from listener from controller directly
> (for more example: see home_example.dart )

a.1) single tap listener

```dart
controller.listenerMapSingleTapping.addListener(() {
      if (controller.listenerMapSingleTapping.value != null) {
        /// put you logic here
      }
    });
```

a.2) long tap listener

```dart
controller.listenerMapLongTapping.addListener(() {
      if (controller.listenerMapLongTapping.value != null) {
        /// put you logic here
      }
    });
```

a.3) region change listener

```dart
controller.listenerRegionIsChanging.addListener(() {
      if (controller.listenerRegionIsChanging.value != null) {
        /// put you logic here
      }
    });
```

<b>15) Create Marker Programmatically </b>

> you can change marker icon by using attribute `markerIcon`
> the angle value should be between [0,2pi]
> set anchor of ther Marker

```dart
await controller.addMarker(GeoPoint,
      markerIcon:MarkerIcon,
      angle:pi/3,
      anchor:IconAnchor(anchor: Anchor.top,)
);
```

<b> 15.1) Update Marker </b>

> you can change the location,icon,angle,anchor of the specific marker

> The old configuration of the Marker will be keep it the same if not specificied

```dart
await controller.changeLocationMarker(oldGeoPoint,newGeoPoint,MarkerIcon,angle,IconAnchor);
```

<b> 15.2) Change Icon Marker </b>

> You can change marker icon by using attribute `markerIcon` of existing Marker
> The GeoPoint/Marker should be exist

```dart
await controller.setMarkerIcon(GeoPoint,MarkerIcon);
```

<b> 15.3) Remove marker </b>

```dart
 await controller.removeMarker(geoPoint);
```

- PS : static position cannot be removed by this method

<b>16) Draw road,recuperate instructions ,distance in km and duration in sec</b>

> you can add an middle position to pass your route through them
> change configuration of the road in runtime
> zoom into the region of the road
> change the type of the road that user want to use

```dart
 RoadInfo roadInfo = await controller.drawRoad(
   GeoPoint(latitude: 47.35387, longitude: 8.43609),
   GeoPoint(latitude: 47.4371, longitude: 8.6136),
   roadType: RoadType.car,
   intersectPoint : [ GeoPoint(latitude: 47.4361, longitude: 8.6156), GeoPoint(latitude: 47.4481, longitude: 8.6266)]
   roadOption: RoadOption(
       roadWidth: 10,
       roadColor: Colors.blue,
       zoomInto: true,
   ),
);
 print("${roadInfo.distance}km");
 print("${roadInfo.duration}sec");
 print("${roadInfo.instructions}");
```

### properties of `RoadOption`

| Properties        | Description                                                                                    |
| ----------------- | ---------------------------------------------------------------------------------------------- |
| `roadColor`       | (Color) required Field, change the default color of the route in runtime                       |
| `roadWidth`       | (double) change the road width, default value 5.0                                              |
| `roadBorderColor` | (Color?) set color of border polyline                                                          |
| `roadBorderWidth` | (double?) set border width of polyline, if width null or 0,polyline will be drawn without border |
| `zoomInto`        | (bool) change zoom level to make the all the road visible (default:true)                       |
| `isDotted`        | (bool) to draw dotted polyline (default: false)                                                |

**Note** drawing dotted polyline has limitation on web where we cannot draw dotted polyline with borderWidth > 0

<b> 16.b) draw road manually </b>

```dart
await controller.drawRoadManually(
        waysPoint,
        interestPointIcon: MarkerIcon(
          icon: Icon(
            Icons.location_history,
            color: Colors.black,
          ),
        ),
        interestPoints: [waysPoint[3],waysPoint[6]],
        zoomInto: true
)
```

<b>17) Delete last road </b>

```dart
 await controller.removeLastRoad();
```

<b>18) draw multiple roads </b>

```dart
final configs = [
      MultiRoadConfiguration(
        startPoint: GeoPoint(
          latitude: 47.4834379430,
          longitude: 8.4638911095,
        ),
        destinationPoint: GeoPoint(
          latitude: 47.4046149269,
          longitude: 8.5046595453,
        ),
      ),
      MultiRoadConfiguration(
          startPoint: GeoPoint(
            latitude: 47.4814981476,
            longitude: 8.5244329867,
          ),
          destinationPoint: GeoPoint(
            latitude: 47.3982152237,
            longitude: 8.4129691189,
          ),
          roadOptionConfiguration: MultiRoadOption(
            roadColor: Colors.orange,
          )),
      MultiRoadConfiguration(
        startPoint: GeoPoint(
          latitude: 47.4519015578,
          longitude: 8.4371175094,
        ),
        destinationPoint: GeoPoint(
          latitude: 47.4321999727,
          longitude: 8.5147623089,
        ),
      ),
    ];
    await controller.drawMultipleRoad(
      configs,
      commonRoadOption: MultiRoadOption(
        roadColor: Colors.red,
      ),
    );

```

<b>19) delete all roads </b>

```dart
 await controller.clearAllRoads();
```

<b>20) Change static GeoPoint position </b>

> add new staticPoints with empty list of geoPoints (notice: if you add static point without marker,they will get default maker used by plugin)

> change their position over time

> change orientation of the static GeoPoint with `GeoPointWithOrientation`

```dart
 await controller.setStaticPosition(List<GeoPoint> geoPoints,String id );
```

<b>21) Change/Add Marker old/new static GeoPoint position </b>

> add marker of new static point

> change their marker of existing static geoPoint over time

```dart
 await controller.setMarkerOfStaticPoint(String id,MarkerIcon markerIcon );
```

<b>22) change orientation of the map</b>

```dart
 await controller.rotateMapCamera(degree);
```

<b>23) Draw Shape in the map </b>

- Circle

```dart
 /// to draw
 await controller.drawCircle(CircleOSM(
              key: "circle0",
              centerPoint: GeoPoint(latitude: 47.4333594, longitude: 8.4680184),
              radius: 1200.0,
              color: Colors.red,
              borderColor:Colors.green,
              strokeWidth: 0.3,
            )
          );
 /// to remove Circle using Key
 await controller.removeCircle("circle0");

 /// to remove All Circle in the map
 await controller.removeAllCircle();

```

- Rect

```dart
 /// to draw
 await controller.drawRect(RectOSM(
              key: "rect",
              centerPoint: GeoPoint(latitude: 47.4333594, longitude: 8.4680184),
              distance: 1200.0,
              color: Colors.red.withOpacity(0.4),
              borderColor:Colors.green,
              strokeWidth: 0.3,
            ));
 /// to remove Rect using Key
 await controller.removeRect("rect");

 /// to remove All Rect in the map
 await controller.removeAllRect();

```

- remove all shapes in the map

```dart
 await controller.removeAllShapes();
```

### Interfaces

- OSMMixinObserver :
  > contain listener methods to get event from native map view like when mapIsReady,mapRestored

> you should add this line `controller.addObserver(this);` in initState

> override mapIsReady to implement your own logic after initialisation of the map

> `mapIsReady` will replace `listenerMapIsReady`

| Methods             | Description                                                                                                 |
| ------------------- | ----------------------------------------------------------------------------------------------------------- |
| `mapIsReady`        | (callback) Should be override this method, to get notified when map is ready to go or not                   |
| `mapRestored`       | (callback) Should be override this method, to get notified when map is restored you can also add you backup |
| `onSingleTap`       | (callback) Called when the user makes single click on map                                                   |
| `onLongTap`         | (callback) Called when the user makes long click on map                                                     |
| `onMarkerClicked`   | (callback) Called when the user makes single click on marker                                                |
| `onMarkerLongPress` | (callback) Called when the user makes long press click on marker                                            |
| `onRegionChanged`   | (callback) Notified when map is change region (on moves)                                                    |
| `onRoadTap`         | (callback) Notified when user click on the polyline (road)                                                  |
| `onLocationChanged` | (callback) Notified when user location changed                                                              |

\*\* example

```dart
class YourOwnStateWidget extends State<YourWidget> with OSMMixinObserver {

   //etc
  @override
  void initState() {
    super.initState();
    controller.addObserver(this);
  }
    @override
    Future<void> mapIsReady(bool isReady) async {
      if (isReady) {
        /// put you logic
      }
    }
  @override
  Future<void> mapRestored() async {
    super.mapRestored();
    /// TODO
  }
    @override
  void onSingleTap(GeoPoint position) {
    super.onSingleTap();
    /// TODO
  }

  @override
  void onLongTap(GeoPoint position) {
    super.onLongTap();
    /// TODO

  }

  @override
  void onRegionChanged(Region region) {
    super.onRegionChanged();
    /// TODO
  }

  @override
  void onRoadTap(RoadInfo road) {
    super.onRoadTap();
    /// TODO
  }
  @override
  void onLocationChanged(GeoPoint userLocation) {
    super.onLocationChanged();
    /// TODO
  }
}
```

## `OSMFlutter`

| Properties            | Description                                                                                            |
| --------------------- | ------------------------------------------------------------------------------------------------------ |
| `mapIsLoading`        | (Widget) show custom widget when the map finish initialization                                         |
| `osmOption`           | (OSMOption) used to configure OSM Map such as zoom,road,userLocationMarker                             |
| `onGeoPointClicked`   | (callback) listener triggered when marker is clicked ,return current geoPoint of the marker            |
| `onGeoPointLongPress` | (callback) listener triggered when marker is long press clicked ,return current geoPoint of the marker |
| `onLocationChanged`   | (callback) it is fired when you activate tracking and user position has been changed                   |
| `onMapMoved`          | (callback) it is each the map moved user handler or navigate to another location using APIs            |
| `onMapIsReady`        | (callback) listener trigger to get map is initialized or not                                           |

## `OSMOption`

| Properties                   | Description                                                                 |
| ---------------------------- | --------------------------------------------------------------------------- |
| `trackMyPosition`            | enable tracking user position.                                              |
| `showZoomController`         | show default zoom controller.                                               |
| `userLocationMarker`         | change user marker or direction marker icon in tracking location            |
| `markerOption`               | configure marker of osm map                                                 |
| `zoomOption`                 | set configuration for zoom in the Map                                       |
| `roadConfiguration`          | (RoadOption) set default color,width,borderColor,borderWidth for polylines  |
| `staticPoints`               | List of Markers you want to show always ,should every marker have unique id |
| `showContributorBadgeForOSM` | (bool) enable to show copyright widget of osm in the map                    |
| `enableRotationByGesture`    | (bool) enable to rotation gesture for map, default: false                   |
| `showDefaultInfoWindow`      | (bool) enable/disable default infoWindow of marker (default = false)        |
| `isPicker`                   | (bool) enable advanced picker from init of the map (default = false)        |

## `ZoomOption`

| Properties     | Description                                            |
| -------------- | ------------------------------------------------------ |
| `stepZoom`     | set step zoom to use in zoomIn()/zoomOut() (default 1) |
| `initZoom`     | set init zoom level in the map (default 10)            |
| `maxZoomLevel` | set maximum zoom level in the map (2 <= x <= 19)       |
| `minZoomLevel` | set minimum zoom level in the map (2 <= x <= 19 )      |

### Custom Controller

> To create your own MapController to need to extends from `BaseMapController`,
> if you want to make a custom initialization to need to call init() and put your code after super.init()

- example

```dart
class CustomMapController extends BaseMapController {

  @override
  void dispose() {
    /// TODO put you logic here
    super.dispose();
  }

  @override
  void init() {
    super.init();
    /// TODO put you logic here
  }
}
```

### STATIC Map:

> using `OSMViewer` we can show static map that contain on location

```dart
OSMViewer(
        controller: SimpleMapController(
          initPosition: GeoPoint(
              latitude: 47.4358055,
              longitude: 8.4737324,
          ),
        markerHome: const MarkerIcon(
            icon: Icon(Icons.home),
          ),
        ),
        zoomOption: const ZoomOption(
        initZoom: 16,
        minZoomLevel: 11,
    ),
)
```

## STATIC METHODS:

<b>1) Calculate distance between 2 geoPoint position </b>

```dart
 double distanceEnMetres = await distance2point(GeoPoint(longitude: 36.84612143139903,latitude: 11.099388684927824,),
        GeoPoint( longitude: 36.8388023164018, latitude: 11.096959785428027, ),);
```

<b>2) Get search Suggestion of text </b>

> you should know that i'm using public api, don't make lot of request

```dart
    List<SearchInfo> suggestions = await addressSuggestion("address");
```

## show dialog picker

> simple dialog location picker to selected user location

```dart
GeoPoint p = await showSimplePickerLocation(
                      context: context,
                      isDismissible: true,
                      title: "Title dialog",
                      textConfirmPicker: "pick",
                      initCurrentUserPosition: true,
                    )
```

## CustomLocationPicker

> customizable widget to build search location

> you should use `PickerMapController` as controller for the widget
> see example : [ search widget ](https://github.com/liodali/osm_flutter/blob/master/example/lib/search_example.dart)

#### Properties of `CustomLocationPicker`

| Properties           | Description                                                                                                               |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `controller`         | (PickerMapController) controller of the widget                                                                            |
| `appBarPicker`       | (AppBar) appbar for the widget                                                                                            |
| `topWidgetPicker`    | (Widget?) widget will be show on top of osm map,for example to show address suggestion                                    |
| `bottomWidgetPicker` | (Widget?) widget will be show at bottom of screen for example to show more details about selected location or more action |

## Notice

> `The map supports Android, iOS, and Web.`

> `If you get ssl certfiction exception,use can use http by following instruction below`

> `If you want to use http in Android PIE or above :`

- enable useSecureURL and add `android:usesCleartextTraffic="true"` in your manifest like example below :

      * ` <application
          ...
          android:usesCleartextTraffic="true">
          `

> Before you publish your application using this library,
> you should take care about copyright of openStreetMap Data,
> that's why i add `CopyrightOSMWidget` see example and this issue [#101](https://github.com/liodali/osm_flutter/issues/101)

#### MIT LICENCE

<p align="center">
  <img src="https://raw.githubusercontent.com/liodali/osm_flutter/0.70.1/.github/OSM%20Flutter%20Logo.png?sanitize=true" width="500px">
</p>

# flutter_osm_plugin 

![pub](https://img.shields.io/badge/pub-v1.0.0-blue)   


## Platform Support
| Android | iOS | Web |
|:---:|:---:|:---:|
| supported :heavy_check_mark: | supported :heavy_check_mark: (min iOS supported : 13) | supported :heavy_check_mark: |


<b>osm plugin for flutter apps </b>

* current position (Android/iOS/web)
* change position (Android/iOS/web) 
* create Marker manually (Android/iOS/web)
* tracking user location (Android/iOS/web)
* customize Icon Marker (Android/iOS/web)
* customize user Marker (Android/iOS/web)
* assisted selection position (Android/iOS)
* set BoundingBox (Android/iOS/Web)
* zoom into region (Android/iOS/web)
* draw Road  (Android/iOS/web)
* recuperate information (instruction/duration/distance) of the current road  (Android/iOS/web)
* draw Road manually (Android/iOS/web)
* draw multiple Roads  (Android/iOS/web)
* ClickListener on Marker (Android/iOS/web)
* ClickListener on Map (Android/iOS/web)
* calculate distance between 2 points 
* address suggestion
* draw shapes (Android/iOS/web)
* simple dialog location picker (Android/iOS)
* listen to region change (Android/iOS/Web)
* set custom tiles (Android/iOS/Web) 


## Getting Started
<img src="https://github.com/liodali/osm_flutter/blob/master/osm.gif?raw=true" alt="openStreetMap flutter examples"><br>
<br>
<img src="https://github.com/liodali/osm_flutter/blob/0.41.0/tileLayerRuntime.gif?raw=true" alt="openStreetMap flutter examples" width=260><br>
<br>
<img src="https://github.com/liodali/osm_flutter/blob/master/dialogSimplePickerLocation.gif?raw=true" alt="openStreetMap flutter examples"><br>

## Installing

Add the following to your `pubspec.yaml` file:

    dependencies:
      flutter_osm_plugin: ^1.0.0



## Integration with Hooks

> To use our map library with `Flutter_Hooks` library use our new extension library
https://pub.dev/packages/osm_flutter_hooks
many thanks for @ben-xD

### Migration to `0.41.2` (Android Only)

> open file build.gradle inside android file

    * change kotlin version from `1.5.21` to `1.7.20`
    * change gradle version from `7.0.4` to `7.1.3`
    * change compileSdkVersion to 33


### Migration to `0.34.0` (Android Only)
> if you are using this plugin before Flutter 3

> you should make some modification in build.gradle before that run flutter clean && flutter pub get

> open file build.gradle inside android file

    * change kotlin version from `1.5.21` to `1.6.21`
    * change gradle version from `7.0.2` to `7.1.3` or `7.0.4`
    * change compileSdkVersion to 32
    
### Migration to `0.16.0` (Android Only)
> if you are using this plugin before Flutter 2 

> you should make some modification in build.gradle before that run flutter clean && flutter pub get

> open file build.gradle inside android file

    * change kotlin version from `1.4.21` to `1.5.21`
    * change gradle version from `4.1.1` to `7.0.2`

### For web integration

> To show buttons,UI that have to manage user click over the map, you should use this library : `pointer_interceptor`


## Simple Usage
#### Creating a basic `OSMFlutter` :
  
  
```dart
 OSMFlutter( 
        controller:mapController,
        osmOption: OSMOption(
              userTrackingOption: UserTrackingOption(
              enableTracking: true,
              unFollowUser: false,
            ),
            zoomOption: ZoomOption(
                  initZoom: 8,
                  minZoomLevel: 3,
                  maxZoomLevel: 19,
                  stepZoom: 1.0,
            ),
            userLocationMarker: UserLocationMaker(
                personMarker: MarkerIcon(
                    icon: Icon(
                        Icons.location_history_rounded,
                        color: Colors.red,
                        size: 48,
                    ),
                ),
                directionArrowMarker: MarkerIcon(
                    icon: Icon(
                        Icons.double_arrow,
                        size: 48,
                    ),
                ),
            ),
            roadConfiguration: RoadOption(
                    roadColor: Colors.yellowAccent,
            ),
            markerOption: MarkerOption(
                defaultMarker: MarkerIcon(
                    icon: Icon(
                      Icons.person_pin_circle,
                      color: Colors.blue,
                      size: 56,
                    ),
                )
            ),
        )
    );

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

<b> 3) Properties  of default `MapController` </b>

> `MapController` has 2 named Constructor `MapController.withPosition`,
`MapController.withUserPosition` to control initialization of the Map

| Properties                   |  Description                                                        |
| ---------------------------- | ----------------------------------------------------------------------- |
| `initMapWithUserPosition`    | (UserTrackingOption?) initialize map with user position   |
| `initPosition`               | (GeoPoint) if it isn't null, the map will be pointed at this position   |
| `areaLimit`                  | (Bounding) set area limit of the map (default BoundingBox.world())   |
| `customLayer`                | (CustomTile) set customer layer  using different osm server , this attribute used only with named constructor `customLayer`  |
| ` useExternalTracking`       | (bool) if true,we will disable our logic to show userlocation marker or to move to the user position |


<b> 3.1) Custom Layers with  `MapController` </b>

* To change the tile source in OSMFlutter, you should used our named constructor `customLayer`, see the example below

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
            url: "https://tile.opentopomap.org/",
            subdomains: [],
          )
        ],
        tileSize: 256,
      ),
    )

```

* also,you can use our predefined custom tiles like 
* `cyclOSMLayer` constructor for cycling tiles
* `publicTransportationLayer` constructor for transport tiles ,it's public osm server

For more example see our example in `home_example.dart`
<br>
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

* For the box attribute ,If you don't have bounding box,you can use list of geopoint like this `BoundingBox.fromGeoPoints`

<b> 6) get current zoom level </b>b>

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


<b> 8)  Track user current position </b>

> for iOS,you should add those line in your info.plist file
```text
   <key>NSLocationWhenInUseUsageDescription</key>
	<string>any text you want</string>
	<key>NSLocationAlwaysUsageDescription</key>
	<string>any text you want</string>
``` 
> from version 0.40.0 we can call only `enableTracking` will animate to user location 
without need to call `currentLocation`

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

* recuperate geoPoint of marker add it by user except static points

```dart
List<GeoPoint> geoPoints = await controller.geopoints;
```
<b> 13) get bounding box  map </b>

```dart
BoundingBox bounds = await controller.bounds;
```

<b> 14) Map Listener  </b>

> Get GeoPoint from  listener from controller directly
 (for more example: see home_example.dart )

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

<b> 15.2) Change Icon Marker  </b>

> You can change marker icon by using attribute `markerIcon` of existing Marker
> The GeoPoint/Marker should be exist

```dart
await controller.setMarkerIcon(GeoPoint,MarkerIcon);
```

<b> 15.3) Remove marker </b>

```dart
 await controller.removeMarker(geoPoint);
```
* PS : static position cannot be removed by this method 


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


| Properties               | Description                         |
| ------------------------ | ----------------------------------- |
| `roadColor`              | (Color) required Field,  change the default color of the route in runtime    |
| `roadWidth`              | (double) change the road width, default value 5.0       |
| `roadBorderColor`        | (Color?) set color of border polyline       |
| `roadBorderWidth`        | (double?) set border width of polyline, if width null or 0,polyline will drawed without border |
| `zoomInto`               | (bool)  change zoom level to make the all the road visible (default:true)    |


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

>  change orientation of the static GeoPoint with `GeoPointWithOrientation`


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

* Circle
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
* Rect
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
* remove all shapes in the map
```dart
 await controller.removeAllShapes();
```

### Interfaces:
* OSMMixinObserver :
> contain listener methods to get event from native map view like when mapIsReady,mapRestored

> you should add ths line `controller.addObserver(this);` in initState

> override mapIsReady to implement your own logic after initialisation of the map

> `mapIsReady` will replace `listenerMapIsReady`

| Methods                       | Description                         |
| ----------------------------- | ----------------------------------- |
| `mapIsReady`                  | (callback) Should be override this method, to get notified when map is ready to go or not |
| `mapRestored`                 | (callback) Should be override this method, to get notified when map is restored you can also add you backup |
| `onSingleTap`                 | (callback) Called when the user makes single click on map |
| `onLongTap`                   | (callback) Called when the user makes long click on map |
| `onRegionChanged`             | (callback) Notified when map is change region (on moves) |
| `onRoadTap`                   | (callback) Notified when user click on the polyline (road) |
| `onLocationChanged`           | (callback) Notified when user location changed  |


** example 
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



##  `OSMFlutter`

| Properties                    | Description                         |
| ----------------------------- | ----------------------------------- |
| `mapIsLoading`                | (Widget)  show custom  widget when the map finish initialization     |
| `osmOption`                   | (OSMOption) used to configure OSM Map such as zoom,road,userLocationMarker    |
| `onGeoPointClicked`           | (callback) listener triggered when marker is clicked ,return current geoPoint of the marker         |
| `onLocationChanged`           | (callback) it is fired when you activate tracking and  user position has been changed          |
| `onMapMoved`                  | (callback) it is each the map moved user handler or navigate to another location using APIs       |
| `onMapIsReady`                | (callback) listener trigger to get map is initialized or not |

## `OSMOption` 

| Properties                    | Description                         |
| ----------------------------- | ----------------------------------- |
| `mapIsLoading`                | (Widget)  show custom  widget when the map finish initialization     |
| `trackMyPosition`             | enable tracking user position.     |
| `showZoomController`          | show default zoom controller.       |
| `userLocationMarker`          | change user marker or direction marker icon in tracking location                |
| `markerOption`                | configure marker of osm map                   |
| `zoomOption`                  | set  configuration for zoom in the Map
| `roadConfiguration`           | (RoadOption) set  default color,width,borderColor,borderWdith for polylines |
| `staticPoints`                | List of Markers you want to show always ,should every marker have unique id |
| `showContributorBadgeForOSM`  | (bool) enable to show copyright widget of osm in the map  |
| `enableRotationByGesture`     | (bool) enable to rotation gesture for map, default: false  |
| `showDefaultInfoWindow`       | (bool) enable/disable default infoWindow of marker (default = false)         |
| `isPicker`                    | (bool) enable advanced picker from init of  the map (default = false)         |


## `ZoomOption`

| Properties                    | Description                                                  |
| ----------------------------- | ------------------------------------------------------------ |
| `stepZoom`                    | set step zoom to use in zoomIn()/zoomOut() (default 1)       |
| `initZoom`                    | set init zoom level in the map (default 10)                  |
| `maxZoomLevel`                | set maximum zoom level in the map  (2 <= x <= 19)            |
| `minZoomLevel`                | set minimum zoom level in the map  (2 <= x <= 19 )           |

### Custom Controller
> To create your own MapController to need to extends from `BaseMapController`,
> if you want to make a custom initialization to need to call init() and put your code after super.init()

* example
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



## STATIC METHODS:

<b>1) Calculate distance between 2 geoPoint position </b>
```dart
 double distanceEnMetres = await distance2point(GeoPoint(longitude: 36.84612143139903,latitude: 11.099388684927824,),
        GeoPoint( longitude: 36.8388023164018, latitude: 11.096959785428027, ),);
```

<b>2) Get search Suggestion of text </b>

>  you should know that i'm using public api, don't make lot of request

```dart
    List<SearchInfo> suggestions = await addressSuggestion("address");
```

## show dialog picker

> simple dialog  location picker to selected user location   

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
> customizable widget to build  search location  

> you should use `PickerMapController` as controller for the widget
 see example  :  [ search widget ](https://github.com/liodali/osm_flutter/blob/master/example/lib/search_example.dart) 

#### Properties of `CustomLocationPicker`


| Properties               | Description                         |
| ------------------------ | ----------------------------------- |
| `controller`             | (PickerMapController) controller of the widget     |
| `appBarPicker`           | (AppBar) appbar for the widget        |
| `topWidgetPicker`        | (Widget?) widget will be show on top of osm map,for example to show address suggestion                     |
| `bottomWidgetPicker`     | (Widget?) widget will be show at bottom of screen for example to show more details about selected location or more action       |



## NOTICE:
> `For now the map working for android,iOS , web will be available soon `

> ` If you get ssl certfiction exception,use can use http by following instruction below `

> ` If you want to use http in Android PIE or above : `
  * enable useSecureURL and add ` android:usesCleartextTraffic="true" `  in your manifest like example below :

    * ` <application
        ...
        android:usesCleartextTraffic="true"> 
        `
> if you faced build error in fresh project you need to follow those instruction [#40](https://github.com/liodali/osm_flutter/issues/40)
    
    1) remove flutter_osm_plugin from pubspec, after that pub get
    2) open android module in android studio ( right click in name of project -> flutter-> open android module in android studio)
    3) update gradle version to 4.1.1 ( IDE will show popup to make update)
    4) update kotlin version to 1.4.21 & re-build the project
    5) re-add flutter_osm_plugin in pubspec , pub get ( or flutter clean & pub get )

> Before you publish your application using this library,
> you should take care about copyright of openStreetMap Data,
> that's why i add `CopyrightOSMWidget` see example and this issue [#101](https://github.com/liodali/osm_flutter/issues/101)

#### MIT LICENCE

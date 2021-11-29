# flutter_osm_plugin
![pub](https://img.shields.io/badge/pub-v0.26.1-orange) 

## Platform Support
| Android | iOS | Web |
|:---:|:---:|:---:|
| supported :heavy_check_mark: | supported :heavy_check_mark: (min iOS supported : 12) | under-development |


<b>osm plugin for flutter apps </b>

* current position (Android/iOS)
* change position (Android/iOS) 
* create Marker manually (Android/iOS)
* tracking user location (Android/iOS)
* customize Icon Marker (Android/iOS)
* customize user Marker (Android/iOS)
* assisted selection position (Android/iOS)
* set BoundingBOx (Android)
* draw Road,recuperate information (duration/distance) of the current road (Android/iOS)
* draw Road manually (Android/iOS)
* ClickListener on Marker (Android/iOS)
* ClickListener on Map (Android/iOS)
* calculate distance between 2 points 
* address suggestion
* draw shapes (Only Android)
* simple dialog location picker (Android/iOS)

## Getting Started
<img src="https://github.com/liodali/osm_flutter/blob/master/osm.gif?raw=true" alt="openStreetMap flutter examples"><br>
<br>
<img src="https://github.com/liodali/osm_flutter/blob/master/dialogSimplePickerLocation.gif?raw=true" alt="openStreetMap flutter examples"><br>

## Installing

Add the following to your `pubspec.yaml` file:

    dependencies:
      flutter_osm_plugin: ^0.26.1

### Migration to `0.16.0` (Android Only)
> if you are using this plugin before Flutter 2 

> you should make some modification in build.gradle before that run flutter clean && flutter pub get

> open file build.gradle inside android file

    * change kotlin version from `1.4.21` to `1.5.21`
    * change gradle version from `4.1.1` to `7.0.2`


## Simple Usage
#### Creating a basic `OSMFlutter` :
  
  
```dart
 OSMFlutter( 
        controller:mapController,
        trackMyPosition: false,
        initZoom: 12,
        minZoomLevel: 8,
        maxZoomLevel: 14,
        stepZoom: 1.0,
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
        road: Road(
                startIcon: MarkerIcon(
                  icon: Icon(
                    Icons.person,
                    size: 64,
                    color: Colors.brown,
                  ),
                ),
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
    );

```

## MapController

> Declare `MapController` to control OSM map 
 
<b>1) Initialisation </b>

```dart
 MapController controller = MapController(
                            initMapWithUserPosition: false,
                            initPosition: GeoPoint(latitude: 47.4358055, longitude: 8.4737324),
                            areaLimit: BoundingBox( east: 10.4922941, north: 47.8084648, south: 45.817995, west: 5.9559113,),
                       );
```
<b>2) Dispose </b>
```dart
     controller.dispose();
```
<b> 3) Properties  of `MapController` </b>

| Properties                   | Description                                                             |
| ---------------------------- | ----------------------------------------------------------------------- |
| `initMapWithUserPosition`    | (bool) initialize map with user position (default:true                  |
| `initPosition`               | (GeoPoint) if it isn't null, the map will be pointed at this position   |
| `areaLimit`                  | (Bounding) set area limit of the map (default BoundingBox.world())   |

<b>4) Set map on user current position </b>

```dart
 await controller.currentPosition();

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


```dart
 await controller.enableTracking();
```

<b> 9) Disable tracking user position </b>

```dart
 await controller.disabledTracking();
```

<b>10) update the location </b>

> this method will create marker on that specific position

```dart
 await controller.changeLocation(GeoPoint(latitude: 47.35387, longitude: 8.43609));
```
> Change the location without create marker

```dart
 await controller.goToLocation(GeoPoint(latitude: 47.35387, longitude: 8.43609));
```


<b> 11) recuperation current position </b>

```dart
 GeoPoint geoPoint = await controller.myLocation();
```
<b> 12) get center map </b>b>

```dart
GeoPoint centerMap = await controller.centerMap;
```

<b> 13) select/create new position </b>

* we have 2 way to select location in map

<b>13.1 Manual selection (deprecated) </b>

a) select without change default marker 
```dart
 GeoPoint geoPoint = await controller.selectPosition();
```
b) select position with dynamic marker
 * Flutter widget 
```dart
 GeoPoint geoPoint = await controller.selectPosition(
     icon: MarkerIcon(
                      icon: Icon(
                        Icons.location_history,
                        color: Colors.amber,
                        size: 48,
          ), 
);
```
 * image from network
 ```dart
  GeoPoint geoPoint = await controller.selectPosition(  
          imageURL: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/back/1.png"
);
 ```

c) select using listener from controller directly
* for more example  see  home_example.dart 
c.1) single tap listener
```dart
controller.listenerMapSingleTapping.addListener(() {
      if (controller.listenerMapSingleTapping.value != null) {
        /// put you logic here
      }
    });
```
c.2) long tap listener
```dart
controller.listenerMapLongTapping.addListener(() {
      if (controller.listenerMapLongTapping.value != null) {
        /// put you logic here
      }
    });
```
<b>13.2 Assisted selection </b> (for more details see example) 

```dart
 /// To Start assisted Selection
 await controller.advancedPositionPicker();
 /// To get location desired
  GeoPoint p = await controller.getCurrentPositionAdvancedPositionPicker();
  /// To get location desired and close picker
 GeoPoint p = await controller.selectAdvancedPositionPicker();
 /// To cancel assisted Selection
 await controller.cancelAdvancedPositionPicker();
```

<b>14) Create Marker Programmatically </b>
> you can change marker icon by using attribute `markerIcon`
```dart
await controller.addMarker(GeoPoint,markerIcon:MarkerIcon,angle:pi/3);
```

<b> 14.1) Remove marker </b>

```dart
 await controller.removeMarker(geoPoint);
```
* PS : static position cannot be removed by this method 

<b>15) Draw road,recuperate distance in km and duration in sec </b>

> you can add an middle position to pass your route through them
>
```dart
 RoadInfo roadInfo = await controller.drawRoad( 
   GeoPoint(latitude: 47.35387, longitude: 8.43609),
   GeoPoint(latitude: 47.4371, longitude: 8.6136),
   roadType: RoadType.car,
   intersectPoint : [ GeoPoint(latitude: 47.4361, longitude: 8.6156), GeoPoint(latitude: 47.4481, longitude: 8.6266)]
   roadOption: RoadOption(
       roadWidth: 10,
       roadColor: Colors.blue,
       showMarkerOfPOI: false
   ),
);
 print("${roadInfo.distance}km");
 print("${roadInfo.duration}sec");
```

<b> 15.b) draw road manually </b>
```dart
await controller.drawRoadManually(
        waysPoint,
        Colors.purpleAccent,
        6.0,
      )
```

<b>16) Delete last road </b>

```dart
 await controller.removeLastRoad();
```

<b>17) Change static GeoPoint position </b>

> add new staticPoints with empty list of geoPoints (notice: if you add static point without marker,they will get default maker used by plugin)

> change their position over time

>  change orientation of the static GeoPoint with `GeoPointWithOrientation`


```dart
 await controller.setStaticPosition(List<GeoPoint> geoPoints,String id );
```
<b>18) Change/Add Marker old/new static GeoPoint position </b>

> add marker of new static point

> change their marker of existing static geoPoint over time

```dart
 await controller.setMarkerOfStaticPoint(String id,MarkerIcon markerIcon );
```

<b>19) change orientation of the map</b>

```dart
 await controller.rotateMapCamera(degree);
```

<b>20) Draw Shape in the map </b>

* Circle
```dart
 /// to draw
 await controller.drawCircle(CircleOSM(
              key: "circle0",
              centerPoint: GeoPoint(latitude: 47.4333594, longitude: 8.4680184),
              radius: 1200.0,
              color: Colors.red,
              strokeWidth: 0.3,
            ));
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
              color: Colors.red,
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
| `mapIsReady`                  | (callback) should be override this method, to get notified when map is ready to go or not,     |
| `mapRestored`                 | (callback) should be override this method, to get notified when map is restored you can also add you bakcup   |


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
    //etc
}
```



##  `OSMFlutter`

| Properties                    | Description                         |
| ----------------------------- | ----------------------------------- |
| `mapIsLoading`                | (Widget)  show custom  widget when the map finish initialization     |
| `trackMyPosition`             | enable tracking user position.     |
| `showZoomController`          | show default zoom controller.       |
| `userLocationMarker`          | change user marker or direction marker icon in tracking location                |
| `markerOption`                | configure marker of osm map                   |
| `stepZoom`                    | set step zoom to use in zoomIn()/zoomOut() (default 1)       |
| `initZoom`                    | set init zoom level in the map (default 10)       |
| `maxZoomLevel`                | set maximum zoom level in the map  (2 <= x <= 19)       |
| `minZoomLevel`                | set minimum zoom level in the map  (2 <= x <= 19 )       |
| `road`                        | set color and start/end/middle markers in road |
| `staticPoints`                | List of Markers you want to show always ,should every marker have unique id |
| `onGeoPointClicked`           | (callback) listener triggered when marker is clicked ,return current geoPoint of the marker         |
| `onLocationChanged`           | (callback) it is fired when you activate tracking and  user position has been changed          |
| `onMapIsReady`                | (callback) listener trigger to get map is initialized or not |
| `showDefaultInfoWindow`       | (bool) enable/disable default infoWindow of marker (default = false)         |
| `isPicker`                    | (bool) enable advanced picker from init of  the map (default = false)         |
| `showContributorBadgeForOSM`  | (bool) enable to show copyright widget of osm in the map  |


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
> `For now the map working only for android,iOS will be available soon `

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

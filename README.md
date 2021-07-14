# flutter_osm_plugin
![pub](https://img.shields.io/badge/pub-v0.8.0-orange)

## Platform Support
| Android | iOS | Web |
|:---:|:---:|:---:|
| supported :heavy_check_mark: | supported (not stable yet) :  0.10.1-alpha  | under-development |

<b>osm plugin for flutter apps </b>

* current position
* change position 
* tracking user location
* customize Icon Marker
* assisted selection position
* draw Road,recuperate information (duration/distance) of the current road
* ClickListener on Marker
* calculate distance between 2 points
* address suggestion
* draw shapes
* simple dialog location picker

## Getting Started
<img src="https://github.com/liodali/osm_flutter/blob/master/osm.gif?raw=true" alt="openStreetMap flutter examples"><br>
<br>
<img src="https://github.com/liodali/osm_flutter/blob/master/searchExample.gif?raw=true" alt="openStreetMap flutter examples"><br>
<br>
<img src="https://github.com/liodali/osm_flutter/blob/master/dialogSimplePickerLocation.gif?raw=true" alt="openStreetMap flutter examples"><br>

## Installing

Add the following to your `pubspec.yaml` file:

    dependencies:
      flutter_osm_plugin: ^0.8.0

* alpha version (iOS support)


```dart
 dependencies:
          flutter_osm_plugin: ^0.10.1-alpha.0
```
    
    

## Simple Usage
#### Creating a basic `OSMFlutter` :
  
  
```dart
 OSMFlutter( 
        controller:mapController,
        trackMyPosition: false,
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
        markerIcon: MarkerIcon(
        icon: Icon(
          Icons.person_pin_circle,
          color: Colors.blue,
          size: 56,
          ),
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


<b>4) Set map on user current position </b>

```dart
 await controller.currentPosition();
```
<b> 5) Zoom IN </b>

```dart
 await controller.zoom(2.);
 // or 
 await controller.zoomIn();
```

<b> 6Android) Zoom Out </b>

```dart
 await controller.zoom(-2.);
 // or 
 await controller.zoomOut();
```

<b> 7)  Track user current position </b>

```dart
 await controller.enableTracking();
```

<b> 8) Disable tracking user position </b>

```dart
 await controller.disabledTracking();
```

<b>9) update the location </b>

> this method will create marker on that specific position

```dart
 await controller.changeLocation(GeoPoint(latitude: 47.35387, longitude: 8.43609));
```
> Change the location without create marker

```dart
 await controller.goToLocation(GeoPoint(latitude: 47.35387, longitude: 8.43609));
```


<b> 10) recuperation current position </b>

```dart
 GeoPoint geoPoint = await controller.myLocation();
```

<b> 11) select/create new position </b>

* we have 2 way to select location in map

<b>11.1 Manual selection </b>

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
 
<b>11.2 Assisted selection </b> (for more details see example) 

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
* PS : selected position can be removed by long press 

<b>12) Remove marker </b>

```dart
 await controller.removePosition(geoPoint);
```
* PS : static position cannot be removed by this method 

<b>13) Draw road,recuperate distance in km and duration in sec </b>

> you can add an middle position to pass your route through them
>
```dart
 RoadInfo roadInfo = await controller.drawRoad( 
   GeoPoint(latitude: 47.35387, longitude: 8.43609),
   GeoPoint(latitude: 47.4371, longitude: 8.6136),
   intersectPoint : [ GeoPoint(latitude: 47.4361, longitude: 8.6156), GeoPoint(latitude: 47.4481, longitude: 8.6266)]
   roadOption: RoadOption(
       roadWidth: 10.0,
       roadColor: Colors.blue,
       showMarkerOfPOI: false
   ),
);
 print("${roadInfo.distance}km");
 print("${roadInfo.duration}sec");
```

<b>14) Delete last road </b>

```dart
 await controller.removeLastRoad();
```

<b>15) Change static GeoPoint position </b>

> you can use it if you don't have at first static position and you need to add  staticPoints with empty list of geoPoints
> you can use it to change their position over time

```dart
 await controller.setStaticPosition(List<GeoPoint> geoPoints,String id );
```

<b>16) change orientation of the map</b>

```dart
 await controller.rotateMapCamera(degree);
```

<b>17) Draw Shape in the map </b>

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

<b>18) Map Tapping Listener  </b> 

> listener to singleTap and LongPress on the map (available on Android)

```dart
/// Listener LongPress
controller.listenerMapLongTapping.addListener(() {
      if(controller.listenerMapLongTapping.value!=null){
         final geoP = controller.listenerMapLongTapping.value;
      }
    });
/// Listener SingleTap

controller.listenerMapSingleTapping.addListener(() {
      if(controller.listenerMapSingleTapping.value!=null){
         final geoP = controller.listenerMapLongTapping.value;
      }
});
```




##  `OSMFlutter`

| Properties                    | Description                         |
| ----------------------------- | ----------------------------------- |
| `mapIsLoading`                | (Widget)  show custom  widget when the map finish initialization     |
| `trackMyPosition`             | enable tracking user position.     |
| `showZoomController`          | show default zoom controller.       |
| `markerIcon`                  | set icon Marker  (deprecated replaced with `markerOption` )                   |
| `markerOption`                | configure marker of osm map                   |
| `defaultZoom`                 | set default zoom to use in zoomIn()/zoomOut() (default 1)       |
| `road`                        | set color and start/end/middle markers in road |
| `staticPoints`                | List of Markers you want to show always ,should every marker have unique id |
| `onGeoPointClicked`           | (callback) listener triggered when marker is clicked ,return current geoPoint of the marker         |
| `onLocationChanged`           | (callback) it is hire when you activate tracking and  user position has been changed          |
| `showDefaultInfoWindow`       | (bool) enable/disable default infoWindow of marker (default = false)         |
| `isPicker`                    | (bool) enable advanced picker from init of  the map (default = false)         |
| `showContributorBadgeForOSM`  | (bool) enable to show copyright widget of osm in the map  |

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

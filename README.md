# flutter_osm_plugin
![pub](https://img.shields.io/badge/pub-v0.6.4-orange)

osm plugin for flutter apps (only Android for now, iOS will be supported in future)

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

## Getting Started


## Installing

Add the following to your `pubspec.yaml` file:

    dependencies:
      flutter_osm_plugin: ^0.6.3
## Simple Usage
#### Creating a basic `OSMFlutter` :
  
  
```dart
OSMFlutter( 
        controler:mapController,
        currentLocation: false,
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
        initPosition: GeoPoint(latitude: 47.35387, longitude: 8.43609),
    );

```

### Declare MapController to control osm map instead of using GlobalKey 
 
#### Initialisation
```dart
MapController controller = MapController(
                            initMapWithUserPosition: false,
                            initPosition: GeoPoint(latitude: 47.4358055, longitude: 8.4737324),
                       );
```
#### dispose
```dart
     controller.dispose();
```
####  `MapController`
| Properties                   | Description                                                             |
| ---------------------------- | ----------------------------------------------------------------------- |
| `initMapWithUserPosition`    | (bool) initialize map with user position (default:true                  |
| `initPosition`               | (GeoPoint) if it isn't null, the map will be pointed at this position   |

>  GlobalKey was deprecated

### set map on user current position

```dart
await controller.currentPosition();
```
### zoomIN
```dart
await controller.zoom(2.);
// or 
await controller.zoomIn();
```

### zoomOut
```dart
await controller.zoom(-2.);
// or 
await controller.zoomOut();
```

###  track user current position

```dart
await controller.enableTracking();
```

### disable tracking user position

```dart
await controller.disabledTracking();
```

### initialise position

```dart
controller.changeLocation(GeoPoint(latitude: 47.35387, longitude: 8.43609));
```
### recuperation current position

```dart
GeoPoint geoPoint = controller.myLocation();
```

### select/create new position

* we have 2 way to select location in map

1) manual selection

```dart
GeoPoint geoPoint = controller.selectPosition();
```
2) assisted selection (for more details see example)

```dart
/// To Start assisted Selection
await controller.advancedPositionPicker();
/// To get location desired
GeoPoint p = await controller.selectAdvancedPositionPicker();
/// To cancel assisted Selection
await controller.cancelAdvancedPositionPicker();
```
* PS : selected position can be removed by long press 

### remove marker

```dart
controller.removePosition(geoPoint);
```
* PS : static position cannot be removed by this method 

### draw road,recuperate distance in km and duration in sec
```dart
RoadInfo roadInfo = await controller.drawRoad( GeoPoint(latitude: 47.35387, longitude: 8.43609),GeoPoint(latitude: 47.4371, longitude: 8.6136));
print("${roadInfo.distance}km");
print("${roadInfo.duration}sec");
```

### delete last road

```dart
await controller.removeLastRoad();
```

### change static GeoPoint position
> you can use it if you don't have at first static position and you need to add  staticPoints with empty list of geoPoints
> you can use it to change their position over time

```dart
await controller.setStaticPosition(List<GeoPoint> geoPoints,String id );
```

### draw Shape in the map

* Circle
```dart
/// to draw
await controller.drawCircle(CircleOSM(
              key: "circle0",
              centerPoint: GeoPoint(latitude: 47.4333594, longitude: 8.4680184),
              radius: 1200.0,
              color: Colors.red,
              stokeWidth: 0.3,
            ));
/// to remove Circle using Key
await controller.removeCircle("circle0");

/// to remove All Circle in the map 
await controller.removeAllCircle();

```




####  `OSMFlutter`
| Properties               | Description                         |
| ------------------------ | ----------------------------------- |
| `trackMyPosition`        | enbaled tracking user position.     |
| `showZoomController`     | show default zoom controller.       |
| `markerIcon`             | set icon Marker                     |
| `defaultZoom`            | set default zoom to use in zoomIn()/zoomOut() (default 1)       |
| `road`                   | set color and start/end/middle markers in road |
| `useSecureURL`           | enabled secure urls                  |
| `staticPoints`           | List of Markers you want to show always ,should every marker have unique id |
| `onGeoPointClicked`      | (callback) listener triggered when marker is clicked ,return current geoPoint of the marker         |
| `onLocationChanged`      | (callback) it is hire when you activate tracking and  user position has been changed          |
| `showDefaultInfoWindow`  | (bool) enable/disable default infoWindow of marker (default = false)         |

## STATIC METHODS:
### calculate distance between 2 geoPoint position
```dart
 double distanceEnMetres = await distance2point(GeoPoint(longitude: 36.84612143139903,latitude: 11.099388684927824,),
        GeoPoint( longitude: 36.8388023164018, latitude: 11.096959785428027, ),);
```

### get search Suggestion of text 

>  you should know that i'm using public api, don't make lot of request

```dart
    List<SearchInfo> suggestions = await addressSuggestion("address");
```


## NOTICE:
> `for now the map working only for android,iOS will be available soon `

> ` if you get ssl certfiction exception,use can use http by following instruction below `

> ` if you want to use http in Android PIE or above : `
  * enable useSecureURL and add ` android:usesCleartextTraffic="true" `  in your manifest like example below :

    * ` <application
        ...
        android:usesCleartextTraffic="true"> 
        `
> if you faced build error in fresh project you need to follow those instruction ([#40])
    
    1) remove flutter_osm_plugin from pubspec, after that pub get
    2) open android module in android studio ( right click in name of project -> flutter-> open android module in android studio)
    3) update gradle version to 4.1.1 ( IDE will show popup to make update)
    4) update kotlin version to 1.4.21 & re-build the project
    5) re-add flutter_osm_plugin in pubspec , pub get ( or flutter clean & pub get )

#### MIT LICENCE

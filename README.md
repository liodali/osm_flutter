# flutter_osm_plugin
![pub](https://img.shields.io/badge/pub-v0.3.6%2B4-orange)

osm plugin for flutter apps (only Android for now, iOS will be supported in future)

* current position
* change position 
* tracking user location
* customize Icon Marker
* draw Road
* ClickListener on Marker
  
## Getting Started


## Installing

Add the following to your `pubspec.yaml` file:

    dependencies:
      flutter_osm_plugin: ^0.3.6+4
## Simple Usage
#### Creating a basic `OSMFlutter`:
  
  
    OSMFlutter( 
        key: osmKey,
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

### Declare GlobalKey

`  GlobalKey<OSMFlutterState> osmKey = GlobalKey<OSMFlutterState>();`

### set map on user current position

` osmKey.currentState.currentPosition() `

### zoomIN

` osmKey.currentState.zoom(2.) `


### zoomOut

` osmKey.currentState.zoom(-2.) `

###  track user current position or disable tracking

` osmKey.currentState.enableTracking() `

### initialise position

` osmKey.currentState.changeLocation(GeoPoint(latitude: 47.35387, longitude: 8.43609)) `

### recuperation current position

`GeoPoint geoPoint = osmKey.currentState.myLocation() `

### select/create new position

`GeoPoint geoPoint = osmKey.currentState.selectPosition() `

### draw road
` osmKey.currentState.drawRoad( GeoPoint(latitude: 47.35387, longitude: 8.43609),GeoPoint(latitude: 47.4371, longitude: 8.6136)); `

### change static geopoint position
> you can use it if you don't have at first static position and you need to add  staticPoints with empty list of geoPoints
> you can use it to change their position over time
` osmKey.currentState.setStaticPosition(List<GeoPoint> geoPoints,String id ) `



####  `OSMFlutter`
| Properties           | Description                         |
| -------------------- | ----------------------------------- |
| `currentLocation`    | enable the current position.        |
| `trackMyPosition`    | enbaled tracking user position.     |
| `showZoomController` | show default zoom controller.       |
| `initPosition`       | set default position showing in map |
| `markerIcon`         | set icon Marker                     |
| `road`               | set color and start/end/middle markers in road |
| `useSecureURL`       | enabled secure urls                  |
| `staticPoints`       | List of Markers you want to show always ,should every marker have unique id |
| `onGeoPointClicked`  | listener on static geoPoint          |

## NOTICE:
> `for now the map working only for android,iOS will be available soon `

> ` if you get ssl certfiction exception,use can use http by following instruction below `

> ` if you want to use http in Android PIE or above : `
  * enable useSecureURL and add ` android:usesCleartextTraffic="true" `  in your manifest like example below :

    * ` <application
        ...
        android:usesCleartextTraffic="true"> 
        `

#### MIT LICENCE

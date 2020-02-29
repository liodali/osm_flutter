# flutter_osm_plugin
![pub](https://img.shields.io/badge/pub-v0.2.0-orange)

osm plugin for flutter apps (only Android for now, iOS will be supported in future)

* current position
* change position 
* tracking user location
  
## Getting Started


## Installing

Add the following to your `pubspec.yaml` file:

    dependencies:
      flutter_osm_plugin: ^0.2.0
## Simple Usage
#### Creating a basic `OSMFlutter`:
  
  
    OSMFlutter( 
          key: osmKey,
          currentLocation: false,
          markerIcon: MarkerIcon(
              icon: Icon(
                Icons.person_pin_circle,
                color: Colors.blue,
                size: 56,
              ),
          ),
          initPosition: GeoPoint(latitude: 47.35387, longitude: 8.43609,);

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

####  `OSMFlutter`
| Properties           | Description                         |
| -------------------- | ----------------------------------- |
| `currentLocation`    | enable the current position.        |
| `trackMyPosition`    | enbaled tracking user position.     |
| `showZoomController` | show default zoom controller.       |
| `initPosition`       | set default position showing in map |
| `markerIcon`         | set icon Marker                     |

## NB:
`for now the map working only for android,iOS will be available soon `

#### MIT LICENCE

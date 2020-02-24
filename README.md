# flutter_osm_plugin
![pub](https://img.shields.io/badge/pub-v0.1.0%2B3-orange)

osm plugin for flutter apps (only Android for now, iOS will be supported in future)

* current position
* change position 
* tracking user location
  
## Getting Started


## Installing

Add the following to your `pubspec.yaml` file:

    dependencies:
      flutter_osm_plugin: ^0.1.0+3
## Simple Usage
#### Creating a basic `OSMFlutter`

    OSMFlutter(
                  key: osmKey,
                  currentLocation: false,
                  initPosition: GeoPoint(latitude: 47.35387, longitude: 8.43609),
            );

### Declare GlobalKey to get selection

`  GlobalKey<OSMFlutterState> osmKey = GlobalKey<OSMFlutterState>();`

### set current position

` osmKey.currentState.currentPosition() `

### zoomIN

` osmKey.currentState.zoom(2.) `


### zoomOut

` osmKey.currentState.zoom(-2.) `

### enabled track current position

` osmKey.currentState.trackMe() `

### initialise position

` osmKey.currentState.initLocationPosition(GeoPoint(latitude: 47.35387, longitude: 8.43609)) `

####  `OSMFlutter`
| Properties           | Description                         |
| -------------------- | ----------------------------------- |
| `currentLocation`    | enable the current position.        |
| `trackMyPosition`    | enbaled tracking user position.     |
| `showZoomController` | show default zoom controller.       |
| `initPosition`       | set default position showing in map |

## NB:
`for now the map working only for android,iOS will be available soon `

#### MIT LICENCE

## 0.6.1+1 [beta-version]:
* fix bugs
## 0.6.1 [beta-version]:
* add new attribute to control the visibility if infoWindow of Marker
## 0.6.0+1 [beta-version]:
* fix readme
## 0.6.0 [beta-version]:
* separation of controller from osmFlutter
* remove working with globalkey to make operation in osmMap
* create MapController to communicate with osm map
* improve readability of code
## 0.4.7+8 [beta-version]:
* fix error in road when markers not initialized
## 0.4.7+7 [beta-version]:
* fix enableTracking and deactivateTracking
## 0.4.7+6 [beta-version]:
* fix bug in map when currentLocation = true map freeze and no response due to infinite loop
in requestPermission
## 0.4.7+5 [beta-version]:
* fix readme
## 0.4.7+4 [beta-version]:
* update readme
## 0.4.7+3 [beta-version]:
* create new method to delete last road in map
## 0.4.7+2 [beta-version]:
* fix zoom level when new position was picked
## 0.4.7+1 [beta-version]:
* format files
* add comments
## 0.4.7 [beta-version]:
* add marker picked by user deletable in long click
* add new method to delete marker manually (cannot delete static point with this method)
## 0.4.6 [beta-version]:
* receive update location when tracking is enabled
## 0.4.5+1 [beta-version]:
* fix enable/disable tracking
## 0.4.5 [beta-version]:
* disableTracking when activity goes in background and re-enabled when is resumed
* add new method to disable tracking
## 0.4.4+3 [beta-version]:
* fix missing export utilities
## 0.4.4+2 [beta-version]:
* fix bug in multiple staticPoint
## 0.4.4+1 [beta-version]:
* fix display marker of staticPoint
## 0.4.4 [beta-version]:
* add attribute defaultZoom
* add zoomIn/zoomOut as 2 other method to make zoom in map
* fix bug in zoom method in native code
## 0.4.3 [beta-version]:
* fix lifecycle of map in activity
## 0.4.2 [beta-version]:
* create method to calculate distance between 2 point : distance2point
* format files
## 0.4.1 [beta-version]:
* recuperation distance and duration of current road
## 0.4.0 [beta-version]:
* migrate native android code from java to kotlin
## 0.3.6+7 [beta-version]:
* remove deprecated tag in pubspec
## 0.3.6+6 [beta-version]:
* remove deprecated tag in pubspec
## 0.3.6+5 [beta-version]:
* update dependencies
* update docs
## 0.3.6+4 [beta-version]:
* request permission only when you want to activate tracking or get current location
## 0.3.6+3 [beta-version]:
* upgrade dependencies
## 0.3.6+2 [beta-version]:
* change longPress in selectPosition to simplePress
* fix error and behavior
## 0.3.6+1 [beta-version]:
* fix draw last point in draw
## 0.3.6 [beta-version]:
* staticPoints become list of Markers with unique id
* add callback setStaticPosition to set position if you don't have it or to change it over time
* to use setStaticPosition correctly you need to initialize staticPoints with markers that have empty geoPoints and unique ids
## 0.3.5+1 [beta-version]:
* fix problem show address when geoPoint clicked
## 0.3.5 [beta-version]: new feature
* add static geoPoint
* listener click for static geoPoint
* fix error
* improve more code
## 0.3.4 [alpha-version]: customisation infowindow of marker
*show adresse from geopoint
## 0.3.3 [alpha-version]:
* widget road to modify marker in road and color of line
* enable/disable https to get road in map
## 0.3.2+1 [alpha-version]:
* fix readme
## 0.3.2 [alpha-version]:

* draw road
* handle geopoint and road exception 
## 0.3.0 [alpha-version]:

* pick position and recuperation of the position
## 0.2.0 [alpha-version]:

* Custom Marker Icon
## 0.1.1 [alpha-version]:

* you can now ,recuperation your current location
## 0.1.0+4 [alpha-version]:

* fix readme
## 0.1.0+3 [alpha-version]:

* fix zoom parametre 
## 0.1.0+2 [alpha-version]:

* fix readme
## 0.1.0+1 [alpha-version]:

## 0.1.0 [alpha-version]:

* contain basic for android
* trakcing,set position,current position

## 0.0.1

* TODO: Describe initial release.

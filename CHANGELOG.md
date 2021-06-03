## 0.7.7+2 :
* fix bug : hide markers of start and end position
## 0.7.7+1 :
* remove `roadWidth` , `roadColor` from the method `drawRoad`
* create new class RoadOption contain new attribute `showMarkerOfPOI`
* fix bug in color road
## 0.7.7 :
* add interest point to draw road 
## 0.7.6+1  :
* increase score
## 0.7.6  :
* add new attribute markerOption to configuration marker in osm map
* deprecate attribute markerIcon
* add method `changeAdvPickerIconMarker` 
## 0.7.5+2  :
* remove unnecessary code
## 0.7.5+1  :
* fix bug
* update osmdroid  to 6.1.10 
* update osmbonuspack to 6.7.0
## 0.7.5  :
* add `rotateMapCamera` function to chang orientation of the osm map
## 0.7.4-nullsafety.2  :
* fix readme
## 0.7.4-nullsafety.1  :
* update readme
## 0.7.4-nullsafety.0  :
* add new widget `CustomPickerLocatiob` to build custom search picker
* add new attribute `textCancelPicker` showSimplePickerLocation
## 0.7.3-nullsafety.0  :
* add new attribute to drawRoad : `roadColor`,`roadWidth`
## 0.7.2-nullsafety.0  :
* add goToLocation method to change location in the map without add marker
* change example
* fix bug
## 0.7.1-nullsafety.0  :
* create `showSimplePickerLocation` method that display simple dialog with osm map  
## 0.7.0-nullsafety.0  :
* migrate plugin to null safety
* fix bugs
* remove dependencies that doesn't support null safety
* open gps service when current location demanded by user
## 0.6.7+3  :
* remove default zoom from track location
## 0.6.7+2  :
* remove deprecated api in build.gradle
## 0.6.7+1  :
* fix issues
## 0.6.7  :
* add new method to get current location without close advanced picker
* create new example  search picker example 
## 0.6.6+1  :
* fix error export
## 0.6.6  :
* add removeAllRect,removeAllShapes
* optimisation in native android code
## 0.6.5  :
* add drawRect , removeRect
## 0.6.4  :
* add assisted selection position 
## 0.6.3  :
* add drawCircle , removeCircle and removeAllCircle method
* update android dependencies  
## 0.6.2  :
* add addressSuggestion for search completion 
## 0.6.1+1  :
* fix bugs
## 0.6.1  :
* add new attribute to control the visibility if infoWindow of Marker
## 0.6.0+1  :
* fix readme
## 0.6.0  :
* separation of controller from osmFlutter
* remove working with globalkey to make operation in osmMap
* create MapController to communicate with osm map
* improve readability of code
## 0.4.7+8  :
* fix error in road when markers not initialized
## 0.4.7+7  :
* fix enableTracking and deactivateTracking
## 0.4.7+6  :
* fix bug in map when currentLocation = true map freeze and no response due to infinite loop
in requestPermission
## 0.4.7+5  :
* fix readme
## 0.4.7+4  :
* update readme
## 0.4.7+3  :
* create new method to delete last road in map
## 0.4.7+2  :
* fix zoom level when new position was picked
## 0.4.7+1  :
* format files
* add comments
## 0.4.7  :
* add marker picked by user deletable in long click
* add new method to delete marker manually (cannot delete static point with this method)
## 0.4.6  :
* receive update location when tracking is enabled
## 0.4.5+1  :
* fix enable/disable tracking
## 0.4.5  :
* disableTracking when activity goes in background and re-enabled when is resumed
* add new method to disable tracking
## 0.4.4+3  :
* fix missing export utilities
## 0.4.4+2  :
* fix bug in multiple staticPoint
## 0.4.4+1  :
* fix display marker of staticPoint
## 0.4.4  :
* add attribute defaultZoom
* add zoomIn/zoomOut as 2 other method to make zoom in map
* fix bug in zoom method in native code
## 0.4.3  :
* fix lifecycle of map in activity
## 0.4.2  :
* create method to calculate distance between 2 point : distance2point
* format files
## 0.4.1  :
* recuperation distance and duration of current road
## 0.4.0  :
* migrate native android code from java to kotlin
## 0.3.6+7  :
* remove deprecated tag in pubspec
## 0.3.6+6  :
* remove deprecated tag in pubspec
## 0.3.6+5  :
* update dependencies
* update docs
## 0.3.6+4  :
* request permission only when you want to activate tracking or get current location
## 0.3.6+3  :
* upgrade dependencies
## 0.3.6+2  :
* change longPress in selectPosition to simplePress
* fix error and behavior
## 0.3.6+1  :
* fix draw last point in draw
## 0.3.6  :
* staticPoints become list of Markers with unique id
* add callback setStaticPosition to set position if you don't have it or to change it over time
* to use setStaticPosition correctly you need to initialize staticPoints with markers that have empty geoPoints and unique ids
## 0.3.5+1  :
* fix problem show address when geoPoint clicked
## 0.3.5  : new feature
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

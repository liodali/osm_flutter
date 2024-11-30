### 1.3.6: fix bug
* fix set multiple static marker icon (#575)
### 1.3.5+1: fix bug
* fix android build by remove unnecessary dependency in gradle file
### 1.3.5: fix bug
* fix issue in convert js object to dart for web side
### 1.3.4: fix bug
### 1.3.3+1:
* remove unnecessary gradle dependency that cause issue
### 1.3.3:
* fix bug in web side
### 1.3.2:
* fix bug in mylocation on web side
### 1.3.1:
* fix bug in setIconMarker In web side (#560)
### 1.3.0:
* add new attribute `isDotted` to `RoadOption`  to draw dotted line
* fix bug related to draw shapes in mobile side
### 1.2.0:
* Create new widget `OSMViewer` as static map
* Add `SimpleMapController` as controller to manipulate `OSMViewer`
* Improve BoundingBox API
### 1.1.0:
* fix bug in drawMultiRoad #530
* improve customTile where we added the support for full url
* improve lints
### 1.0.5:
* remove unnecessary internal APIs
* fix lastknownLocation in android
### 1.0.4:
* fix bug #527
### 1.0.3:
* fix bug #521
* fix bug related to removeMarker,removeMarker in iOS #508
### 1.0.2:
* fix bug #519 
### 1.0.1: 
* fix bug #518
### 1.0.0: Update iOS SDK, Stablize APIs
* replace Tangram es with another ios sdk
* add `startLocationUpdating`,`stopLocationUpdating` for external control of user location
* fix some bugs
* migrate to wasm for web
* replace gotoPosition by moveTo
### 1.0.0-rc.6: update dependencies
### 1.0.0-rc.5: fix userlocation in android
* fix user location tracking in android side (bug:#507)
### 1.0.0-rc.4: fix userlocation in ios
* update ios sdk and fix bug related to userlocation 
* fix draw border for road in ios side 
### 1.0.0-rc.3: fix bugs
* fix bug related to user location in android #507
* update docs(thanx to @vargab95)
### 1.0.0-rc.2: update web dependency
* migrate to wasm
### 1.0.0-rc.1: 
* fix bug #500
### 1.0.0-rc:
* add support draw shapes in iOS side
### 1.0.0-dev.4:
* improve picker_map_controller
* improve picker dialog and widget
### 1.0.0-dev.3:
* Dix bug in init map with zoomOption in iOS side
* Add `isEqual` method to `GeoPoint`
* Improve/fix bug in ios sdk
### 1.0.0-dev.2:
* fix bugs for angle/iconAnchor in web side
* fix bug for iconAnchor in iOS side
* fix customTile in ios when it's null
### 1.0.0-dev.1 : 
* update readme
### 1.0.0-dev : 
* switch iOS sdk
* remove advPicker API
* add toggleLayerVisibility
* fix bugs
### 0.70.4 : fix bugs
* fix bug related to user location in android ( #482, thnx for @vargab95)
* fix launchURl (thnx for @derklaro)### 0.70.3 :
* fix bug #480
### 0.70.2 :
* fix bugs (thanks for @JobiJoba)
### 0.70.1 :
* update dependencies, fix namespaces for gradle 8.0
### 0.70.0 :
* add anchor to UserLocation
* add onLocationChanged to osmMixin
* fix bugs
* some improvement for web side
### 0.60.5 : 
* fix bug #452
### 0.60.4 :
* fix bug in cache marker in android #445
### 0.60.3 : 
* fix bugs related to icon size for user location #440
* fix bugs related to camera map rotation #355
### 0.60.2 : fix bugs #433,#434
* remove `androidHotReloadSupport` from OSMOption
* fix parsing route in `RoadInfo`
### 0.60.1 :  
* fix issue
### 0.60.0+3 : 
* fix py script for automator
### 0.60.0+2 : 
* forget update changelog
### 0.60.0+1 : 
* fix issue
### 0.60.0 : Improvement API and fix bugs ( contain break changes )
* Add iconAnchor for addMarker/changeLocationMarker
* Fix bugs #420 , #262 , #430 , #419
* Add `OSMOption` as configuration for `OSMFlutter`
### 0.55.3 : fix bugs
* fix angle for addMarker where it should be between 0 and 2pi
### 0.55.2 : fix bugs
* fix issue related to rotate markers
### 0.55.1+1 : 
* fix readme
### 0.55.1 : 
* fix bugs
### 0.55.0 : add UserTrackingOption to MapController
* create UserTrackOption class and add it MapController
### 0.54.2 : fix bugs
* fix bug #407
* fix jdk 17 to 8
### 0.54.1 : fix bugs
* fix bug #407,#403
### 0.54.0 : improvement and fix bugs
* migrate to v3.10
* fix bugs #407 #409
* add support rotation by gesture for android/ios (add `enableRotationByGesture` attribute)
### 0.53.4+1 : fix bug
* fix web_widget platform by removing the cast
### 0.53.4 : fix bug #385
* improve js/dart code to manage show multiple maps in web side
### 0.53.3 : Improve instruction for roadInfo in web
### 0.53.2 : Improve instruction for roadInfo in iOS
* re-impl build intruction retrieved fron orsm api in drawRoad
### 0.53.1 : improve add OSMMixinObserver
* improve implementation of  OSMMixinObserver in mobile,web
### 0.53.0 :new feature 
* disable rotation for person marker
* add instruction in RoadInfo
### 0.51.0 :  fix bugs,add new API
* add removeMarkers
* fix bug name attribute zoomInto in android 
### 0.50.0 :  add Web support,improve road APIs
* add `roadBorderColor`,`roadBorderWidth` to [RoadOption]
* remove `keepInitialGeoPoints` and `showMarkerOfPOI`
* add new  callbacks to `OSMMixinObserver`
* add callback to get polyline event
* add osm_web_interface plugin
* add create osm widget for web
### 0.42.0 : add api to enableTracking
* add parameter `enableStopFollow` in `enableTracking`
* disable follow track user location when user start drag
* fix drawRoad : add keepInitialGeo in ios side
### 0.41.2 : fix dependencies for android sdk 33
### 0.41.1 : add `withPosition` and `withUserPosition` as new named constructor for `MapController`
### 0.41.0 : change tile in runtime
* add `changeTileLayer` in map_controller
### 0.40.3+2 : fix bugs
* replace firebase url used in ios for map styles
### 0.40.3+1 : fix bugs
* replace firebase url used in ios for map styles
### 0.40.3 : fix bugs (#335)
* fix set custom tiles in android 
### 0.40.2 : fix bugs
* fix disable follow user location when calling myLocation
### 0.40.1 : fix bugs
### 0.40.0 : fix bugs
* disable user location when widget is disposed
* improve get user location in android side
* enableTracking now will enableUserLocation no need to call currentLocation before calling enableTracking
### 0.39.1 : fix ios markers size (ios)
* change icon size types from double to int
* fix set userLocationMarker in iOS
### 0.39.0 : fix ios markers size
* create MarkerIconData to store icon and size
* set default size as 48px
* change set icons in ios side
### 0.38.0 : support custom layer for ios
* create TileURLs to manage osm server urls
* change type of urls to TileURLs in customTile
* impl change styles yml in ios side
* put convert Uint8List to string for ios markers in _capturePng
### 0.37.2+5 : fix bugs
* set api attribute of CustomTile in android side
* fix visibility of static marker in ios
* setEnableAutoStop to true in android
### 0.37.2+2 : fix bug in setStaticMarker
### 0.37.2+1 : fix bug in setZoom
### 0.37.2 : fix map not showing (#293)
* fix bug send customTile null to android side
### 0.37.1 : remove hide static marker
### 0.37.0 : custom tiles for android , re-implement custom location manager
* add set custom tile for osm map for now available only for android
* create LocationManager in android side
* add the support of change location marker in ios side
### 0.34.1+6 : fix bug in boundingbox
### 0.34.1+5 : fix dependencies
### 0.34.1+4 : fix dependencies
### 0.34.1+3 : fix  bugs 
* fix cast String? in drawRoadManually (ios)
* update dependencies
* update docs
### 0.34.1+2 : fix build bugs in parsing road in iOS
### 0.34.1+1 : fix build bugs in android
### 0.34.1 : fix major bugs
* remove delete cache of osmdroid when widget disposed
* remove detach map when widget disposed
* refactor some code in android side
### 0.34.0+1 : fix build error for android
### 0.34.0: update plugin to support the new changing in Flutter 3.0
* fix override from `PlatformViewFactory`
* fix nullable activity context in osm_plugin
* fix dart nullable error in mobile_osm_flutter 
### 0.33.0+2:
* disable show windowinfo for marker in android
### 0.33.0+1:
* fix osm_interface verions
### 0.33.0:
* fix permission request in ios
* add `geoPoints` method in controller to get list of geo point of existing marker except static points
### 0.32.2: 
* add onMapReady in custom_picker_location
### 0.32.1: fix bugs 
* fix order of drawing marker and polyline in drawRoadManually
* fix show the right custom icon marker
### 0.32.0:
* add `iconWidget` in `MarkerIcon` to show dynamic widget
* support show interestPoint for drawing road manually
* add deleteOldRoad in drawRoadManually to prevent delete last road if it not needed
### 0.31.0:
* add drawMultiRoad in iOS side
* fix request permission when map initialized on user location
* add `zommInto` attribute in drawRoadManually method
### 0.30.1+2:
* hotfix for IndexOutOfBounds when put folder of road in overlay of the map before overlay of user location
### 0.30.1+1:
* remove unnecessary assert in inner controller
### 0.30.1:
* fix cast Double to CGFloat
* add extension method to List of GeoPoint to convert to Encoded route String
* add extension to convert Encoded route to List of GeoPoint
### 0.30.0: add draw multi roads and fix bug 
* create new method `drawMutliRoad` to draw multiple road in the same time
* create new method `clearAllRoads` to clear all roads in the map
* fix bug when user location marker hidden by polylines
* remove deprecated attribute `image` from `MarkerIcon`, suppose to use `assetMarker`
### 0.29.1+3:
* fix docs
### 0.29.1+2:
* fix check permission in iOS for CustomPickerLocation
* remove unnecessary check when isPicker is true  in initialisation of the map
### 0.29.1+1:
* fix check permission when initialize map in iOS
### 0.29.1:
* create `CustomPickerLocationConfig` to set osmflutter widget in pickerLocationWidget
* fix readme
### 0.29.0:
* create `changeIconMarker` to change icon of existing marker
* remove location package and replaced with permission_handler
* implement location permission for iOS manually
* replace shw diolog ( use google service  ) to open gps in android by redirect to setting to set gps on
### 0.28.2:
* fix enable tracking when `trackMyPosition` is true
* add check permision when `initWithUserLocation` in `MapController` is true
### 0.28.1:
* fix map not visible when build release apk
* fix name of method in androidlifecyceleMixin
### 0.28.0+1:
* fix version osm_interface
### 0.28.0:
* add method `zoomToBoundingBox` to adjust zoom level in the map to make the region visible
* add attribute `zoomInto` in RoadOption that used in the method drawRoad
* add 2 method in class `BoundingBox` to convert list of geopoint to Boundingbox
* change the name of class `Road` to `RoadConfiguration`
* change the attribute name `road` in OSMFlutter to `roadConfiguration`
### 0.27.1:
* add new attribute `androidHotReloadSupport` to activate or desactivate hotreload support in mapview on android
### 0.27.0+1:
* add == operator to osm types
### 0.27.0 : add changing region listener and get bounds from mapview
* add `listenerRegionIsChanging` listener to get new region when map was moved
* add `bounds` in map_controller to get bounding box 
* add new attribue `AssetMarker` in `MarkerIcon` 
* add new attribue `route` in `Road` 
### 0.26.1 : fix bug
* clause job coroutine of getRoads when flutter widget call dispose native method
* fix name of centerMapasync to centerMap
### 0.26.0 : add multi map cache (0.25.0 skipped)
* store last map state before reloading widget in android
* create OSMMixinObserver to replace ValueListenable in MapController
* fix show picker map
* add titleWidget for osm picker
* add textStyle for title osm picker
* improve cache map in android 
* fix tracking location in android side
* fix close streamController when we already have another widget use the osmFlutter
### 0.22.3+1 : version versioning in osm_interface package
* improve prepare publish script to manage max version supported by osm_interface
### 0.22.3 :
* fix map listener not working after cancel or confirm advanced picker (#181)
### 0.22.2 :
* add click of simple marker hit the callback `onGeoPointClicked`
### 0.22.1 :
* fix duplication of last icon when addMarker called twice  (#178)
### 0.22.0 :
* add attribute `angle` to the method `addMarker` to rotate icon marker or image with any animation
* deprecation of the method `selectPosition`,use callback to listen to click or long click on the map and addMarker to add marker on that location if it needed
* fix removeMarker,addMarker in ios part
### 0.21.4 :
* change type of `minZoomLevel` and `maxZoomLevel` from int to double
* replace sceneURL in ios with our custom raster tile
### 0.21.3 :
* fix set default advPicker Icon in ios 
### 0.21.2 :
* fix bug in removeMarker [#171]
* improve readme
### 0.21.1 :
* fix bug in currentLocation [#169]
### 0.21.0 :
* fix crash app when close page contain mapView and make request to PlatformChannel [#157]
* fix integrate  version of flutter_osm_interface in flutter_osm_plugin
### 0.21.0-rc.2 :
### 0.21.0-rc :
* fix crash app when close page contain mapView and make request to PlatformChannel [#157]
### 0.20.0+2 : 
*fix pubspec
### 0.20.0+1 : 
* format files
* update dependencies
### 0.20.0 : 
* separate osm_interface in another flutter package
* add IBaseMapController and make BaseMapController api more flexible to be used in custom controller
* create MobileOSMController as inner controller for mobile platform
* create MobileWidget for mobile platform
* fix hotreload problem [#77]
### 0.16.0 : update kotlin version and gralde,add listener on polylines 
* update kotlin version to `1.5.21` (migration instruction in the readme)
* update gradle version to `7.0.2`  (migration instruction in the readme)
* add listener to polylines to get geoPoint selected on the map
### 0.15.0 : add bike,foot routing
* create RoadType and added as paramter to drawRoad, default value : RoadType.car
* add small example in main
### 0.14.2 : fix bug
* fix `setZoom` method by change type variable of `zoomLevel` from int to double
### 0.14.1 : fix bug
* forget to replace the removed attribute `defaultZoom` with `stepZoom`
### 0.14.0 : improve zoom 
* deprecate attribute `defaultZoom`
* replace `defaultZoom` with new attribute `stepZoom`
* deprecated method `zoom` and replaced with `setZoom`
* change logic of setZoom by adding two attribute stepZoom,zoomLevel
* add new attribute `minZoomLevel` and `maxZoomLevel`
* add new attribute `initZoom` to initialize map with that zoom
### 0.13.0 :
* add `onMapIsReady` attribute in OSMFluter to get notified when map is initialized
* add valueListenable `listenerMapIsReady` to `MapController` as notifier for map initialization
### 0.12.0 :
* add new method addMarker to create marker in specific location programmatically
### 0.11.0 :
* add customization of user location marker 
* implement ortiention of the user marker in ios
* add orientation of static geopoint in ios
### 0.11.0-beta.4 :
* add map rotation in ios side
### 0.11.0-beta.3 :
* add default road color for ios side
* fix send color of road for ios side
* add send geoPoint when the marker of static point is clicked
### 0.11.0-beta.2 :
* fix icon marker size in iOS
* add init road config in iOS
### 0.11.0-beta.1 :
fix invokeMethod in gotoPosition
### 0.11.0-beta.0 :
* merge stable feature with alpha 
* remove unnecessary attribute in show static geopoint
* check zoom when add static geopoint to set visibility of geopoint in the map
* change `withSpeed` attribute in fly with `withDuration`
* add remove last road when draw road manually
### 0.11.0-alpha.0 :
* merge new api in 0.8.0 in alpha version
### 0.10.1-alpha.0 :
* hide unnecessary api
### 0.10.0-alpha.0 :
* add draw road manually for dev that they have they own routing api 
### 0.9.0-alpha.0 :
* support drawRoad in iOS
### 0.8.3+2 (without ios support)
* remove unnecesssary att
### 0.8.3+1 (without ios support)
* fix readme
### 0.8.3 (without ios support)
* create new class `GeoPointWithOrientation`
* change orientation of marker of the static GeoPoint in runtime
### 0.8.2 (without ios support)
* add new attribute `limitArea` in MapController to init map in specific area
* add new method `limitArea` to set BoundingBox of camera in the map
* add new method`removeLimitArea` to remove limit area in the map 
### 0.8.1+4 (without ios support)
* fix: set correctly the color of the circle
### 0.8.1+3 (without ios support)
* optimize draw marker before send it to native view in OSMFlutter widget
* replace `selectAdvancedPositionPicker` to get select position with  `getCurrentPositionAdvancedPositionPicker` for ios purpose
### 0.8.1+2 (without ios support)
* fix zoom init map in customPickerLocation
### 0.8.1+1 (without ios support)
* remove unused attribute
### 0.8.1 (without ios support)
* add new method `setMarkerOfStaticPoint` to set marker of group of geoPoint
* remove deprecated attribute `markerIcon` that replaced with `markerOption`
### 0.8.0 (without ios support)
* add new attribute `mapIsLoading` to show custom widget before map has been initialized
* remove show marker in init location
* separate change location from init location
* add internal listener to notify when map is ready
### 0.8.0-alpha.1 :
* fix set color static marker position
* fix convert bitmap to string
### 0.8.0-alpha.0 :
* support ios ( not stable )
  * visualisation of map in ios 
  * support select position (custom marker, not network image will not work) 
  * support track user location
### 0.7.10+1 :
* remove show dialog when map config road
### 0.7.10 :
* (#123) fix zoom when changeLocation was called
* (#123) remove previous marker  when changeLocation was called
### 0.7.9+3 :
* remove background location permission
### 0.7.9+2 :
* fix reinitialize the stream controller when map screen was disposed and reopened again
### 0.7.9+1 :
* fix problem when `await selectPosition` used should
cancel global map listener 
### 0.7.9 :
* add `listenerMapLongTapping` and `listenerMapSingleTapping` to manage Tapping Listener on the map (available for Android)
* remove deletion of marker with LongPres
### 0.7.8+4 :
* remove `useSecureURL` attribute
* remove setURL for drawRoad
### 0.7.8+3 :
* fix bug in android side (check for intersectPoint using wrong key)
* change name attribute from `interestPoint` to `intersectPoint` in drawRoad
### 0.7.8+2 :
* add copyright widget for osm copyright
### 0.7.8+1 :
* fix null check in OSMFlutter 
### 0.7.8 :
* add put dynamic image to marker for select position 
   * you could put flutter widget
   * load image from network
### 0.7.7+2 :
* fix bug : hide markers of start and end position
### 0.7.7+1 :
* remove `roadWidth` , `roadColor` from the method `drawRoad`
* create new class RoadOption contain new attribute `showMarkerOfPOI`
* fix bug in color road
### 0.7.7 :
* add interest point to draw road 
### 0.7.6+1  :
* increase score
### 0.7.6  :
* add new attribute markerOption to configuration marker in osm map
* deprecate attribute markerIcon
* add method `changeAdvPickerIconMarker` 
### 0.7.5+2  :
* remove unnecessary code
### 0.7.5+1  :
* fix bug
* update osmdroid  to 6.1.10 
* update osmbonuspack to 6.7.0
### 0.7.5  :
* add `rotateMapCamera` function to chang orientation of the osm map
### 0.7.4-nullsafety.2  :
* fix readme
### 0.7.4-nullsafety.1  :
* update readme
### 0.7.4-nullsafety.0  :
* add new widget `CustomPickerLocatiob` to build custom search picker
* add new attribute `textCancelPicker` showSimplePickerLocation
### 0.7.3-nullsafety.0  :
* add new attribute to drawRoad : `roadColor`,`roadWidth`
### 0.7.2-nullsafety.0  :
* add goToLocation method to change location in the map without add marker
* change example
* fix bug
### 0.7.1-nullsafety.0  :
* create `showSimplePickerLocation` method that display simple dialog with osm map  
### 0.7.0-nullsafety.0  :
* migrate plugin to null safety
* fix bugs
* remove dependencies that doesn't support null safety
* open gps service when current location demanded by user
### 0.6.7+3  :
* remove default zoom from track location
### 0.6.7+2  :
* remove deprecated api in build.gradle
### 0.6.7+1  :
* fix issues
### 0.6.7  :
* add new method to get current location without close advanced picker
* create new example  search picker example 
### 0.6.6+1  :
* fix error export
### 0.6.6  :
* add removeAllRect,removeAllShapes
* optimisation in native android code
### 0.6.5  :
* add drawRect , removeRect
### 0.6.4  :
* add assisted selection position 
### 0.6.3  :
* add drawCircle , removeCircle and removeAllCircle method
* update android dependencies  
### 0.6.2  :
* add addressSuggestion for search completion 
### 0.6.1+1  :
* fix bugs
### 0.6.1  :
* add new attribute to control the visibility if infoWindow of Marker
### 0.6.0+1  :
* fix readme
### 0.6.0  :
* separation of controller from osmFlutter
* remove working with globalkey to make operation in osmMap
* create MapController to communicate with osm map
* improve readability of code
### 0.4.7+8  :
* fix error in road when markers not initialized
### 0.4.7+7  :
* fix enableTracking and deactivateTracking
### 0.4.7+6  :
* fix bug in map when currentLocation = true map freeze and no response due to infinite loop
in requestPermission
### 0.4.7+5  :
* fix readme
### 0.4.7+4  :
* update readme
### 0.4.7+3  :
* create new method to delete last road in map
### 0.4.7+2  :
* fix zoom level when new position was picked
### 0.4.7+1  :
* format files
* add comments
### 0.4.7  :
* add marker picked by user deletable in long click
* add new method to delete marker manually (cannot delete static point with this method)
### 0.4.6  :
* receive update location when tracking is enabled
### 0.4.5+1  :
* fix enable/disable tracking
### 0.4.5  :
* disableTracking when activity goes in background and re-enabled when is resumed
* add new method to disable tracking
### 0.4.4+3  :
* fix missing export utilities
### 0.4.4+2  :
* fix bug in multiple staticPoint
### 0.4.4+1  :
* fix display marker of staticPoint
### 0.4.4  :
* add attribute defaultZoom
* add zoomIn/zoomOut as 2 other method to make zoom in map
* fix bug in zoom method in native code
### 0.4.3  :
* fix lifecycle of map in activity
### 0.4.2  :
* create method to calculate distance between 2 point : distance2point
* format files
### 0.4.1  :
* recuperation distance and duration of current road
### 0.4.0  :
* migrate native android code from java to kotlin
### 0.3.6+7  :
* remove deprecated tag in pubspec
### 0.3.6+6  :
* remove deprecated tag in pubspec
### 0.3.6+5  :
* update dependencies
* update docs
### 0.3.6+4  :
* request permission only when you want to activate tracking or get current location
### 0.3.6+3  :
* upgrade dependencies
### 0.3.6+2  :
* change longPress in selectPosition to simplePress
* fix error and behavior
### 0.3.6+1  :
* fix draw last point in draw
### 0.3.6  :
* staticPoints become list of Markers with unique id
* add callback setStaticPosition to set position if you don't have it or to change it over time
* to use setStaticPosition correctly you need to initialize staticPoints with markers that have empty geoPoints and unique ids
### 0.3.5+1  :
* fix problem show address when geoPoint clicked
### 0.3.5  : new feature
* add static geoPoint
* listener click for static geoPoint
* fix error
* improve more code
### 0.3.4 [alpha-version]: customisation infowindow of marker
*show adresse from geopoint
### 0.3.3 [alpha-version]:
* widget road to modify marker in road and color of line
* enable/disable https to get road in map
### 0.3.2+1 [alpha-version]:
* fix readme
### 0.3.2 [alpha-version]:

* draw road
* handle geopoint and road exception 
### 0.3.0 [alpha-version]:

* pick position and recuperation of the position
### 0.2.0 [alpha-version]:

* Custom Marker Icon
### 0.1.1 [alpha-version]:

* you can now ,recuperation your current location
### 0.1.0+4 [alpha-version]:

* fix readme
### 0.1.0+3 [alpha-version]:

* fix zoom parametre 
### 0.1.0+2 [alpha-version]:

* fix readme
### 0.1.0+1 [alpha-version]:

### 0.1.0 [alpha-version]:

* contain basic for android
* trakcing,set position,current position

### 0.0.1

* TODO: Describe initial release.

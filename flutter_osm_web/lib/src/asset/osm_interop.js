var osmLinks = new Map();
class OSMJS {
   constructor(mapId) {
      this.mapId = mapId;
    }
   /*
   * shared dart function that called from js
   */
  isMapReady(isReady) {
   initMapFinish(isReady);
  }
  onGeoPointClicked(lon, lat) {
   onStaticGeoPointClicked(lon, lat);
  }
  onMapSingleTapClicked(lon, lat) {
   onMapSingleTapListener(lon, lat);
  }
  onRegionChanged(box, center) {
   onRegionChangedListener(box.north, box.east, box.south, box.west, center.lon, center.lat);
  }
  onRoadClicked(roadKey) {
   onRoadListener(roadKey);
  }
  onUserPositionListener(lon, lat) {
   onUserPositionListener(lon, lat);
  }
}








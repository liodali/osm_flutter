var osmLinks = new Map();
class OSMJS {
   constructor(mapId) {
      this.mapId = mapId;
    }
   /*
   * shared dart function that called from js
   */
  isMapReady(isReady) {
   initMapFinish(this.mapId,isReady);
  }
  onGeoPointClicked(lon, lat) {
   onStaticGeoPointClicked(this.mapId,lon, lat);
  }
  onMapSingleTapClicked(lon, lat) {
   onMapSingleTapListener(this.mapId,lon, lat);
  }
  onRegionChanged(box, center) {
   onRegionChangedListener(this.mapId,box.north, box.east, box.south, box.west, center.lon, center.lat);
  }
  onRoadClicked(roadKey) {
   onRoadListener(this.mapId,roadKey);
  }
  onUserPositionListener(lon, lat) {
   onUserPositionListener(this.mapId,lon, lat);
  }
}








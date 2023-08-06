async function centerMap(mapId) {
   var iframe = getIframe(mapId);
   var geoAsync = await iframe.contentWindow.centerMap();
   return geoAsync;
}

async function locateMe(mapId) {
   var iframe = getIframe(mapId);
   var geoAsync = await iframe.contentWindow.getMyLocation();
   console.log(geoAsync);
   return geoAsync;
}

async function changeTileLayer(mapId,tile) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.changeTileLayer(tile);
}

async function addPosition(mapId,point, showMarker, animate) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.changePosition(point, showMarker, animate);
}

async function addMarker(mapId,point, icon,angle,anchor) {
   var iframe = getIframe(mapId);
   return iframe.contentWindow.addMarker(point, icon,angle,anchor);
}
async function changeMarker(mapId,oldPoint, point, icon,angle,anchor) {
   var iframe = getIframe(mapId);
   return iframe.contentWindow.changeMarker(oldPoint, point, icon,angle,anchor);
}

async function modifyMarker(mapId,point, icon) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.modifyMarker(point, icon);
}

async function initMapLocation(mapId,point) {
   console.log(point.lon + ":" + point.lat)
   var iframe = getIframe(mapId);
   await iframe.contentWindow.initMapLocation(point);
}

async function setDefaultIcon(mapId,icon) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.setDefaultIcon(icon);
}
async function setIconStaticGeoPoints(mapId,id, icon) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.setStaticGeoPointIcon(id, icon);
}
async function setStaticGeoPoints(mapId,id, points) {
   console.log(points)
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.setStaticGeoPoint(id, points);
}
async function setStaticGeoPointsWithOrientation(mapId,id, points) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.setStaticGeoPointsWithOrientation(id, points);
}
async function setZoomStep(mapId,zoomStep) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.setZoomStep(zoomStep);
}
async function zoomIn(mapId) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.zoomIn();
}
async function zoomOut(mapId) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.zoomOut();
}
async function setZoom(mapId,zoom) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.setZoomLevel(zoom);
}
async function setZoomWithStep(mapId,step) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.setZoomWithStep(step);
}
async function getZoom(mapId) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.getZoom();
}
async function configZoom(mapId,step, zoom, minZoomLevel, maxZoomLevel) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.configInitZoomMap(step, zoom, minZoomLevel, maxZoomLevel);
}
async function currentUserLocation(mapId) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.userLocation();
}
async function removeMarker(mapId,point) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.removeMarker(point);
}
async function setMaxZoomLevel(mapId,zoomLevel) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.setMaxZoomLevel(zoomLevel);
}
async function setMinZoomLevel(mapId,zoomLevel) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.setMinZoomLevel(zoomLevel);
}
async function limitArea(mapId,box) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.limitBoundingBox(box);
}
async function getBounds(mapId) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.getBounds();
}
async function flyToBounds(mapId,box, padding) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.flyToBoundingBox(box, padding);
}
function drawRoad(mapId,key,route, color, roadWidth, zoomInto, roadBorderColor,roadBorderWidth, interestPoints, iconInteretPoint) {
   console.log(route);
   var iframe = getIframe(mapId);
   return iframe.contentWindow.drawRoad(key,route, color, roadWidth, zoomInto, roadBorderColor,roadBorderWidth, interestPoints, iconInteretPoint);
}
async function removeLastRoad(mapId){
   var iframe = getIframe(mapId);
   return iframe.contentWindow.removeLastRoad(mapId);
}
async function removeRoad(mapId,roadId){
   var iframe = getIframe(mapId);
   return iframe.contentWindow.removeRoad(mapId,roadId);
}
async function getGeoPoints(mapId) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.getGeoPoints();

}
async function setUserLocationIconMarker(mapId,icon){
   var iframe = getIframe(mapId);
   return iframe.contentWindow.setUserLocationIconMarker(icon);
}

async function enableTracking(mapId,enableStopFollow){
   var iframe = getIframe(mapId);
   return iframe.contentWindow.enableTracking(enableStopFollow);
}
async function disableTracking(mapId) {
   var iframe = getIframe(mapId);
   return iframe.contentWindow.disableTracking();
}
async function changeIconAdvPickerMarker(mapId,icon) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.changeIconAdvPickerMarker(icon);
}
async function advSearchLocation(mapId) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.advSearchLocation();
}
async function cancelAdvSearchLocation(mapId) {
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.cancelAdvSearchLocation();
}
async function drawRect(mapId,config,bounds){
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.drawRect(config.key,bounds,config.color,config.strokeWidth);
}
async function drawCircle(mapId,config){
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.drawCircle(config);
}
async function removePath(mapId,key){
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.removePath(key);
}

async function removeAllCircle(mapId){
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.removeAllCircle();
}

async function removeAllRect(mapId){
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.removeAllRect();
}

async function removeAllShapes(mapId){
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.removeAllShapes();
}

async function clearAllRoads(mapId){
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.clearAllRoads();
}

async function removeRoad(mapId,roadKey){
   var iframe = getIframe(mapId);
   return await iframe.contentWindow.removeRoad(roadKey);
}
var osmLinks = new Map();
function setUpMap(mapId){
   const osmJS = new OSMJS(mapId);
   osmLinks.set(mapId,osmJS);
   var innerWindow = getIframe(mapId).contentWindow;
   innerWindow.isMapReady = (isReady)=>{
      osmJS.isMapReady(isReady)
   };
   innerWindow.onGeoPointClicked =(lon, lat)=> { osmLinks.get(mapId).onGeoPointClicked(lon, lat) };
   innerWindow.onMapSingleTapClicked =(lon, lat)=>{ osmLinks.get(mapId).onMapSingleTapClicked(lon, lat) };
   innerWindow.onRegionChanged = (box, center)=>{ osmLinks.get(mapId).onRegionChanged(box, center) };
   innerWindow.onRoadClicked = (roadKey) => { osmLinks.get(mapId).onRoadClicked(roadKey) };
   return 200;
}
function getIframe(mapId){
   var iframe = document.getElementById("osm_map_"+mapId).firstChild;
   return iframe;
}
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
}








async function centerMap(){
   var iframe = document.getElementById("frame_map");
   var geoAsync = await iframe.contentWindow.centerMap();
   return geoAsync;
}

async function locateMe() {
   var iframe = document.getElementById("frame_map");
   var geoAsync = await iframe.contentWindow.getMyLocation();
   console.log(geoAsync);
   return geoAsync;
}

async function addPosition(point,showMarker,animate) {
   var iframe = document.getElementById("frame_map");
   return  await iframe.contentWindow.changePosition(point,showMarker,animate);
}

async function initMapLocation(point) {
   var iframe = document.getElementById("frame_map");
   await iframe.contentWindow.initMapLocation(point);
}

async function setDefaultIcon(icon) {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.setDefaultIcon(icon);
}
async function setIconStaticGeoPoints(id,icon) {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.setStaticGeoPointIcon(id,icon);
}
async function setStaticGeoPoints(id,points) {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.setStaticGeoPoint(id,points);
}
async function setZoomStep(zoomStep) {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.setZoomStep(zoomStep);
}
async function zoomIn() {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.zoomIn();
}
async function zoomOut() {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.zoomOut();
}
async function setZoom(zoom) {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.setZoomLevel(zoom);
}
async function setZoomWithStep(step) {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.setZoomWithStep(step);
}
async function getZoom(){
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.getZoom();
}
async function configZoom(step,zoom,minZoomLevel,maxZoomLevel) {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.configInitZoomMap(step,zoom,minZoomLevel,maxZoomLevel);
}
async function currentUserLocation() {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.userLocation();
}
async function removeMarker(point){
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.removeMarker(point);
}
async function setMaxZoomLevel(zoomLevel){
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.setMaxZoomLevel(point);
}
async function setMinZoomLevel(zoomLevel){
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.setMinZoomLevel(point);
}
async function limitArea(box){
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.limitBoundingBox(box);
}
async function getBounds(){
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.getBounds();
}
async function flyToBounds(box,padding){
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.flyToBoundingBox(box,padding);
}

/*
* shared dart function that called from js
*/
function isMapReady(isReady) {
   initMapFinish(isReady);
}
function onGeoPointClicked(lon,lat) {
   onStaticGeoPointClicked(lon,lat);
}
function onMapSingleTapClicked(lon,lat) {
   onMapSingleTapListener(lon,lat);
}
function onRegionChanged(box,center) {
   onRegionChangedListener(box.north,box.east,box.south,box.west,center.lon,center.lat);
}


var innerWindow = document.getElementById('frame_map').contentWindow;
innerWindow.isMapReady = isMapReady;
innerWindow.onGeoPointClicked = onGeoPointClicked;
innerWindow.onMapSingleTapClicked = onMapSingleTapClicked;
innerWindow.onRegionChanged = onRegionChanged;




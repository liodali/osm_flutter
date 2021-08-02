

async function locateMe() {
   var iframe = document.getElementById("frame_map");
   var geoAsync = await iframe.contentWindow.getMyLocation();
   console.log(geoAsync);
   return geoAsync;
}

async function addPosition(point) {
   console.log(point)
   var iframe = document.getElementById("frame_map");
   var result = await iframe.contentWindow.addPosition(point);
   return result;
}

async function initMapLocation(point) {
   var iframe = document.getElementById("frame_map");
   await iframe.contentWindow.initMapLocation(point);
}

function isMapReady(isReady) {
   initMapFinish(isReady);
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


var innerWindow = document.getElementById('frame_map').contentWindow;
innerWindow.isMapReady = isMapReady;




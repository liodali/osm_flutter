
async function locateMe() {
   var iframe = document.getElementById("frame_map");
   var geoAync = await iframe.contentWindow.gotMyLocation();
   console.log(geoAync);
   return geoAync;
}

async function addPosition(point) {
   console.log(point)
   var iframe = document.getElementById("frame_map");
   var geoAync = await iframe.contentWindow.addPosition(point);
   console.log(geoAync);
   return geoAync;
}

async function initMapLocation(point) {
   var iframe = document.getElementById("frame_map");
   await iframe.contentWindow.initMapLocation(point);
}

async function isMapReady(isReady) {
   console.log(isReady);
   initMapFinish(isReady);
}
var innerWindow = document.getElementById('frame_map').contentWindow;
innerWindow.isMapReady = isMapReady;




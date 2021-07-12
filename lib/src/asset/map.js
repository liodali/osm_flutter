
async function locateMe() {
   var iframe = document.getElementById("frame_map");
   var geoAync = await iframe.contentWindow.gotMyLocation();
   console.log(geoAync);
   return geoAync;
}

async function addPosition(point) {
   var iframe = document.getElementById("frame_map");
   var geoAync = await iframe.contentWindow.addPosition(point);
   console.log(geoAync);
   return geoAync;
}




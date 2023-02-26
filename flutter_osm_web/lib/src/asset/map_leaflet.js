var zoom = 2.0;
var stepZoom = 1.0;
var defaultIcon = "";
var roadMarkerIcons = new Map();
var staticIcons = new Map();
var staticGeoPoint = new Map();
var userLocationMarkerIcon = "";
var dynamicIcon = "";
var advSearchIcon = "";
var homeMarker;
var userPosition;
var isReady = false;
var lastRoad;
var colorRoad;
var routesLayer = [];
var idTracking;
var startAdvSearchLocation = false;
var cachedLayers;
var mymap;
var customTile;



mymap = L.map('osm_map_0', {
  renderer: L.canvas(),
  zoomControl: false,
});
var OpenStreetMap_Mapnik = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
  attribution: 'Leaflet | Map data &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
  maxZoom: 19,
  minZoom: 2,
  tileSize: 256,
});
OpenStreetMap_Mapnik.addTo(mymap);
cachedLayers = L.layerGroup([]);
//mymap.setView([0, 0], 2);

mymap.on('click', function (event) {
const geoP = event.latlng;
onMapSingleTapClicked(geoP.lng, geoP.lat);
});
mymap.on('moveend', function (e) {
if (isReady) {
  var bounds = mymap.getBounds();
  var center = mymap.getCenter();
  var box = {
    north: bounds.getNorth(),
    east: bounds.getEast(),
    west: bounds.getWest(),
    south: bounds.getSouth(),
  };
  var centerP = {
    lat: center.lat,
    lon: center.lng
  };
  onRegionChanged(box, centerP);
}

});

 
 async function initMapLocation(point) {
   console.log("zoom init map :" + zoom);
   console.log(point.lon + ":" + point.lat)
   mymap.setView([point.lat, point.lon], zoom);
   isReady = true;
   isMapReady(isReady);
   //L.polyline([{lat: 8.498037, lng: 47.489106},{lat: 8.537061, lng: 47.412961}],{color:'red'}).addTo(mymap)
 }

 async function changeTileLayer(tile) {
  console.log("tile map :" + tile);
  if(tile.url.includes('tile.openstreetmap.org') && customTile != undefined){
    customTile.remove();
    customTile = undefined;
    OpenStreetMap_Mapnik.addTo(mymap);
  }else {
      customTile = L.tileLayer(tile.url+'{z}/{x}/{y}'+tile.tileExtension+tile.apiKey,//'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', 
      {
        subdomains:tile.subDomains,
        //attribution: 'Leaflet | Map data &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
        maxZoom: tile.maxZoom,
        minZoom: tile.minZoom,
        tileSize: tile.tileSize,
     });
    customTile.addTo(mymap);
    OpenStreetMap_Mapnik.remove();
  }

}

 async function currentUserLocation() {
  locateMe().then((user) => {
     mymap.flyTo([user.lat, user.lon], mymap.getZoom());
   });

   return 200;
 }
 async function centerMap() {
   var center = mymap.getCenter();
   return {
     lat: center.lat,
     lon: center.lng
   };
 }

 async function locateMe() {
   var position = await new Promise((resolve, reject) => {
     if (!navigator.geolocation) {
       reject({ error: true, message: 'Geolocation is not supported by your browser' });
     } else {
       navigator.geolocation.getCurrentPosition(
         resolve,
         (position) => {
           reject({ error: true, message: 'Unable to retrieve your location' });
         }
       );
     }
   });
   const latitude = position.coords.latitude;
   const longitude = position.coords.longitude;

   return {
     lat: latitude,
     lon: longitude
   };
 }
 async function getGeoPoints() {
   var listGeoPoint = [];
   mymap.eachLayer(function (layer) {
     if (layer instanceof L.Marker) {
       var geoPoint = layer.getLatLng();
       listGeoPoint.push({
         lat: geoPoint.lat,
         lon: geoPoint.lng
       })
     }
   });
   return { list: JSON.stringify(listGeoPoint) };
 }

 async function addPosition(point, showMarker, animate) {
   const position = [point.lat, point.lon];
   var args = {}
   if (showMarker && defaultIcon != "") {
     args = {
       icon: L.icon(
         {
           iconUrl: "data:image/png;base64," + defaultIcon,
           iconSize: [32, 32]
         }
       )
     }

   }
   if (!animate) {
     mymap.setView(position, mymap.getZoom());
   } else {
     mymap.flyTo(position, mymap.getZoom());
   }
   setHomeMarker(point, args);
   return 200;
 }
 function addMarker(point, iconMarker) {
   const position = [point.lat, point.lon];
   var argsIcon = {
     iconSize: [32, 32],
   }
   if (iconMarker != "") {
     argsIcon["iconUrl"] = "data:image/png;base64," + iconMarker
   }
   var args = {
     icon: L.icon(
       argsIcon
     )
   }
   L.marker(position, args)
     .addTo(mymap)
     .on("click", function (event) {
       const geoP = event.latlng;
       onGeoPointClicked(geoP.lng, geoP.lat)
     });
   return 200;
 }
 async function changeMarker(oldPoint, point, icon) {

   var latlng = L.latLng([point.lat, point.lon]);
   var oldLatlng = L.latLng([oldPoint.lat, oldPoint.lon]);
   mymap.eachLayer(function (layer) {
     if (layer instanceof L.Marker) {
       var geoPoint = layer.getLatLng();
       if (geoPoint.lat == oldLatlng.lat && geoPoint.lng == oldLatlng.lng) {
         layer.setLatLng(latlng)
         if (icon != undefined) {
           var iconMarker = L.icon({
             iconUrl: "data:image/png;base64," + icon,
             iconSize: [32, 32]
           });
           layer.setIcon(iconMarker)
         }
         return this;
       }
     }
   })
 }

 async function modifyMarker(point, icon) {
   const position = [point.lat, point.lon];
   var latlng = L.latLng(position);
   mymap.eachLayer(function (layer) {
     if (layer instanceof L.Marker) {
       var geoPoint = layer.getLatLng();
       if (geoPoint.lat == latlng.lat && geoPoint.lng == latlng.lng) {
         var iconMarker = L.icon({
           iconUrl: "data:image/png;base64," + icon,
           iconSize: [32, 32]
         });
         layer.setIcon(iconMarker)
         return this;
       }
     }
   })
 }

 async function removeMarker(point) {
   mymap.eachLayer(function (layer) {
     if (layer instanceof L.Marker) {
       const latlng = layer.getLatLng()
       if (latlng.lat == point.lat && latlng.lng == point.lon) {
         mymap.removeLayer(layer);
       }
     }
   });
 }

 async function setDefaultIcon(icon) {
   defaultIcon = icon;
   return 200;
 }

 async function setIconStaticGeoPoints(id, icon) {
   staticIcons.set(id, icon)
   return 200;
 }

 async function setStaticGeoPoints(id, points) {
   var markers = [];
   if (staticGeoPoint.has(id) && staticGeoPoint[id] != undefined) {
     staticGeoPoint[id].clearLayers();
   }
   var args = {}
   if (staticIcons.has(id)) {

     args = {
       icon: L.icon(
         {
           iconUrl: "data:image/png;base64," + staticIcons.get(id),
           iconSize: [32, 32]
         }
       )
     }
   }

   points.forEach(function (ele) {
     removeMarker(ele);
     markers.push(L.marker([ele.lat, ele.lon], args)
       .addTo(mymap)
       .on("click", function (event) {
         const geoP = event.latlng;
         onGeoPointClicked(geoP.lng, geoP.lat)
       }))
   })
   const groupLayer = L.layerGroup(markers).addTo(mymap);
   staticGeoPoint.set(id, groupLayer);

   return 200;
 }
 async function setStaticGeoPointsWithOrientation(id, points) {
   var markers = [];
   if (staticGeoPoint.has(id) && staticGeoPoint[id] != undefined) {
     staticGeoPoint[id].clearLayers();
   }
   var icon = L.icon(
     {
       iconUrl: "data:image/png;base64," + staticIcons.get(id),
       iconSize: [32, 32]
     }
   )
   points.forEach(function (ele) {

     removeMarker(ele);
     var marker = L.marker([ele.lat, ele.lon], {
       icon: icon,
       //iconAngle: ele.angle
       rotationAngle: ele.angle,
       rotationOrigin: "center"
     })
       .addTo(mymap)
       .on("click", function (event) {
         const geoP = event.latlng;
         onGeoPointClicked(geoP.lng, geoP.lat)
       });
     //marker.setRotationAngle(ele.angle);
     markers.push(marker);

   })
   const groupLayer = L.layerGroup(markers).addTo(mymap);
   staticGeoPoint.set(id, groupLayer);

   return 200;
 }
 async function configZoom(step, initZoom, minZoomLevel, maxZoomLevel) {
   mymap.setMinZoom(minZoomLevel);
   mymap.setMaxZoom(maxZoomLevel);
   zoom = initZoom;
   stepZoom = step;
   return 200;
 }

 async function setZoomStep(zoomStep) {
   stepZoom = zoomStep
   return 200;
 }
 async function zoomIn() {
   mymap.zoomIn(stepZoom);
   return 200;
 }
 async function zoomOut() {
   mymap.zoomOut(stepZoom);
   return 200;
 }
 async function setZoom(zoom) {
   var nzoomlevel = zoom;
   if (nzoomlevel >= mymap.getMinZoom() && nzoomlevel <= mymap.getMaxZoom()) {
     console.log(nzoomlevel)
     mymap.setZoom(nzoomlevel);
   }
   return 200;
 }
 async function setZoomWithStep(step) {
   var nzoomlevel = mymap.getZoom() + step;
   if (nzoomlevel >= mymap.getMinZoom() && nzoomlevel <= mymap.getMaxZoom()) {
     mymap.setZoom(nzoomlevel);
   } else {
     if (nzoomlevel > mymap.getMaxZoom()) {
       mymap.setZoom(mymap.getMaxZoom());
     } else if (nzoomlevel < mymap.getMinZoom()) {
       mymap.setZoom(mymap.getMinZoom());
     }
   }
   return 200;
 }
 async function getZoom() {
   return mymap.getZoom();
 }
 async function setMaxZoomLevel(zoomLevel) {
   mymap.setMaxZoom(zoomLevel);
 }
 async function setMinZoomLevel(zoomLevel) {
   mymap.setMinZoom(zoomLevel);
 }
 async function limitArea(box) {
   var bounds = L.latLngBounds(
     L.latLng(box.north, box.east),
     L.latLng(box.south, box.west)
   );
   mymap.setMaxBounds(bounds);
   return 200;
 }
 async function getBounds() {
   var box = mymap.getBounds();
   return {
     south: box.getSouth(),
     west: box.getWest(),
     east: box.getEast(),
     north: box.getNorth()
   };
 }
 async function flyToBoundingBox(box, pad) {
   var bounds = L.latLngBounds(
     L.latLng(box.north, box.east),
     L.latLng(box.south, box.west)
   );
   mymap.flyToBounds(bounds, { padding: [pad, pad] });
   return 200;
 }

 async function configRoad(color, startIcon, middleIcon, endIcon) {
   colorRoad = color
   roadMarkerIcons["startIcon"] = startIcon
   roadMarkerIcons["middleIcon"] = middleIcon
   roadMarkerIcons["endIcon"] = startIcon
 }

 function drawRoad(route, colorRoute, routeWidth, zoomInto, keepInitialGeoPoints, interestGeoPts, iconInterestPoint) {
   if (lastRoad != undefined) {
     mymap.removeLayer(lastRoad)
     routesLayer.pop()
     lastRoad = undefined;
   }
   var routePolyline = route.map((elem) => L.latLng(elem.lat, elem.lon))//[elem.lon,elem.lat])
   lastRoad = L.polyline(routePolyline, { color: colorRoute, weight: routeWidth }).addTo(mymap)

   routesLayer.push(lastRoad)
   if (zoomInto) {
     mymap.flyToBounds(lastRoad.getBounds());
   }
   if (interestGeoPts.length > 0) {
     var len = route.length
     interestGeoPts.forEach(function (geoPoint) {
       var icon = undefined;
       if (geoPoint.lat == route[0].lat && geoPoint.lon == route[0].lon && !keepInitialGeoPoints) {
         icon = roadMarkerIcons["startIcon"]
       } else if (geoPoint.lat == route[len - 1].lat && geoPoint.lon == route[len - 1].lon && !keepInitialGeoPoints) {
         icon = roadMarkerIcons["endIcon"]
       } else {
         if (iconInterestPoint) {
           icon = iconInterestPoint
         } else {
           icon = roadMarkerIcons["middleIcon"]
         }
       }
       if (icon) {
         addMarker(geoPoint, icon)
       }

     })
   }
   return 200;
 }
 function setUserLocationIconMarker(icon) {
   if (icon != undefined && icon != "")
     userLocationMarkerIcon = icon;
 }
 async function enableTracking() {
   idTracking = navigator.geolocation.watchPosition(function (position) {
     var userPos = [position.coords.latitude, position.coords.longitude]

     mymap.flyTo(userPos, mymap.getZoom());
     var args = {}
     if (userLocationMarkerIcon != undefined) {
       args = {
         icon: L.icon({
           iconUrl: "data:image/png;base64," + userLocationMarkerIcon,
           iconSize: [32, 32]
         })
       }
     }
     if (userPosition == undefined) {
       userPosition = L.marker(userPos, args).addTo(mymap);
     } else if (userPosition != undefined) {
       userPosition.setLatLng(userPos);
     }
   })
 }

 function disableTracking() {
   navigator.geolocation.clearWatch(idTracking);
 }

 async function advSearchLocation(mapId) {
   startAdvSearchLocation = true
   mymap.eachLayer(function (layer) {
     if (!(layer instanceof L.TileLayer)) {
       var cachedLayer = layer;
       cachedLayers.addLayer(cachedLayer);
       mymap.removeLayer(layer);
     }
   });
   /*
       display: block;
 position: absolute;
 z-index: 1000;
 overflow: hidden;
 top: 47%;
 left: 47%;
   */
   document.getElementById("render-icon-"+mapId).style.display = "block";
   document.getElementById("render-icon-"+mapId).style.position = "absolute";
   document.getElementById("render-icon-"+mapId).style.zIndex = "1000";
   document.getElementById("render-icon-"+mapId).style.top = "45%";
   document.getElementById("render-icon-"+mapId).style.left = "45%";
 }
 async function cancelAdvSearchLocation(mapId) {
   document.getElementById("render-icon-"+mapId).style.display = "none";
   cachedLayers.eachLayer(function (layer) {
     mymap.addLayer(layer);
   });
   cachedLayers.clearLayers();

 }
 async function changeIconAdvPickerMarker(icon,id) {
   advSearchIcon = icon;
   const nodeImg = document.createElement("img");
   nodeImg.setAttribute('src', 'data:image/png;base64,' + icon);
   document.getElementById("render-icon-"+id).replaceChildren(nodeImg);
   nodeImg.style.height = "32px";
   nodeImg.style.width = "32px";
 }




 function setHomeMarker(point, args) {
   if (homeMarker == undefined) {
     homeMarker = L.marker([point.lat, point.lon], args).addTo(mymap);

   } else {
     homeMarker.setLatLng([point.lat, point.lon]);
   }
 }


/*
async function centerMap() {
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

async function addPosition(point, showMarker, animate) {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.changePosition(point, showMarker, animate);
}

async function addMarker(point, icon) {
   var iframe = document.getElementById("frame_map");
   return iframe.contentWindow.addMarker(point, icon);
}
async function changeMarker(oldPoint, point, icon) {
   console.log("change : " + oldPoint)
   console.log("to :" + point)
   var iframe = document.getElementById("frame_map");
   return iframe.contentWindow.changeMarker(oldPoint, point, icon);
}

async function modifyMarker(point, icon) {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.modifyMarker(point, icon);
}

async function initMapLocation(point) {
   console.log(point.lon + ":" + point.lat)
   var iframe = document.getElementById("frame_map");
   await iframe.contentWindow.initMapLocation(point);
}

async function setDefaultIcon(icon) {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.setDefaultIcon(icon);
}
async function setIconStaticGeoPoints(id, icon) {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.setStaticGeoPointIcon(id, icon);
}
async function setStaticGeoPoints(id, points) {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.setStaticGeoPoint(id, points);
}
async function setStaticGeoPointsWithOrientation(id, points) {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.setStaticGeoPointsWithOrientation(id, points);
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
async function getZoom() {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.getZoom();
}
async function configZoom(step, zoom, minZoomLevel, maxZoomLevel) {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.configInitZoomMap(step, zoom, minZoomLevel, maxZoomLevel);
}
async function currentUserLocation() {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.userLocation();
}
async function removeMarker(point) {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.removeMarker(point);
}
async function setMaxZoomLevel(zoomLevel) {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.setMaxZoomLevel(point);
}
async function setMinZoomLevel(zoomLevel) {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.setMinZoomLevel(point);
}
async function limitArea(box) {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.limitBoundingBox(box);
}
async function getBounds() {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.getBounds();
}
async function flyToBounds(box, padding) {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.flyToBoundingBox(box, padding);
}
async function configRoad(color, startIcon, middleIcon, endIcon) {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.configRoad(color, startIcon, middleIcon, endIcon);


}
function drawRoad(route, color, roadWidth, zoomInto, keepInitialGeoPoints, interestPoints, iconInteretPoint) {
   console.log(route);
   var iframe = document.getElementById("frame_map");
   return iframe.contentWindow.drawRoad(route, color, roadWidth, zoomInto, keepInitialGeoPoints, interestPoints, iconInteretPoint);
}

async function getGeoPoints() {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.getGeoPoints();

}
async function setUserLocationIconMarker(icon){
   var iframe = document.getElementById("frame_map");
   return iframe.contentWindow.setUserLocationIconMarker(icon);
}

async function enableTracking(){
   var iframe = document.getElementById("frame_map");
   return iframe.contentWindow.enableTracking();
}
async function disableTracking() {
   var iframe = document.getElementById("frame_map");
   return iframe.contentWindow.disableTracking();
}
async function changeIconAdvPickerMarker(icon) {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.changeIconAdvPickerMarker(icon);
}
async function advSearchLocation() {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.advSearchLocation();
}
async function cancelAdvSearchLocation() {
   var iframe = document.getElementById("frame_map");
   return await iframe.contentWindow.cancelAdvSearchLocation();
}





var innerWindow = document.getElementById('frame_map').contentWindow;
*/
// shared dart function that called from js

function isMapReady(isReady) {
   initMapFinish(isReady);
}
function onGeoPointClicked(lon, lat) {
   onStaticGeoPointClicked(lon, lat);
}
function onMapSingleTapClicked(lon, lat) {
   onMapSingleTapListener(lon, lat);
}
function onRegionChanged(box, center) {
   onRegionChangedListener(box.north, box.east, box.south, box.west, center.lon, center.lat);
} 

// innerWindow.isMapReady = isMapReady;
// innerWindow.onGeoPointClicked = onGeoPointClicked;
// innerWindow.onMapSingleTapClicked = onMapSingleTapClicked;
// innerWindow.onRegionChanged = onRegionChanged;




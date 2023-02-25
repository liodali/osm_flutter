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


  var leafletScript = document.createElement("script");
leafletScript.id = "leafletScript"
leafletScript.type = "text/javascript";
leafletScript.src = "https://unpkg.com/leaflet@1.9.3/dist/leaflet.js";
document.getElementsByTagName('head')[0].appendChild(leafletScript);


var leafletCSS = document.createElement("link");
leafletCSS.id = "leafletCSS"
leafletCSS.setAttribute('rel', 'stylesheet');
leafletCSS.setAttribute('type', 'text/css');
leafletCSS.setAttribute('href', 
                        'https://unpkg.com/leaflet@1.9.3/dist/leaflet.css');
document.getElementsByTagName('head')[0].appendChild(leafletCSS);

leafletScript.onload = function(){
      console.log(L);

      var leafletRotateScript = document.createElement("script");
      leafletRotateScript.id = "leafletRotateScript"
      leafletRotateScript.type = "text/javascript";
      leafletRotateScript.src = "https://cdn.jsdelivr.net/npm/leaflet-rotatedmarker@0.2.0/leaflet.rotatedMarker.min.js";
      document.getElementsByTagName('head')[0].appendChild(leafletRotateScript);
} 
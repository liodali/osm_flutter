import 'package:flutter_osm_interface/src/common/utilities.dart';

/// [CustomTile]
///
/// this class used to set custom tile for osm mapview (android,ios,web)
/// but for now we will support only android,other platform will add it soon,
///
/// [urlsServers]    : url(s) to get tile(s) from,it should at least one address
///
/// [tileExtension]  : extension of tile that we will get from server(s)
///
/// [sourceName]     : unique name will be used in android for caching purpose , this values will be take in in ios side
///
/// [tileSize]       : (int)  size tile will get from server tile
///
/// [minZoomLevel]   :  (int) minimum zoom level for custom tile source, this values will be take in in ios side
///
/// [maxZoomLevel]   :  (int) maximum zoom level for custom tile source
///
/// [keyApi]         : (MapEntry) should contain key name and api key value for tile server that need api key access
class CustomTile {
  final List<TileURLs> urlsServers;
  final String tileExtension;
  final String sourceName;
  final int tileSize, minZoomLevel, maxZoomLevel;
  final MapEntry<String, String>? keyApi;

  CustomTile({
    required this.urlsServers,
    required this.tileExtension,
    required this.sourceName,
    this.tileSize = 256,
    this.minZoomLevel = 2,
    this.maxZoomLevel = 19,
    this.keyApi,
  })  : assert(urlsServers.isNotEmpty),
        assert(
          urlsServers.where((element) => element.url.isEmpty).isEmpty,
        ),
        assert([128, 256, 512, 1024].contains(tileSize)),
        assert(minZoomLevel < maxZoomLevel),
        assert(minZoomLevel >= 2 && minZoomLevel < maxZoomLevel),
        assert(maxZoomLevel > minZoomLevel && maxZoomLevel > 0),
        assert(
          keyApi == null || (keyApi.key.isNotEmpty && keyApi.value.isNotEmpty),
          "if your own server use key access,you should provide the right key name and key api",
        );
  CustomTile.osm({
    this.maxZoomLevel = 19,
    this.minZoomLevel = 2,
  })  : urlsServers = [
          TileURLs(
            url: "https://{s}.tile.openstreetmap.org/",
            subdomains: [
              "a",
              "b",
              "c",
            ],
          ),
        ],
        tileExtension = ".png",
        sourceName = "mapnik",
        tileSize = 256,
        keyApi = null;
  CustomTile.cycleOSM({
    this.maxZoomLevel = 19,
    this.minZoomLevel = 2,
  })  : urlsServers = [
          TileURLs(
            url: "https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm/",
            subdomains: [
              "a",
              "b",
              "c",
            ],
          ),
        ],
        tileExtension = ".png",
        sourceName = "cycleMapnik",
        tileSize = 256,
        keyApi = null;
  CustomTile.publicTransportationOSM({
    this.maxZoomLevel = 19,
    this.minZoomLevel = 2,
  })  : urlsServers = [
          TileURLs(url: "https://tile.memomaps.de/tilegen/"),
        ],
        tileExtension = ".png",
        sourceName = "memomapsMapnik",
        tileSize = 256,
        keyApi = null;

  Map toMap() {
    final map = {
      "name": sourceName,
      "urls": urlsServers
          .map((e) => e.toMapPlatform())
          .toList(),
      "tileSize": tileSize,
      "tileExtension": tileExtension,
      "maxZoomLevel": maxZoomLevel,
      "minZoomLevel": minZoomLevel,
    };
    if (keyApi != null) {
      map.putIfAbsent("api", () => {keyApi!.key: keyApi!.value});
    }
    return map;
  }
}

/// TileURLs
///
/// this class used to set url and subdomain for custoöm tile layer
/// url represent base server url tile , if you have multiple url that contain
/// subdomains use [subdomains] to specify them
/// and replace them in url with {s} to configure correctly the map
class TileURLs {
  final String url;
  final List<String> subdomains;

  TileURLs({
    required this.url,
    this.subdomains = const [],
  });

  List<String> toMapAndroid() {
    if (subdomains.isEmpty) {
      return [
        url,
      ];
    }
    return List.generate(
        subdomains.length, (i) => url.replaceAll("{s}", subdomains[i]));
  }

  Map<String, dynamic> toMapiOS() {
    final Map<String, dynamic> map = {
      "url": url,
    };
    if (subdomains.isNotEmpty) {
      map.putIfAbsent("subdomains", () => subdomains);
    }
    return map;
  }

  List<String> toWeb() {
    return [
      url,
      subdomains.isNotEmpty
          ? subdomains.reduce((value, element) => '$value$element')
          : ''
    ];
  }
}

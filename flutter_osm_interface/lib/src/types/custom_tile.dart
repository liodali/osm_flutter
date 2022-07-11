/// [CustomTile]
///
/// this class used to set custom tile for osm mapview (android,ios,web)
/// but for now we will support only android,other platform will add it soon,
///
/// [urlsServers]    : url(s) to get tile(s) from,it should at least one address
///
/// [tileExtension]  : extension of tile that we will get from server(s)
///
/// [sourceName]     : unique name will be used in android for caching purpose
///
/// [tileSize]       : (int)  size tile will get from server tile
///
/// [minZoomLevel]   :  (int) minimum zoom level for custom tile source
///
/// [maxZoomLevel]   :  (int) maximum zoom level for custom tile source
///
/// [keyApi]         : (MapEntry) should contain key name and api key value for tile server that need api key access
class CustomTile {
  final List<String> urlsServers;
  final String tileExtension;
  final String sourceName;
  final int tileSize, minZoomLevel, maxZoomLevel;
  final MapEntry<String,String>? keyApi;

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
          urlsServers.where((element) => element.isEmpty).isEmpty,
        ),
        assert([128, 256, 512, 1024].contains(tileSize)),
        assert(minZoomLevel < maxZoomLevel),
        assert(minZoomLevel >= 2 && minZoomLevel < maxZoomLevel),
        assert(maxZoomLevel > minZoomLevel && maxZoomLevel > 0),
        assert(keyApi == null || (keyApi.key.isNotEmpty && keyApi.value.isNotEmpty),"if your own server use key access,you provide the right key name,and api");

  Map toMap() {
    final map = {
      "name": sourceName,
      "urls": urlsServers,
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

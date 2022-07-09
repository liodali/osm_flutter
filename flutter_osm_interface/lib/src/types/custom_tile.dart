/// [CustomTile]
///
/// this class used to set custom tile for osm mapview (android,ios,web)
/// but for now we will support only android,other platform will add it soon,
///
///  [urlsServers] : url(s) to get tile(s) from,it should at least one address
///
/// [tileExtension] : extension of tile that we will get from server(s)
///
/// [sourceName] : unique name will be used in android for caching purpose
class CustomTile {
  final List<String> urlsServers;
  final String tileExtension;
  final String sourceName;
  final int tileSize, minZoomLevel, maxZoomLevel;

  CustomTile({
    required this.urlsServers,
    required this.tileExtension,
    required this.sourceName,
    required this.tileSize,
    this.minZoomLevel = 2,
    this.maxZoomLevel = 19,
  })  : assert(urlsServers.isNotEmpty),
        assert(
          urlsServers.where((element) => element.isEmpty).isEmpty,
        ),
        assert(minZoomLevel < maxZoomLevel),
        assert(minZoomLevel >= 2 && minZoomLevel < maxZoomLevel),
        assert(maxZoomLevel > minZoomLevel && maxZoomLevel > 0);

  Map toMap() => {
        "name": sourceName,
        "urls": urlsServers,
        "tileSize": tileSize,
        "tileExtension": tileExtension,
        "maxZoomLevel": maxZoomLevel,
        "minZoomLevel": minZoomLevel,
      };
}

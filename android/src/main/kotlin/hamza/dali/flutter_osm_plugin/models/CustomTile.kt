package hamza.dali.flutter_osm_plugin.models

data class CustomTile(
    val urls: List<String>,
    val tileFileExtension: String,
    val sourceName: String,
    val tileSize: Int,
    val minZoomLevel: Int,
    val maxZoomLevel: Int,
)

fun fromMapToCustomTile(map: HashMap<String, Any>): CustomTile = CustomTile(
    urls = map["urls"] as List<String>,
    sourceName = map["name"] as String,
    tileFileExtension = map["tileExtension"] as String,
    tileSize = map["tileSize"] as Int,
    minZoomLevel = map["minZoomLevel"] as Int,
    maxZoomLevel = map["maxZoomLevel"] as Int,
)
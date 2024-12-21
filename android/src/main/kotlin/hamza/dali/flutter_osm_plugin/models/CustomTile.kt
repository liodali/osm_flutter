package hamza.dali.flutter_osm_plugin.models

sealed class OSMTile

data class CustomTile(
    val urls: List<String>,
    val tileFileExtension: String,
    val sourceName: String,
    val tileSize: Int,
    val minZoomLevel: Int,
    val maxZoomLevel: Int,
    val api: Pair<String, String>?
) : OSMTile() {
    companion object {
        fun fromMap(map: HashMap<*, *>): CustomTile {
            return fromMapToCustomTile(map)
        }
    }
}
data class VectorOSMTile(
    val style: String,
) : OSMTile()

fun fromMapToCustomTile(map: HashMap<*, *>): CustomTile = CustomTile(
    urls = (map["urls"] as List<*>).first() as List<String>,
    sourceName = map["name"] as String,
    tileFileExtension = map["tileExtension"] as String,
    tileSize = map["tileSize"] as Int,
    minZoomLevel = map["minZoomLevel"] as Int,
    maxZoomLevel = map["maxZoomLevel"] as Int,
    api = when {
        map.contains("api") -> Pair(
            (map["api"] as HashMap<*, *>).entries.first().key as String,
            (map["api"] as HashMap<*, *>).entries.first().value as String
        )

        else -> null
    }
)
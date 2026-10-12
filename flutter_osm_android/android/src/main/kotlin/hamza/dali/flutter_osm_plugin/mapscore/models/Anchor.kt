package hamza.dali.flutter_osm_plugin.mapscore.models

data class Anchor(val x: Float, val y: Float) {
    private var offset: Pair<Double, Double>? = null

    constructor(map: HashMap<String, Any>) : this(
        (map["x"]!! as Double).toFloat(),
        (map["y"]!! as Double).toFloat()
    ) {
        if (map.containsKey("offset")) {
            val offsetMap = map["offset"]!! as HashMap<String, Double>
            offset = Pair(offsetMap["x"]!!, offsetMap["y"]!!)
        }
    }

    fun offset() = offset
}

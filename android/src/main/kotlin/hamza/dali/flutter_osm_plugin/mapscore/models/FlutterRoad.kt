package hamza.dali.flutter_osm_plugin.mapscore.models

import io.openmobilemaps.mapscore.shared.map.coordinates.Coord
import io.openmobilemaps.mapscore.shared.map.layers.line.LineInfoInterface
import io.openmobilemaps.mapscore.shared.map.layers.line.LineLayerInterface

/**
 * mapscore counterpart of [hamza.dali.flutter_osm_plugin.models.FlutterRoad].
 *
 * A road is rendered as one or two [LineInfoInterface] entries inside a shared
 * [LineLayerInterface]: an optional wider border line drawn under the main line.
 */
class FlutterRoad(
    val idRoad: String,
    val roadDuration: Double,
    val roadDistance: Double,
    private val lineLayer: LineLayerInterface,
) {
    private var borderLine: LineInfoInterface? = null
    private var mainLine: LineInfoInterface? = null
    private var roadCoords: List<Coord> = emptyList()

    var onRoadClickListener: OnRoadClickListener? = null

    val coordinates: List<Coord> get() = roadCoords

    interface OnRoadClickListener {
        fun onClick(road: FlutterRoad)
    }

    fun setRoad(
        coords: List<Coord>,
        border: LineInfoInterface?,
        main: LineInfoInterface,
    ) {
        remove()
        roadCoords = coords
        borderLine = border
        mainLine = main
        border?.let { lineLayer.add(it) }
        lineLayer.add(main)
    }

    fun remove() {
        borderLine?.let { lineLayer.remove(it) }
        mainLine?.let { lineLayer.remove(it) }
        borderLine = null
        mainLine = null
    }

    fun matches(line: LineInfoInterface): Boolean =
        mainLine?.getIdentifier() == line.getIdentifier() || borderLine?.getIdentifier() == line.getIdentifier()
}

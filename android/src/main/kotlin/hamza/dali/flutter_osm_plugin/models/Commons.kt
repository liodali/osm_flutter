package hamza.dali.flutter_osm_plugin.models

import org.osmdroid.api.IGeoPoint
import org.osmdroid.util.BoundingBox

typealias VoidCallback = () -> Unit

typealias OnClickSymbols = (IGeoPoint) -> Unit
typealias OnMapMove = (BoundingBox, IGeoPoint) -> Unit
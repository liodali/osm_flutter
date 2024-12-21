package hamza.dali.flutter_osm_plugin.models

import hamza.dali.flutter_osm_plugin.utilities.encodePolyline
import hamza.dali.flutter_osm_plugin.utilities.toPolylineEncode
import org.maplibre.android.plugins.annotation.Line
import org.maplibre.android.plugins.annotation.LineManager
import org.maplibre.android.plugins.annotation.OnLineClickListener
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.overlay.FolderOverlay
import org.osmdroid.views.overlay.Polyline

sealed interface FlutterRoad {
    val idRoad: String

    interface OnRoadClickListener {
        fun onClick(idRoad: String, lineId: String, lineDecoded: String)
    }
}

open class FlutterMapLibreOSMRoad(
    override val idRoad: String,
    val lineManager: LineManager
) : FlutterRoad {
    companion object {
        val DashPoly = arrayOf(1f, 1.5f)
    }

    var onRoadClickListener: FlutterRoad.OnRoadClickListener? = null
    private val lines: MutableList<Line> = mutableListOf()
    private val linesIdPair: MutableList<Pair<Long, String>> = mutableListOf()

    fun addSegment(
        id: String,
        polyline: List<GeoPoint>,
        polylineOption: RoadOption,
        isBorder: Boolean = false
    ) {
        val lineOptions = polylineOption.toLineOption(polyline = polyline.toLngLats(), isBorder)
        when {
            polylineOption.isDotted && !isBorder -> {
                lineManager.lineDasharray = DashPoly
                lineManager.lineRoundLimit = 12f
            }
            else -> {
                lineManager.lineDasharray = emptyArray<Float>()
                lineManager.lineRoundLimit = 1f
            }
        }

        val line = lineManager.create(lineOptions)
        lineManager.updateSource()
        linesIdPair.add(Pair(line.id, id))
        lineManager.addClickListener(object : OnLineClickListener {
            override fun onAnnotationClick(t: Line?): Boolean {
                if (t != null && lines.contains(t)) {
                    this@FlutterMapLibreOSMRoad.onRoadClickListener?.onClick(
                        idRoad,
                        linesIdPair.first { it.first == t.id }.second,
                        t.latLngs.encodePolyline()
                    )
                }
                return true
            }
        })
        lines.add(line)
    }

    fun remove() {
        lineManager.delete(lines)
        lineManager.updateSource()
    }
}

abstract class FlutterOSMRoadFolder : FolderOverlay(), FlutterRoad
open class FlutterOSMRoad(
    override val idRoad: String,
) : FlutterOSMRoadFolder() {
    private val segments: MutableList<Polyline> = mutableListOf()
    val roadSegments = segments.toList()
    var onRoadClickListener: FlutterRoad.OnRoadClickListener? = null
    fun addSegment(seg: Polyline) {
        seg.id = "${idRoad}-seg-${segments.size + 1}"
        seg.setOnClickListener { poly, _, geoPointClicked ->
            val arrays = java.util.ArrayList<GeoPoint>(poly.actualPoints.size)
            arrays.addAll(poly.actualPoints)
            val encoded = poly.actualPoints.toPolylineEncode()
            onRoadClickListener?.onClick(idRoad, seg.id, encoded)
            true
        }
        segments.add(seg)

    }


}

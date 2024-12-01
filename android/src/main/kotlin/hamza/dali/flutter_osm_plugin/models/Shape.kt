package hamza.dali.flutter_osm_plugin.models

import android.graphics.Color
import android.graphics.Paint
import hamza.dali.flutter_osm_plugin.utilities.toARGB
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Polygon

enum class Shape {
    CIRCLE, POLYGON

}

class OSMShape(val args: HashMap<*, *>, map: MapView) : Polygon(map) {

     val shape: Shape = when {
        args.containsKey("radius") -> Shape.CIRCLE
        else -> Shape.POLYGON
    }

    init {
        val geoPoint = GeoPoint(args["lat"]!! as Double, args["lon"]!! as Double)
        val key = args["key"] as String
        val colorRgb = args["color"] as List<*>

        val stokeWidth = (args["strokeWidth"] as Double).toFloat()
        val colorBorder = when (args.contains("colorBorder")) {
            true -> (args["colorBorder"] as List<*>).filterIsInstance<Int>().toARGB()

            else -> null
        }
        val colorFillPaint = colorRgb.filterIsInstance<Int>().toARGB()

        val shapeGeos: List<GeoPoint> = when (shape) {
            Shape.POLYGON -> {
                val distance = (args["distance"] as Double)
                pointsAsRect(geoPoint, distance, distance).toList().filterIsInstance<GeoPoint>()
            }

            else -> {
                val radius = (args["radius"] as Double)
                pointsAsCircle(geoPoint, radius)
            }
        }
        id = key
        points = shapeGeos
        fillPaint.color = colorFillPaint
        fillPaint.style = Paint.Style.FILL
        //p.fillPaint.alpha = 50
        outlinePaint.strokeWidth = stokeWidth
        outlinePaint.color = colorBorder ?: colorFillPaint
        setOnClickListener { polygon, _, _ ->
            polygon.closeInfoWindow()
            false
        }
    }


    fun drawShape(){

    }
}
package hamza.dali.flutter_osm_plugin.models

import android.graphics.Color
import android.graphics.Paint
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
            true -> {
                val rgb = args["colorBorder"] as List<*>
                Color.argb(
                    Integer.parseInt(rgb[3].toString()),
                    Integer.parseInt(rgb[0].toString()),
                    Integer.parseInt(rgb[1].toString()),
                    Integer.parseInt(rgb[2].toString()),
                )
            }

            else -> null
        }
        val colorFillPaint = Color.argb(
            Integer.parseInt(colorRgb[3].toString()),
            Integer.parseInt(colorRgb[0].toString()),
            Integer.parseInt(colorRgb[1].toString()),
            Integer.parseInt(colorRgb[2].toString()),
        )

        val shapeGeos: List<GeoPoint> = when (shape) {
            Shape.POLYGON -> {
                val distance = (args["distance"] as Double)
                pointsAsRect(geoPoint, distance, distance).toList() as List<GeoPoint>
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
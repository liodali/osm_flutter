package hamza.dali.flutter_osm_plugin.map

import android.graphics.Bitmap
import hamza.dali.flutter_osm_plugin.models.Anchor
import hamza.dali.flutter_osm_plugin.models.FlutterGeoPoint
import hamza.dali.flutter_osm_plugin.models.OSMTile
import hamza.dali.flutter_osm_plugin.models.RoadOption
import hamza.dali.flutter_osm_plugin.models.Shape
import hamza.dali.flutter_osm_plugin.models.VectorOSMTile
import hamza.dali.flutter_osm_plugin.models.toRoadOption
import hamza.dali.flutter_osm_plugin.utilities.toBitmap
import hamza.dali.flutter_osm_plugin.utilities.toGeoPoint
import org.osmdroid.api.IGeoPoint
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import kotlin.collections.get


data class OSMInitConfiguration(
    val point: GeoPoint,
    val minZoom: Double = 3.0,
    val maxZoom: Double = 19.0,
    val zoomStep: Double = 1.0,
    val initZoom: Double = 10.0,
    val bounds: BoundingBox? = null,
    val customTile: OSMTile? = null,
) {
    companion object {
        fun fromMap(args: HashMap<String, Any>): OSMInitConfiguration {

            val point = when {
                args.contains("point") -> (args["point"] as HashMap<String, Double>).toGeoPoint()
                else -> GeoPoint(0.0, 0.0)
            }
            val minZoom = when {
                args.contains("minZoom") -> args["minZoom"] as Double
                else -> 3.0
            }
            val maxZoom = when {
                args.contains("maxZoom") -> args["maxZoom"] as Double
                else -> 19.0
            }
            val zoomStep = when {
                args.contains("zoomStep") -> args["zoomStep"] as Double
                else -> 1.0
            }
            val initZoom = when {
                args.contains("initZoom") -> args["initZoom"] as Double
                else -> 10.0
            }
            val bounds = when {
                args.contains("bounds") -> {
                    val boundsArgs = args["bounds"] as HashMap<String, Double>
                    BoundingBox.fromGeoPoints(
                        arrayOf(
                            GeoPoint(
                                boundsArgs["north"] as Double,
                                boundsArgs["east"] as Double,
                            ),
                            GeoPoint(
                                boundsArgs["south"] as Double,
                                boundsArgs["west"] as Double,
                            ),
                        ).toMutableList()
                    )
                }

                else -> BoundingBox()
            }
            val customTile = when {
                args.contains("vectorURL") -> VectorOSMTile(args["vectorURL"] as String)
                else -> null
            }

            return OSMInitConfiguration(
                point,
                bounds = bounds,
                minZoom = minZoom,
                maxZoom = maxZoom,
                zoomStep = zoomStep,
                initZoom = initZoom,
                customTile = customTile
            )
        }
    }
}

data class OSMZoomConfiguration(
    val minZoom: Double = 3.0,
    val maxZoom: Double = 19.0,
    val zoomStep: Double = 1.0,
    val initZoom: Double = 10.0,
)

data class OSMShapeConfiguration(
    val point: List<GeoPoint>,
    val radius: Double,
    val shape: Shape,
    val color: String,
    val colorBorder: String,
    val strokeWidth: Double
)

@Suppress("UNCHECKED_CAST")
data class MarkerConfiguration(
    val markerIcon: Bitmap,
    val markerRotate: Double,
    val markerAnchor: Anchor,
    val factorSize: Double,
) {
    companion object {
        fun fromArgs(args: HashMap<*, *>, defaultIcon: Bitmap?): MarkerConfiguration {

            var iconBitmap = defaultIcon
            if (args.containsKey("icon")) {
                iconBitmap = (args["icon"] as ByteArray).toBitmap()

            }
            val angle = when ((args["point"] as HashMap<*, *>).containsKey("angle")) {
                true -> (args["point"] as HashMap<*, *>)["angle"] as Double
                else -> 0.0
            }
            val anchor = when (args.containsKey("iconAnchor")) {
                true -> Anchor(args["iconAnchor"] as HashMap<String, Any>)
                else -> Anchor(0.5f, 0.5f)
            }
            val factorSize = when (args.containsKey("factorSize")) {
                true -> args["factorSize"] as Double
                else -> 1.8
            }
            return MarkerConfiguration(
                markerIcon = iconBitmap!!,
                angle,
                anchor,
                factorSize
            )
        }
    }
}

data class OSMRoadConfiguration(
    val id: String,
    val linesConfig: List<OSMLineConfiguration>,
    val zoomInto: Boolean
) {
    companion object {

        fun fromArgs(args: HashMap<*, *>): OSMRoadConfiguration {
            val zoomToRegion = args["zoomIntoRegion"] as Boolean

            return OSMRoadConfiguration(
                id = args["key"] as String,
                zoomInto = zoomToRegion,
                linesConfig = when (args.contains("segments") && args["segments"] is List<*>) {
                    true -> (args["segments"] as List<*>).map { arg ->
                        OSMLineConfiguration.fromArgs(arg as HashMap<*, *>)
                    }

                    else -> emptyList()
                }
            )
        }
    }
}

data class OSMLineConfiguration(
    val encodedPolyline: String,
    val roadOption: RoadOption
) {
    companion object {

        fun fromArgs(args: HashMap<*, *>): OSMLineConfiguration {
            return OSMLineConfiguration(
                encodedPolyline = args["polylineEncoded"] as String,
                roadOption = when (args.contains("option") && args["option"] is HashMap<*, *>) {
                    true -> (args["option"] as HashMap<*, *>).toRoadOption()
                    else -> RoadOption()
                }
            )
        }
    }
}

interface OSMBase : OSM {
    var customMarkerIcon: Bitmap?
    var staticMarkerIcon: HashMap<String, Bitmap>
    val staticPoints: HashMap<String, MutableList<FlutterGeoPoint>>
    fun init(configuration: OSMInitConfiguration)
    fun zoomConfig(zoomConfig: OSMZoomConfiguration)
    fun setBoundingBox(bounds: BoundingBox)
    fun moveTo(point: IGeoPoint, zoom: Double? = null, animate: Boolean)
    fun moveToBounds(bounds: BoundingBox, padding:Int, animate: Boolean)
    fun addMarker(point: IGeoPoint, markerConfiguration: MarkerConfiguration)
    fun removeMarker(point: IGeoPoint)
    fun setStaticMarkerIcons(id: String, icon: ByteArray, factorSize: Double?)
    fun setStaticMarkers(id: String, markers: List<FlutterGeoPoint>)
    fun drawPolyline(road: OSMRoadConfiguration, animate: Boolean): String
    fun updatePolyline(road: OSMRoadConfiguration)
    fun removePolyline(id: String)
    fun addShape(shapeConfiguration: OSMShapeConfiguration): String
    fun removeShape(id: String)
    fun zoomIn(step: Int, animate: Boolean)
    fun zoomOut(step: Int, animate: Boolean)
    fun setZoomLevel(zoomLevel: Double, animate: Boolean)
    fun zoom(): Double
    fun center(): IGeoPoint
    fun markers(): List<IGeoPoint>
    fun bounds(): BoundingBox
    fun startLocation()
    fun stopLocation()
    fun onMapClick(onClick: (IGeoPoint) -> Unit)
    fun onMapMove(onMove: (BoundingBox, IGeoPoint) -> Unit)
    fun onUserLocationChanged(onUserLocationChanged: (IGeoPoint) -> Unit)
    fun onMarkerSingleClick(onClick: (IGeoPoint) -> Unit)
    fun onMarkerLongClick(onClick: (IGeoPoint) -> Unit)
    fun onPolylineClick(onClick: (IGeoPoint, polylineId: String) -> Unit)
}
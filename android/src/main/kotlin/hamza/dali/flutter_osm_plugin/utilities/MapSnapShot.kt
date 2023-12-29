package hamza.dali.flutter_osm_plugin.utilities

import hamza.dali.flutter_osm_plugin.FlutterOsmView
import hamza.dali.flutter_osm_plugin.models.FlutterGeoPoint
import hamza.dali.flutter_osm_plugin.models.RoadGeoPointInstruction
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint

class MapSnapShot {
    private var customPersonMarkerIcon: ByteArray? = null
    private var customArrowMarkerIcon: ByteArray? = null
    private var staticPointsIcons = HashMap<String, ByteArray>()
    private var staticPoints: HashMap<String, Pair<List<GeoPoint>, List<Double>>> = HashMap()
    private var centerMap: GeoPoint? = null
    private var boundingWorldBox: BoundingBox = FlutterOsmView.boundingWorldBox

    private var lastRoadCache: RoadSnapShot? = null
    private var roadsCache: MutableList<RoadSnapShot> = emptyList<RoadSnapShot>().toMutableList()
    private var zoom: Double? = null
    private var isAdvancedPicker: Boolean = false
    private var isTrackMe: Boolean = false
    private var enableLocation: Boolean = false
    private var disableRotation: Boolean = false
    private var mapOrientation: Float = 0f

    private var markers: MutableList<FlutterGeoPoint> = emptyList<FlutterGeoPoint>().toMutableList()
    //ArrayMap<GeoPoint, HashMap<String, Any>>()//ByteArray?

    fun advancedPicker() = isAdvancedPicker
    fun centerGeoPoint() = centerMap
    fun boundingWorld() = boundingWorldBox
    fun zoomLevel(initZoom: Double) = zoom ?: initZoom
    fun markers() = markers
    fun staticGeoPoints() = staticPoints
    fun staticGeoPointsIcons() = staticPointsIcons
    fun addToStaticGeoPoints(id: String, value: Pair<List<GeoPoint>, List<Double>>) {
        staticPoints[id] = value
    }

    fun addToIconsStaticGeoPoints(id: String, value: ByteArray) {
        staticPointsIcons[id] = value
    }

    fun saveMapOrientation(orientation: Float) {
        mapOrientation = orientation
    }

    fun getEnableMyLocation() = enableLocation
    fun getDisableRotation() = disableRotation
    fun trackMyLocation() = isTrackMe
    fun lastCachedRoad() = lastRoadCache
    fun cachedRoads() = roadsCache
    fun mapOrientation() = mapOrientation
    fun clearCachedRoad() {
        lastRoadCache = null
    }

    fun clearListCachedRoad() {
        roadsCache.clear()
    }

    fun setBoundingWorld(box: BoundingBox) {
        this.boundingWorldBox = box
    }

    fun cacheRoad(road: RoadSnapShot) {
        lastRoadCache = road
    }

    fun cacheListRoad(road: RoadSnapShot) {
        roadsCache.add(road)
    }


    fun setTrackLocation(isTracking: Boolean) {
        isTrackMe = isTracking
    }

    fun setEnableMyLocation(isEnabled: Boolean, disableRotation: Boolean = false) {
        enableLocation = isEnabled
        this.disableRotation = disableRotation
    }

    fun cacheLocation(
        geoPoint: GeoPoint,
        zoom: Double,
    ) {
        centerMap = geoPoint
        this.zoom = zoom
    }

    fun setUserTrackMarker(
        personMarker: ByteArray?, arrowMarker: ByteArray?
    ) {
        this.customPersonMarkerIcon = personMarker
        this.customArrowMarkerIcon = arrowMarker
    }

    fun getPersonUserTrackMarker() = this.customPersonMarkerIcon
    fun getArrowDirectionTrackMarker() = this.customArrowMarkerIcon


    fun cache(
        geoPoint: GeoPoint,
        zoom: Double,
    ) {
        centerMap = geoPoint
        this.zoom = zoom

    }

    fun setAdvancedPicker(isActive: Boolean) {
        isAdvancedPicker = isActive
    }

    fun overlaySnapShotMarker(
        point: FlutterGeoPoint,
        oldPoint: GeoPoint? = null,
    ) {/*markers[point] = HashMap<String, Any>().apply {
            this["icon"] = icon
        }*/
        when {
            !markers.contains(point) -> markers.add(point)
            else -> {
                markers[markers.indexOf(point)] = point
            }
        }
        oldPoint?.let { old ->
            markers.removeIf { m -> m.geoPoint == old }

        }
    }

    fun removeMarkersFromSnapShot(removedPoints: List<GeoPoint>) {
        markers.removeIf { m -> removedPoints.contains(m.geoPoint) }
    }

    fun reset(all: Boolean = false) {
        if (all) {
            centerMap = null
            zoom = null
            markers.clear()
            staticPoints.clear()
            isAdvancedPicker = false
            isTrackMe = false
            enableLocation = false
            disableRotation = false
            lastRoadCache = null
            roadsCache.clear()
        }
        customPersonMarkerIcon = null
        customArrowMarkerIcon = null
    }

}

data class RoadSnapShot(
    val roadPoints: List<GeoPoint>,
    val roadColor: Int?,
    val roadBorderColor: Int?,
    val roadWidth: Float,
    val roadBorderWidth: Float,
    val roadID: String,
    val duration: Double,
    val distance: Double,
    val instructions: List<RoadGeoPointInstruction>
)
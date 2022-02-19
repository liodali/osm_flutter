package hamza.dali.flutter_osm_plugin.utilities

import android.util.ArrayMap
import hamza.dali.flutter_osm_plugin.FlutterOsmView
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint

class MapSnapShot {
    private var customPersonMarkerIcon: ByteArray? = null
    private var customArrowMarkerIcon: ByteArray? = null
    private var customPickerMarkerIcon: ByteArray? = null
    private var customRoadMarkerIcon = HashMap<String, ByteArray>()
    private var staticPointsIcons = HashMap<String, ByteArray>()
    private var staticPoints: HashMap<String, Pair<List<GeoPoint>, List<Double>>> =
        HashMap()
    private var centerMap: GeoPoint? = null
    private var boundingWorldBox: BoundingBox = FlutterOsmView.boundingWorldBox

    private var lastRoadCache: RoadSnapShot? = null
    private var roadsCache: MutableList<RoadSnapShot> = emptyList<RoadSnapShot>().toMutableList()
    private var zoom: Double? = null
    private var isAdvancedPicker: Boolean = false
    private var isTrackMe: Boolean = false
    private var enableLocation: Boolean = false
    private var mapOrientation: Float = 0f

    private var markers: ArrayMap<GeoPoint, ByteArray?> = ArrayMap<GeoPoint, ByteArray?>()

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

    fun setEnableMyLocation(isEnabled: Boolean) {
        enableLocation = isEnabled
    }

    fun cacheLocation(
        geoPoint: GeoPoint,
        zoom: Double,
    ) {
        centerMap = geoPoint
        this.zoom = zoom
    }

    fun setUserTrackMarker(
        personMarker: ByteArray?,
        arrowMarker: ByteArray?
    ) {
        this.customPersonMarkerIcon = personMarker
        this.customArrowMarkerIcon = arrowMarker
    }

    fun getPersonUserTrackMarker() = this.customPersonMarkerIcon
    fun getArrowDirectionTrackMarker() = this.customArrowMarkerIcon


    fun cache(
        geoPoint: GeoPoint,
        zoom: Double,
        customRoadMarkerIcon: HashMap<String, ByteArray>,
        customPickerMarkerIcon: ByteArray?,
    ) {
        centerMap = geoPoint
        this.zoom = zoom
        this.customRoadMarkerIcon = customRoadMarkerIcon
        this.customPickerMarkerIcon = customPickerMarkerIcon
    }

    fun setAdvancedPicker(isActive: Boolean) {
        isAdvancedPicker = isActive
    }

    fun overlaySnapShotMarker(point: GeoPoint, icon: ByteArray) {
        markers[point] = icon
    }

    fun removeMarkersFromSnapShot(removedPoints: List<GeoPoint>) {
        val geoPoints = markers.filter { geo ->
            removedPoints.containGeoPoint(geo.key)
        }.keys
        markers.removeAll(geoPoints)
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
            lastRoadCache = null
            roadsCache.clear()
        }
        customRoadMarkerIcon.clear()
        customPersonMarkerIcon = null
        customArrowMarkerIcon = null
        customPickerMarkerIcon = null
    }

}

data class RoadSnapShot(
    val roadPoints: List<GeoPoint>,
    val showIcons: Boolean,
    val roadColor: Int?,
    val roadWith: Float,
    val listInterestPoints: List<GeoPoint> = emptyList(),
)
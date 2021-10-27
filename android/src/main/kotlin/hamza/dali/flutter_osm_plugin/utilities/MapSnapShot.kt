package hamza.dali.flutter_osm_plugin.utilities

import android.util.ArrayMap
import org.osmdroid.util.GeoPoint

class MapSnapShot {
    private var customPersonMarkerIcon: ByteArray? = null
    private var customArrowMarkerIcon: ByteArray? = null
    private var customPickerMarkerIcon: ByteArray? = null
    private var customRoadMarkerIcon = HashMap<String, ByteArray>()
    private var staticPoints: HashMap<String, Triple<List<GeoPoint>, List<Double>, ByteArray?>> =
        HashMap()
    private var centerMap: GeoPoint? = null

    private var zoom: Double? = null
    private var isAdvancedPicker: Boolean = false
    private var isTrackMe: Boolean = false
    private var enableLocation: Boolean = false

    private var markers: ArrayMap<GeoPoint, ByteArray?> = ArrayMap<GeoPoint, ByteArray?>()

    fun advancedPicker() = isAdvancedPicker
    fun centerGeoPoint() = centerMap
    fun zoomLevel(initZoom: Double) = zoom ?: initZoom
    fun markers() = markers
    fun staticGeoPoints() = staticPoints
    fun addToStaticGeoPoints(id: String, value: Triple<List<GeoPoint>, List<Double>, ByteArray?>) {
        staticPoints[id] = value
    }

    fun getEnableMyLocation() = enableLocation
    fun trackMyLocation() = isTrackMe

    fun setTrackLocation(isTracking: Boolean) {
        isTrackMe = isTracking
    }

    fun setEnableMyLocation(isEnabled: Boolean) {
        enableLocation = isEnabled
    }

    fun cache(
        geoPoint: GeoPoint,
        zoom: Double,
        customRoadMarkerIcon: HashMap<String, ByteArray>,
        customPersonMarkerIcon: ByteArray?,
        customArrowMarkerIcon: ByteArray?,
        customPickerMarkerIcon: ByteArray?,
    ) {
        centerMap = geoPoint
        this.zoom = zoom
        this.customRoadMarkerIcon = customRoadMarkerIcon
        this.customPersonMarkerIcon = customPersonMarkerIcon
        this.customArrowMarkerIcon = customArrowMarkerIcon
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
        }
        customRoadMarkerIcon.clear()
        customPersonMarkerIcon = null
        customArrowMarkerIcon = null
        customPickerMarkerIcon = null
    }

}
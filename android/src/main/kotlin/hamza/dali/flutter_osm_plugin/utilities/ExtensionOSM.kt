package hamza.dali.flutter_osm_plugin.utilities

import android.app.Activity
import android.content.Intent
import android.provider.Settings
import hamza.dali.flutter_osm_plugin.FlutterOsmView
import org.osmdroid.tileprovider.MapTileProviderBasic
import org.osmdroid.tileprovider.tilesource.ITileSource
import org.osmdroid.tileprovider.tilesource.OnlineTileSourceBase
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import org.osmdroid.util.MapTileIndex
import org.osmdroid.views.MapView


fun GeoPoint.toHashMap(): HashMap<String, Double> {
    return HashMap<String, Double>().apply {
        this[Constants.latLabel] = latitude
        this[Constants.lonLabel] = longitude
    }

}

fun GeoPoint.eq(other: GeoPoint): Boolean {
    return this.latitude == other.latitude && this.longitude == other.longitude
}

fun HashMap<String, Double>.toGeoPoint(): GeoPoint {
    if (this.keys.contains("lat") && this.keys.contains("lon")) {
        return GeoPoint(this["lat"]!!, this["lon"]!!)
    }
    throw IllegalArgumentException("cannot map this hashMap to GeoPoint")

}

fun List<GeoPoint>.containGeoPoint(point: GeoPoint): Boolean {
    return this.firstOrNull { p ->
        p.eq(point)
    } != null
}

fun BoundingBox.isWorld(): Boolean {
    return this.latNorth == 85.0 && this.latSouth == -85.0
            && this.lonEast == 180.0
            && this.lonWest == -180.0
}

fun BoundingBox.toHashMap(): HashMap<String, Double> {
    return HashMap<String, Double>().apply {
        this["north"] = latNorth
        this["east"] = lonEast
        this["south"] = latSouth
        this["west"] = lonWest
    }

}

fun FlutterOsmView.openSettingLocation(requestCode: Int, activity: Activity?) {
    val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
    activity?.startActivityForResult(intent, requestCode)
}

fun MapView.setCustomTile(
        name: String,
        minZoomLvl: Int = 1,
        maxZoomLvl: Int = 19,
        tileSize: Int = 256,
        tileExtensionFile: String = ".png",
        baseURLs: Array<String>,
        api: Pair<String, String>?
) {
    //val imageEndingTile = tileExtensionFile

    val tileSource: ITileSource = object : OnlineTileSourceBase(
            name,
            minZoomLvl,
            maxZoomLvl,
            tileSize,
            tileExtensionFile,
            baseURLs
    ) {
        override fun getTileURLString(pMapTileIndex: Long): String {
            val url = baseUrl + MapTileIndex.getZoom(pMapTileIndex) + "/" + MapTileIndex.getX(
                    pMapTileIndex
            ) + "/" + MapTileIndex.getY(pMapTileIndex) + mImageFilenameEnding
            val key = when {
                api != null -> "?${api.first}=${api.second}"
                else -> ""
            }
            return url + key
        }

    }

    this.setTileSource(tileSource)
}

fun MapView.resetTileSource() {
    //val imageEndingTile = tileExtensionFile
    if (tileProvider.tileSource != TileSourceFactory.DEFAULT_TILE_SOURCE){
        this.setTileSource(TileSourceFactory.DEFAULT_TILE_SOURCE)
    }
}

package hamza.dali.flutter_osm_plugin.maplibre

import androidx.collection.LongSparseArray
import androidx.collection.forEach
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.plugins.annotation.Symbol
import org.osmdroid.api.IGeoPoint
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint

fun IGeoPoint.toLngLat(): LatLng = LatLng(latitude = latitude, longitude = longitude)
fun LatLng.toGeoPoint(): IGeoPoint = GeoPoint(latitude, longitude)
fun BoundingBox.toBoundsLibre(): LatLngBounds = LatLngBounds.fromLatLngs(
    arrayOf(
        LatLng(latNorth, lonEast),
        LatLng(latSouth, lonWest)
    ).toList()
)
fun LatLngBounds.toBoundingBox(): BoundingBox = BoundingBox.fromGeoPoints(
    this.toLatLngs().toGeoPoints()
)
fun Array<LatLng>.toGeoPoints(): List<IGeoPoint> {
   return map {
        it.toGeoPoint()
    }.toList()
}
fun LongSparseArray<Symbol>.where(f: (Symbol) -> Boolean): Symbol? {
    this.forEach { k, symbol ->
        if (f(symbol)) {
            return symbol
        }
    }

    return null
}
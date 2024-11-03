package hamza.dali.flutter_osm_plugin.models

import androidx.collection.LongSparseArray
import androidx.collection.forEach
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.plugins.annotation.Symbol
import org.maplibre.android.plugins.annotation.SymbolOptions
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

fun List<FlutterGeoPoint>.toSymbols(iconId: String): List<SymbolOptions> {
    return map {
        SymbolOptions().withLatLng(it.geoPoint.toLngLat())
            .withIconRotate(it.angle.toFloat())
            .withIconImage(iconId)
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

fun LongSparseArray<Symbol>.toList(): List<Symbol> {
    val list = mutableListOf<Symbol>()
    this.forEach { k, symbol ->
        list.add(symbol)
    }

    return list.toList()
}
fun LongSparseArray<Symbol>.toGeoPoints(): List<IGeoPoint> {
    val list = mutableListOf<IGeoPoint>()
    this.forEach { k, symbol ->
        list.add(symbol.latLng.toGeoPoint())
    }

    return list.toList()
}

fun List<Symbol>.toGeoPoints(): List<IGeoPoint> = map {
    it.latLng.toGeoPoint()
}
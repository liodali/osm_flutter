package hamza.dali.flutter_osm_plugin.models

import android.graphics.Color
import androidx.collection.LongSparseArray
import androidx.collection.forEach
import hamza.dali.flutter_osm_plugin.map.OSMLineConfiguration
import hamza.dali.flutter_osm_plugin.utilities.setStyle
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.plugins.annotation.Symbol
import org.maplibre.android.plugins.annotation.SymbolOptions
import org.osmdroid.api.IGeoPoint
import org.osmdroid.bonuspack.utils.PolylineEncoder
import org.osmdroid.util.BoundingBox
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.overlay.Polyline
import kotlin.collections.get

fun IGeoPoint.toLngLat(): LatLng = LatLng(latitude = latitude, longitude = longitude)
fun List<IGeoPoint>.toLngLats(): List<LatLng> =
    map { gp -> gp.toLngLat() }

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
fun Collection<LatLng>.toGeoPoints(): List<GeoPoint> {
    return map {
        it.toGeoPoint() as GeoPoint
    }.toList()
}
fun Collection<LatLng>.toArrayGeoPoints(): java.util.ArrayList<GeoPoint> {
    return map {
        it.toGeoPoint() as GeoPoint
    }.toList().toCollection(java.util.ArrayList())
}
fun Collection<GeoPoint>.toArrayLatLng(): java.util.ArrayList<LatLng> {
    return toList().toLngLats().toCollection(java.util.ArrayList())
}
fun List<FlutterGeoPoint>.toSymbols(iconId: String): List<SymbolOptions> {
    return map { fGp ->
        SymbolOptions().withLatLng(fGp.geoPoint.toLngLat())
            .withIconRotate(fGp.angle.toFloat())
            .withIconImage(iconId)
            .withIconSize(fGp.factorSize.toFloat())
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

//fun LongSparseArray<Symbol>.toList(): List<Symbol> {
//    val list = mutableListOf<Symbol>()
//    this.forEach { k, symbol ->
//        list.add(symbol)
//    }
//    return list.toList()
//}
 fun <T>  LongSparseArray<T>.toList(): List<T> {
    val list = mutableListOf<T>()
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

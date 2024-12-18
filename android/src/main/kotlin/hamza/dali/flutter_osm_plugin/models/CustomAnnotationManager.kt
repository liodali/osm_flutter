package hamza.dali.flutter_osm_plugin.models

import com.google.gson.JsonObject
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import org.maplibre.android.plugins.annotation.Line
import org.maplibre.android.plugins.annotation.CircleManager
import org.maplibre.android.plugins.annotation.FillManager
import org.maplibre.android.plugins.annotation.LineManager
import org.maplibre.android.plugins.annotation.LineOptions
import org.maplibre.android.plugins.annotation.Symbol
import org.maplibre.android.plugins.annotation.SymbolManager
import org.maplibre.android.plugins.annotation.SymbolOptions
import org.maplibre.android.style.layers.PropertyValue
import org.maplibre.geojson.LineString


class CustomLineManager(
    mapView: MapView,
    mapLibre: MapLibreMap,
    style: Style,
    belowLayerId: String?,
    aboveLayerId: String?,
) :
    LineManager(mapView, mapLibre, style, belowLayerId, aboveLayerId) {
    fun toggle(toggle: Boolean) {
        layer.setProperties(PropertyValue<String>("visibility", "$toggle"))
    }


    override fun create(options: LineOptions?): Line? {
        val line = super.create(options)


        return line
    }
    fun test(){
        annotations[0]
    }
}

class CustomSymbolManager(
    mapView: MapView,
    mapLibre: MapLibreMap,
    style: Style,
    belowLayerId: String? = null,
    aboveLayerId: String? = null,
) :
    SymbolManager(mapView, mapLibre, style, belowLayerId, aboveLayerId) {
    fun toggle(toggle: Boolean) {
        layer.setProperties(PropertyValue<String>("visibility", "$toggle"))
    }

}

class CustomFillManager(
    mapView: MapView,
    mapLibre: MapLibreMap,
    style: Style,
    belowLayerId: String?,
    aboveLayerId: String?,
) :
    FillManager(mapView, mapLibre, style, belowLayerId, aboveLayerId) {
    fun toggle(toggle: Boolean) {
        layer.setProperties(PropertyValue<String>("visibility", "$toggle"))
    }
}

class CustomCircleManager(
    mapView: MapView,
    mapLibre: MapLibreMap,
    style: Style,
    belowLayerId: String?,
    aboveLayerId: String?,
) :
    CircleManager(mapView, mapLibre, style, belowLayerId, aboveLayerId) {
    fun toggle(toggle: Boolean) {
        layer.setProperties(PropertyValue<String>("visibility", "$toggle"))
    }
}


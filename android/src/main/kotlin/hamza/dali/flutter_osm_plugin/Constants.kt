package hamza.dali.flutter_osm_plugin

import android.view.View

fun View.gone() {
    this.visibility = View.GONE
}

fun View.visible() {
    this.visibility = View.VISIBLE
}

class Constants {


    enum class PositionMarker {
        START, MIDDLE, END
    }

    companion object {
        const val circlesNames: String = "static_circles"
        const val roadName: String="DYNAMIC-ROAD"
        const val zoomStaticPosition: Double = 12.0
        const val latLabel: String = "lat"
        const val lonLabel: String = "lon"
        const val zoomMyLocation: Double = 15.0
        const val defaultZoom: Double = 1.0
        const val url = "router.project-osrm.org/route/v1/driving/"
        const val unvailableAdress = "unvailable addresse"
        const val STARTPOSITIONROAD = "START"
        const val MIDDLEPOSITIONROAD = "MIDDLE"
        const val ENDPOSITIONROAD = "END"
        const val nameFolderStatic = "staticPositionGeoPoint"

    }
}
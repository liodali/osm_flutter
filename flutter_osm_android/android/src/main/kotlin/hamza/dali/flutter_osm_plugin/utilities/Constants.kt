package hamza.dali.flutter_osm_plugin.utilities

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
        const val shapesNames: String = "static_shapes"
        const val regionNames: String = "static_regions"
        const val circlesNames: String = "static_circles"
        const val roadName: String="Dynamic-Road"
        const val markerNameOverlay: String="Markers"
        const val zoomStaticPosition: Double = 12.0
        const val latLabel: String = "lat"
        const val lonLabel: String = "lon"
        const val zoomMyLocation: Double = 15.0
        const val stepZoom: Double = 1.0
        const val unavailableAddress = "unvailable addresse"
        const val STARTPOSITIONROAD = "START"
        const val MIDDLEPOSITIONROAD = "MIDDLE"
        const val ENDPOSITIONROAD = "END"
        const val nameFolderStatic = "staticPositionGeoPoint"

    }
}
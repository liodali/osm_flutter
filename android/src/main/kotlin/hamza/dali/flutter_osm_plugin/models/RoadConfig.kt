package hamza.dali.flutter_osm_plugin.models

import org.osmdroid.bonuspack.routing.OSRMRoadManager
import org.osmdroid.util.GeoPoint

data class RoadConfig(
  val wayPoints:List<GeoPoint>,
  val interestPoints : List<GeoPoint>,
  val meanUrl :String = OSRMRoadManager.MEAN_BY_CAR,
  val colorRoad :Int? = null,
  val roadWidth :Float = 5f,
)

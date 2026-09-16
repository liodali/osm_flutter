package hamza.dali.flutter_osm_plugin.mapscore.network

import android.util.Log
import hamza.dali.flutter_osm_plugin.mapscore.models.MeanOfTransport
import hamza.dali.flutter_osm_plugin.mapscore.models.RoadGeoPointInstruction
import hamza.dali.flutter_osm_plugin.mapscore.utilities.decodePolyline
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * Standalone OSRM client used by the mapscore implementation to fetch road geometry.
 *
 * This replaces osmbonuspack's [org.osmdroid.bonuspack.routing.OSRMRoadManager]. Road
 * fetching stays native for now (Phase 4 of the migration plan will move it to Dart via
 * routing_client_dart); the public Dart API is unchanged.
 */
class OsmRoadManager(
    private val baseUrl: String = DEFAULT_OSRM_BASE_URL,
) {
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    data class RoadResult(
        val encodedPolyline: String,
        val coords: List<Pair<Double, Double>>,
        val distance: Double,
        val duration: Double,
        val instructions: List<RoadGeoPointInstruction>,
    )

    fun fetchRoad(
        wayPoints: List<Pair<Double, Double>>,
        interestPoints: List<Pair<Double, Double>>,
        mean: MeanOfTransport,
    ): RoadResult? {
        val ordered = ArrayList(wayPoints)
        if (interestPoints.isNotEmpty() && ordered.size >= 2) {
            ordered.addAll(1, interestPoints)
        }
        if (ordered.size < 2) return null

        val coordStr = ordered.joinToString(";") { (lat, lon) -> "$lon,$lat" }
        val url = "$baseUrl/route/v1/${mean.profile}/$coordStr" +
            "?overview=full&geometries=polyline&steps=true"

        return try {
            val response = client.newCall(Request.Builder().url(url).build()).execute()
            val body = response.body?.string() ?: return null
            val json = JSONObject(body)
            if (json.optString("code") != "Ok") {
                Log.e("OsmRoadManager", "OSRM error: $body")
                return null
            }
            val route = json.getJSONArray("routes").getJSONObject(0)
            val geometry = route.getString("geometry")
            val coords = decodePolyline(geometry, 5)
            val instructions = buildInstructions(route)
            RoadResult(
                encodedPolyline = geometry,
                coords = coords,
                distance = route.optDouble("distance", 0.0),
                duration = route.optDouble("duration", 0.0),
                instructions = instructions,
            )
        } catch (e: Exception) {
            Log.e("OsmRoadManager", "fetch failed", e)
            null
        }
    }

    private fun buildInstructions(route: JSONObject): List<RoadGeoPointInstruction> {
        val result = ArrayList<RoadGeoPointInstruction>()
        val legs = route.optJSONArray("legs") ?: return result
        for (i in 0 until legs.length()) {
            val steps = legs.getJSONObject(i).optJSONArray("steps") ?: continue
            for (s in 0 until steps.length()) {
                val step = steps.getJSONObject(s)
                val maneuver = step.optJSONObject("maneuver") ?: continue
                val location = maneuver.optJSONArray("location") ?: continue
                val lon = location.optDouble(0)
                val lat = location.optDouble(1)
                val name = step.optString("name", "")
                val type = maneuver.optString("type", "")
                val instruction = buildInstructionText(type, name)
                if (instruction.isNotEmpty()) {
                    result.add(RoadGeoPointInstruction(instruction, lat, lon))
                }
            }
        }
        return result
    }

    private fun buildInstructionText(type: String, name: String): String {
        if (type.isEmpty()) return name
        val verb = when (type) {
            "turn" -> "Turn"
            "new name" -> "Continue"
            "merge" -> "Merge"
            "on ramp" -> "Take the ramp"
            "off ramp" -> "Take the exit"
            "fork" -> "At the fork"
            "end of road" -> "At the end of the road"
            "continue" -> "Continue"
            "roundabout" -> "At the roundabout"
            "rotary" -> "At the roundabout"
            "arrive" -> "Arrive"
            "depart" -> "Depart"
            else -> type.replaceFirstChar { it.uppercase() }
        }
        return if (name.isNotEmpty()) "$verb onto $name" else verb
    }

    companion object {
        const val DEFAULT_OSRM_BASE_URL = "https://router.project-osrm.org"
    }
}

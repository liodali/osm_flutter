package hamza.dali.flutter_osm_plugin.network

import hamza.dali.flutter_osm_plugin.models.Adresse
import retrofit2.http.GET
import retrofit2.http.Headers
import retrofit2.http.Query

interface ApiClient {

    @Headers(
            "Content-Type: application/json"
    )
    @GET("reverse?format=jsonv2")
    suspend fun reverseGeoPointToAdress(
            @Query("lat") lat: String,
            @Query("lon") lon: String,
    ): Adresse

}
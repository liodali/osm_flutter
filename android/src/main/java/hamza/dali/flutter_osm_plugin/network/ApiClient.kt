package hamza.dali.flutter_osm_plugin.network

import hamza.dali.flutter_osm_plugin.Adresse
import okhttp3.ResponseBody
import retrofit2.http.Field
import retrofit2.http.GET

interface ApiClient {

    @GET("https://nominatim.openstreetmap.org/reverse?format=jsonv2")
    suspend fun reverseGeoPointToAdress(
            @Field("lat") lat: String,
            @Field("lon") lon: String,
    ):Adresse

}
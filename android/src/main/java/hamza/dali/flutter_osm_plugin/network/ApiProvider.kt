package hamza.dali.flutter_osm_plugin.network

import okhttp3.OkHttpClient
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory

object ApiProvider {
    val apiClient: ApiClient = Retrofit.Builder()
            .client(OkHttpClient())
            .addConverterFactory(MoshiConverterFactory.create())
            .build()
            .create(ApiClient::class.java)
}
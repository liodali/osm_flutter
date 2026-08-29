package hamza.dali.flutter_osm_plugin.models

import android.util.Log
import android.view.View
import hamza.dali.flutter_osm_plugin.databinding.InfowindowBinding
import hamza.dali.flutter_osm_plugin.network.ApiProvider
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers.IO
import kotlinx.coroutines.Dispatchers.Main
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.infowindow.InfoWindow
import hamza.dali.flutter_osm_plugin.utilities.*
class FlutterInfoWindow(view: View, mapView: MapView?, private val point: GeoPoint) :
    InfoWindow(view, mapView) {
    private var infoView: InfowindowBinding = InfowindowBinding.bind(view)
    private var job: Job? = null
    private var scope: CoroutineScope? = null

    constructor(mapView: MapView, infoView: View, point: GeoPoint, scope: CoroutineScope? = null) :
            this(mapView = mapView, view = infoView, point = point) {
        this.scope = scope
    }

    override fun onOpen(item: Any?) {
        if (isOpen) {
            close()
        } else {
            infoView.root.setOnClickListener {
                close()
            }
            infoView.progressCircularOsm.visible()
            infoView.adresseInfowindow.gone()
            job = scope?.launch(IO) {
                try {
                    val adresse = ApiProvider.apiClientNominatim.reverseGeoPointToAdress(
                        point.latitude.toString(),
                        point.longitude.toString(),
                    )
                    withContext(Main) {
                        infoView.progressCircularOsm.gone()
                        infoView.adresseInfowindow.text = adresse.name
                        infoView.adresseInfowindow.visible()
                    }


                } catch (e: Exception) {
                    Log.e("error address", e.stackTrace.toString())
                    withContext(Main) {
                        infoView.progressCircularOsm.gone()
                        infoView.adresseInfowindow.text = Constants.unavailableAddress
                        infoView.adresseInfowindow.visible()
                    }
                }
            }
        }
    }

    override fun onClose() {
        close()
        job?.cancel()
        mView.setOnClickListener(null)
    }
}
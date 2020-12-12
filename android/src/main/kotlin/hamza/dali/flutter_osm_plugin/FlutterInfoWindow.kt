package hamza.dali.flutter_osm_plugin

import android.util.Log
import android.view.View
import hamza.dali.flutter_osm_plugin.databinding.InfowindowBinding
import hamza.dali.flutter_osm_plugin.network.ApiProvider
import kotlinx.coroutines.Dispatchers.IO
import kotlinx.coroutines.Dispatchers.Main
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.infowindow.InfoWindow

class FlutterInfoWindow(view: View, mapView: MapView?) :
        InfoWindow(view, mapView) {
    private lateinit var point: GeoPoint
    private lateinit var infoView: InfowindowBinding
    private var job: Job? = null

    constructor(mapView: MapView, infoView: View, point: GeoPoint) :
            this(mapView = mapView, view = infoView) {
        this.point = point
        this.infoView = InfowindowBinding.bind(infoView)
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
            job = GlobalScope.launch(IO) {
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
                        infoView.adresseInfowindow.text = Constants.unvailableAdress
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
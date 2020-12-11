package hamza.dali.flutter_osm_plugin

import hamza.dali.flutter_osm_plugin.databinding.InfowindowBinding
import hamza.dali.flutter_osm_plugin.network.ApiProvider
import kotlinx.coroutines.Dispatchers.IO
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.infowindow.InfoWindow

class FlutterInfoWindow(layoutResId: Int, mapView: MapView?) :
        InfoWindow(layoutResId, mapView) {
    private lateinit var point: GeoPoint
    private lateinit var infoView: InfowindowBinding
    private var job: Job? = null

    constructor(mapView: MapView, infoView: InfowindowBinding, point: GeoPoint) :
            this(mapView = mapView, layoutResId = infoView.root.id) {
        this.point = point
        this.infoView = infoView
    }

    override fun onOpen(item: Any?) {
        if (isOpen) {
            close()
        } else {
            infoView.root.setOnClickListener {
                onClose()
            }
            infoView.progressCircularOsm.visible()
            infoView.adresseInfowindow.gone()
            job = GlobalScope.launch(IO) {
                try {
                    val adresse = ApiProvider.apiClient.reverseGeoPointToAdress(
                            point.latitude.toString(),
                            point.longitude.toString(),
                    )
                    infoView.progressCircularOsm.gone()
                    infoView.adresseInfowindow.text = adresse.name
                    infoView.adresseInfowindow.visible()


                } catch (e: Exception) {
                    infoView.progressCircularOsm.gone()
                    infoView.adresseInfowindow.text = Constants.unvailableAdress
                    infoView.adresseInfowindow.visible()
                }
            }
        }
    }

    override fun onClose() {
        job?.cancel()
        mView.setOnClickListener(null)
    }
}
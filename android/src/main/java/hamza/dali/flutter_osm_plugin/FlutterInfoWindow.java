package hamza.dali.flutter_osm_plugin;

import android.util.Log;
import android.view.View;
import android.widget.ProgressBar;
import android.widget.TextView;

import com.androidnetworking.AndroidNetworking;
import com.androidnetworking.common.ANRequest;
import com.androidnetworking.error.ANError;
import com.androidnetworking.interfaces.JSONObjectRequestListener;

import org.json.JSONException;
import org.json.JSONObject;
import org.osmdroid.util.GeoPoint;
import org.osmdroid.views.MapView;
import org.osmdroid.views.overlay.infowindow.InfoWindow;

public class FlutterInfoWindow extends InfoWindow {

    private GeoPoint geoPoint;
    private ANRequest request;

    public FlutterInfoWindow(int layoutResId, MapView mapView) {
        super(layoutResId, mapView);
    }

    public FlutterInfoWindow(View view, MapView mapView, GeoPoint p) {
        super(view, mapView);
        this.geoPoint = p;
    }


    @Override
    public void onOpen(Object item) {
        mView.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                close();
            }
        });
        final ProgressBar progressBar = mView.findViewById(R.id.progress_circular_osm);
        final TextView textView = mView.findViewById(R.id.adresse_infowindow);
        request = AndroidNetworking.get("https://nominatim.openstreetmap.org/reverse")
                .addQueryParameter("format", "jsonv2")
                .addQueryParameter("lat", String.valueOf(geoPoint.getLatitude()))
                .addQueryParameter("lon", String.valueOf(geoPoint.getLongitude()))
                .build();
        request.getAsJSONObject(new JSONObjectRequestListener() {
            @Override
            public void onResponse(JSONObject response) {
                Log.e("err nominatim", response.toString());
                progressBar.setVisibility(View.GONE);
                textView.setVisibility(View.VISIBLE);
                if (response.has("error")) {
                    textView.setText(Constants.unvailableAdress);
                } else {
                    try {
                        if ((response.getString("lat").equals("0") && response.getString("lon").equals("0"))) {
                            textView.setText(Constants.unvailableAdress);
                        } else
                            textView.setText(response.getString("display_name"));
                    } catch (JSONException e) {
                        Log.e("err parse", e.getMessage());
                        textView.setText(Constants.unvailableAdress);
                    }
                }
            }

            @Override
            public void onError(ANError anError) {
                progressBar.setVisibility(View.GONE);
                textView.setVisibility(View.VISIBLE);
                textView.setText("unvailable addresse");
            }
        });
    }

    @Override
    public void onClose() {
        mView.setOnClickListener(null);
        if (request != null && request.isRunning()) {
            request.cancel(true);
        }
    }
}

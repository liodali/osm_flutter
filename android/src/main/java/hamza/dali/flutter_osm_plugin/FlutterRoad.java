package hamza.dali.flutter_osm_plugin;

import android.app.Application;
import android.graphics.Bitmap;

import org.osmdroid.views.MapView;
import org.osmdroid.views.overlay.Overlay;
import org.osmdroid.views.overlay.Polyline;

import java.util.HashMap;

public class FlutterRoad extends Overlay {
    private Polyline road;
    private FlutterRoadMarker startPoint, endPoint;
    private Application application;
    private MapView mapView;
    private HashMap<String, Bitmap> customRoadMarkerIcon;

    public FlutterRoad(Application application, MapView mapView) {
        this.application = application;
        this.mapView = mapView;
    }

    public void setCustomRoadMarkerIcon(HashMap<String, Bitmap> customRoadMarkerIcon) {
        this.customRoadMarkerIcon = customRoadMarkerIcon;
    }

    public void setRoad(Polyline road) {
        this.road = road;
    }

    private void drawEndPoint() {
        endPoint = new FlutterRoadMarker(application, mapView,this.road.getPoints().get(this.road.getPoints().size()));
        endPoint.setRoadMarkers(customRoadMarkerIcon);
        endPoint.setIconPosition(Constants.PositionMarker.END);
        this.mapView.getOverlays().add(endPoint);
    }

    private void drawStartPoint() {
        startPoint = new FlutterRoadMarker(application, mapView,this.road.getPoints().get(0));
        startPoint.setRoadMarkers(customRoadMarkerIcon);

        startPoint.setIconPosition(Constants.PositionMarker.START);
        this.mapView.getOverlays().add(startPoint);
    }

    void drawRoad() {
        drawStartPoint();
        drawEndPoint();
        this.mapView.getOverlays().add(this.road);
    }


}

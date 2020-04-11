package hamza.dali.flutter_osm_plugin;

import android.app.Application;
import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;

import org.osmdroid.views.MapView;

import java.util.HashMap;

public class FlutterRoadMarker extends  FlutterMarker {
    private HashMap<String, Bitmap> customRoadMarkerIcon;

    public FlutterRoadMarker(Application application, MapView mapView) {
        super(application, mapView);
        customRoadMarkerIcon = new HashMap<>();
    }
    void setRoadMarkers(HashMap<String, Bitmap> customRoadMarkerIcon){
        this.customRoadMarkerIcon=customRoadMarkerIcon;
    }

    void setIconPosition(Constants.PositionMarker positionMarker){
        Drawable iconDrawable=getDefaultIconDrawable(null,null);
        switch (positionMarker) {
            case START:
                if (customRoadMarkerIcon.containsKey(Constants.STARTPOSITIONROAD)) {
                    iconDrawable = new BitmapDrawable(application.getResources(), customRoadMarkerIcon.get(Constants.STARTPOSITIONROAD));
                }
                break;
            case MIDDLE:
                if (customRoadMarkerIcon.containsKey(Constants.MIDDLEPOSITIONROAD)) {
                    iconDrawable = new BitmapDrawable(application.getResources(), customRoadMarkerIcon.get(Constants.MIDDLEPOSITIONROAD));
                }
                break;
            case END:
                if (customRoadMarkerIcon.containsKey(Constants.ENDPOSITIONROAD)) {
                    iconDrawable = new BitmapDrawable(application.getResources(), customRoadMarkerIcon.get(Constants.ENDPOSITIONROAD));
                }
                break;
        }
        setIcon(iconDrawable);
    }
}

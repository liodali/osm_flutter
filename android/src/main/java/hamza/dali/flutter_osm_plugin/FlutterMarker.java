package hamza.dali.flutter_osm_plugin;

import android.app.Application;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.PorterDuff;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.os.Build;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;

import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;

import org.osmdroid.util.GeoPoint;
import org.osmdroid.views.MapView;
import org.osmdroid.views.overlay.Marker;
import org.osmdroid.views.overlay.infowindow.MarkerInfoWindow;

public class FlutterMarker extends Marker implements Marker.OnMarkerClickListener {
    MapView map;
    View infoWindow;
    OnMarkerClickListener listener;
    Application application;

    public FlutterMarker(Application application,MapView mapView) {
        super(mapView);
        this.map=mapView;
        this.application=application;
        setOnMarkerClickListener(this);

        //setInfoWindow(new FlutterInfoWindow(creatWindowInfoView(),mapView,this.mPosition));
    }
    public FlutterMarker(Application application,MapView mapView,GeoPoint p) {
        super(mapView);
        this.map=mapView;
        this.application=application;
        this.mPosition=p;
        setOnMarkerClickListener(this);
        setInfoWindow(new FlutterInfoWindow(creatWindowInfoView(),mapView,this.mPosition));
    }

    public FlutterMarker(MapView mapView,View viewInfoWindow) {
        super(mapView);
        this.map=mapView;
        this.infoWindow=viewInfoWindow;

    }
    void setIconMaker(Bitmap bitmap,@Nullable Integer color){
        Drawable drawable=getDefaultIconDrawable(color,bitmap);
        setIcon(drawable);

    }
    public void setDefaultFlutterInfoWindow(){
        setInfoWindow(new FlutterInfoWindow(creatWindowInfoView(),map,this.mPosition));
    }
    public void setInfo(View InfoWindow){
        setInfoWindow(new FlutterInfoWindow(InfoWindow,map,this.mPosition));
    }
    @Override
    public void setInfoWindow(MarkerInfoWindow infoWindow) {
        super.setInfoWindow(infoWindow);
    }

    @Override
    public void showInfoWindow() {
        super.showInfoWindow();
    }

    private View creatWindowInfoView(){
        LayoutInflater inflater = (LayoutInflater) application.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
        View view=inflater.inflate(R.layout.infowindow,null);
        return  view;
    }

    protected Drawable getDefaultIconDrawable(@Nullable Integer color,Bitmap bitmap) {
        Drawable iconDrawable = null;
        if (bitmap != null) {
            iconDrawable = new BitmapDrawable(application.getResources(), bitmap);
            if (color != null)
                iconDrawable.setColorFilter(color, PorterDuff.Mode.SRC_OVER);
        } else {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                iconDrawable = application.getDrawable(R.drawable.ic_location_on_red_24dp);
            } else {
                iconDrawable = ContextCompat.getDrawable(application, R.drawable.ic_location_on_red_24dp);
            }
        }
        return iconDrawable;
    }

    public void setListener(OnMarkerClickListener listener) {
        this.listener = listener;
    }

    @Override
    public boolean onMarkerClick(Marker marker, MapView mapView) {
        Log.e("clicked","CLicked");
        showInfoWindow();
        if(listener!=null){
            return  this.listener.onMarkerClick(this,map);
        }
        return true;

        //return false;
    }
}

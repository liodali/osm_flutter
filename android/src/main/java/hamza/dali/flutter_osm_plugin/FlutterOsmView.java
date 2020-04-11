package hamza.dali.flutter_osm_plugin;


import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.Point;
import android.graphics.PorterDuff;
import android.graphics.Rect;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.preference.PreferenceManager;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;
import androidx.lifecycle.DefaultLifecycleObserver;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleOwner;

import com.androidnetworking.AndroidNetworking;
import com.google.android.material.card.MaterialCardView;

import org.osmdroid.bonuspack.routing.OSRMRoadManager;
import org.osmdroid.bonuspack.routing.Road;
import org.osmdroid.bonuspack.routing.RoadManager;
import org.osmdroid.config.Configuration;
import org.osmdroid.events.MapEventsReceiver;
import org.osmdroid.events.MapListener;
import org.osmdroid.events.ScrollEvent;
import org.osmdroid.events.ZoomEvent;
import org.osmdroid.tileprovider.tilesource.TileSourceFactory;
import org.osmdroid.util.GeoPoint;
import org.osmdroid.views.CustomZoomButtonsController;
import org.osmdroid.views.MapView;
import org.osmdroid.views.overlay.FolderOverlay;
import org.osmdroid.views.overlay.MapEventsOverlay;
import org.osmdroid.views.overlay.Marker;
import org.osmdroid.views.overlay.Overlay;
import org.osmdroid.views.overlay.Polyline;
import org.osmdroid.views.overlay.mylocation.GpsMyLocationProvider;
import org.osmdroid.views.overlay.mylocation.MyLocationNewOverlay;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.platform.PlatformView;

import static hamza.dali.flutter_osm_plugin.Constants.PositionMarker.START;
import static hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.CREATED;
import static hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.DESTROYED;
import static hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.PAUSED;
import static hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.RESUMED;
import static hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.STARTED;
import static hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.STOPPED;
import static io.flutter.plugin.common.MethodChannel.Result;
import static org.apache.commons.lang3.ArrayUtils.toArray;


public class FlutterOsmView implements
        Application.ActivityLifecycleCallbacks,
        DefaultLifecycleObserver,
        ActivityPluginBinding.OnSaveInstanceStateListener,
        PlatformView,
        EventChannel.StreamHandler,
        MethodChannel.MethodCallHandler {

    private MapView map;
    private MyLocationNewOverlay locationNewOverlay;
    private Context context;
    private final MethodChannel methodChannel;
    private final EventChannel eventChannel;
    private EventChannel.EventSink eventSink;

    private final int activityHashCode; // Do not use directly, use getActivityHashCode() instead to get correct hashCode for both v1 and v2 embedding.
    private final Lifecycle lifecycle;
    private final Application mApplication;
    private Activity mActivity;
    private final AtomicInteger activityState;
    private PluginRegistry.Registrar registrar;
    private Bitmap customMarkerIcon;
    private Bitmap staticMarkerIcon;
    private HashMap<String, Bitmap> customRoadMarkerIcon = new HashMap<>();
    private List<GeoPoint> staticPoints;
    private FolderOverlay folderStaticPosition;
    private FlutterRoad flutterRoad;


    private MapEventsOverlay mapEventsOverlay;
    private OSRMRoadManager roadManager;
    private Integer roadColor = null;
    private final double defaultZoom = 10.;
    private final String url = "router.project-osrm.org/route/v1/driving/";
    private boolean useScureURL = true;

    public FlutterOsmView(Context ctx,
                          PluginRegistry.Registrar registrar,
                          BinaryMessenger binaryMessenger,
                          int id,
                          AtomicInteger activityState,
                          Application application,
                          Activity activity,
                          Lifecycle lifecycle,
                          int registrarActivityHashCode) {

        this.context = ctx;
        if (registrar != null)
            this.registrar = registrar;
        this.mActivity = activity;

        staticPoints = new ArrayList<>();
        folderStaticPosition=new FolderOverlay();
        folderStaticPosition.setName(Constants.nameFolderStatic);
        //LinearLayout view = (LinearLayout) getViewFromXML();
        Configuration.getInstance().load(context, PreferenceManager.getDefaultSharedPreferences(context));
        map = new MapView(context);
        map.setLayoutParams(new MapView.LayoutParams(new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)));
        map.setTilesScaledToDpi(true);
        map.setMultiTouchControls(true);

        map.addMapListener(new MapListener() {
            @Override
            public boolean onScroll(ScrollEvent event) {
                /*Rect currentMapBoundsRect = new Rect();
                map.getDrawingRect(currentMapBoundsRect);
                for (Overlay overlay : map.getOverlays()) {
                    if (overlay instanceof Marker) {
                        Point currentDevicePosition = new Point();
                        map.getProjection().toPixels(((Marker) overlay).getPosition(), currentDevicePosition);
                        if (!currentMapBoundsRect.contains(currentDevicePosition.x, currentDevicePosition.y)) {
                            map.getOverlays().remove(overlay);
                        }
                    }
                }*/

                return false;
            }

            @Override
            public boolean onZoom(ZoomEvent event) {
                if(event.getZoomLevel()<10.){
                    Rect currentMapBoundsRect = new Rect();
                    map.getDrawingRect(currentMapBoundsRect);

                   map.getOverlays().remove(folderStaticPosition);
                }else{

                    if(!map.getOverlays().contains(folderStaticPosition)){
                        map.getOverlays().add(folderStaticPosition);
                    }
                }
                return false;
            }
        });

        //map.setZoomRounding(true);
        map.setTileSource(TileSourceFactory.MAPNIK);
        map.getZoomController().setVisibility(CustomZoomButtonsController.Visibility.NEVER);


        methodChannel = new MethodChannel(binaryMessenger, "plugins.dali.hamza/osmview_" + id);
        eventChannel = new EventChannel(binaryMessenger, "plugins.dali.hamza/osmview_stream_" + id);
        methodChannel.setMethodCallHandler(this);
        eventChannel.setStreamHandler(this);

        mApplication = application;
        this.lifecycle = lifecycle;
        this.activityHashCode = registrarActivityHashCode;
        this.activityState = activityState;
    }

    @Override
    public void onFlutterViewAttached(View flutterView) {

    }

    @Override
    public void onFlutterViewDetached() {
        map.onPause();
    }


    @Override
    public View getView() {

        return map;
    }

    private void setZoom(MethodCall methodCall, Result result) {
        try{
            double zoom = (Double) methodCall.arguments;
            map.getController().setZoom(zoom);

            result.success(null);
        }catch (Exception e){

        }
    }

    private void initPosition(MethodCall methodCall, Result result) {

        HashMap<String, Double> args = (HashMap<String, Double>) methodCall.arguments;
        map.getOverlays().clear();
        GeoPoint geoPoint = new GeoPoint(args.get("lat"), args.get("lon"));
        addMarker(geoPoint, defaultZoom, null, null);
        result.success(null);
    }

    private void addMarker(GeoPoint geoPoint, double zoom, @Nullable Integer color, @Nullable Constants.PositionMarker posmarker) {

        map.getController().setZoom(zoom);
        map.getController().animateTo(geoPoint);
        map.getOverlays().add(createMarker(geoPoint, color, posmarker));

    }

    private Marker createMarker(GeoPoint geoPoint, @Nullable Integer color, @Nullable Constants.PositionMarker posmarker) {
        FlutterMarker marker = new FlutterMarker(getApplication(), map);
        Drawable iconDrawable = getDefaultIconDrawable(color);


        marker.setIcon(iconDrawable);
        //marker.setInfoWindow(new FlutterInfoWindow(creatWindowInfoView(),map,geoPoint));

        marker.setPosition(geoPoint);
        return marker;
    }


    private Drawable getDefaultIconDrawable(@Nullable Integer color) {
        Drawable iconDrawable = null;
        if (customMarkerIcon != null) {
            iconDrawable = new BitmapDrawable(getActivity().getResources(), customMarkerIcon);
            if (color != null)
                iconDrawable.setColorFilter(color, PorterDuff.Mode.SRC_OVER);
        } else {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                iconDrawable = getActivity().getDrawable(R.drawable.ic_location_on_red_24dp);
            } else {
                iconDrawable = ContextCompat.getDrawable(getActivity(), R.drawable.ic_location_on_red_24dp);
            }
        }
        return iconDrawable;
    }

    private void enableMyLocation(Result result) {

        map.getOverlays().clear();
        if (!staticPoints.isEmpty()) {
            showStaticPosition();
        }
        this.locationNewOverlay = new MyLocationNewOverlay(new GpsMyLocationProvider(getApplication()), map);
        this.locationNewOverlay.enableMyLocation();
        this.locationNewOverlay.runOnFirstFix(new Runnable() {
            @Override
            public void run() {
                if (getActivity() != null) {
                    getActivity().runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            GeoPoint geo = new GeoPoint(locationNewOverlay.getLastFix().getLatitude(), locationNewOverlay.getLastFix().getLongitude());
                            //map.getController().zoomToSpan(Math.abs(geo.getLatitude()),Math.abs(geo.getLongitude()));
                            map.getController().setZoom(15.);
                            map.getController().animateTo(geo);
                        }
                    });
                } else {
                    Log.d("mActivity ", "null");
                }
            }
        });

        map.getOverlays().add(this.locationNewOverlay);


        result.success(null);
    }

    @Override
    public void dispose() {

        methodChannel.setMethodCallHandler(null);
        getApplication().unregisterActivityLifecycleCallbacks(this);

    }


    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "use#secure":
                setSecureURL(call, result);
                break;
            case "Zoom":
                setZoom(call, result);
                break;
            case "currentLocation":
                enableMyLocation(result);
                break;
            case "showZoomController":
                showZoomController(call, result);
                break;
            case "initPosition":
                initPosition(call, result);
                break;
            case "trackMe":
                enableTracking(call, result);
                break;
            case "user#position":
                userPosition(call, result);
                break;
            case "user#pickPosition":
                pickPosition(call, result);
                break;
            case "road":
                drawRoad(call, result);
                break;
            case "marker#icon":
                changeIcon(call, result);
                break;
            case "road#color":
                setRoadColor(call, result);
                break;
            case "road#markers":
                setMarkerRoad(call, result);
                break;
            case "staticPosition":
                setStaticPosition(call, result);
                break;
            case "staticPosition#IconMarker":
                setStaticPositionIcon(call, result);
                break;
            default:
                Log.i("info method",call.method);
                result.notImplemented();
        }

    }

    private void setStaticPositionIcon(MethodCall call, Result result) {
        try {
            staticMarkerIcon = getBitmap((byte[]) call.arguments);
            result.success(null);
        } catch (Exception e) {
            result.error("400", "error to getBitmap static POsition", "");
            staticMarkerIcon = null;
        }
    }

    private void setStaticPosition(MethodCall call, Result result) {
        final List<HashMap<String, Double>> points = (List<HashMap<String, Double>>) call.arguments;

        for (HashMap<String, Double> hashmap : points) {
            staticPoints.add(new GeoPoint(hashmap.get("lat"), hashmap.get("lon")));
        }
        showStaticPosition();
    }
    private void  showStaticPosition(){
        for (GeoPoint p : staticPoints) {
            FlutterMarker marker = new FlutterMarker(getApplication(), map);
            marker.setDefaultFlutterInfoWindow();
            marker.setOnMarkerClickListener(new Marker.OnMarkerClickListener() {
                @Override
                public boolean onMarkerClick(Marker marker, MapView mapView) {
                    marker.showInfoWindow();
                    HashMap<String, Double> hashMap = new HashMap<>();
                    hashMap.put("lon", marker.getPosition().getLongitude());
                    hashMap.put("lat", marker.getPosition().getLatitude());
                    eventSink.success(hashMap);
                    return false;
                }
            });
            marker.setPosition(p);
            if (staticMarkerIcon != null)
                marker.setIconMaker(staticMarkerIcon, null);
            folderStaticPosition.getItems().add(marker);
        }
        map.getOverlays().add(folderStaticPosition);
    }
    private void setSecureURL(MethodCall call, Result result) {
        useScureURL = (boolean) call.arguments;
        result.success(null);
    }

    private void drawRoad(MethodCall call, final Result result) {
        final List<HashMap<String, Double>> points = (List<HashMap<String, Double>>) call.arguments;

        if (roadManager == null) {
            roadManager = new OSRMRoadManager(getApplication());
            if (useScureURL)
                roadManager.setService("https://" + url);
        }
        for (int i = 0; i < map.getOverlays().size(); i++) {
            if (map.getOverlays().get(i) instanceof Polyline) {
                Polyline p = (Polyline) map.getOverlays().get(i);
                map.getOverlays().remove(p.getPoints().get(p.getPoints().size()));
                map.getOverlays().remove(p.getPoints().get(0));
                map.getOverlays().remove(i);
            }
        }
        map.invalidate();

        new AsyncTask<List<HashMap<String, Double>>, Void, Road>() {
            ArrayList<GeoPoint> waypoints = new ArrayList();

            @Override
            protected Road doInBackground(List<HashMap<String, Double>>... lists) {

                for (HashMap<String, Double> hashmap : lists[0]) {
                    waypoints.add(new GeoPoint(hashmap.get("lat"), hashmap.get("lon")));
                }
                return roadManager.getRoad(waypoints);
            }

            @Override
            protected void onPostExecute(Road road) {
                super.onPostExecute(road);
                if (getActivity() != null) {
                    if (road.mRouteHigh.size() > 2) {

                        Polyline roadOverlay = RoadManager.buildRoadOverlay(road);
                        roadOverlay.getOutlinePaint().setColor(Color.GREEN);
                        if (roadColor != null) {
                            roadOverlay.getOutlinePaint().setColor(roadColor);
                        }
                        flutterRoad = new FlutterRoad(getApplication(), map);
                        flutterRoad.setRoad(roadOverlay);
                        flutterRoad.setCustomRoadMarkerIcon(customRoadMarkerIcon);
                        flutterRoad.drawRoad();
                        map.invalidate();
                        result.success(null);
                    } else {
                        result.error("423", "Opps!we cannot draw road correctly!", null);
                    }

                }

            }
        }.execute(points);


    }

    private void pickPosition(MethodCall call, Result result) {
        final Result _result = result;
        if (mapEventsOverlay == null) {
            mapEventsOverlay = new MapEventsOverlay(new MapEventsReceiver() {
                @Override
                public boolean singleTapConfirmedHelper(GeoPoint p) {
                    return false;
                }

                @Override
                public boolean longPressHelper(GeoPoint p) {
                    HashMap<String, Double> Hashmap = new HashMap<>();
                    Hashmap.put("lat", p.getLatitude());
                    Hashmap.put("lon", p.getLongitude());
                    map.getOverlays().remove(0);
                    addMarker(p, 15., null, null);
                    mapEventsOverlay = null;
                    _result.success(Hashmap);
                    return false;
                }
            });
            map.getOverlays().add(0, mapEventsOverlay);
        }

    }

    private void changeIcon(MethodCall call, Result result) {
        try {

            customMarkerIcon = getBitmap((byte[]) call.arguments);
            //customMarkerIcon.recycle();
            result.success(null);
        } catch (Exception e) {
            Log.d("err", e.getMessage());
            customMarkerIcon = null;
            result.error("500", "Cannot make markerIcon custom", "");
        }

    }

    Bitmap getBitmap(byte[] bytes) {
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
    }

    private void setRoadColor(MethodCall call, Result result) {
        List<Integer> argb = (List<Integer>) call.arguments;
        roadColor = Color.rgb(argb.get(0), argb.get(1), argb.get(2));
        result.success(null);
    }

    private void setMarkerRoad(MethodCall call, Result result) {
        try {
            HashMap<String, byte[]> icons = (HashMap<String, byte[]>) call.arguments;
            if (icons.containsKey(Constants.STARTPOSITIONROAD)) {
                customRoadMarkerIcon.put(Constants.STARTPOSITIONROAD,
                        BitmapFactory.decodeByteArray(icons.get(Constants.STARTPOSITIONROAD), 0, icons.get(Constants.STARTPOSITIONROAD).length));
            }
            if (icons.containsKey(Constants.ENDPOSITIONROAD)) {
                customRoadMarkerIcon.put(Constants.ENDPOSITIONROAD,
                        BitmapFactory.decodeByteArray(icons.get(Constants.ENDPOSITIONROAD), 0,
                                icons.get(Constants.ENDPOSITIONROAD).length));
            }
            if (icons.containsKey(Constants.MIDDLEPOSITIONROAD)) {
                customRoadMarkerIcon.put(Constants.MIDDLEPOSITIONROAD,
                        BitmapFactory.decodeByteArray(icons.get(Constants.MIDDLEPOSITIONROAD), 0,
                                icons.get(Constants.MIDDLEPOSITIONROAD).length));
            }
            //customMarkerIcon = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
            //customMarkerIcon.recycle();
            result.success(null);
        } catch (Exception e) {
            Log.d("err", e.getMessage());
            customMarkerIcon = null;
            result.error("500", "Cannot make markerIcon custom", "");
        }

    }


    private void userPosition(MethodCall call, Result result) {
        if (this.locationNewOverlay == null || !this.locationNewOverlay.isMyLocationEnabled()) {
            result.error("400", "current location is not enabled yet!", null);
        } else {
            if (this.locationNewOverlay.getLastFix() != null) {
                HashMap<String, Double> map = new HashMap<>();
                GeoPoint geo = new GeoPoint(locationNewOverlay.getLastFix().getLatitude(), locationNewOverlay.getLastFix().getLongitude());
                map.put("lat", geo.getLatitude());
                map.put("lon", geo.getLongitude());
                result.success(map);
            } else
                result.error("400", "location not available yet!", null);
        }


    }

    private void showZoomController(MethodCall call, Result result) {
        boolean showZoom = (boolean) call.arguments;
        map.getZoomController().setVisibility(showZoom ? CustomZoomButtonsController.Visibility.ALWAYS : CustomZoomButtonsController.Visibility.NEVER);
    }

    private void enableTracking(MethodCall call, Result result) {
        if (this.locationNewOverlay != null) {
            if (locationNewOverlay.isFollowLocationEnabled()) {
                locationNewOverlay.disableFollowLocation();
            } else {
                locationNewOverlay.enableFollowLocation();
            }
        }
        result.success(null);
    }

    private Activity getActivity() {
        if (registrar != null && registrar.activity() != null) {
            return registrar.activity();
        } else {
            return mActivity;
        }
    }

    private Application getApplication() {
        if (registrar != null && registrar.activity() != null) {
            return registrar.activity().getApplication();
        } else {
            return mApplication;
        }
    }

    @Override
    public void onActivityCreated(Activity activity, Bundle bundle) {
        AndroidNetworking.initialize(getApplication());
    }

    @Override
    public void onActivityStarted(Activity activity) {

    }

    @Override
    public void onActivityResumed(Activity activity) {
        map.onResume();

    }

    @Override
    public void onActivityPaused(Activity activity) {
        map.onPause();

    }

    @Override
    public void onActivityStopped(Activity activity) {

    }

    @Override
    public void onActivitySaveInstanceState(Activity activity, Bundle bundle) {

    }

    @Override
    public void onActivityDestroyed(Activity activity) {

    }

    @Override
    public void onSaveInstanceState(Bundle bundle) {

    }

    @Override
    public void onRestoreInstanceState(Bundle bundle) {

    }

    @Override
    public void onCreate(@NonNull LifecycleOwner owner) {

    }

    @Override
    public void onStart(@NonNull LifecycleOwner owner) {

    }

    @Override
    public void onResume(@NonNull LifecycleOwner owner) {
        map.onResume();
    }

    @Override
    public void onPause(@NonNull LifecycleOwner owner) {
        map.onPause();
    }

    @Override
    public void onStop(@NonNull LifecycleOwner owner) {

    }

    @Override
    public void onDestroy(@NonNull LifecycleOwner owner) {

    }

    void init() {
        switch (activityState.get()) {
            case STOPPED:
                break;
            case PAUSED:
                map.onPause();
                break;
            case RESUMED:
                map.onResume();
                break;
            case STARTED:
                break;
            case CREATED:
                break;
            case DESTROYED:
                // Nothing to do, the activity has been completely destroyed.
                break;
            default:
                throw new IllegalArgumentException(
                        "Cannot interpret " + activityState.get() + " as an activity state");
        }
        if (lifecycle != null) {
            lifecycle.addObserver(this);
        } else {
            getApplication().registerActivityLifecycleCallbacks(this);
        }

    }

    @Override
    public void onListen(Object arguments, final EventChannel.EventSink events) {
        Log.e("started listening","started");
        this.eventSink=events;


    }

    @Override
    public void onCancel(Object arguments) {
            eventSink=null;
    }
}

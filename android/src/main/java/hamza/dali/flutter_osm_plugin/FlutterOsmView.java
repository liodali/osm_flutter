package hamza.dali.flutter_osm_plugin;

import android.Manifest;
import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.preference.PreferenceManager;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.LinearLayout;

import androidx.annotation.NonNull;
import androidx.lifecycle.DefaultLifecycleObserver;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleOwner;

import org.osmdroid.config.Configuration;
import org.osmdroid.tileprovider.MapTileProviderBase;
import org.osmdroid.tileprovider.tilesource.TileSourceFactory;
import org.osmdroid.views.CustomZoomButtonsController;
import org.osmdroid.views.MapView;
import org.osmdroid.views.overlay.mylocation.GpsMyLocationProvider;
import org.osmdroid.views.overlay.mylocation.MyLocationNewOverlay;

import java.util.concurrent.atomic.AtomicInteger;

import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.platform.PlatformView;

import static hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.CREATED;
import static hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.DESTROYED;
import static hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.PAUSED;
import static hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.RESUMED;
import static hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.STARTED;
import static hamza.dali.flutter_osm_plugin.FlutterOsmPlugin.STOPPED;
import static io.flutter.plugin.common.MethodChannel.Result;

public class FlutterOsmView implements
        Application.ActivityLifecycleCallbacks,
        DefaultLifecycleObserver,
        ActivityPluginBinding.OnSaveInstanceStateListener,
        PlatformView,
        MethodChannel.MethodCallHandler {
    MapView map;
    private  MyLocationNewOverlay locationNewOverlay;
    private Context context;
    private final MethodChannel methodChannel;
    private final int
            activityHashCode; // Do not use directly, use getActivityHashCode() instead to get correct hashCode for both v1 and v2 embedding.
    private final Lifecycle lifecycle;
    private final Application
            mApplication;
    private final AtomicInteger activityState;
    private PluginRegistry.Registrar registrar;

    public FlutterOsmView(Context ctx,
                          PluginRegistry.Registrar registrar,
                          BinaryMessenger binaryMessenger,
                          int id,
                          AtomicInteger activityState,
                          Application application,
                          Lifecycle lifecycle,
                          int registrarActivityHashCode) {

        this.context = ctx;
        this.registrar=registrar;


        //LinearLayout view = (LinearLayout) getViewFromXML();
        Configuration.getInstance().load(context, PreferenceManager.getDefaultSharedPreferences(context));
        map = new MapView(context);
        map.setTileSource(TileSourceFactory.MAPNIK);
        map.getZoomController().setVisibility(CustomZoomButtonsController.Visibility.NEVER);
        /*
        view.addView(map, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT));

        Log.d("view map", "map");
        if (map != null) {
            map.removeAllViews();
        }
        //map.onResume();

         */

        methodChannel = new MethodChannel(binaryMessenger, "plugins.dali.hamza/osmview_" + id);
        methodChannel.setMethodCallHandler(this);
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

    private View getViewFromXML() {
        return LayoutInflater.from(getApplication()).inflate(R.layout.osm_layout, null, false);
    }

    @Override
    public View getView() {

        return map;
    }

    private void setZoom(MethodCall methodCall, Result result) {
        int zoom = (int) methodCall.arguments;
        map.getController().setZoom((double) zoom);

        result.success(null);
    }
    private  void enableMyLocation(MethodCall methodCall,Result result){
        this.locationNewOverlay = new MyLocationNewOverlay(new GpsMyLocationProvider(context),map);
        this.locationNewOverlay.enableMyLocation();
        map.getOverlays().add(this.locationNewOverlay);
    }

    @Override
    public void dispose() {

        methodChannel.setMethodCallHandler(null);
        getApplication().unregisterActivityLifecycleCallbacks(this);

    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "Zoom":
                setZoom(call, result);
                break;
            case "currentLocation":
                enableMyLocation(call,result);
                break;
            case "Road":
                result.notImplemented();
                break;
            default:
                result.notImplemented();
        }

    }



    private boolean hasLocationPermission() {
        return checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                == PackageManager.PERMISSION_GRANTED
                || checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
                == PackageManager.PERMISSION_GRANTED;
    }

    private int checkSelfPermission(String permission) {
        if (permission == null) {
            throw new IllegalArgumentException("permission is null");
        }
        return context.checkPermission(
                permission, android.os.Process.myPid(), android.os.Process.myUid());
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
}

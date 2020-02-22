package hamza.dali.flutter_osm_plugin;


import android.Manifest;
import android.app.Activity;
import android.app.Application;
import android.content.pm.PackageManager;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.lifecycle.DefaultLifecycleObserver;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleOwner;

import java.util.concurrent.atomic.AtomicInteger;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
//import io.flutter.embedding.engine.plugins.activity.FlutterLifecycleAdapter;

import io.flutter.embedding.engine.plugins.lifecycle.FlutterLifecycleAdapter;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * FlutterOsmPlugin
 */
public class FlutterOsmPlugin implements
        Application.ActivityLifecycleCallbacks,
        FlutterPlugin,
        ActivityAware,
        DefaultLifecycleObserver {


    static final int CREATED = 1;
    static final int STARTED = 2;
    static final int RESUMED = 3;
    static final int PAUSED = 4;
    static final int STOPPED = 5;
    static final int DESTROYED = 6;
    private final AtomicInteger state = new AtomicInteger(0);
    private int registrarActivityHashCode;
    private FlutterPluginBinding pluginBinding;
    private Lifecycle lifecycle;
    private static final String VIEW_TYPE = "plugins.dali.hamza/osmview";

    public static void registerWith(Registrar registrar) {
        if (registrar.activity() == null) {
            // When a background flutter view tries to register the plugin, the registrar has no activity.
            // We stop the registration process as this plugin is foreground only.
            return;
        }
        FlutterOsmPlugin plugin = new FlutterOsmPlugin(registrar.activity());
        registrar.activity().getApplication().registerActivityLifecycleCallbacks(plugin);
        registrar
                .platformViewRegistry()
                .registerViewFactory(
                        VIEW_TYPE,
                        new OsmFactory(plugin.state,
                                registrar.messenger(),null,null,
                                -1, registrar));
    }


    public  FlutterOsmPlugin(){ }

    private FlutterOsmPlugin(Activity activity) {
        this.registrarActivityHashCode = activity.hashCode();
    }

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        pluginBinding = binding;
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        pluginBinding = null;
    }


    @Override
    public void onAttachedToActivity(ActivityPluginBinding binding) {
        lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(binding);
        lifecycle.addObserver(this);

        pluginBinding
                .getPlatformViewRegistry()
                .registerViewFactory(
                        VIEW_TYPE,
                        new OsmFactory(state,
                                pluginBinding.getBinaryMessenger(),
                                binding.getActivity().getApplication(),
                                lifecycle,
                                binding.getActivity().hashCode(),null)
                );
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        this.onDetachedFromActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
        lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(binding);
        lifecycle.addObserver(this);
    }

    @Override
    public void onDetachedFromActivity() {
        lifecycle.removeObserver(this);
    }

    @Override
    public void onActivityCreated(Activity activity, Bundle bundle) {
        if (activity.hashCode() != registrarActivityHashCode) {
            return;
        }
        boolean permissionAccessCoarseLocationApproved =
                ActivityCompat.checkSelfPermission(activity,
                        Manifest.permission.ACCESS_COARSE_LOCATION)
                        == PackageManager.PERMISSION_GRANTED;

        if (permissionAccessCoarseLocationApproved) {
            boolean backgroundLocationPermissionApproved =
                    ActivityCompat.checkSelfPermission(activity,
                            Manifest.permission.ACCESS_FINE_LOCATION)
                            == PackageManager.PERMISSION_GRANTED;

            if (backgroundLocationPermissionApproved) {
                // App can access location both in the foreground and in the background.
                // Start your service that doesn't have a foreground service type
                // defined.
            } else {
                // App can only access location in the foreground. Display a dialog
                // warning the user that your app must have all-the-time access to
                // location in order to function properly. Then, request background
                // location.
                ActivityCompat.requestPermissions(activity, new String[] {
                                Manifest.permission.ACCESS_FINE_LOCATION},
                        200);
            }
        } else {
            // App doesn't have access to the device's location at all. Make full request
            // for permission.
            ActivityCompat.requestPermissions(activity, new String[] {
                            Manifest.permission.ACCESS_COARSE_LOCATION,
                            Manifest.permission.ACCESS_FINE_LOCATION
                    },
                    201);
        }
        state.set(CREATED);
    }

    @Override
    public void onActivityStarted(Activity activity) {
        if (activity.hashCode() != registrarActivityHashCode) {
            return;
        }
        state.set(STARTED);
    }

    @Override
    public void onActivityResumed(Activity activity) {
        if (activity.hashCode() != registrarActivityHashCode) {
            return;
        }
        state.set(RESUMED);
    }

    @Override
    public void onActivityPaused(Activity activity) {
        if (activity.hashCode() != registrarActivityHashCode) {
            return;
        }
        state.set(PAUSED);
    }

    @Override
    public void onActivityStopped(Activity activity) {
        if (activity.hashCode() != registrarActivityHashCode) {
            return;
        }
        state.set(STOPPED);
    }

    @Override
    public void onActivitySaveInstanceState(Activity activity, Bundle bundle) {

    }

    @Override
    public void onActivityDestroyed(Activity activity) {
        if (activity.hashCode() != registrarActivityHashCode) {
            return;
        }
        activity.getApplication().unregisterActivityLifecycleCallbacks(this);
        state.set(DESTROYED);
    }

    @Override
    public void onCreate(@NonNull LifecycleOwner owner) {
        state.set(CREATED);
    }

    @Override
    public void onStart(@NonNull LifecycleOwner owner) {
        state.set(STARTED);
    }

    @Override
    public void onResume(@NonNull LifecycleOwner owner) {
        state.set(RESUMED);
    }

    @Override
    public void onPause(@NonNull LifecycleOwner owner) {
        state.set(PAUSED);
    }

    @Override
    public void onStop(@NonNull LifecycleOwner owner) {
        state.set(STOPPED);
    }

    @Override
    public void onDestroy(@NonNull LifecycleOwner owner) {
        state.set(DESTROYED);
    }

}

package hamza.dali.flutter_osm_plugin;

import android.app.Activity;
import android.app.Application;
import android.content.Context;

import androidx.lifecycle.Lifecycle;

import java.util.concurrent.atomic.AtomicInteger;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MessageCodec;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

public class OsmFactory extends PlatformViewFactory {

    private final PluginRegistry.Registrar registrar;
    private final AtomicInteger mActivityState;
    private final BinaryMessenger binaryMessenger;
    private final Application application;
    private final Activity activity;
    private final int activityHashCode;
    private final Lifecycle lifecycle;

    public OsmFactory( AtomicInteger state,
                      BinaryMessenger binaryMessenger,
                      Application application,
                      Lifecycle lifecycle,
                      Activity activity,
                      int activityHashCode,
                       PluginRegistry.Registrar registrar) {
        super(StandardMessageCodec.INSTANCE);
        this.registrar=registrar;
        this.mActivityState=state;
        this.binaryMessenger=binaryMessenger;
        this.application=application;
        this.activity=activity;
        this.activityHashCode=activityHashCode;
        this.lifecycle=lifecycle;
    }

    @Override
    public PlatformView create(Context context, int viewId, Object args) {
        FlutterOsmView flutterOsmView= new FlutterOsmView(context, registrar,
                binaryMessenger, viewId,
                mActivityState, application,activity,
                lifecycle,activityHashCode);
         flutterOsmView.init();
        return flutterOsmView;
    }
}

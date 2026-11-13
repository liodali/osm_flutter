# Only enabled for -PintegrationTestBuildType=release. Android loads this class
# by name from the test APK manifest, but integration_test also puts it on the
# app's runtime classpath. Preserve its name and reflective constructor in R8.
-keep class androidx.test.runner.AndroidJUnitRunner {
    public <init>();
}

# JUnit resolves @RunWith from the separately compiled test APK. The app shrink
# cannot see that annotation or the reflective constructor call.
-keep class dev.flutter.plugins.integration_test.FlutterTestRunner {
    public <init>(java.lang.Class);
}

# This constructor is called only by the test APK; keep it in the app too.
-keep class androidx.test.rule.ActivityTestRule {
    public <init>(java.lang.Class, boolean, boolean);
}

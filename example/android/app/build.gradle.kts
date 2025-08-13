import com.android.sdklib.AndroidVersion.VersionCodes.BAKLAVA
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}
val keystoreProperties =  Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
android {
    namespace = "hamza.dali.flutter_osm_plugin_example"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    if (keystorePropertiesFile.exists()) {
        signingConfigs {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "hamza.dali.flutter_osm_plugin_example"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 30
        targetSdk = BAKLAVA
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        if(keystorePropertiesFile.exists()){
            release {
                signingConfig = signingConfigs.getByName("release")
            }
        }else {
            release {
                signingConfig = signingConfigs.getByName("debug")
            }
        }

    }
}

flutter {
    source = "../.."
}

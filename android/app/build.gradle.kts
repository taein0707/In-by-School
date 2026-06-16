plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ocl.ocl_study"
    compileSdk = flutter.compileSdkVersion
    // Match the NDK version required by the Firebase / notification plugins.
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Required by flutter_local_notifications (Java 8+ time APIs).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.ocl.ocl_study"
        minSdk = 23 // Firebase Auth requires API 23+
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring runtime — needed by flutter_local_notifications.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

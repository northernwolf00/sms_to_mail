// Reference app-level Gradle config. If you generated the Android scaffold with
// `flutter create .`, MERGE these values into the generated build.gradle.kts
// (don't blindly overwrite — keep the Flutter plugin blocks it creates).
plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after Android & Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.northernwolf.relay"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.northernwolf.relay"
        // Flutter manages this (currently 24), which covers the battery-
        // optimization + notification APIs this app uses. Set a literal value
        // here only if you need to force a different floor.
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // For personal sideloading, signing with the debug key is fine.
            // Replace with your own keystore if you prefer.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

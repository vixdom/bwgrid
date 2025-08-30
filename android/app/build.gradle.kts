import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropsFile = rootProject.file("key.properties")
val keystoreProps = Properties().apply {
    if (keystorePropsFile.exists()) {
        load(keystorePropsFile.inputStream())
    } else {
        logger.warn("key.properties not found at ${keystorePropsFile.absolutePath}. Release signing will not be configured.")
    }
}

android {
    namespace = "com.moviemasala.wordsearch"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Icons are now stored directly under src/main/res/mipmap-*/ic_launcher.png

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.moviemasala.wordsearch"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        // 🚨 MANUALLY bump these for every Play Store upload
        versionCode = 6
        versionName = "1.0.8"
    }

    signingConfigs {
        create("release") {
            val store = keystoreProps["storeFile"] as String?
            val storePass = keystoreProps["storePassword"] as String?
            val alias = keystoreProps["keyAlias"] as String?
            val keyPass = keystoreProps["keyPassword"] as String?

            if (store.isNullOrBlank() || storePass.isNullOrBlank() || alias.isNullOrBlank() || keyPass.isNullOrBlank()) {
                logger.warn("Release signing config not fully specified in key.properties; using unsigned release.")
            } else {
                storeFile = file(store)
                storePassword = storePass
                keyAlias = alias
                keyPassword = keyPass
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            isDebuggable = false
            ndk {
                debugSymbolLevel = "none"
            }
        }
        getByName("debug") {
            isDebuggable = true
        }
    }
}

flutter {
    source = "../.."
}
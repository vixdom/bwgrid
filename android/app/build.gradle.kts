import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
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

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.moviemasala.wordsearch"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = 9
        versionName = "1.2.1"
        multiDexEnabled = true
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

    packagingOptions {
        jniLibs.keepDebugSymbols.add("**/*.so")
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        debug {
            isDebuggable = true
            applicationIdSuffix = ".debug"
        }
    }
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("androidx.core:core-ktx:1.12.0")
    // Removed deprecated Play Core deps (core/core-ktx) that are incompatible with targetSdk 34
    // If you need in-app updates or review, use:
    // implementation("com.google.android.play:app-update:2.1.0")
    // implementation("com.google.android.play:review:2.0.1")
    // Play Core dependency removed for Play Store compliance. If you need in-app updates or reviews, use:
    // implementation("com.google.android.play:app-update:2.1.0")
    // implementation("com.google.android.play:review:2.0.1")
}

flutter {
    source = "../.."
}
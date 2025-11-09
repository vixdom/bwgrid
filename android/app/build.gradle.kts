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
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    defaultConfig {
        applicationId = "com.moviemasala.wordsearch"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        // Align with pubspec.yaml if properties are provided by Flutter tooling
        val flutterVersionCode = project.findProperty("flutter.versionCode")?.toString()?.toIntOrNull()
        val flutterVersionName = project.findProperty("flutter.versionName")?.toString()
    versionCode = flutterVersionCode ?: 2
        versionName = flutterVersionName ?: "2.1.0"
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

    // Packaging: let Gradle strip release native libs and produce proper symbols
    // We avoid keepDebugSymbols to prevent conflicts during AAB build.

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // Generate native symbols for Play Console (smaller than FULL)
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
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
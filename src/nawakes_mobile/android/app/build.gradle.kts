import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is driven by android/key.properties (git-ignored, never
// commit it). Required keys: storeFile, storePassword, keyAlias, keyPassword.
// Without a valid keystore the release build FAILS rather than silently
// debug-signing, so an artifact can never be mistaken for a production release.
// For a disposable local trial build only, set NAWAQS_ALLOW_DEBUG_SIGNING=true.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.nawakes.nawakes_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.nawakes.nawakes_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                val alias = keystoreProperties.getProperty("keyAlias")
                val keyPass = keystoreProperties.getProperty("keyPassword")
                val storePass = keystoreProperties.getProperty("storePassword")
                val storePath = keystoreProperties.getProperty("storeFile")
                require(alias != null && keyPass != null && storePass != null && storePath != null) {
                    "android/key.properties is missing one of storeFile, storePassword, keyAlias, keyPassword."
                }
                keyAlias = alias
                keyPassword = keyPass
                storeFile = file(storePath)
                storePassword = storePass
            }
        }
    }

    buildTypes {
        release {
            // Never ship a debug-signed release: fail the build if the keystore
            // is missing. Set NAWAQS_ALLOW_DEBUG_SIGNING=true only for a local
            // trial build; artifacts from that path are not releasable.
            // The check is deferred to assembly time so debug builds (and any
            // Gradle task that only reads the configuration) still work on a
            // machine without signing keys.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else if (System.getenv("NAWAQS_ALLOW_DEBUG_SIGNING") == "true") {
                logger.warn(
                    "WARNING: release build is using the debug keystore. " +
                        "Do not distribute this artifact. Configure android/key.properties."
                )
                signingConfigs.getByName("debug")
            } else {
                // Null here; the guard below fails the release task with a
                // clear message instead of breaking every Gradle invocation.
                null
            }
            // R8 code + resource shrinking for smaller, obfuscated release builds
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

// Fail only when a release artifact is actually being assembled without a
// configured keystore. Debug/profile builds and IDE sync are unaffected.
tasks.configureEach {
    if (name.startsWith("assembleRelease") || name.startsWith("bundleRelease")) {
        doFirst {
            if (!hasReleaseKeystore && System.getenv("NAWAQS_ALLOW_DEBUG_SIGNING") != "true") {
                throw GradleException(
                    "Release signing is not configured. Create " +
                        "${keystorePropertiesFile.absolutePath} with storeFile, " +
                        "storePassword, keyAlias and keyPassword. For a throwaway " +
                        "local build, set NAWAQS_ALLOW_DEBUG_SIGNING=true."
                )
            }
        }
    }
}

flutter {
    source = "../.."
}

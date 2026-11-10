import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.pratiyush.readle"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications (the daily reminder) uses java.time on older Android.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.pratiyush.readle"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Debug and profile: Google's sample AdMob app id (the release build type sets Readle's).
        manifestPlaceholders["admobAppId"] = "ca-app-pub-3940256099942544~3347511713"
    }

    // The upload key: android/key.properties (git-ignored; storeFile, storePassword, keyAlias,
    // keyPassword), or the file READLE_KEY_PROPERTIES names. Without it a release build is
    // debug-signed: fine on a test device, refused by tool/release.sh and by Play.
    val keyFile = System.getenv("READLE_KEY_PROPERTIES")?.let(::file) ?: rootProject.file("key.properties")
    val uploadKey = keyFile.takeIf { it.exists() }?.let { f -> Properties().apply { f.inputStream().use(::load) } }
    signingConfigs {
        if (uploadKey != null) {
            create("upload") {
                storeFile = keyFile.parentFile.resolve(uploadKey.getProperty("storeFile"))
                storePassword = uploadKey.getProperty("storePassword")
                keyAlias = uploadKey.getProperty("keyAlias")
                keyPassword = uploadKey.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Readle's AdMob app (hub German/docs/admob-ids.json, verified 2026-11-08).
            manifestPlaceholders["admobAppId"] = "ca-app-pub-5964569110696877~7982698610"
            signingConfig = signingConfigs.findByName("upload") ?: signingConfigs.getByName("debug")
            // R8: plugins reached through JNI are kept by proguard-rules.pro (google_mobile_ads pulls in
            // WorkManager/Room, whose known release-build crash those rules prevent).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // java.time for flutter_local_notifications on Android < 8 (see compileOptions).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

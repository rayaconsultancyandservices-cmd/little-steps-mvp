plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.little_steps_mvp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // हा आयडी flavors मध्ये override होतो, म्हणून तसाच ठेवला आहे.
        applicationId = "com.example.little_steps_mvp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ===== नवीन: Teacher आणि Parent चे वेगळे flavors =====
    flavorDimensions += "role"

    productFlavors {
        create("teacher") {
            dimension = "role"
            applicationId = "com.example.little_steps_mvp.teacher"
            manifestPlaceholders["appName"] = "Little Steps Teacher"
        }
        create("parent") {
            dimension = "role"
            applicationId = "com.example.little_steps_mvp.parent"
            manifestPlaceholders["appName"] = "Little Steps Parent"
        }
    }
    // =====================================================

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
            ?: throw GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")
        flutterSdkPath
    }
    settings.extra["flutterSdkPath"] = flutterSdkPath

    includeBuild("${settings.extra["flutterSdkPath"]}/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.22" apply false
}

include(":app")

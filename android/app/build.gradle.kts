plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.datedash"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.datedash"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

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

// Fix Agora SDK namespace conflict: both iris-rtc and agora-special-full
// declare package="io.agora.rtc" which AGP 8+ rejects as duplicate.
// Patch iris-rtc's cached manifest to use a unique namespace before merging.
tasks.matching {
    it.name.contains("processDebugMainManifest") ||
    it.name.contains("processReleaseMainManifest") ||
    it.name.contains("processProfileMainManifest")
}.configureEach {
    doFirst {
        val transformsDir = File(gradle.gradleUserHomeDir, "caches")
            .listFiles()
            ?.filter { it.isDirectory && it.name.matches(Regex("\\d+\\.\\d+(\\.\\d+)?")) }
            ?.flatMap { versionDir ->
                val tDir = File(versionDir, "transforms")
                if (tDir.exists()) listOf(tDir) else emptyList()
            } ?: emptyList()

        for (tDir in transformsDir) {
            tDir.walkTopDown()
                .filter {
                    it.name == "AndroidManifest.xml" &&
                    it.absolutePath.contains("iris-rtc") &&
                    !it.absolutePath.contains("agora-special")
                }
                .forEach { manifest ->
                    val content = manifest.readText()
                    if (content.contains("package=\"io.agora.rtc\"")) {
                        manifest.writeText(
                            content.replace(
                                "package=\"io.agora.rtc\"",
                                "package=\"io.agora.rtc.iris\""
                            )
                        )
                    }
                }
        }
    }
}

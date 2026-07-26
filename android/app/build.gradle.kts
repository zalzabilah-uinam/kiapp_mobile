plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.sosmeddownloader.sosmed_downloader"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.sosmeddownloader.sosmed_downloader"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Resolve keystore dari salah satu sumber, urutan prioritas:
            //  1. Gradle property KEYSTORE_FILE  (dari -PKEYSTORE_FILE=… via workflow)
            //  2. android/key.properties         (lokal, di-.gitignore)
            //  3. <rootDir>/keystore.jks        (di-copy workflow ke repo root)
            val propsFile = rootProject.file("key.properties")
            val localCfg = if (propsFile.exists()) {
                java.util.Properties().apply { propsFile.inputStream().use { load(it) } }
            } else null

            val ksFile = (project.findProperty("KEYSTORE_FILE") as String?)
                ?: localCfg?.getProperty("storeFile")
                ?: "$rootDir/keystore.jks"

            if (file(ksFile).exists()) {
                storeFile = file(ksFile)
                storePassword = (project.findProperty("KEYSTORE_PASSWORD") as String?)
                    ?: localCfg?.getProperty("storePassword")
                    ?: ""
                keyAlias = (project.findProperty("KEY_ALIAS") as String?)
                    ?: localCfg?.getProperty("keyAlias")
                    ?: ""
                keyPassword = (project.findProperty("KEY_PASSWORD") as String?)
                    ?: localCfg?.getProperty("keyPassword")
                    ?: ""
            }
        }
    }

    buildTypes {
        release {
            val propsFile = rootProject.file("key.properties")
            val localCfg = if (propsFile.exists()) {
                java.util.Properties().apply { propsFile.inputStream().use { load(it) } }
            } else null
            val ksFile = (project.findProperty("KEYSTORE_FILE") as String?)
                ?: localCfg?.getProperty("storeFile")
                ?: "$rootDir/keystore.jks"
            signingConfig = if (file(ksFile).exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

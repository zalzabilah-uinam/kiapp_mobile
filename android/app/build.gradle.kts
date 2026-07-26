import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Resolve keystore config dari salah satu sumber, urutan prioritas:
//   1. Gradle property KEYSTORE_FILE/KEYSTORE_PASSWORD/KEY_ALIAS/KEY_PASSWORD
//      (di-pass via -PKEYSTORE_FILE=… dari GitHub Actions workflow)
//   2. android/key.properties (lokal, di-.gitignore)
//   3. <rootDir>/keystore.jks  (default fallback kalau workflow copy keystore ke repo root)
fun resolveKeyCfg(project: org.gradle.api.Project): KeyCfg {
    val propsFile = project.rootProject.file("key.properties")
    val localCfg: Properties? = if (propsFile.exists()) {
        Properties().apply { propsFile.inputStream().use { stream -> load(stream) } }
    } else null

    fun p(key: String): String? = project.findProperty(key) as String?

    val ksFile = p("KEYSTORE_FILE")
        ?: localCfg?.getProperty("storeFile")
        ?: "${project.rootDir}/keystore.jks"

    val exists = project.file(ksFile).exists()
    return KeyCfg(
        storeFilePath = if (exists) ksFile else null,
        storePassword = p("KEYSTORE_PASSWORD")
            ?: localCfg?.getProperty("storePassword")
            ?: "",
        keyAlias = p("KEY_ALIAS")
            ?: localCfg?.getProperty("keyAlias")
            ?: "",
        keyPassword = p("KEY_PASSWORD")
            ?: localCfg?.getProperty("keyPassword")
            ?: "",
    )
}

data class KeyCfg(
    val storeFilePath: String?,
    val storePassword: String,
    val keyAlias: String,
    val keyPassword: String,
)

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
        applicationId = "com.sosmeddownloader.sosmed_downloader"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val cfg = resolveKeyCfg(project)
            if (cfg.storeFilePath != null) {
                storeFile = file(cfg.storeFilePath)
                storePassword = cfg.storePassword
                keyAlias = cfg.keyAlias
                keyPassword = cfg.keyPassword
            }
        }
    }

    buildTypes {
        release {
            val cfg = resolveKeyCfg(project)
            signingConfig = if (cfg.storeFilePath != null) {
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

import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// android/key.properties (gitignored), ticket env vars, or legacy RELEASE_* env vars.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
fun releaseProp(name: String): String? {
    keyProps.getProperty(name)?.takeIf { it.isNotBlank() }?.let { return it }

    val ticketEnvName = when (name) {
        "storeFile" -> "KEYSTORE_PATH"
        "storePassword" -> "KEYSTORE_PASSWORD"
        "keyAlias" -> "KEY_ALIAS"
        "keyPassword" -> "KEY_PASSWORD"
        else -> null
    }
    ticketEnvName?.let { System.getenv(it)?.takeIf { value -> value.isNotBlank() } }
        ?.let { return it }

    val legacyEnvName = "RELEASE_" + name.replace(Regex("([A-Z])"), "_$1").uppercase()
    System.getenv(legacyEnvName)?.takeIf { it.isNotBlank() }?.let { return it }

    return if (name == "storeFile") "keystore/release.jks" else null
}
val hasReleaseKey = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !releaseProp(it).isNullOrBlank() }

android {
    namespace = "com.secretbase.secret_base_app"
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
        applicationId = "com.secretbase.secret_base_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(releaseProp("storeFile")!!)
                storePassword = releaseProp("storePassword")
                keyAlias = releaseProp("keyAlias")
                keyPassword = releaseProp("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Release keystore if configured; otherwise fall back to debug signing
            // so `flutter run --release` and CI without secrets keep working.
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

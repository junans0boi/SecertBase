import java.util.Properties
import java.io.File

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Keep existing signing material in place, including in another worktree.
val externalKeyPropsPath = System.getenv("KEYSTORE_PROPERTIES_PATH")?.takeIf { it.isNotBlank() }
val keyPropsFile = externalKeyPropsPath?.let { rootProject.file(it) }
    ?: rootProject.file("key.properties")
val keyProps = Properties().apply {
    if (keyPropsFile.isFile) keyPropsFile.inputStream().use { load(it) }
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
// Relative storeFile paths belong to the properties file's directory, not app/.
val releaseStoreFile = releaseProp("storeFile")?.let { storePath ->
    val candidate = File(storePath)
    if (candidate.isAbsolute) candidate else File(keyPropsFile.parentFile, storePath)
}
val hasReleaseKey = (externalKeyPropsPath == null || keyPropsFile.isFile) &&
    releaseStoreFile?.isFile == true &&
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !releaseProp(it).isNullOrBlank() }
val allowDebugReleaseSigning = System.getenv("ALLOW_DEBUG_RELEASE_SIGNING") == "true"

// Configuration, signingReport and debug builds remain usable without secrets.
// Any release packaging (APK, AAB, flavor or install) must have signing material.
gradle.taskGraph.whenReady {
    val packagesRelease = allTasks.any { task ->
        task.project == project && task.name.contains("Release") &&
            listOf("assemble", "bundle", "package", "install").any { task.name.startsWith(it) }
    }
    if (packagesRelease && !hasReleaseKey && !allowDebugReleaseSigning) {
        throw GradleException(
            "Release signing is missing or incomplete. Set KEYSTORE_PROPERTIES_PATH " +
                "to the existing properties file, or provide KEYSTORE_PATH, " +
                "KEYSTORE_PASSWORD, KEY_ALIAS and KEY_PASSWORD. " +
                "ALLOW_DEBUG_RELEASE_SIGNING=true is for local testing only."
        )
    }
}

android {
    namespace = "com.secretbase.secret_base_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
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
                storeFile = releaseStoreFile
                storePassword = releaseProp("storePassword")
                keyAlias = releaseProp("keyAlias")
                keyPassword = releaseProp("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else if (allowDebugReleaseSigning) {
                signingConfigs.getByName("debug")
            } else {
                null
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// FCM: only wire Firebase when the human has supplied google-services.json,
// so the build keeps working without it.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

flutter {
    source = "../.."
}

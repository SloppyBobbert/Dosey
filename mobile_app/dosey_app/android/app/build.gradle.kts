plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun dotenvValue(key: String): String? {
    val dotenv = rootProject.file("../.env")
    if (!dotenv.isFile) return null
    return dotenv.readLines()
        .firstOrNull { it.trimStart().startsWith("$key=") }
        ?.substringAfter('=')
        ?.trim()
        ?.trim('"', '\'')
        ?.takeIf { it.isNotEmpty() }
}

android {
    namespace = "com.sloppybobbert.dosey_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.sloppybobbert.dosey_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // The callback scheme must match Appwrite's project-specific OAuth
        // scheme, but the project ID remains in the ignored local .env file.
        manifestPlaceholders["appwriteCallbackScheme"] =
            "appwrite-callback-${dotenvValue("APPWRITE_PROJECT_ID") ?: "not-configured"}"
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

import java.util.Base64
import org.gradle.api.Action
import org.gradle.api.execution.TaskExecutionGraph

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

val requiredPublicKeys = listOf(
    "APPWRITE_ENDPOINT",
    "APPWRITE_PROJECT_ID",
    "APPWRITE_CREATE_PAIRING_CODE_FUNCTION_ID",
    "APPWRITE_CLAIM_ROBOT_FUNCTION_ID",
)
val publicConfiguration = requiredPublicKeys.associateWith { key -> dotenvValue(key) }
val dartDefines = providers.gradleProperty("dart-defines").orNull
    ?.split(',')
    ?.mapNotNull { encoded ->
        runCatching { String(Base64.getDecoder().decode(encoded)) }.getOrNull()
    }
    ?.associate { define -> define.substringBefore('=') to define.substringAfter('=', "") }
    .orEmpty()
val configuredProfile = dartDefines["DOSEY_BUILD_PROFILE"]
val configuredRuntimeCapability = dartDefines["DOSEY_RUNTIME_CAPABILITY"]

val keystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
val keystorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
val keyAliasValue = System.getenv("ANDROID_KEY_ALIAS")
val keyPasswordValue = System.getenv("ANDROID_KEY_PASSWORD")
val signingValues = listOf(keystorePath, keystorePassword, keyAliasValue, keyPasswordValue)

gradle.taskGraph.whenReady(Action<TaskExecutionGraph> {
    val resolvedTasks = allTasks.map { it.path.lowercase() }
    val variantTasks = resolvedTasks.map { it.substringAfterLast(':') }
    val requestedFlavors = buildSet {
        if (variantTasks.any { it.startsWith("assemblepersonal") || it.startsWith("bundlepersonal") }) {
            add("personal")
        }
        if (variantTasks.any { it.startsWith("assemblerobot") || it.startsWith("bundlerobot") }) {
            add("robot")
        }
    }
    if (requestedFlavors.isNotEmpty()) {
        val missingKeys = publicConfiguration.filterValues { it == null }.keys
        if (missingKeys.isNotEmpty()) {
            throw GradleException(
                "Missing required public Appwrite values in .env: ${missingKeys.joinToString()}",
            )
        }
        if (configuredProfile !in setOf("personal", "robot")) {
            throw GradleException(
                "DOSEY_BUILD_PROFILE must be explicitly set to personal or robot for Android flavor builds.",
            )
        }
        if (requestedFlavors.size != 1 || configuredProfile !in requestedFlavors) {
            throw GradleException(
                "Android flavor '${requestedFlavors.joinToString()}' does not match " +
                    "DOSEY_BUILD_PROFILE='$configuredProfile'.",
            )
        }
        if (configuredProfile == "robot" && configuredRuntimeCapability != "phone-only") {
            throw GradleException(
                "Android Robot builds require DOSEY_RUNTIME_CAPABILITY=phone-only.",
            )
        }
        if (configuredProfile == "personal" && configuredRuntimeCapability != "hardware-assisted") {
            throw GradleException(
                "Android Personal builds require DOSEY_RUNTIME_CAPABILITY=hardware-assisted.",
            )
        }
        if (variantTasks.any { (it.startsWith("assemble") || it.startsWith("bundle")) && "release" in it } &&
            signingValues.any { it == null }
        ) {
            throw GradleException(
                "Release signing requires ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD, " +
                    "ANDROID_KEY_ALIAS, and ANDROID_KEY_PASSWORD.",
            )
        }
    }
})

android {
    namespace = "com.sloppybobbert.dosey_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    flavorDimensions += "distribution"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.sloppybobbert.dosey_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    productFlavors {
        create("personal") {
            dimension = "distribution"
            manifestPlaceholders["appwriteCallbackScheme"] =
                "appwrite-callback-${publicConfiguration["APPWRITE_PROJECT_ID"] ?: "not-configured"}"
        }
        create("robot") {
            dimension = "distribution"
            applicationIdSuffix = ".robot"
        }
    }

    signingConfigs {
        if (signingValues.all { it != null }) {
            create("release") {
                storeFile = file(keystorePath!!)
                storePassword = keystorePassword
                keyAlias = keyAliasValue
                keyPassword = keyPasswordValue
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
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

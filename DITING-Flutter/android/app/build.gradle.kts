import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: android/key.properties or the DITING_KEY* env vars in CI; neither is committed.
val keystorePropertiesFile: File = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

val releaseStoreFilePath: String? = keystoreProperties.getProperty("storeFile")
    ?: System.getenv("DITING_KEYSTORE_FILE")
val releaseStorePassword: String? = keystoreProperties.getProperty("storePassword")
    ?: System.getenv("DITING_KEYSTORE_PASSWORD")
val releaseKeyAlias: String? = keystoreProperties.getProperty("keyAlias")
    ?: System.getenv("DITING_KEY_ALIAS")
val releaseKeyPassword: String? = keystoreProperties.getProperty("keyPassword")
    ?: System.getenv("DITING_KEY_PASSWORD")

// Relative paths resolve against the key.properties dir, then the android root, then the app dir.
val releaseKeystoreFile: File? = releaseStoreFilePath?.let { path ->
    val fromPropDir = File(keystorePropertiesFile.parentFile, path)
    val fromAndroidRoot = rootProject.file(path)
    val fromAppDir = file(path)
    when {
        fromPropDir.exists() -> fromPropDir
        fromAndroidRoot.exists() -> fromAndroidRoot
        fromAppDir.exists() -> fromAppDir
        else -> null
    }
}

val hasReleaseSigning: Boolean = releaseKeystoreFile != null &&
    releaseKeystoreFile.exists() &&
    !releaseStorePassword.isNullOrBlank() &&
    !releaseKeyAlias.isNullOrBlank()

// Debug signed with the release key: else INSTALL_FAILED_UPDATE_INCOMPATIBLE over a release build.
val signDebugWithRelease: Boolean =
    project.findProperty("signDebugWithRelease")?.toString()?.let {
      it.isBlank() || it == "true" || it == "1"
    } ?: true

android {
    namespace = "com.haoze.diting"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.haoze.diting"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Version code from pubspec.yaml; split APKs add 1000 * ABI_VERSION unless overridden.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseKeystoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword ?: releaseStorePassword
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        debug {
            if (signDebugWithRelease) {
                signingConfigs.findByName("release")?.let { signingConfig = it }
            }
        }
        release {
            // Release key when available, else debug so `flutter run --release` works.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// libs/tunnel.aar is arm64-only; drop the other ABIs at jniLibs, abiFilters gets overwritten.


val splitPerAbi: Boolean =
    project.findProperty("split-per-abi")?.toString()?.toBoolean() ?: false
androidComponents {
    onVariants { variant ->
        if (variant.name == "release" && !splitPerAbi) {
            variant.packaging.jniLibs.excludes.addAll(
                "**/armeabi-v7a/**",
                "**/x86_64/**",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// Copies each assembled APK to a versioned name, so releases do not overwrite the base one.
val apkVersionName: String = project.findProperty("ditingApkVersionName")?.toString()
    ?: run {
        val pubspec = rootProject.file("../pubspec.yaml")
        val match = Regex("^version:\\s*([^+\\s]+)", RegexOption.MULTILINE)
            .find(pubspec.readText())
        match?.groupValues?.get(1) ?: "unknown"
    }
if (!splitPerAbi) {
    listOf("debug", "release").forEach { buildType ->
        val capitalized = buildType.replaceFirstChar { it.uppercase() }
        val copyTask = tasks.register<Copy>("copy${capitalized}ApkWithVersion") {
            from(layout.buildDirectory.dir("outputs/apk/$buildType")) {
                include("app-$buildType.apk")
            }
            rename { "DITING-$buildType-v$apkVersionName.apk" }
            into(layout.buildDirectory.dir("outputs/apk/versioned/$buildType"))
        }
        tasks.configureEach {
            if (name == "assemble$capitalized") {
                finalizedBy(copyTask)
            }
        }
    }
}

dependencies {
    // Go userspace tunnel (gomobile AAR); x86_64 emulators need -PtunnelAar=libs/tunnel-debug.aar.
    val tunnelAar = project.findProperty("tunnelAar")?.toString() ?: "libs/tunnel.aar"
    implementation(files(tunnelAar))
}

flutter {
    source = "../.."
}

import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ==============================================================================
// Release 签名（从 android/key.properties 读取；缺失时自动回退 debug 签名）
// ==============================================================================
// 密钥与口令**不入库**：`android/.gitignore` 排除了 `key.properties`，
// 根 `.gitignore` 排除了 `keystore/` 与 `*.jks`。
// CI 可用环境变量覆盖，避免把凭据写进磁盘：
//   DITING_KEYSTORE_FILE / DITING_KEYSTORE_PASSWORD / DITING_KEY_ALIAS / DITING_KEY_PASSWORD
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

// 相对路径按「key.properties 所在目录 → android 根 → app 目录」依次尝试，
// 这样同一份 key.properties 无论以哪种基准写路径都能解析到。
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

// `-PsignDebugWithRelease` 让 debug 构建也用 release 密钥签名。
// 默认开启：debug 包要能覆盖安装已发布的正式版（同签名），否则装上就报
// INSTALL_FAILED_UPDATE_INCOMPATIBLE，真机联调只能先卸正式版、丢数据。
// 裸仓库（无密钥）时 hasReleaseSigning 为 false，自然回退 debug 密钥。
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
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
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
            // 有正式密钥就用正式密钥；没有则退回 debug 密钥，
            // 保证 `flutter run --release` 在裸仓库上依然可跑。
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// ==============================================================================
// Release 只打 arm64-v8a，显著缩小安装包（约 60MB → 35MB）
// ==============================================================================
// 随包 Go 引擎 `libs/tunnel.aar` 里的 `libgojni.so` **只有 arm64-v8a**（README §2）。
// 但 `flutter build apk --release` 默认把 libflutter.so / libapp.so 的
// armeabi-v7a 与 x86_64 副本也一起塞进包，这两个 ABI 的引擎副本真机加载不了、
// 装上了也用不了，只是白白多出约 25MB。
//
// 这里在 release variant 的 jniLibs 打包层排除这两个 ABI 目录。之所以放在
// androidComponents.onVariants 而不是 defaultConfig.ndk.abiFilters：Flutter 的
// Gradle 插件会在 variant 阶段把 abiFilters 重置成 `--target-platform` 的平台集
// （见 FlutterPlugin.configureAbiWithoutSplits），defaultConfig 里的设置会被覆盖；
// 而 jniLibs 的 excludes 只剔除产物里的目录，不改编译目标，且仅作用于 release。
//
// 不影响调试/模拟器：debug 构建不经过这里，仍带 x86_64，模拟器联调照旧
// （README §2）。如需一个能装 32 位机的包，改用 `--split-per-abi` 单独出 32 位包
// （但 Go 引擎仍只支持 arm64）。`--split-per-abi` 时保持原行为、不在此剔除，否则
// 会把 32 位分包的 so 也删空（与 FlutterPlugin.shouldProjectSplitPerAbi 同判据）。
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

// ==============================================================================
// 版本化产物命名（对齐 DITING-Legacy 的 copy${BuildType}ApkWithVersion）
// ==============================================================================
// Flutter 产出的包名固定是 `app-<buildType>.apk`，多次发版后会互相覆盖，也不
// 知道手上这个是哪个版本。这里在 assemble 之后复制一份到
// `build/outputs/apk/versioned/<buildType>/DITING-<buildType>-v<versionName>.apk`，
// 与旧版归档习惯一致（例如 DITING-release-v2.0.0.apk）。
//
// 版本号取自 pubspec.yaml，不在 Gradle 里再写一遍，免得两处漂移。`--split-per-abi`
// 时 Flutter 会产出带 ABI 后缀的多个包，本任务只处理不分包的基础包（已在外层
// 用 splitPerAbi 跳过）。
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
    // Go userspace tunnel (gomobile AAR) reused unchanged from 1.4.3.
    // Local x86_64 emulators need an amd64 build; pass
    // -PtunnelAar=libs/tunnel-debug.aar to swap it in without touching the
    // shipped arm64 artifact.
    val tunnelAar = project.findProperty("tunnelAar")?.toString() ?: "libs/tunnel.aar"
    implementation(files(tunnelAar))
}

flutter {
    source = "../.."
}

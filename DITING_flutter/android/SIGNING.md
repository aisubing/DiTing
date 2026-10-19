# Android 签名与 APK 编译

本目录的签名配置与编译脚本，从原生工程 `Android/` 迁移而来，适配 Flutter 构建流程。

## 文件

| 文件 | 是否入库 | 说明 |
|---|---|---|
| `app/build.gradle.kts` | ✅ 入库 | 读取签名配置，装配 `signingConfigs.release` |
| `build_apk.bat`（在 `DITING_flutter/` 下） | ✅ 入库 | 菜单式编译/安装脚本 |
| `key.properties` | ❌ **不入库** | 密钥路径与口令 |
| `keystore/diting-release.jks` | ❌ **不入库** | 私钥本体 |

两个敏感文件已被忽略：

- `android/.gitignore` 的 `key.properties`
- 根 `.gitignore` 的 `keystore/` 与 `*.jks`

验证命令（应输出两行匹配，且 `git status` 为空）：

```bash
git check-ignore -v DITING_flutter/android/key.properties DITING_flutter/android/keystore/diting-release.jks
```

## 密钥获取

新克隆仓库里没有这两个文件，需要从备份取回：

```bash
mkdir -p DITING_flutter/android/keystore
cp <备份>/diting-release.jks         DITING_flutter/android/keystore/
cp <备份>/keystore.properties        DITING_flutter/android/key.properties
```

`key.properties` 格式（`storeFile` 相对于 `android/app/`）：

```properties
storeFile=../keystore/diting-release.jks
storePassword=<口令>
keyAlias=diting-release
keyPassword=<口令>
```

CI 上可改用环境变量，避免落盘：`DITING_KEYSTORE_FILE`、`DITING_KEYSTORE_PASSWORD`、
`DITING_KEY_ALIAS`、`DITING_KEY_PASSWORD`。

**缺失时的行为**：`app/build.gradle.kts` 会检测不到密钥并自动回退到 debug 签名，
`flutter build apk --release` 仍然能成功，只是产物签名不是正式的。

## 编译

交互式：

```bat
build_apk.bat
```

菜单项：

| 选项 | 等价命令 |
|---|---|
| `[1]` Debug | `flutter build apk --debug -PsignDebugWithRelease=true` |
| `[2]` Release | `flutter build apk --release` |
| `[3]` Debug (Flutter Key) | `flutter build apk --debug` |
| `[4]` Split per ABI | `flutter build apk --release --split-per-abi` |
| `[5]` Clean | `flutter clean` + `gradlew clean` |

非交互：

```bash
flutter build apk --debug  -PsignDebugWithRelease=true   # 联调用：debug 快，正式签名
flutter build apk --release                              # 发布
```

产物都在 `build/app/outputs/flutter-apk/`。

## 为什么必须走 `flutter build`

原生工程用 `gradlew assembleDebug` 就行；**Flutter 工程不行**——直接调 Gradle 只会
编译 Android 壳，Dart 代码不会被编进 APK，装上去是空壳或闪退。必须由
`flutter build apk` 驱动，它会在调用 Gradle 前先跑 `flutter assemble` 产出 Dart 快照。

## 校验签名

```bash
# 从 keystore 读权威指纹
keytool -list -v -keystore DITING_flutter/android/keystore/diting-release.jks \
        -storepass <口令> -alias diting-release | grep SHA256

# 从 APK 读实际签名
$ANDROID_HOME/build-tools/<ver>/apksigner verify --print-certs \
        DITING_flutter/build/app/outputs/flutter-apk/app-debug.apk
```

两者 SHA-256 一致即正确。**正式密钥的 DN 是 `CN=DITING, OU=DITING Team, O=DITING, C=CN`**；
如果看到 `CN=Android Debug`，说明回退到了 debug 密钥——检查 `android/key.properties`
是否存在、`storeFile` 路径是否解析得到。

当前实测（2026-10-19）：`app-debug.apk` 用 `[1]` 编出的签名 SHA-256 为
`276423e13ac0b3534213c3807491dd22b2abb215a1ae18b7a5681afc636db2f4`，
与 keystore 内证书一致。

## 脚本为什么是纯英文

`build_apk.bat` 里没有中文。Windows 的 `cmd.exe` 按 OEM 代码页（本机 936/GBK）
解析批处理文件，UTF-8 中文会被错切成乱码，把 `if`/`goto` 行截断成非法命令——
表现为一堆 `'xx' is not recognized as an internal or external command`。
`chcp 65001` 写在文件里也救不了，因为脚本解析发生在它生效之前。

中文说明因此放在本文件里。**后续修改 `build_apk.bat` 请保持纯 ASCII。**

## 与原生工程的差异

| 项 | `Android/`（原生） | 本工程（Flutter） |
|---|---|---|
| 构建入口 | `gradlew assembleXxx` | `flutter build apk` |
| 签名属性文件 | `DITING-keystore/keystore.properties` | `android/key.properties` |
| 密钥目录 | `DITING-keystore/` | `android/keystore/` |
| 属性名 | 同名（`storeFile`/`storePassword`/`keyAlias`/`keyPassword`） | 相同 |
| debug 用正式签名 | `-PsignDebugWithRelease=true` | 相同（参数名保持一致） |

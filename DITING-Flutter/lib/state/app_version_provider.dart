/// 应用版本的 provider：唯一真源是 `pubspec.yaml` 的 `version:`。
///
/// 这里只做「取一次、全应用共享」：真正的读取在 [loadAppVersion]（Android 走
/// 包信息，测试 / 桌面读 `pubspec.yaml`）。`main()` 用真实值覆盖本 provider，
/// 因此页面、更新检查、预设播种、清理动作拿到的都是同一个版本，不会各自漂移。
library;

import 'package:diting/data/native/app_version.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 默认实现直接读工作目录的 `pubspec.yaml`：`flutter test` 的 cwd 就是工程根，
/// 所以单元测试里显示的也是真实版本，不需要每个用例 override。
///
/// 设备上没有这个文件时退回 [AppVersion.unknown]（正常构建会被 `main()` 覆盖）。
final appVersionProvider = Provider<AppVersion>(
  (ref) => AppVersion.fromPubspec() ?? AppVersion.unknown,
);

/// 系统域状态：免责声明 / 开发者模式 / WebDAV 连接 / 应用更新 / IP 质量。
///
/// 这里已经是真实实现，不再是「全内存模拟」：
/// - **应用更新**走 GitHub `releases/latest` 真实请求（`AppUpdateChecker`）；
/// - **IP 质量**先取出口 IP 再并发查三个公开情报源（`IpQualityChecker`）；
/// - **WebDAV** 的连接/上传/下载由真实 `dav_client.dart` 完成，本文件只保存
///   连接状态机。
///
/// 曾经的 `AccessControl*`（访问控制白/黑名单草稿）在本轮删除：它只有内存状态、
/// 没有任何页面读它，也没有落盘——是「看起来像功能」的死代码。真正的应用访问
/// 控制在 `app_selection_pages.dart`（落 `dns_vpn_prefs`）与 `app_rules_page`
/// （落规则库 `appScope`），它们才是引擎真正消费的那份数据。
library;

import 'dart:async';

import 'package:diting/data/backup/dav_client.dart';
import 'package:diting/data/native/update_bridge.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/tools/ip_quality_checker.dart';
import 'package:diting/data/update/app_update_checker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// WebDAV 连接状态机。
enum DavStatus {
  idle('未连接'),
  connecting('连接中'),
  connected('连接成功'),
  failed('连接失败');

  const DavStatus(this.label);

  final String label;
}

/// WebDAV 表单与连接结果。
class DavState {
  const DavState({
    this.server = '',
    this.username = '',
    this.password = '',
    this.path = '/diting/',
    this.status = DavStatus.idle,
    this.message,
  });

  final String server;
  final String username;
  final String password;
  final String path;
  final DavStatus status;

  /// 失败原因；只在 [status] 为 [DavStatus.failed] 时非空。
  final String? message;

  bool get isConfigured => server.isNotEmpty && username.isNotEmpty;

  DavState copyWith({
    String? server,
    String? username,
    String? password,
    String? path,
    DavStatus? status,
    String? message,
    bool clearMessage = false,
  }) => DavState(
    server: server ?? this.server,
    username: username ?? this.username,
    password: password ?? this.password,
    path: path ?? this.path,
    status: status ?? this.status,
    message: clearMessage ? null : (message ?? this.message),
  );
}

/// WebDAV 连接状态机；[DavNotifier.test] 发起真实请求。
class DavNotifier extends Notifier<DavState> {
  @override
  DavState build() => const DavState();

  void update(DavState Function(DavState state) update) =>
      state = update(state);

  /// 真连一次：`PROPFIND` 探测目录，不存在就 `MKCOL` 建。
  ///
  /// 上一轮这里是 `await Future.delayed(1.2s)` + 「地址里有没有 fail 字样」——
  /// 服务器倒着也会显示「连接成功」，用户据此以为云备份可用。现在成败由服务器
  /// 的真实响应决定，失败时带上状态码与可操作的原因。
  Future<void> test() async {
    if (!state.isConfigured) {
      state = state.copyWith(
        status: DavStatus.failed,
        message: '服务器地址与用户名不能为空',
      );
      return;
    }
    state = state.copyWith(status: DavStatus.connecting, clearMessage: true);
    final result = await const DavClient().probe(
      DavCredentials(
        server: state.server,
        username: state.username,
        password: state.password,
        path: state.path,
      ),
    );
    if (result.succeeded) {
      state = state.copyWith(
        status: DavStatus.connected,
        message: result.created ? '目录不存在，已自动创建' : null,
      );
      return;
    }
    state = state.copyWith(
      status: DavStatus.failed,
      message: result.error,
    );
  }

  void reset() => state = const DavState();

  /// 云端的备份文件名。固定一个名字 = 「覆盖上一份」，与旧版 WebDAV 表单的语义一致
  /// （它是同步而不是归档，每台设备只保留最新一份）。
  static const remoteFileName = 'diting-config.json';

  DavCredentials get credentials => DavCredentials(
    server: state.server,
    username: state.username,
    password: state.password,
    path: state.path,
  );

  /// 上传：`PUT` 到 `<path>/diting-config.json`。
  Future<DavProbeResult> upload(String content) async {
    state = state.copyWith(status: DavStatus.connecting, clearMessage: true);
    final result = await const DavClient().putText(
      credentials,
      name: remoteFileName,
      content: content,
    );
    state = result.succeeded
        ? state.copyWith(status: DavStatus.connected, message: '已上传到云端')
        : state.copyWith(status: DavStatus.failed, message: result.error);
    return result;
  }

  /// 下载：`GET` 云端备份；云端没有文件时返回 `null`（不是失败）。
  Future<String?> download() async {
    state = state.copyWith(status: DavStatus.connecting, clearMessage: true);
    try {
      final text = await const DavClient().getText(
        credentials,
        name: remoteFileName,
      );
      state = text == null
          ? state.copyWith(
              status: DavStatus.connected,
              message: '云端还没有备份文件',
            )
          : state.copyWith(status: DavStatus.connected, message: '已从云端取回备份');
      return text;
    } on Object catch (error) {
      state = state.copyWith(status: DavStatus.failed, message: '$error');
      return null;
    }
  }
}

final davProvider = NotifierProvider<DavNotifier, DavState>(DavNotifier.new);

/// 免责声明的阶段：未同意 / 已同意；部分页面要求在同意前复述一段文字。
class DisclaimerNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void agree() => state = true;

  void reset() => state = false;
}

final disclaimerAcceptedProvider = NotifierProvider<DisclaimerNotifier, bool>(
  DisclaimerNotifier.new,
);

/// 开发者模式总开关；关掉时选项区整体禁用（上游行为）。
class DeveloperModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle(bool value) => state = value;
}

final developerModeProvider = NotifierProvider<DeveloperModeNotifier, bool>(
  DeveloperModeNotifier.new,
);

/// 应用更新的演示阶段。
enum UpdateStage {
  idle('未检查'),
  checking('检查中'),
  upToDate('已是最新'),
  available('发现新版本'),
  downloading('下载中'),
  downloaded('下载完成');

  const UpdateStage(this.label);

  final String label;

  bool get isBusy => this == checking || this == downloading;
}

/// 应用更新的状态机；[UpdateNotifier.check] 发起真实的 GitHub Releases 请求。
class UpdateState {
  const UpdateState({
    this.stage = UpdateStage.idle,
    this.progress = 0,
    this.info,
    this.currentVersion,
    this.error,
    this.apkPath,
  });

  final UpdateStage stage;

  /// 0–1；只在 [UpdateStage.downloading] 时有意义。
  final double progress;

  /// 发现的新版本；只有 [UpdateStage.available] 及之后才有值。
  final UpdateInfo? info;

  /// 本机版本，用于「当前 x → 最新 y」。
  final String? currentVersion;

  /// 检查失败的原因；[UpdateStage.idle] 且非空表示上一次检查失败。
  final String? error;

  /// 已下载安装包的绝对路径；只有 [UpdateStage.downloaded] 时有值。
  final String? apkPath;

  UpdateState copyWith({
    UpdateStage? stage,
    double? progress,
    UpdateInfo? info,
    String? currentVersion,
    String? error,
    String? apkPath,
    bool clearError = false,
    bool clearInfo = false,
    bool clearApkPath = false,
  }) => UpdateState(
    stage: stage ?? this.stage,
    progress: progress ?? this.progress,
    info: clearInfo ? null : (info ?? this.info),
    currentVersion: currentVersion ?? this.currentVersion,
    error: clearError ? null : (error ?? this.error),
    apkPath: clearApkPath ? null : (apkPath ?? this.apkPath),
  );
}

/// 检查更新走真实 `releases/latest` 请求；不再「永远发现新版本」。
///
/// 上一轮 `check()` 是 `await Future.delayed(900ms)` 然后直接置
/// `UpdateStage.available`——与服务器无关，永远提示有更新，引导用户去下载一个
/// 不存在的安装包。
class UpdateNotifier extends Notifier<UpdateState> {
  @override
  UpdateState build() => const UpdateState();

  /// 本机版本。
  ///
  /// 来自 `app_version_name`（`LegacySettings` 写入的构建版本），
  /// 读不到时回落到 `1.4.4` —— 与 `app_version_code` 的默认 10404 对应。
  String get _currentVersion {
    final raw = ref.read(legacySettingsProvider).rawValue('app_version_name');
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return '1.4.4';
  }

  Future<void> check() async {
    if (state.stage.isBusy) return;
    final current = _currentVersion;
    state = state.copyWith(
      stage: UpdateStage.checking,
      progress: 0,
      currentVersion: current,
      clearError: true,
      clearInfo: true,
      clearApkPath: true,
    );
    final result = await ref.read(appUpdateCheckerProvider).check(current);
    if (result.failed) {
      // 失败回到 idle 并带上原因：停在「检查中」会让页面永远转圈，
      // 而伪装成「已是最新」会让用户错过真正的更新。
      state = state.copyWith(
        stage: UpdateStage.idle,
        error: result.error,
      );
      return;
    }
    state = result.hasUpdate
        ? state.copyWith(stage: UpdateStage.available, info: result.info)
        : state.copyWith(stage: UpdateStage.upToDate, clearInfo: true);
  }

  /// 真实下载：原生侧把 APK 写进应用私有目录，进度通过通道回推。
  ///
  /// 上一轮这里只回一句「本机尚未接入安装包下载器」——那是诚实的占位，但用户
  /// 真正需要的是装上新版。现在下载与安装都接上了（见 `UpdateBridge`）。
  Future<void> download() async {
    if (state.stage.isBusy) return;
    final info = state.info;
    if (info == null) {
      state = state.copyWith(error: '请先检查更新');
      return;
    }
    state = state.copyWith(
      stage: UpdateStage.downloading,
      progress: 0,
      clearError: true,
      clearApkPath: true,
    );
    final result = await ref
        .read(updateBridgeProvider)
        .download(
          url: info.downloadUrl,
          version: info.version,
          onProgress: (progress) {
            // 下载期间用户可能已经离开或重新检查：只在仍处于 downloading 时更新。
            if (state.stage != UpdateStage.downloading) return;
            state = state.copyWith(progress: progress.fraction ?? 0);
          },
        );
    if (!result.ok) {
      state = state.copyWith(
        stage: UpdateStage.available,
        error: result.error,
        progress: 0,
      );
      return;
    }
    state = state.copyWith(
      stage: UpdateStage.downloaded,
      progress: 1,
      apkPath: result.path,
    );
  }

  /// 调起系统安装器安装已下载的包。返回是否成功唤起。
  Future<bool> install() async {
    final path = state.apkPath;
    if (path == null) {
      state = state.copyWith(error: '请先下载更新包');
      return false;
    }
    final ok = await ref.read(updateBridgeProvider).install(path);
    if (!ok) {
      state = state.copyWith(error: '无法调起系统安装器，请稍后重试');
      return false;
    }
    return true;
  }

  void reset() => state = const UpdateState();
}

/// 更新检查器（可在测试里覆盖端点）。
final appUpdateCheckerProvider = Provider<AppUpdateChecker>(
  (ref) => const AppUpdateChecker(),
);

/// 更新下载/安装通道（可在测试里替换为假实现）。
final updateBridgeProvider = Provider<UpdateBridge>((ref) => UpdateBridge());

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(
  UpdateNotifier.new,
);

/// IP 质量检测阶段。
enum IpQualityStage {
  idle('未检测'),
  loading('检测中'),
  loaded('检测完成'),
  failed('检测失败');

  const IpQualityStage(this.label);

  final String label;
}

/// 当前 IP 质量检测的状态。
class IpQualityState {
  const IpQualityState({
    this.stage = IpQualityStage.idle,
    this.report,
    this.error,
  });

  final IpQualityStage stage;

  /// 最近一次成功的报告；失败时保留上一份，便于对照。
  final IpQualityReport? report;

  /// 失败原因。
  final String? error;

  IpQualityState copyWith({
    IpQualityStage? stage,
    IpQualityReport? report,
    String? error,
    bool clearError = false,
  }) => IpQualityState(
    stage: stage ?? this.stage,
    report: report ?? this.report,
    error: clearError ? null : (error ?? this.error),
  );
}

/// 当前 IP 质量浮层要显示的地址与阶段；每次打开浮层重新检测一次。
/// IP 质量检测：真查出口 IP 与三个公开情报源。
///
/// 上一轮 `detect()` 只有 `await Future.delayed(1000ms)`，报告本身是写死的
/// `mockIpQualityReport`——点「重新检测」只有转圈在动，数字与结论从不变化。
class IpQualityNotifier extends Notifier<IpQualityState> {
  @override
  IpQualityState build() => const IpQualityState();

  Future<void> detect() async {
    if (state.stage == IpQualityStage.loading) return;
    state = state.copyWith(stage: IpQualityStage.loading, clearError: true);
    final outcome = await ref.read(ipQualityCheckerProvider).detect();
    state = switch (outcome) {
      IpQualitySuccess(:final report) => state.copyWith(
        stage: IpQualityStage.loaded,
        report: report,
        clearError: true,
      ),
      IpQualityError(:final failure) => state.copyWith(
        stage: IpQualityStage.failed,
        error: failure.message,
      ),
    };
  }
}

/// IP 质量检测器（测试里可替换端点）。
final ipQualityCheckerProvider = Provider<IpQualityChecker>(
  (ref) => const IpQualityChecker(),
);

final ipQualityProvider = NotifierProvider<IpQualityNotifier, IpQualityState>(
  IpQualityNotifier.new,
);

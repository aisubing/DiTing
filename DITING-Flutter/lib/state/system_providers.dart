/// System domain: disclaimer, developer mode, WebDAV, app updates and IP quality; access control
/// lives in the pages.
library;

import 'dart:async';

import 'package:diting/data/backup/dav_client.dart';
import 'package:diting/data/native/update_bridge.dart';
import 'package:diting/data/tools/ip_quality_checker.dart';
import 'package:diting/data/update/app_update_checker.dart';
import 'package:diting/state/app_version_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DavStatus {
  idle('未连接'),
  connecting('连接中'),
  connected('连接成功'),
  failed('连接失败');

  const DavStatus(this.label);

  final String label;
}

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

  /// Failure reason; non-null only while [status] is [DavStatus.failed].
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

/// WebDAV connection state machine; [DavNotifier.test] performs a real request.
class DavNotifier extends Notifier<DavState> {
  @override
  DavState build() => const DavState();

  void update(DavState Function(DavState state) update) =>
      state = update(state);

  /// Connects for real: `PROPFIND` probes, `MKCOL` creates; failures carry status and reason.
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

  /// Fixed name, so an upload overwrites the previous copy: sync, not archive.
  static const remoteFileName = 'diting-config.json';

  DavCredentials get credentials => DavCredentials(
    server: state.server,
    username: state.username,
    password: state.password,
    path: state.path,
  );

  /// Uploads with `PUT` to `<path>/diting-config.json`.
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

  /// Downloads the cloud backup with `GET`; null when no file exists.
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

/// Disclaimer stage; some pages require restating a passage before accepting.
class DisclaimerNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void agree() => state = true;

  void reset() => state = false;
}

final disclaimerAcceptedProvider = NotifierProvider<DisclaimerNotifier, bool>(
  DisclaimerNotifier.new,
);

/// Developer-mode master switch; when off the option section is disabled.
class DeveloperModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle(bool value) => state = value;
}

final developerModeProvider = NotifierProvider<DeveloperModeNotifier, bool>(
  DeveloperModeNotifier.new,
);

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

/// App-update state machine; [UpdateNotifier.check] queries GitHub Releases.
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

  /// 0-1; meaningful only while [UpdateStage.downloading].
  final double progress;

  /// New version found; set from [UpdateStage.available] onwards.
  final UpdateInfo? info;

  /// Local version, for the "current x to latest y" label.
  final String? currentVersion;

  /// Failure reason; non-null while idle means the last check failed.
  final String? error;

  /// Absolute path of the downloaded package; set once downloaded.
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

class UpdateNotifier extends Notifier<UpdateState> {
  @override
  UpdateState build() => const UpdateState();

  /// Local version from `pubspec.yaml` ([appVersionProvider]), the only source.
  String get _currentVersion => ref.read(appVersionProvider).name;

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
      // Back to idle with the reason; staying "checking" spins forever.
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

  /// Real download: the native side writes the APK and reports progress (`UpdateBridge`).
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
            // The user may leave or re-check mid-download, so only update while still downloading.
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

  /// Launches the system installer for the downloaded package.
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

/// Update checker; tests may override the endpoint.
final appUpdateCheckerProvider = Provider<AppUpdateChecker>(
  (ref) => const AppUpdateChecker(),
);

/// Update download/install channel, replaceable in tests.
final updateBridgeProvider = Provider<UpdateBridge>((ref) => UpdateBridge());

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(
  UpdateNotifier.new,
);

enum IpQualityStage {
  idle('未检测'),
  loading('检测中'),
  loaded('检测完成'),
  failed('检测失败');

  const IpQualityStage(this.label);

  final String label;
}

class IpQualityState {
  const IpQualityState({
    this.stage = IpQualityStage.idle,
    this.report,
    this.error,
  });

  final IpQualityStage stage;

  /// Last successful report; kept on failure for comparison.
  final IpQualityReport? report;

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

/// Address and stage shown by the IP-quality overlay, re-detected on each open.
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

/// IP-quality checker; tests may override the endpoints.
final ipQualityCheckerProvider = Provider<IpQualityChecker>(
  (ref) => const IpQualityChecker(),
);

final ipQualityProvider = NotifierProvider<IpQualityNotifier, IpQualityState>(
  IpQualityNotifier.new,
);

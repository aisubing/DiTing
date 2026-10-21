/// 演示用状态：系统域（访问控制 / 备份 / 免责声明 / 开发者 / 更新）。
///
/// 全部纯内存，不落盘、不联网：本阶段只做 UI，所有「连接中 → 成功」之类的
/// 过程都用 `Future.delayed` 模拟。放在独立文件而不是塞进页面，是因为访问
/// 控制的选择结果要被设置页与演示页共用，页面内部 `setState` 活不过一次
/// 路由往返。
library;

import 'dart:async';

import 'package:diting/data/backup/dav_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 访问控制模式：白名单（只放行选中）/ 黑名单（只拦截选中）。
enum AccessMode {
  whitelist('白名单模式'),
  blacklist('黑名单模式');

  const AccessMode(this.label);

  final String label;
}

/// 访问控制列表的排序方式。
enum AccessSort {
  none('默认'),
  name('按名称'),
  time('按时间');

  const AccessSort(this.label);

  final String label;
}

/// 访问控制的全部可编辑项。
///
/// 用一个不可变记录而不是多个 provider：这些字段在「保存」时要一起提交，
/// 拆开会让「哪些改动算 dirty」变成一个跨 provider 的比较问题。
class AccessControlState {
  const AccessControlState({
    this.enabled = false,
    this.mode = AccessMode.whitelist,
    this.sort = AccessSort.none,
    this.showSystemApps = false,
    this.showNonInternetApps = false,
    this.selected = const {},
  });

  final bool enabled;
  final AccessMode mode;
  final AccessSort sort;

  /// 是否把系统应用列出来（上游是「过滤系统应用」的反向开关）。
  final bool showSystemApps;
  final bool showNonInternetApps;

  /// 选中的应用包名。
  final Set<String> selected;

  AccessControlState copyWith({
    bool? enabled,
    AccessMode? mode,
    AccessSort? sort,
    bool? showSystemApps,
    bool? showNonInternetApps,
    Set<String>? selected,
  }) => AccessControlState(
    enabled: enabled ?? this.enabled,
    mode: mode ?? this.mode,
    sort: sort ?? this.sort,
    showSystemApps: showSystemApps ?? this.showSystemApps,
    showNonInternetApps: showNonInternetApps ?? this.showNonInternetApps,
    selected: selected ?? this.selected,
  );
}

/// 访问控制草稿；`saved` 是上次保存的快照，两者不等即为 dirty。
class AccessControlNotifier extends Notifier<AccessControlState> {
  @override
  AccessControlState build() => const AccessControlState();

  void update(AccessControlState Function(AccessControlState state) update) =>
      state = update(state);

  void toggle(String packageName) {
    final next = {...state.selected};
    if (!next.remove(packageName)) {
      next.add(packageName);
    }
    state = state.copyWith(selected: next);
  }

  /// 全选 / 反选只作用于传入的候选集（即「当前可见」），与规则页同一口径。
  void selectAll(Iterable<String> packageNames) =>
      state = state.copyWith(selected: {...packageNames});

  void invert(Iterable<String> packageNames) {
    final next = {...state.selected};
    for (final packageName in packageNames) {
      if (!next.remove(packageName)) {
        next.add(packageName);
      }
    }
    state = state.copyWith(selected: next);
  }

  void reset() => state = const AccessControlState();
}

final accessControlProvider =
    NotifierProvider<AccessControlNotifier, AccessControlState>(
      AccessControlNotifier.new,
    );

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

class UpdateState {
  const UpdateState({this.stage = UpdateStage.idle, this.progress = 0});

  final UpdateStage stage;

  /// 0–1；只在 [UpdateStage.downloading] 时有意义。
  final double progress;

  UpdateState copyWith({UpdateStage? stage, double? progress}) => UpdateState(
    stage: stage ?? this.stage,
    progress: progress ?? this.progress,
  );
}

/// 检查更新 → 发现新版本 → 下载进度，全程 `Future.delayed` 模拟。
class UpdateNotifier extends Notifier<UpdateState> {
  @override
  UpdateState build() => const UpdateState();

  Future<void> check() async {
    if (state.stage.isBusy) {
      return;
    }
    state = state.copyWith(stage: UpdateStage.checking, progress: 0);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    state = state.copyWith(stage: UpdateStage.available);
  }

  Future<void> download() async {
    if (state.stage.isBusy) {
      return;
    }
    for (var step = 1; step <= 10; step++) {
      state = state.copyWith(
        stage: UpdateStage.downloading,
        progress: step / 10,
      );
      await Future<void>.delayed(const Duration(milliseconds: 160));
    }
    state = state.copyWith(stage: UpdateStage.downloaded);
  }

  void reset() => state = const UpdateState();
}

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(
  UpdateNotifier.new,
);

/// IP 质量检测阶段。
enum IpQualityStage {
  loading('检测中'),
  loaded('检测完成'),
  failed('检测失败');

  const IpQualityStage(this.label);

  final String label;
}

/// 当前 IP 质量浮层要显示的地址与阶段；每次打开浮层重新检测一次。
class IpQualityNotifier extends Notifier<({String ip, IpQualityStage stage})> {
  @override
  ({String ip, IpQualityStage stage}) build() =>
      (ip: '203.0.113.24', stage: IpQualityStage.loaded);

  Future<void> detect(String ip) async {
    state = (ip: ip, stage: IpQualityStage.loading);
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    state = (ip: ip, stage: IpQualityStage.loaded);
  }
}

final ipQualityProvider =
    NotifierProvider<IpQualityNotifier, ({String ip, IpQualityStage stage})>(
      IpQualityNotifier.new,
    );

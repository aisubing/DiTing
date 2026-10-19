/// 配置档案域的演示状态：档案网格、自定义配置的六个子表、扩展模式。
///
/// 为什么状态放在 provider 而不是页面 `State`：档案网格与每个子页面（节点、
/// 组、规则…）要跨路由共享同一份数据，且从子页面返回网格时不能让改动跟着
/// 页面一起消失。演示版没有数据库，provider 就是唯一的持久层。
///
/// 文件按用途拆成三个 part（AGENTS.md 的 550 行上限）：
/// - 本文件：档案网格与节点；
/// - `profiles_providers_custom.dart`：代理组、规则、代理/规则提供者；
/// - `profiles_providers_extend.dart`：拨号器、扩展模式、脚本、匹配目标、追加规则。
library;

import 'dart:async';

import 'package:diting/data/mock_profiles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'profiles_providers_custom.dart';
part 'profiles_providers_extend.dart';

/// 档案网格的状态。
class ProfilesState {
  const ProfilesState({
    required this.profiles,
    this.currentId,
    this.updatingIds = const {},
    this.selection = const {},
  });

  final List<MockProfile> profiles;

  /// 当前生效的档案；点卡片就是切换它。
  final String? currentId;

  /// 正在拉取的档案（进度条与禁用态都看这个集合）。
  final Set<String> updatingIds;

  /// 长按进入的多选集合；非空时顶栏换成选择工具栏。
  final Set<String> selection;

  bool get isSelecting => selection.isNotEmpty;

  MockProfile? get current {
    for (final profile in profiles) {
      if (profile.id == currentId) {
        return profile;
      }
    }
    return profiles.isEmpty ? null : profiles.first;
  }

  ProfilesState copyWith({
    List<MockProfile>? profiles,
    String? currentId,
    Set<String>? updatingIds,
    Set<String>? selection,
  }) {
    return ProfilesState(
      profiles: profiles ?? this.profiles,
      currentId: currentId ?? this.currentId,
      updatingIds: updatingIds ?? this.updatingIds,
      selection: selection ?? this.selection,
    );
  }
}

/// 网格排序方式（顶栏「排序」菜单）。
enum ProfileSort {
  name('按名称'),
  updatedAt('按更新时间'),
  kind('按类型');

  const ProfileSort(this.label);

  final String label;
}

/// 档案网格：增删改、选择、排序、下载进度都在这里。
///
/// 下载进度用定时器模拟：演示版没有真实订阅可拉，但进度条的中间态（部分进度、
/// 波浪头、更新完成后时间戳变化）正是要验证的东西，直接给个静态 62% 看不出
/// 它会不会动。
class ProfilesNotifier extends Notifier<ProfilesState> {
  final _timers = <String, Timer>{};
  var _sequence = 0;

  @override
  ProfilesState build() {
    ref.onDispose(() {
      for (final timer in _timers.values) {
        timer.cancel();
      }
      _timers.clear();
    });
    return ProfilesState(
      profiles: [...mockProfiles],
      currentId: mockProfiles.first.id,
    );
  }

  void select(String id) {
    state = state.copyWith(currentId: id);
  }

  /// 长按进入多选；已选中则再点一次取消。
  void toggleSelection(String id) {
    final next = {...state.selection};
    if (!next.add(id)) {
      next.remove(id);
    }
    state = state.copyWith(selection: next);
  }

  void selectAll() {
    state = state.copyWith(
      selection: {for (final profile in state.profiles) profile.id},
    );
  }

  void clearSelection() {
    if (state.selection.isEmpty) {
      return;
    }
    state = state.copyWith(selection: const {});
  }

  /// 删除多选中的档案；当前档案被删掉时自动落到剩下的第一条。
  void deleteSelected() {
    final ids = state.selection;
    if (ids.isEmpty) {
      return;
    }
    _removeWhere((profile) => ids.contains(profile.id));
  }

  void delete(String id) => _removeWhere((profile) => profile.id == id);

  void _removeWhere(bool Function(MockProfile) test) {
    final removed = state.profiles
        .where(test)
        .map((profile) => profile.id)
        .toSet();
    if (removed.isEmpty) {
      return;
    }
    for (final id in removed) {
      _timers.remove(id)?.cancel();
    }
    final kept = [
      for (final profile in state.profiles)
        if (!removed.contains(profile.id)) profile,
    ];
    state = ProfilesState(
      profiles: kept,
      currentId: removed.contains(state.currentId)
          ? (kept.isEmpty ? null : kept.first.id)
          : state.currentId,
      updatingIds: state.updatingIds.difference(removed),
      selection: state.selection.difference(removed),
    );
  }

  /// 拖拽重排后整体替换顺序。
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) {
      return;
    }
    final profiles = [...state.profiles];
    if (oldIndex < 0 || oldIndex >= profiles.length) {
      return;
    }
    final moved = profiles.removeAt(oldIndex);
    profiles.insert(newIndex.clamp(0, profiles.length), moved);
    state = state.copyWith(profiles: profiles);
  }

  void sortBy(ProfileSort sort) {
    final profiles = [...state.profiles];
    profiles.sort(switch (sort) {
      ProfileSort.name => (a, b) => a.name.compareTo(b.name),
      // 更新时间是人类可读字符串，只能按预设顺序取序号；真实实现按时间戳排。
      ProfileSort.updatedAt => (a, b) => _updatedRank(
        a,
      ).compareTo(_updatedRank(b)),
      ProfileSort.kind => (a, b) => a.kind.index.compareTo(b.kind.index),
    });
    state = state.copyWith(profiles: profiles);
  }

  int _updatedRank(MockProfile profile) {
    // 「正在更新」永远排最前，其次是「N 分钟前」，最后是绝对时间。
    if (profile.isDownloading) {
      return -1;
    }
    if (profile.updatedAt.contains('分钟')) {
      return 0;
    }
    if (profile.updatedAt.contains('小时')) {
      return 1;
    }
    if (profile.updatedAt.contains('昨天')) {
      return 2;
    }
    return 3;
  }

  /// 新增档案，返回新档案的 id。
  String add({
    required String name,
    required ProfileKind kind,
    String url = '',
    String fileName = '',
    String fileSize = '',
    AutoUpdateInterval autoUpdate = AutoUpdateInterval.off,
    String userAgent = '',
  }) {
    final id = 'p-new-${_sequence++}';
    final profile = MockProfile(
      id: id,
      name: name.trim(),
      kind: kind,
      updatedAt: '刚刚创建',
      ruleCount: 0,
      proxyCount: 0,
      url: url.trim(),
      fileName: fileName,
      fileSize: fileSize,
      autoUpdate: autoUpdate,
      userAgent: userAgent,
    );
    state = ProfilesState(
      profiles: [...state.profiles, profile],
      currentId: state.currentId ?? id,
    );
    return id;
  }

  /// 编辑页保存：返回 false 表示名称与现有档案重名。
  bool update(
    String id, {
    required String name,
    required String url,
    required AutoUpdateInterval autoUpdate,
    required String userAgent,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (state.profiles.any(
      (profile) => profile.id != id && profile.name == trimmed,
    )) {
      return false;
    }
    _replace(
      id,
      (profile) => profile.copyWith(
        name: trimmed,
        url: url.trim(),
        autoUpdate: autoUpdate,
        userAgent: userAgent,
      ),
    );
    return true;
  }

  void setAutoUpdate(String id, AutoUpdateInterval interval) {
    _replace(id, (profile) => profile.copyWith(autoUpdate: interval));
  }

  void _replace(String id, MockProfile Function(MockProfile) update) {
    state = state.copyWith(
      profiles: [
        for (final profile in state.profiles)
          if (profile.id == id) update(profile) else profile,
      ],
    );
  }

  /// 拉取远程档案：进度条从 0 走到 1，走完把更新时间改成「刚刚」。
  void startUpdate(String id) {
    if (state.updatingIds.contains(id)) {
      return;
    }
    final profile = _profileOf(id);
    if (profile == null || profile.kind == ProfileKind.local) {
      return;
    }
    _timers.remove(id)?.cancel();
    state = ProfilesState(
      profiles: [
        for (final item in state.profiles)
          if (item.id == id) _withProgress(item, 0) else item,
      ],
      currentId: state.currentId,
      updatingIds: {...state.updatingIds, id},
      selection: state.selection,
    );
    var step = 0;
    _timers[id] = Timer.periodic(const Duration(milliseconds: 140), (timer) {
      step++;
      // 前几秒慢、中间快：真实下载的进度条也不是匀速的。
      final progress = step < 4 ? step * 0.06 : step * 0.13;
      if (progress >= 1) {
        timer.cancel();
        _timers.remove(id);
        _finishUpdate(id);
        return;
      }
      state = ProfilesState(
        profiles: [
          for (final item in state.profiles)
            if (item.id == id) _withProgress(item, progress) else item,
        ],
        currentId: state.currentId,
        updatingIds: state.updatingIds,
        selection: state.selection,
      );
    });
  }

  void _finishUpdate(String id) {
    _replace(
      id,
      (profile) => profile.copyWith(
        updatedAt: '刚刚',
        clearProgress: true,
        ruleCount: profile.ruleCount == 0 ? 1840 : profile.ruleCount,
        proxyCount: profile.proxyCount == 0 ? 26 : profile.proxyCount,
      ),
    );
    state = state.copyWith(updatingIds: {...state.updatingIds}..remove(id));
  }

  MockProfile _withProgress(MockProfile profile, double progress) {
    return MockProfile(
      id: profile.id,
      name: profile.name,
      kind: profile.kind,
      updatedAt: profile.updatedAt,
      ruleCount: profile.ruleCount,
      proxyCount: profile.proxyCount,
      url: profile.url,
      fileName: profile.fileName,
      fileSize: profile.fileSize,
      autoUpdate: profile.autoUpdate,
      userAgent: profile.userAgent,
      subscription: profile.subscription,
      downloadProgress: progress,
      wavyProgress: profile.wavyProgress,
    );
  }

  MockProfile? _profileOf(String id) {
    for (final profile in state.profiles) {
      if (profile.id == id) {
        return profile;
      }
    }
    return null;
  }
}

final profilesProvider = NotifierProvider<ProfilesNotifier, ProfilesState>(
  ProfilesNotifier.new,
);

/// 当前档案的只读视图；顶栏与编辑页都只看它，换选中不会重建整个网格。
final currentProfileProvider = Provider<MockProfile?>(
  (ref) => ref.watch(profilesProvider.select((state) => state.current)),
);

/// 多选自建节点：[1100] 上游的 `itemsProvider`。
///
/// 只存 id 集合而不是整条记录：列表随时可能因为搜索/重排变化，存记录会让
/// 「选中项」指向一份过期副本。
class ProxySelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String id) {
    final next = {...state};
    if (!next.add(id)) {
      next.remove(id);
    }
    state = next;
  }

  void selectAll(Iterable<String> ids) {
    state = state.containsAll(ids) ? const {} : {...ids};
  }

  void clear() => state = const {};
}

final proxySelectionProvider =
    NotifierProvider<ProxySelectionNotifier, Set<String>>(
      ProxySelectionNotifier.new,
    );

/// 自定义节点表。
class CustomProxiesNotifier extends Notifier<List<MockProxy>> {
  var _sequence = 0;

  @override
  List<MockProxy> build() => [...mockProxies];

  /// 新增或替换；返回 false 表示名称重复。
  bool put(MockProxy proxy) {
    final exists = state.any(
      (item) => item.id != proxy.id && item.name == proxy.name,
    );
    if (exists) {
      return false;
    }
    final index = state.indexWhere((item) => item.id == proxy.id);
    state = index < 0
        ? [...state, proxy]
        : [
            for (var i = 0; i < state.length; i++)
              if (i == index) proxy else state[i],
          ];
    return true;
  }

  MockProxy create({
    required String name,
    required ProxyProtocol protocol,
    required String server,
    required int port,
    required String cipher,
    required String password,
    required bool tls,
    required String sni,
    required bool skipCertVerify,
    required bool udp,
  }) {
    return MockProxy(
      id: 'n-new-${_sequence++}',
      name: name.trim(),
      protocol: protocol,
      server: server.trim(),
      port: port,
      latencyMs: 120,
      cipher: cipher,
      password: password,
      tls: tls,
      sni: sni.trim(),
      skipCertVerify: skipCertVerify,
      udp: udp,
    );
  }

  void remove(Set<String> ids) {
    state = [
      for (final proxy in state)
        if (!ids.contains(proxy.id)) proxy,
    ];
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex || oldIndex < 0 || oldIndex >= state.length) {
      return;
    }
    final next = [...state];
    next.insert(newIndex.clamp(0, next.length), next.removeAt(oldIndex));
    state = next;
  }

  /// 批量编辑：把多选节点的端口一起改掉（上游批量编辑里最常用的一项）。
  void setPort(Set<String> ids, int port) {
    state = [
      for (final proxy in state)
        if (ids.contains(proxy.id)) proxy.copyWith(port: port) else proxy,
    ];
  }

  /// 批量编辑：把多选节点的协议一起改掉。
  void setProtocol(Set<String> ids, ProxyProtocol protocol) {
    state = [
      for (final proxy in state)
        if (ids.contains(proxy.id))
          proxy.copyWith(protocol: protocol)
        else
          proxy,
    ];
  }

  void setLatency(Set<String> ids, int latencyMs) {
    state = [
      for (final proxy in state)
        if (ids.contains(proxy.id))
          MockProxy(
            id: proxy.id,
            name: proxy.name,
            protocol: proxy.protocol,
            server: proxy.server,
            port: proxy.port,
            latencyMs: latencyMs,
            cipher: proxy.cipher,
            password: proxy.password,
            tls: proxy.tls,
            sni: proxy.sni,
            skipCertVerify: proxy.skipCertVerify,
            udp: proxy.udp,
          )
        else
          proxy,
    ];
  }

  /// 快速编辑保存：整份替换（文本编辑器的语义就是「这段文本就是全部」）。
  void replaceAll(List<MockProxy> proxies) => state = [...proxies];
}

final customProxiesProvider =
    NotifierProvider<CustomProxiesNotifier, List<MockProxy>>(
      CustomProxiesNotifier.new,
    );

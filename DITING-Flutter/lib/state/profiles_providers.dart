/// Demo state for the profile domain; providers rather than page `State` so every sub page shares
/// one copy.
library;

import 'dart:async';

import 'package:diting/data/mock_profiles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'profiles_providers_custom.dart';
part 'profiles_providers_extend.dart';

class ProfilesState {
  const ProfilesState({
    required this.profiles,
    this.currentId,
    this.updatingIds = const {},
    this.selection = const {},
  });

  final List<MockProfile> profiles;

  /// Active profile; tapping a card switches it.
  final String? currentId;

  /// Profiles being fetched; drives both the progress bar and the disabled state.
  final Set<String> updatingIds;

  /// Long-press selection; a non-empty set turns the top bar into a selection bar.
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

/// Grid sort order (the "sort" menu in the top bar).
enum ProfileSort {
  name('按名称'),
  updatedAt('按更新时间'),
  kind('按类型');

  const ProfileSort(this.label);

  final String label;
}

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

  /// Long-press toggles multi-select.
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

  /// Deletes the selection; deleting the active one falls back to the first remaining.
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
      // The timestamp is a human-readable string, so rank by preset order.
      ProfileSort.updatedAt => (a, b) => _updatedRank(
        a,
      ).compareTo(_updatedRank(b)),
      ProfileSort.kind => (a, b) => a.kind.index.compareTo(b.kind.index),
    });
    state = state.copyWith(profiles: profiles);
  }

  int _updatedRank(MockProfile profile) {
    // "Updating" ranks first, then "N minutes ago", then absolute timestamps.
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

  /// Saves the edit page; false means the name duplicates an existing profile.
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

  /// Fetches a remote profile: progress runs 0 to 1, then the timestamp is "just now".
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
      // Slow at first, fast in the middle: real download progress is not linear.
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

/// Read-only active profile, so switching selection does not rebuild the whole grid.
final currentProfileProvider = Provider<MockProfile?>(
  (ref) => ref.watch(profilesProvider.select((state) => state.current)),
);

/// Multi-select for custom nodes; only ids are stored, since records would go stale with search and
/// reordering.
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

class CustomProxiesNotifier extends Notifier<List<MockProxy>> {
  var _sequence = 0;

  @override
  List<MockProxy> build() => [...mockProxies];

  /// Adds or replaces a node; false means the name is duplicated.
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

  /// Batch edit: sets the port of every selected node.
  void setPort(Set<String> ids, int port) {
    state = [
      for (final proxy in state)
        if (ids.contains(proxy.id)) proxy.copyWith(port: port) else proxy,
    ];
  }

  /// Batch edit: sets the protocol of every selected node.
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

  /// Quick-edit save: replaces everything, since the text is the whole document.
  void replaceAll(List<MockProxy> proxies) => state = [...proxies];
}

final customProxiesProvider =
    NotifierProvider<CustomProxiesNotifier, List<MockProxy>>(
      CustomProxiesNotifier.new,
    );

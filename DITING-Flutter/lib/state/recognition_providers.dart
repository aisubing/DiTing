/// 名单页的状态：一份名单 + 刷新节奏 + 头像可用性。
///
/// ## 为什么把「缓存优先、后台刷新」写在这里而不是 build 里 await 网络
///
/// 旧版的体验是「先把上次的名单画出来，再静默拉一遍，变了就替换」。若在
/// `build()` 里直接 await 网络，弱网时列表页会先转 15 秒圈才出内容，等于把
/// 缓存的意义抹掉。因此 [RecognitionController.build] 只读本地缓存，
/// 网络刷新由页面进入时的 [RecognitionController.ensureFresh] 触发。
///
/// 两个名单页共用同一个 provider：数据源相同，进入任一页都会拉起刷新，另一页
/// 直接复用结果，不会各自下载一遍。
library;

import 'dart:async';

import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/recognition/recognition_members.dart';
import 'package:diting/data/recognition/recognition_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 一次加载后的快照。
@immutable
class RecognitionState {
  const RecognitionState({
    this.members,
    this.updatedAt,
    this.isRefreshing = false,
    this.error,
    this.fromCache = false,
  });

  /// 当前可展示的名单；null 表示还没有拿到任何数据（首次进入且缓存为空）。
  final RecognitionMembers? members;

  /// 上一次成功从云端更新的时间；null 表示从未成功过。
  final DateTime? updatedAt;

  /// 是否正在拉取云端配置（页面据此显示顶栏刷新按钮的 loading 态）。
  final bool isRefreshing;

  /// 最近一次刷新的失败原因；成功后清空。非空时页面在页脚如实提示。
  final String? error;

  /// 当前名单是否来自本地缓存（而非本次会话拉取的新数据）。
  final bool fromCache;

  bool get hasMembers => members != null;

  RecognitionState copyWith({
    RecognitionMembers? members,
    DateTime? updatedAt,
    bool? isRefreshing,
    Object? error = _keep,
    bool? fromCache,
  }) {
    return RecognitionState(
      members: members ?? this.members,
      updatedAt: updatedAt ?? this.updatedAt,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error == _keep ? this.error : error as String?,
      fromCache: fromCache ?? this.fromCache,
    );
  }

  static const _keep = Object();
}

/// 仓库实例。测试可以 override 掉它注入内存假数据。
final recognitionRepositoryProvider = Provider<RecognitionMembersRepository>((
  ref,
) {
  return RecognitionMembersRepository(store: ref.watch(legacyPrefsStoreProvider));
});

class RecognitionController extends AsyncNotifier<RecognitionState> {
  /// 每次进入页面都会问一次；60 秒内刚成功拉过就不再打扰服务器。
  static const freshWindow = Duration(seconds: 60);

  Future<void>? _inFlight;

  @override
  Future<RecognitionState> build() async {
    final repo = ref.watch(recognitionRepositoryProvider);
    final cached = repo.loadCached();
    return RecognitionState(
      members: cached,
      updatedAt: repo.loadCachedAt(),
      fromCache: true,
    );
  }

  /// 页面挂载时调用：需要时发起一次静默刷新（不等待结果）。
  void ensureFresh() {
    final current = state.value;
    if (current == null) return;
    if (current.isRefreshing || _inFlight != null) return;
    // 还没拿到任何名单时必须刷新；已有缓存则按 freshWindow 节流。
    final updatedAt = current.updatedAt;
    if (current.hasMembers &&
        updatedAt != null &&
        DateTime.now().difference(updatedAt) < freshWindow) {
      return;
    }
    unawaited(refresh());
  }

  /// 用户点刷新按钮 / 主动重试时调用。
  Future<void> refresh() {
    final existing = _inFlight;
    if (existing != null) return existing;
    final future = _runRefresh();
    _inFlight = future;
    return future;
  }

  Future<void> _runRefresh() async {
    final current = state.value ?? const RecognitionState();
    state = AsyncData(current.copyWith(isRefreshing: true, error: null));
    final repo = ref.read(recognitionRepositoryProvider);
    try {
      final fresh = await repo.refresh();
      if (fresh == null) {
        // 304：服务器说没变，更新一下「最近检查时间」即可。
        state = AsyncData(
          current.copyWith(
            isRefreshing: false,
            updatedAt: DateTime.now(),
            fromCache: false,
            error: null,
          ),
        );
        // 名单没变不代表每张头像都下到了：重挂 family 让上次失败的补一次。
        ref.invalidate(recognitionAvatarProvider);
        return;
      }
      state = AsyncData(
        RecognitionState(
          members: fresh,
          updatedAt: DateTime.now(),
          isRefreshing: false,
          fromCache: false,
        ),
      );
      // 名单变了就重挂头像 family：上一轮下载失败的（握手被打断/超时）这次重试，
      // 已经拿到字节的走内存缓存，不会重下。
      ref.invalidate(recognitionAvatarProvider);
    } on Object catch (error) {
      // 刷新失败不清空已有名单：旧数据仍然可读，只是页脚提示「用的是缓存」。
      if (!ref.mounted) return;
      final latest = state.value ?? current;
      state = AsyncData(
        latest.copyWith(isRefreshing: false, error: _describe(error)),
      );
    } finally {
      _inFlight = null;
    }
  }

  static String _describe(Object error) {
    final text = error.toString();
    if (error is FormatException) {
      return '云端名单配置无效（${error.message}），已保留本地缓存';
    }
    if (text.contains('HandshakeException')) {
      return '与 GitHub 的连接被中断，请稍后重试';
    }
    if (text.contains('TimeoutException')) {
      return '连接 GitHub 超时，请检查网络后重试';
    }
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup')) {
      return '网络不可用，无法更新名单';
    }
    if (text.contains('HttpException')) {
      return '云端名单拉取失败（$text）';
    }
    return '名单更新失败：$text';
  }
}

final recognitionMembersProvider =
    AsyncNotifierProvider<RecognitionController, RecognitionState>(
      RecognitionController.new,
    );

/// 单张头像的字节：`null` 表示确实拿不到（页面退回默认头像）。
///
/// 用 family 把结果按文件名记忆化：列表滚动重建时不会重复下载，
/// 两个名单页共享同一份缓存。
final recognitionAvatarProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  avatarFileName,
) async {
  final repo = ref.watch(recognitionRepositoryProvider);
  return repo.loadAvatarBytes(avatarFileName);
});

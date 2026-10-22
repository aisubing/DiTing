/// 名单与头像的读取：云端拉取、本地缓存、离线降级。
///
/// ## 数据从哪来
///
/// 1. **云端**：`recognition_members.json` + `avatars/`，改完推送 GitHub `main`
///    即生效，无需发版（见 `docs/development/recognition-members.md`）；
/// 2. **本地缓存**：上一次成功校验的 JSON 原文落在 `recognition_members` 容器里
///    （容器名与旧版 `RecognitionMembersRepository.PREFERENCES_NAME` 一致，
///    升级用户不会丢缓存）；头像字节落在应用私有目录 `recognition_avatars/`。
///
/// **不内置任何名单或头像**：内置副本会随 APK 冻结，用户看到的永远是发版那一刻
/// 的名字，而名单本来就该在服务端改。冷启动没网时如实显示「加载失败 + 重试」，
/// 而不是拿一份过期的假数据糊上去。
///
/// 校验失败（格式/重复/非法头像名）**不会**覆盖缓存：坏配置留在服务器上时，
/// 用户看到的仍是上一次的好名单，而不是错误页。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:diting/data/native/recognition_avatar_bridge.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/recognition/recognition_members.dart';
import 'package:flutter/foundation.dart';

/// 名单/头像的网络与缓存访问。
class RecognitionMembersRepository {
  RecognitionMembersRepository({
    required this.store,
    RecognitionAvatarBridge? avatarBridge,
    this.timeout = const Duration(seconds: 10),
  }) : _avatars = avatarBridge ?? const RecognitionAvatarBridge();

  /// 与旧版 `RecognitionMembersRepository.PREFERENCES_NAME` 同名。
  static const container = 'recognition_members';

  static const _configKey = 'config_json';
  static const _savedAtKey = 'saved_at_ms';
  static const _etagKey = 'etag';

  /// 名单配置上限 256KB：正常一两百条也远到不了，超过说明配置出错。
  static const maxConfigBytes = 256 * 1024;

  /// 单张头像上限 1MB（与旧版 `MAX_AVATAR_BYTES` 一致）。
  static const maxAvatarBytes = 1024 * 1024;

  final LegacyPrefsStore store;
  final Duration timeout;
  final RecognitionAvatarBridge _avatars;

  /// 进程内头像字节缓存，避免滚动列表时反复读盘。
  final Map<String, Uint8List> _avatarMemoryCache = {};

  /// 正在进行中的头像下载，同一个文件名只下一次。
  final Map<String, Future<Uint8List?>> _avatarInFlight = {};

  /// 串行队列的队尾；每张头像下载完才轮到下一张。
  Future<void> _avatarQueue = Future<void>.value();

  /// 读上一次成功校验的缓存；没有或损坏返回 null。
  RecognitionMembers? loadCached() {
    final raw = store.read(container, _configKey);
    if (raw is! String || raw.trim().isEmpty) return null;
    try {
      return parseRecognitionMembers(raw);
    } on FormatException catch (error) {
      debugPrint('recognition: 本地缓存不可用（$error），等待云端刷新');
      return null;
    }
  }

  /// 上次成功拉取的时间；仅用于界面展示与排查。
  DateTime? loadCachedAt() {
    final raw = store.read(container, _savedAtKey);
    if (raw is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(raw);
  }

  /// 从云端拉一份新名单。
  ///
  /// 返回 null 表示「服务器说没变」（HTTP 304）；抛异常表示这次拉取失败，
  /// 调用方应保留手上的数据。
  ///
  /// 与头像一样做有限重试：`HandshakeException` / 超时在这台模拟器上是偶发的，
  /// 一次失败就判「网络不可用」会让列表页在信号正常时也停在错误页。
  Future<RecognitionMembers?> refresh() async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await _refreshOnce();
      } on Object catch (error) {
        lastError = error;
        if (attempt < 2) {
          await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
        }
      }
    }
    throw lastError!;
  }

  Future<RecognitionMembers?> _refreshOnce() async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client
          .getUrl(Uri.parse(recognitionMembersUrl))
          .timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'DITING-Android');
      final etag = store.read(container, _etagKey);
      if (etag is String && etag.isNotEmpty) {
        request.headers.set(HttpHeaders.ifNoneMatchHeader, etag);
      }
      final response = await request.close().timeout(timeout);
      if (response.statusCode == HttpStatus.notModified) {
        return null;
      }
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final raw = await _readLimited(response, maxConfigBytes);
      final members = parseRecognitionMembers(raw);
      _writeCache(raw, response.headers.value(HttpHeaders.etagHeader));
      return members;
    } finally {
      client.close(force: true);
    }
  }

  /// 读头像字节：优先内存，其次磁盘缓存，最后才下载。
  ///
  /// 返回 null 表示这个头像确实拿不到（页面退回默认头像）。
  Future<Uint8List?> loadAvatarBytes(String avatarFileName) {
    final cached = _avatarMemoryCache[avatarFileName];
    if (cached != null) return Future.value(cached);
    final inFlight = _avatarInFlight[avatarFileName];
    if (inFlight != null) return inFlight;
    final future = _enqueue(() => _loadAvatar(avatarFileName));
    _avatarInFlight[avatarFileName] = future;
    return future.whenComplete(() => _avatarInFlight.remove(avatarFileName));
  }

  /// 头像下载串行化。
  ///
  /// 名单首屏会同时建十几行，若全部并发发起 TLS 握手，模拟器/弱网环境下大量
  /// 连接被中途掐断（实测 `HandshakeException: Connection terminated during
  /// handshake`，随后全部退回默认头像）。串行排队后每张图各自完成，列表逐行
  /// 补齐；这也顺带避免把并发连接数打到 raw.githubusercontent.com 的限流上。
  Future<T> _enqueue<T>(Future<T> Function() task) {
    final previous = _avatarQueue;
    final completer = Completer<void>();
    _avatarQueue = completer.future;
    return previous.then((_) => task()).whenComplete(completer.complete);
  }

  Future<Uint8List?> _loadAvatar(String avatarFileName) async {
    final stored = await _avatars.read(avatarFileName);
    if (stored != null && stored.isNotEmpty) {
      _avatarMemoryCache[avatarFileName] = stored;
      return stored;
    }
    final url = recognitionAvatarBaseUrl + avatarFileName;
    // 模拟器与部分网络环境下，Dart 的 TLS 握手偶发被中途掐断
    // （`HandshakeException: Connection terminated during handshake`），
    // 而紧接着重试几乎总能成功。头像是一次性小文件，重试两三次代价很低，
    // 远比让整行停在占位图上要好。
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final bytes = await _download(url);
        if (bytes.isEmpty || bytes.length > maxAvatarBytes) return null;
        _avatarMemoryCache[avatarFileName] = bytes;
        // 落盘失败不影响本次显示，下次再试。
        await _avatars.write(avatarFileName, bytes);
        return bytes;
      } on Object catch (error) {
        if (attempt == 2) {
          debugPrint('recognition: 头像 $avatarFileName 下载失败（$error）');
          return null;
        }
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
    return null;
  }

  Future<Uint8List> _download(String url) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(Uri.parse(url)).timeout(timeout);
      request.headers.set(HttpHeaders.userAgentHeader, 'DITING-Android');
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final builder = BytesBuilder(copy: false);
      var total = 0;
      await for (final chunk in response.timeout(timeout)) {
        total += chunk.length;
        if (total > maxAvatarBytes) throw const HttpException('头像体积超限');
        builder.add(chunk);
      }
      return builder.takeBytes();
    } finally {
      client.close(force: true);
    }
  }

  static Future<String> _readLimited(
    HttpClientResponse response,
    int limit,
  ) async {
    final builder = BytesBuilder(copy: false);
    var total = 0;
    await for (final chunk in response) {
      total += chunk.length;
      if (total > limit) throw const HttpException('名单配置过大');
      builder.add(chunk);
    }
    return utf8.decode(builder.takeBytes());
  }

  void _writeCache(String raw, String? etag) {
    store.putString(container, _configKey, raw);
    // 毫秒时间戳约 1.7e12，超出 32 位范围，必须用 putLong——用 putInt 会被
    // 截断成一个很小的数，页脚于是显示「上次更新：1970-01-20」。
    store.putLong(container, _savedAtKey, DateTime.now().millisecondsSinceEpoch);
    if (etag != null && etag.isNotEmpty) {
      store.putString(container, _etagKey, etag);
    }
  }
}

/// 订阅内容的真实网络下载（`dart:io HttpClient`，不引入 pub 依赖）。
///
/// 行为转写自 1.4.3 `core/rule/SubscriptionDownloader.kt` 的下载层，并**去掉**
/// 规则解析与入库：解析链（`AdGuardRuleParser` 371 行 + `HostsAndDnsmasqParser`
/// 156 行）本轮没有移植，因此这里只负责「把正文拉下来、数行数、拿校验符」。
///
/// ## 本轮边界（必须如实告知用户）
/// 下载到的正文**不会**写进 `block_rule` / `allow_rule` / `rewrite_rule`。写入
/// `subscription.ruleCount` 的是 [countEffectiveRuleLines] 的**词法行数**，是
/// 真实规则条数的上界。UI 文案必须写「已下载 N 行，规则解析与入库将在后续版本
/// 接入」，不能写成「已导入 N 条规则」，否则用户会以为拦截已生效。
///
/// ## 超时与重定向
/// 连接 30s、读取 60s，与 `SubscriptionDownloader` 构造的 `OkHttpClient` 一致。
/// `HttpClient` 默认跟随重定向（最多 5 跳），镜像站常靠 302 跳转，所以不能关。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:diting/data/db/subscription_models.dart';
import 'package:diting/data/subscriptions/subscription_url.dart';

/// 一次下载的结果。[error] 非空表示失败，其余字段无意义。
class SubscriptionFetchResult {
  const SubscriptionFetchResult({
    required this.outcome,
    this.lineCount = 0,
    this.byteLength = 0,
    this.etag,
    this.lastModified,
    this.error,
    this.requestedUrl,
    this.usedMirror = false,
  });

  const SubscriptionFetchResult.notModified({
    this.etag,
    this.lastModified,
    this.requestedUrl,
    this.usedMirror = false,
  }) : outcome = SubscriptionFetchOutcome.notModified,
       lineCount = 0,
       byteLength = 0,
       error = null;

  const SubscriptionFetchResult.failed(
    String message, {
    this.requestedUrl,
    this.usedMirror = false,
  }) : outcome = SubscriptionFetchOutcome.failed,
       lineCount = 0,
       byteLength = 0,
       etag = null,
       lastModified = null,
       error = message;

  final SubscriptionFetchOutcome outcome;

  /// 词法级有效行数（见 [countEffectiveRuleLines] 的「已知近似」说明）。
  final int lineCount;
  final int byteLength;
  final String? etag;
  final String? lastModified;

  /// 失败时的可读文案，直接上屏与落库到 `importError`。
  final String? error;

  /// 实际请求的地址（镜像回退后可能与订阅原址不同）。
  final String? requestedUrl;

  /// 本次是否走了镜像模板。
  final bool usedMirror;

  bool get isSuccess => outcome == SubscriptionFetchOutcome.content;
  bool get isNotModified => outcome == SubscriptionFetchOutcome.notModified;
  bool get isFailure => outcome == SubscriptionFetchOutcome.failed;
}

enum SubscriptionFetchOutcome { content, notModified, failed }

/// 可替换的下载接口：页面与测试都通过它取数据，避免真连网络。
abstract class SubscriptionFetcher {
  /// 下载 [record] 指向的订阅。[useValidators] 为 false 时不带
  /// `If-None-Match` / `If-Modified-Since`（412 重试路径用）。
  Future<SubscriptionFetchResult> fetch(
    SubscriptionRecord record, {
    bool useValidators = true,
  });
}

/// 基于 `dart:io HttpClient` 的实现。
class HttpSubscriptionFetcher implements SubscriptionFetcher {
  HttpSubscriptionFetcher({
    HttpClient Function()? clientFactory,
    this.connectTimeout = const Duration(seconds: 30),
    this.readTimeout = const Duration(seconds: 60),
    this.onProgress,
  }) : _clientFactory = clientFactory ?? HttpClient.new;

  final HttpClient Function() _clientFactory;
  final Duration connectTimeout;
  final Duration readTimeout;

  /// 下载进度：`(已读字节, 总字节；未知为 -1)`。
  final void Function(int received, int total)? onProgress;

  @override
  Future<SubscriptionFetchResult> fetch(
    SubscriptionRecord record, {
    bool useValidators = true,
  }) async {
    final requestedUrl = _mirrorUrlOf(record);
    if (requestedUrl != null) {
      final mirrorResult = await _fetchOnce(
        record,
        requestedUrl,
        useValidators: useValidators,
        usedMirror: true,
      );
      // null 表示「镜像失败且允许回退」，落到底下的原址请求。
      if (mirrorResult != null) {
        return mirrorResult;
      }
    }
    final result = await _fetchOnce(
      record,
      record.url,
      useValidators: useValidators,
      usedMirror: false,
    );
    return result ??
        SubscriptionFetchResult.failed('订阅地址不可用', requestedUrl: record.url);
  }

  /// 镜像地址；没有模板、模板非法或非远程订阅时返回 null（直接问原址）。
  static String? _mirrorUrlOf(SubscriptionRecord record) {
    final template = record.mirrorTemplate?.trim();
    if (template == null || template.isEmpty || !record.isRemote) {
      return null;
    }
    try {
      return buildMirrorUrl(template, record.url);
    } on FormatException {
      return null;
    }
  }

  /// 下载一次。
  ///
  /// 返回 null 只在「镜像下载失败且 `mirrorFallback` 为 true」时发生：由调用方
  /// 换原址重试，与上游 `catch (e) { if (!mirrorFallback) throw; ... }` 一致。
  Future<SubscriptionFetchResult?> _fetchOnce(
    SubscriptionRecord record,
    String requestedUrl, {
    required bool useValidators,
    required bool usedMirror,
  }) async {
    final client = _clientFactory()..connectionTimeout = connectTimeout;
    try {
      // 412（校验符失效）按上游做法去掉校验符重试一次，所以这里是个循环。
      var validators = useValidators;
      while (true) {
        final result = await _request(
          client,
          record,
          requestedUrl,
          useValidators: validators,
          usedMirror: usedMirror,
        );
        // null 哨兵：校验符被服务端拒绝，去掉它们再来一次。
        if (result != null) {
          return result;
        }
        validators = false;
      }
    } on TimeoutException {
      return _fallbackOr(
        SubscriptionFetchResult.failed(
          '下载超时（读取 ${readTimeout.inSeconds} 秒）',
          requestedUrl: requestedUrl,
          usedMirror: usedMirror,
        ),
        record,
        usedMirror,
      );
    } on SocketException catch (error) {
      return _fallbackOr(
        SubscriptionFetchResult.failed(
          _networkErrorText(error),
          requestedUrl: requestedUrl,
          usedMirror: usedMirror,
        ),
        record,
        usedMirror,
      );
    } on HandshakeException {
      return _fallbackOr(
        SubscriptionFetchResult.failed(
          'TLS 握手失败，请检查证书或镜像地址',
          requestedUrl: requestedUrl,
          usedMirror: usedMirror,
        ),
        record,
        usedMirror,
      );
    } on FormatException {
      return _fallbackOr(
        SubscriptionFetchResult.failed(
          '订阅地址格式无效',
          requestedUrl: requestedUrl,
          usedMirror: usedMirror,
        ),
        record,
        usedMirror,
      );
    } finally {
      client.close(force: true);
    }
  }

  /// 单次请求。返回 null 表示「校验符被服务端拒绝（412），去掉后再试一次」。
  Future<SubscriptionFetchResult?> _request(
    HttpClient client,
    SubscriptionRecord record,
    String requestedUrl, {
    required bool useValidators,
    required bool usedMirror,
  }) async {
    final request = await client.getUrl(Uri.parse(requestedUrl));
    request.followRedirects = true;
    request.maxRedirects = 5;
    if (useValidators) {
      final etag = record.httpEtag;
      final lastModified = record.httpLastModified;
      if (etag != null && etag.isNotEmpty) {
        request.headers.set(HttpHeaders.ifNoneMatchHeader, etag);
      }
      if (lastModified != null && lastModified.isNotEmpty) {
        request.headers.set(HttpHeaders.ifModifiedSinceHeader, lastModified);
      }
    }
    final response = await request.close().timeout(readTimeout);
    final etag = response.headers.value(HttpHeaders.etagHeader);
    final lastModified = response.headers.value(HttpHeaders.lastModifiedHeader);

    if (response.statusCode == HttpStatus.preconditionFailed && useValidators) {
      await response.drain<void>();
      return null;
    }
    if (response.statusCode == HttpStatus.notModified) {
      await response.drain<void>();
      return SubscriptionFetchResult.notModified(
        etag: etag,
        lastModified: lastModified,
        requestedUrl: requestedUrl,
        usedMirror: usedMirror,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain<void>();
      return SubscriptionFetchResult.failed(
        'HTTP ${response.statusCode}',
        requestedUrl: requestedUrl,
        usedMirror: usedMirror,
      );
    }

    final body = await _readBody(response);
    if (body.isEmpty) {
      return SubscriptionFetchResult.failed(
        '订阅响应为空',
        requestedUrl: requestedUrl,
        usedMirror: usedMirror,
      );
    }
    final content = const Utf8Decoder(allowMalformed: true).convert(body);
    return SubscriptionFetchResult(
      outcome: SubscriptionFetchOutcome.content,
      lineCount: countEffectiveRuleLines(content),
      byteLength: body.length,
      etag: etag,
      lastModified: lastModified,
      requestedUrl: requestedUrl,
      usedMirror: usedMirror,
    );
  }

  /// 镜像地址失败时：允许回退则返回 null（让调用方换原址），否则原样返回失败。
  ///
  /// 只有本次请求确实走了镜像才有回退目标；原址自己失败没有备选，直接报错。
  SubscriptionFetchResult? _fallbackOr(
    SubscriptionFetchResult failure,
    SubscriptionRecord record,
    bool usedMirror,
  ) {
    if (usedMirror && record.mirrorFallback) {
      return null;
    }
    return failure;
  }

  Future<List<int>> _readBody(HttpClientResponse response) async {
    final total = response.contentLength;
    final body = <int>[];
    await for (final chunk in response.timeout(readTimeout)) {
      body.addAll(chunk);
      onProgress?.call(body.length, total);
    }
    return body;
  }

  static String _networkErrorText(SocketException error) {
    final code = error.osError?.message;
    return code == null || code.isEmpty ? '网络不可达' : '网络不可达：$code';
  }
}

/// 非 Android 宿主 / 未注入实现时的兜底：直接报「不可用」，不抛异常。
class UnavailableSubscriptionFetcher implements SubscriptionFetcher {
  const UnavailableSubscriptionFetcher();

  @override
  Future<SubscriptionFetchResult> fetch(
    SubscriptionRecord record, {
    bool useValidators = true,
  }) async => const SubscriptionFetchResult.failed('当前环境不支持网络订阅更新');
}

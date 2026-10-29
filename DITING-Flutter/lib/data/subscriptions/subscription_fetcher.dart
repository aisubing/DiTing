library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:diting/data/db/subscription_models.dart';
import 'package:diting/data/http/request_user_agent.dart';
import 'package:diting/data/subscriptions/subscription_url.dart';

/// Result of one download. A non-null [error] means failure and the other fields are meaningless.
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
    this.content,
  });

  const SubscriptionFetchResult.notModified({
    this.etag,
    this.lastModified,
    this.requestedUrl,
    this.usedMirror = false,
  }) : outcome = SubscriptionFetchOutcome.notModified,
       lineCount = 0,
       byteLength = 0,
       error = null,
       content = null;

  const SubscriptionFetchResult.failed(
    String message, {
    this.requestedUrl,
    this.usedMirror = false,
  }) : outcome = SubscriptionFetchOutcome.failed,
       lineCount = 0,
       byteLength = 0,
       etag = null,
       lastModified = null,
       error = message,
       content = null;

  final SubscriptionFetchOutcome outcome;

  /// Lexical line count, not imported rules (see [countEffectiveRuleLines]).
  final int lineCount;
  final int byteLength;
  final String? etag;
  final String? lastModified;

  /// Readable failure text, shown to the user and stored as `importError`.
  final String? error;

  /// URL actually requested; differs after a mirror fallback.
  final String? requestedUrl;

  final bool usedMirror;

  final String? content;

  bool get isSuccess => outcome == SubscriptionFetchOutcome.content;
  bool get isNotModified => outcome == SubscriptionFetchOutcome.notModified;
  bool get isFailure => outcome == SubscriptionFetchOutcome.failed;
}

enum SubscriptionFetchOutcome { content, notModified, failed }

/// Replaceable so pages and tests never hit the network.
abstract class SubscriptionFetcher {
  /// Downloads the subscription in [record]. With [useValidators] false the request omits
  /// `If-None-Match` / `If-Modified-Since` (the 412 retry path).
  Future<SubscriptionFetchResult> fetch(
    SubscriptionRecord record, {
    bool useValidators = true,
  });
}

class HttpSubscriptionFetcher implements SubscriptionFetcher {
  HttpSubscriptionFetcher({
    HttpClient Function()? clientFactory,
    this.connectTimeout = const Duration(seconds: 30),
    this.readTimeout = const Duration(seconds: 60),
    this.userAgent = appFallbackUserAgent,
    this.onProgress,
    this.globalMirrorTemplate,
  }) : _clientFactory = clientFactory ?? HttpClient.new;

  final HttpClient Function() _clientFactory;
  final Duration connectTimeout;
  final Duration readTimeout;

  /// `/config/user-agents` override; servers that key on UA reject the default one.
  final String userAgent;

  /// Download progress: (bytes read, total bytes, or -1 when unknown).
  final void Function(int received, int total)? onProgress;

  /// Global mirror for rows without their own template; it always falls back to direct.
  final String? globalMirrorTemplate;

  @override
  Future<SubscriptionFetchResult> fetch(
    SubscriptionRecord record, {
    bool useValidators = true,
  }) async {
    final ownMirror = _mirrorUrlOf(record, record.mirrorTemplate);
    final requestedUrl =
        ownMirror ?? _mirrorUrlOf(record, globalMirrorTemplate);
    if (requestedUrl != null) {
      final mirrorResult = await _fetchOnce(
        record,
        requestedUrl,
        useValidators: useValidators,
        usedMirror: true,
        allowFallback: ownMirror == null || record.mirrorFallback,
      );
      if (mirrorResult != null) {
        return mirrorResult;
      }
    }
    final result = await _fetchOnce(
      record,
      record.url,
      useValidators: useValidators,
      usedMirror: false,
      allowFallback: false,
    );
    return result ??
        SubscriptionFetchResult.failed('订阅地址不可用', requestedUrl: record.url);
  }

  /// Mirror URL, or null without a usable template or for a non-remote record.
  static String? _mirrorUrlOf(SubscriptionRecord record, String? raw) {
    final template = raw?.trim();
    if (template == null || template.isEmpty || !record.isRemote) {
      return null;
    }
    try {
      return buildMirrorUrl(template, record.url);
    } on FormatException {
      return null;
    }
  }

  /// Downloads once. Null only when a mirror failed and fallback is allowed.
  Future<SubscriptionFetchResult?> _fetchOnce(
    SubscriptionRecord record,
    String requestedUrl, {
    required bool useValidators,
    required bool usedMirror,
    required bool allowFallback,
  }) async {
    final client = _clientFactory()..connectionTimeout = connectTimeout;
    try {
      // A 412 means the validators are stale; retry once without them.
      var validators = useValidators;
      while (true) {
        final result = await _request(
          client,
          record,
          requestedUrl,
          useValidators: validators,
          usedMirror: usedMirror,
        );
        // Null sentinel: the server rejected the validators, retry without them.
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
        allowFallback,
      );
    } on SocketException catch (error) {
      return _fallbackOr(
        SubscriptionFetchResult.failed(
          _networkErrorText(error),
          requestedUrl: requestedUrl,
          usedMirror: usedMirror,
        ),
        allowFallback,
      );
    } on HandshakeException {
      return _fallbackOr(
        SubscriptionFetchResult.failed(
          'TLS 握手失败，请检查证书或镜像地址',
          requestedUrl: requestedUrl,
          usedMirror: usedMirror,
        ),
        allowFallback,
      );
    } on FormatException {
      return _fallbackOr(
        SubscriptionFetchResult.failed(
          '订阅地址格式无效',
          requestedUrl: requestedUrl,
          usedMirror: usedMirror,
        ),
        allowFallback,
      );
    } finally {
      client.close(force: true);
    }
  }

  /// Single request. Null means 412: retry without the validators.
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
    request.headers.set(HttpHeaders.userAgentHeader, userAgent);
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
      content: content,
    );
  }

  /// After a mirror failure: null when fallback is allowed, else the failure.
  SubscriptionFetchResult? _fallbackOr(
    SubscriptionFetchResult failure,
    bool allowFallback,
  ) {
    if (allowFallback) {
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

/// Fallback when no implementation is injected: reports "unavailable" instead of throwing.
class UnavailableSubscriptionFetcher implements SubscriptionFetcher {
  const UnavailableSubscriptionFetcher();

  @override
  Future<SubscriptionFetchResult> fetch(
    SubscriptionRecord record, {
    bool useValidators = true,
  }) async => const SubscriptionFetchResult.failed('当前环境不支持网络订阅更新');
}

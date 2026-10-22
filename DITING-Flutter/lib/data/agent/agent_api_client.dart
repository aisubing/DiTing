/// OpenAI 兼容的对话接口客户端（照抄 1.4.3 `AgentApiClient.kt` 用到的那部分）。
///
/// ## 上一轮是什么
///
/// `/hub/agent` 的「分析一个域名」「分析最近流量」点下去弹一份**写死的**对话框：
/// 「风险等级：中」「该域名包含明显的统计参数与第三方追踪特征」。厂商、密钥、
/// 温度、系统提示词全在内存里（`AgentApiNotifier`），杀进程就没了；两个「测试」
/// 按钮不发任何请求。页面自己也写着「本演示不会真正发起网络请求」——这是本仓
/// 唯一一种**明确承认是假的**的入口，但它占着旧版真实能力的位子。
///
/// ## 端点推导逐字照抄旧版
///
/// `AgentApiClient.resolveChatCompletionsEndpoint` / `resolveModelsEndpoint` 里
/// 那几个分支都是有来历的：DeepSeek 的 Base URL 是 `https://api.deepseek.com`，
/// 智谱是 `.../api/paas/v4`，硅基流动是 `.../v1`。拼错一段的表现是 404 +
/// 一段服务端 JSON，用户只会看到「请求失败」。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 一条对话消息。
class AgentChatMessage {
  const AgentChatMessage({required this.role, required this.content});

  /// `system` / `user` / `assistant`。
  final String role;
  final String content;

  Map<String, Object?> toJson() => {'role': role, 'content': content};
}

/// 一次对话返回。
class AgentChatResult {
  const AgentChatResult({
    required this.content,
    required this.model,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
  });

  final String content;
  final String model;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  bool get hasUsage => totalTokens > 0;
}

/// 请求失败，`message` 是可以直接展示给用户的那一句。
class AgentApiException implements Exception {
  const AgentApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 生效中的 AI 配置（对应旧版 `AgentApiConfig`）。
class AgentChatConfig {
  const AgentChatConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.temperature = 0.7,
    this.systemPrompt = '',
  });

  final String baseUrl;
  final String apiKey;
  final String model;
  final double temperature;
  final String systemPrompt;

  bool get hasKey => apiKey.trim().isNotEmpty;
}

/// OpenAI 兼容客户端。
class AgentApiClient {
  const AgentApiClient({
    this.connectTimeout = const Duration(seconds: 15),
    this.readTimeout = const Duration(seconds: 45),
    this.modelsTimeout = const Duration(seconds: 20),
  });

  final Duration connectTimeout;
  final Duration readTimeout;
  final Duration modelsTimeout;

  /// `Base URL` → `/chat/completions`。逐条照抄旧版
  /// `resolveChatCompletionsEndpoint`。
  static String resolveChatCompletionsEndpoint(String rawBaseUrl) {
    final trimmed = rawBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) {
      throw const AgentApiException('接口地址为空，请先在「AI 厂商管理」里填写');
    }
    if (trimmed.endsWith('/chat/completions')) return trimmed;
    if (trimmed.endsWith('/v1')) return '$trimmed/chat/completions';
    if (trimmed.endsWith('/api')) return '$trimmed/v1/chat/completions';
    final lower = trimmed.toLowerCase();
    if (lower == 'https://api.openai.com' ||
        lower == 'https://api.deepseek.com') {
      return '$trimmed/v1/chat/completions';
    }
    return '$trimmed/chat/completions';
  }

  /// `Base URL` → `/models`。逐条照抄旧版 `resolveModelsEndpoint`。
  static String resolveModelsEndpoint(String rawBaseUrl) {
    final trimmed = rawBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) {
      throw const AgentApiException('接口地址为空，请先在「AI 厂商管理」里填写');
    }
    if (trimmed.endsWith('/chat/completions')) {
      return '${trimmed.substring(0, trimmed.length - '/chat/completions'.length)}/models';
    }
    if (trimmed.endsWith('/v1')) return '$trimmed/models';
    if (trimmed.endsWith('/api')) return '$trimmed/v1/models';
    final lower = trimmed.toLowerCase();
    if (lower == 'https://api.openai.com' ||
        lower == 'https://api.deepseek.com') {
      return '$trimmed/v1/models';
    }
    return '$trimmed/models';
  }

  /// 拉模型列表。
  ///
  /// 旧版把「模型候选」完全交给在线拉取，因为硬编码型号会过期。这里保持同一
  /// 取舍，并把三种响应形态（`data` / `models` / `result`）都认下来：国内几家
  /// 兼容实现并不完全一致。
  Future<List<String>> fetchModels({
    required String baseUrl,
    required String apiKey,
  }) async {
    final endpoint = resolveModelsEndpoint(baseUrl);
    final body = await _sendJson(
      method: 'GET',
      url: endpoint,
      apiKey: apiKey,
      timeout: modelsTimeout,
    );
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const AgentApiException('服务端未返回模型列表（响应不是 JSON 对象）');
    }
    final array = decoded['data'] ?? decoded['models'] ?? decoded['result'];
    if (array is! List) {
      throw const AgentApiException('服务端未返回模型列表（响应中缺少 data 字段）');
    }
    final ids = <String>{};
    for (final item in array) {
      String? id;
      if (item is Map) {
        for (final key in const ['id', 'model_id', 'name']) {
          final value = item[key];
          if (value is String && value.trim().isNotEmpty) {
            id = value.trim();
            break;
          }
        }
      } else if (item is String && item.trim().isNotEmpty) {
        id = item.trim();
      }
      if (id != null) ids.add(id);
    }
    if (ids.isEmpty) {
      throw const AgentApiException('接口未返回任何模型，请手动填写模型名称');
    }
    return ids.toList()..sort();
  }

  /// 一次连通性测试：发一句极短的话，确认密钥与模型名都能用。
  Future<AgentChatResult> testConnection(AgentChatConfig config) {
    if (!config.hasKey) {
      throw const AgentApiException('API Key 不能为空');
    }
    return chat(
      config,
      const [
        AgentChatMessage(
          role: 'user',
          content: 'Hi, this is a connectivity test from DITING. '
              "Please reply with 'OK' and your model name in 10 words.",
        ),
      ],
      temperatureOverride: 0.1,
      timeout: const Duration(seconds: 15),
    );
  }

  /// 对话补全。
  Future<AgentChatResult> chat(
    AgentChatConfig config,
    List<AgentChatMessage> messages, {
    double? temperatureOverride,
    Duration? timeout,
  }) async {
    if (!config.hasKey) {
      throw const AgentApiException('API Key 不能为空，请先在 AI 分析设置中配置');
    }
    final endpoint = resolveChatCompletionsEndpoint(config.baseUrl);
    final payload = <String, Object?>{
      'model': config.model.trim().isEmpty ? 'deepseek-flash' : config.model,
      'messages': [for (final message in messages) message.toJson()],
      'temperature': temperatureOverride ?? config.temperature,
    };
    final body = await _sendJson(
      method: 'POST',
      url: endpoint,
      apiKey: config.apiKey,
      payload: payload,
      timeout: timeout ?? readTimeout,
    );
    return _parseChat(body, fallbackModel: config.model);
  }

  // ------------------------------------------------------------------ 内部

  AgentChatResult _parseChat(String body, {required String fallbackModel}) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const AgentApiException('服务端响应不是 JSON 对象');
    }
    final choices = decoded['choices'];
    String content = '';
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final message = first['message'];
        if (message is Map && message['content'] is String) {
          content = (message['content'] as String).trim();
        } else if (first['text'] is String) {
          // 少数实现（补全式端点）把正文直接放在 `choices[].text`。
          content = (first['text'] as String).trim();
        }
      }
    }
    if (content.isEmpty) {
      throw const AgentApiException('模型返回了空内容，请检查模型名称或稍后重试');
    }
    final usage = decoded['usage'];
    int readUsage(String key) =>
        usage is Map && usage[key] is num ? (usage[key] as num).toInt() : 0;
    final model = decoded['model'];
    return AgentChatResult(
      content: content,
      model: model is String && model.trim().isNotEmpty
          ? model.trim()
          : fallbackModel,
      promptTokens: readUsage('prompt_tokens'),
      completionTokens: readUsage('completion_tokens'),
      totalTokens: readUsage('total_tokens'),
    );
  }

  /// 一次请求 + 错误归一。状态码翻成可操作的话，而不是把服务端 JSON 原样抛给用户。
  Future<String> _sendJson({
    required String method,
    required String url,
    required String apiKey,
    Map<String, Object?>? payload,
    required Duration timeout,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw AgentApiException('接口地址不合法：$url');
    }
    final client = HttpClient()..connectionTimeout = connectTimeout;
    try {
      final request = await client.openUrl(method, uri).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'DITING-Android');
      if (apiKey.trim().isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${apiKey.trim()}',
        );
      }
      if (payload != null) {
        final bytes = utf8.encode(jsonEncode(payload));
        request.headers.contentType = ContentType(
          'application',
          'json',
          charset: 'utf-8',
        );
        request.contentLength = bytes.length;
        request.add(bytes);
      }
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join().timeout(
        timeout,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AgentApiException(
          _describe(status: response.statusCode, body: body),
        );
      }
      return body;
    } on AgentApiException {
      rethrow;
    } on TimeoutException {
      throw const AgentApiException('请求超时：模型服务在限定时间内没有响应');
    } on SocketException catch (error) {
      throw AgentApiException(
        '无法连接模型服务（${error.osError?.message ?? error.message}）',
      );
    } on HandshakeException {
      throw const AgentApiException('TLS 握手失败：服务端证书不可信或协议不匹配');
    } on FormatException {
      throw const AgentApiException('服务端响应不是合法 JSON');
    } finally {
      client.close(force: true);
    }
  }

  /// HTTP 状态 + 服务端 `error.message` → 一句能照着做的话。
  static String _describe({required int status, required String body}) {
    var serverMessage = '';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] is String) {
          serverMessage = (error['message'] as String).trim();
        } else if (decoded['message'] is String) {
          serverMessage = (decoded['message'] as String).trim();
        }
      }
    } on FormatException {
      // 非 JSON 响应（网关 HTML 页）不阻塞下面的状态码映射。
    }
    final hint = switch (status) {
      401 => 'API Key 无效或已过期',
      403 => '密钥无权访问该模型，或该地区被限制',
      404 => '接口地址或模型名称不存在（404）',
      429 => '请求过于频繁或额度用尽（429）',
      >= 500 => '模型服务暂时不可用（$status）',
      _ => '请求失败（$status）',
    };
    final detail = serverMessage.isEmpty
        ? ''
        : '：${serverMessage.length > 200 ? '${serverMessage.substring(0, 200)}…' : serverMessage}';
    return '$hint$detail';
  }
}

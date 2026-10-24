import 'dart:async';

import 'package:diting/data/agent/agent_analysis_target.dart';
import 'package:diting/data/agent/agent_api_client.dart';
import 'package:diting/state/agent_providers.dart';
import 'package:diting/state/log_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Answers each request with a scripted delay, so two runs can finish out of order.
class ScriptedClient extends AgentApiClient {
  ScriptedClient(this.replies);

  final List<Completer<AgentChatResult>> replies;

  @override
  Future<AgentChatResult> chat(
    AgentChatConfig config,
    List<AgentChatMessage> messages, {
    double? temperatureOverride,
    Duration? timeout,
    AgentCancelToken? cancelToken,
  }) {
    final index = _taken++;
    return replies[index].future;
  }

  int _taken = 0;

  int get calls => _taken;
}

const _config = AgentChatConfig(
  baseUrl: 'https://api.test',
  apiKey: 'sk-test',
  model: 'm1',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  ProviderContainer containerWith(List<Completer<AgentChatResult>> replies) {
    final container = ProviderContainer(
      overrides: [
        agentChatConfigProvider.overrideWithValue(_config),
        agentApiClientProvider.overrideWithValue(ScriptedClient(replies)),
        // No legacy database in a unit test: the domain branch tolerates null.
        activeLogDatabaseProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('分析会话', () {
    test('新请求取代旧请求，旧请求不再发往模型', () async {
      final reply = Completer<AgentChatResult>();
      final client = ScriptedClient([reply]);
      final container = ProviderContainer(
        overrides: [
          agentChatConfigProvider.overrideWithValue(_config),
          agentApiClientProvider.overrideWithValue(client),
          activeLogDatabaseProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(agentAnalysisProvider.notifier);

      final oldSession = notifier.start(const AgentDomainTarget('old.test'));
      final newSession = notifier.start(const AgentDomainTarget('new.test'));
      expect(newSession, greaterThan(oldSession));

      // The abandoned run is dropped before it reaches the network, so only one call is made.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(client.calls, 1);
      expect(container.read(agentAnalysisProvider).running, isTrue);

      reply.complete(
        const AgentChatResult(content: '新结论', model: 'm1', totalTokens: 2),
      );
      await Future<void>.delayed(Duration.zero);
      final state = container.read(agentAnalysisProvider);
      expect(state.success, isTrue);
      expect(state.content, '新结论');
      expect(state.sessionId, newSession);
      expect((state.target as AgentDomainTarget).domain, 'new.test');
    });

    test('取消后回到空闲，且不写错误', () async {
      final reply = Completer<AgentChatResult>();
      final container = containerWith([reply]);
      final notifier = container.read(agentAnalysisProvider.notifier);
      notifier.start(const AgentDomainTarget('a.test'));
      expect(container.read(agentAnalysisProvider).running, isTrue);

      notifier.cancel();
      final cancelled = container.read(agentAnalysisProvider);
      expect(cancelled.idle, isTrue);
      expect(cancelled.error, isNull);

      // The socket is closed, so the pending future must not resurrect the run.
      reply.complete(
        const AgentChatResult(content: '迟到的结论', model: 'm1'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(agentAnalysisProvider).idle, isTrue);
    });

    test('没有密钥时立刻给出可操作的提示', () async {
      final container = ProviderContainer(
        overrides: [
          agentChatConfigProvider.overrideWithValue(null),
          activeLogDatabaseProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);
      final session = container
          .read(agentAnalysisProvider.notifier)
          .start(const AgentDomainTarget('a.test'));
      final state = container.read(agentAnalysisProvider);
      expect(state.sessionId, session);
      expect(state.failed, isTrue);
      expect(state.error, contains('API Key'));
    });
  });

  group('请求取消', () {
    test('已取消的令牌直接拒绝发请求', () async {
      final token = AgentCancelToken()..cancel();
      await expectLater(
        const AgentApiClient().chat(
          _config,
          const [AgentChatMessage(role: 'user', content: 'hi')],
          cancelToken: token,
        ),
        throwsA(
          isA<AgentApiException>().having(
            (error) => error.message,
            'message',
            '分析已取消',
          ),
        ),
      );
    });
  });
}

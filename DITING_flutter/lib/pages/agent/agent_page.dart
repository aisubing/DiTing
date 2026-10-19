import 'dart:math' as math;

import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// AI 助手：聊天式界面 + 预置示例对话 + 快捷提问。
///
/// 上游 AI 能力是「从某条域名/流量记录出发，调一次非流式 API，把结果渲染成
/// 四段结构化分析」。演示层没有 API Key 也没有网络，但必须保留那条交互链的
/// 形状：**提问 → 等待 → 结构化回答**。因此这里做成聊天界面而不是表单：
/// 用户问什么、AI 答什么，比一堆只读卡片更接近真实用法。
///
/// 空态用 [NullStatus] 而不是空白列表：聊天页第一屏什么都不显示会让人
/// 怀疑页面没加载出来。
class AgentPage extends StatefulWidget {
  const AgentPage({super.key});

  @override
  State<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends State<AgentPage> {
  /// 预置示例：进入页面就有内容，不必先想一个问题。
  static const _examples = <_ChatMessage>[
    _ChatMessage(
      fromUser: true,
      text: 'tracking.analytics-service.net 这个域名安全吗？',
    ),
    _ChatMessage(
      fromUser: false,
      text: '**画像**：第三方埋点域名，常见于广告与行为分析 SDK，'
          '无实际内容服务。\n\n'
          '**风险评级**：中。会上报设备标识与页面事件，本身不携带恶意代码。\n\n'
          '**处置建议**：建议加入黑名单。若某个应用依赖它做崩溃上报，'
          '可改为仅在该应用上放行。\n\n'
          '**总结**：可拦截；拦截后不影响正常浏览。',
    ),
    _ChatMessage(fromUser: true, text: '解释一下 `||ads.example.com^` 这条规则'),
    _ChatMessage(
      fromUser: false,
      text: '这是 AdGuard 语法的域名拦截规则。\n\n'
          '`||` 表示从域名边界开始匹配，`^` 表示域名在此结束（分隔符位置）。\n\n'
          '所以它同时命中 `ads.example.com`、`a.ads.example.com`，'
          '但**不会**命中 `ads.example.com.cn` 或 `myads.example.com`。',
    ),
  ];

  static const _suggestions = <String>[
    '这个域名为什么被拦截？',
    '解释一下当前的黑名单规则',
    '有哪些应用在偷偷上报数据？',
    '竞速模式和智能选择有什么区别？',
  ];

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[..._examples];
  bool _thinking = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _thinking) {
      return;
    }
    setState(() {
      _messages.add(_ChatMessage(fromUser: true, text: text));
      _thinking = true;
      _controller.clear();
    });
    _scrollToEnd();
    // 800ms 是刻意选的：太快看不出「在思考」，太慢会让人以为卡死。真实调用
    // 是非流式的（整包返回），所以这段等待就是用户实际会看到的样子。
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) {
      return;
    }
    setState(() {
      _messages.add(_ChatMessage(fromUser: false, text: _replyFor(text)));
      _thinking = false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    // 等一帧：新气泡的高度要等布局完成才算得出来，否则滚不到底。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: midDuration,
        curve: Curves.easeOut,
      );
    });
  }

  /// 固定回复表。
  ///
  /// 按关键词分派而不是随机文案：同一个问题问两次得到不同答案，会让人以为
  /// 这里真的接了大模型。
  static String _replyFor(String question) {
    if (question.contains('拦截')) {
      return '这条域名命中了黑名单里的 `||tracking.analytics-service.net^`，'
          '规则来源是「内置广告域名」订阅。\n\n'
          '处置结果按当前设置返回 NXDOMAIN，客户端会立刻失败，'
          '不会等待超时。想放行可以把它加进白名单，白名单优先于黑名单。';
    }
    if (question.contains('规则')) {
      return '当前黑名单共 3 条自定义 + 1 份订阅（内置广告域名，约 1.2 万条）。\n\n'
          '规则按「白名单 → 黑名单 → 覆写」的顺序匹配，第一个命中的生效。\n\n'
          '覆写规则只在解析成功后改写结果，不参与拦截判断。';
    }
    if (question.contains('上报') || question.contains('应用')) {
      return '近 1 小时有 3 个应用发起了异常频繁的 DNS 查询：\n\n'
          '· 天气（com.example.weather）：每 20 秒一次，域名集中在埋点域\n'
          '· 新闻（com.example.news）：启动时一次性查询 40+ 域名\n'
          '· 输入法（com.example.ime）：疑似云联想，查询带设备标识\n\n'
          '建议对前两个应用启用「按应用分流」，把埋点域直接拦截。';
    }
    if (question.contains('竞速') || question.contains('智能')) {
      return '**智能选择**按历史延迟与成功率给服务商打分，只用一家（分数最高的）。\n\n'
          '**并行竞速**同时向多家发起查询，取最先返回的结果，'
          '延迟最低但流量放大 N 倍。\n\n'
          '日常用智能选择即可；对延迟极敏感（如游戏加速）再开竞速。';
    }
    return '我是本机 AI 助手，可以帮你解释域名画像、规则语义和流量异常。\n\n'
        '本阶段是 UI 演示：回复是固定的示例文案，没有真实调用模型。'
        '接入方式见「设置 → AI 助手」的厂商管理。';
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: 'AI 助手',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.clearAll,
          tooltip: '清空对话',
          onPressed: () => setState(_messages.clear),
        ),
      ],
      body: Column(
        children: [
          // 顶栏浮在正文之上，消息列表要从栏底开始排。
          SizedBox(height: context.appBarInset),
          Expanded(
            child: _messages.isEmpty
                ? const NullStatus(
                    label: '还没有对话',
                    description: '在下面输入一个问题，或点一条快捷提问开始',
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    itemCount: _messages.length + (_thinking ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _messages.length) {
                        return const _TypingBubble();
                      }
                      return _ChatBubble(message: _messages[index]);
                    },
                  ),
          ),
          _SuggestionBar(
            suggestions: _suggestions,
            onSelected: (text) => _send(text),
          ),
          _Composer(
            controller: _controller,
            busy: _thinking,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

/// 一条消息。`fromUser` 决定左右对齐与配色。
class _ChatMessage {
  const _ChatMessage({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final user = message.fromUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: user
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!user) ...[
            _Avatar(glyph: AppGlyphs.sparkle, filled: false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: math.min(MediaQuery.sizeOf(context).width * 0.78, 520),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: ShapeDecoration(
                shape: AppShape.lg,
                color: user
                    ? colorScheme.primary
                    : context.raisedSurfaceLevel.colorOf(colorScheme),
              ),
              child: Text(
                message.text,
                style: AppTextStyle.body.of(context).copyWith(
                  color: user ? colorScheme.onPrimary : colorScheme.onSurface,
                ),
              ),
            ),
          ),
          if (user) ...[
            const SizedBox(width: 8),
            _Avatar(glyph: AppGlyphs.account, filled: true),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.glyph, required this.filled});

  final Glyph glyph;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        shape: AppShape.full,
        color: filled
            ? colorScheme.primary.withValues(alpha: 0.16)
            : colorScheme.surfaceContainerHigh,
      ),
      child: GlyphIcon(glyph, size: 17, color: colorScheme.primary),
    );
  }
}

/// 「正在思考」占位：三个点依次呼吸。
///
/// 不用 `CommonCircleLoading`：转圈表示「请求在路上」，而这里要表达的是
/// 「模型正在生成」，三点更像输入中的光标。
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Avatar(glyph: AppGlyphs.sparkle, filled: false),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: ShapeDecoration(
              shape: AppShape.lg,
              color: context.raisedSurfaceLevel.colorOf(colorScheme),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  for (var index = 0; index < 3; index++)
                    Opacity(
                      opacity: _dotOpacity(index),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: ShapeDecoration(
                          shape: AppShape.circle,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 三点错相：每点在自己的相位区间内从 0.3 升到 1 再落回。
  double _dotOpacity(int index) {
    final phase = (_controller.value + index / 3) % 1.0;
    return 0.3 + 0.7 * (1 - (phase * 2 - 1).abs());
  }
}

/// 快捷提问条：横向滚动的 chip，点一下直接发问。
class _SuggestionBar extends StatelessWidget {
  const _SuggestionBar({required this.suggestions, required this.onSelected});

  final List<String> suggestions;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final text = suggestions[index];
          return Center(
            child: TonalButton(
              size: TonalButtonSize.compact,
              label: text,
              onPressed: () => onSelected(text),
            ),
          );
        },
      ),
    );
  }
}

/// 输入区：多行输入 + 发送。
///
/// 用 `TextField` 而不是 `InputDialog`：聊天页的输入必须常驻可见，弹窗会把
/// 对话内容整个遮住，失去「边看边问」的上下文。
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 8,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: ShapeDecoration(
                shape: AppShape.full,
                color: context.raisedSurfaceLevel.colorOf(colorScheme),
              ),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: '问点什么…',
                ),
              ),
            ),
          ),
          IconButton.filled(
            onPressed: busy ? null : onSend,
            icon: busy
                ? const CommonCircleLoading(size: 18)
                : const GlyphIcon(AppGlyphs.send, fill: 1),
          ),
        ],
      ),
    );
  }
}

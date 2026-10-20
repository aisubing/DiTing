// ignore_for_file: sort_child_properties_last
import 'package:diting/router.dart';
import 'package:diting/state/hub_settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 规则控制（上游 `RuleControlScreen`）。
///
/// 总开关 + URL 规则入口 + 拦截响应 + 订阅与更新；黑/白/覆写名单仍在
/// 功能中心对应卡片里独立管理。
class RuleControlPage extends ConsumerStatefulWidget {
  const RuleControlPage({super.key});

  @override
  ConsumerState<RuleControlPage> createState() => _RuleControlPageState();
}

class _RuleControlPageState extends ConsumerState<RuleControlPage> {
  bool _domainRules = true;
  final bool _autoUpdate = true;
  final int _intervalHours = 6;

  @override
  Widget build(BuildContext context) {
    final inspection = ref.watch(httpInspectionProvider);
    final inspectionApps = ref.watch(hubAppSelectionsProvider)[
        HubAppPool.httpInspection] ??
        const <String>{};
    final urlSubtitle = !inspection.caReady
        ? '未就绪 · 需先安装并验证 CA 根证书'
        : !inspection.enabled
        ? '未就绪 · 需在 HTTPS 流量检查中开启'
        : inspectionApps.isEmpty
        ? '未就绪 · 需在 HTTPS 流量检查中选择目标应用'
        : !_domainRules
        ? '已暂停 · 未启用解密 URL 过滤与重定向'
        : '运行中 · 解密流量匹配 URL 屏蔽、放行及重定向';
    return CommonScaffold(
      title: '规则控制',
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              child: Text(
                '统一管理域名过滤、URL 规则及规则覆写的总控开关、拦截策略与在线规则订阅。'
                '黑名单、白名单与覆写名单可在功能中心中独立管理。',
                style: context.listSubtitleStyle,
              ),
            ),
          ),
          generateSection(
            title: '过滤与覆写控制',
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.rules),
                title: const Text('启用域名规则'),
                subtitle: Text(
                  _domainRules
                      ? '开启 DNS 阶段域名屏蔽、白名单放行及 IPv4/IPv6 覆写'
                      : '已禁用 DNS 域名过滤，查询将直接放行',
                ),
                value: _domainRules,
                onChanged: (value) => setState(() => _domainRules = value),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.target),
                title: const Text('URL 规则与内容过滤'),
                subtitle: Text(urlSubtitle),
                trailing: Text(
                  inspection.urlRules && inspection.enabled ? '运行中' : '未就绪',
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: context.colorScheme.onSurfaceVariant),
                ),
                onTap: () => context.push('/hub/https-inspection'),
              ),
            ],
          ),
          generateSection(
            title: '拦截策略',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.block),
                title: const Text('拦截响应'),
                subtitle: const Text('动态策略：先 NODATA，高频请求后 NXDOMAIN'),
                onTap: () => context.push('/hub/rules/block-response'),
              ),
            ],
          ),
          generateSection(
            title: '订阅与更新',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.cloudSync),
                title: const Text('规则订阅'),
                subtitle: const Text('管理域名规则与 IPv4/IPv6 覆写订阅源及分组'),
                trailing: Text(
                  '5 个',
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: context.colorScheme.onSurfaceVariant),
                ),
                onTap: () => context.push(Routes.subscriptions),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.refresh),
                title: const Text('自动更新设置'),
                subtitle: Text(
                  _autoUpdate ? '已开启 · 每 $_intervalHours 小时自动更新' : '已关闭自动更新',
                ),
                onTap: () => context.push('/hub/rules/auto-update'),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.layers),
                title: const Text('镜像站模板'),
                subtitle: const Text('维护订阅下载镜像，可在添加订阅时直接选择'),
                trailing: Text(
                  '3 个',
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: context.colorScheme.onSurfaceVariant),
                ),
                onTap: () => context.push('/hub/rules/mirrors'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 拦截响应模式。
enum BlockResponseMode {
  nxdomain('返回 NXDOMAIN', '返回域名不存在，并提供 5 分钟负缓存以减少重复查询'),
  nodata('返回 NODATA', '返回域名存在但没有该记录，并提供 5 分钟负缓存'),
  refused('返回 REFUSED', '返回服务器拒绝该查询，不提供缓存记录'),
  zeroAddress('返回 0.0.0.0 / ::', 'A 返回 0.0.0.0，AAAA 返回 ::，其他类型返回空结果');

  const BlockResponseMode(this.label, this.description);

  final String label;
  final String description;
}

/// 拦截响应设置（上游 `BlockResponseSettingsScreen`）。
class BlockResponsePage extends StatefulWidget {
  const BlockResponsePage({super.key});

  @override
  State<BlockResponsePage> createState() => _BlockResponsePageState();
}

class _BlockResponsePageState extends State<BlockResponsePage> {
  BlockResponseMode _mode = BlockResponseMode.nxdomain;
  bool _dynamic = true;
  int _threshold = 5;
  int _window = 60;
  int _duration = 600;

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '拦截响应',
      body: PageBody(
        children: [
          generateSection(
            title: '固定响应',
            items: [
              for (final mode in BlockResponseMode.values)
                ListItem(
                  leading: GlyphIcon(
                    mode == _mode ? AppGlyphs.checkCircle : AppGlyphs.block,
                    size: 20,
                  ),
                  title: Text(mode.label),
                  subtitle: Text(mode.description),
                  trailing: mode == _mode ? const SelectionCheck() : null,
                  onTap: () => setState(() => _mode = mode),
                ),
            ],
            footer: '动态策略开启时会临时覆盖以上选择：先返回 NODATA，'
                '高频请求后返回 NXDOMAIN。',
          ),
          generateSection(
            title: '动态策略',
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.motion),
                title: const Text('启用动态策略'),
                subtitle: const Text('同一域名的所有记录类型合并计数'),
                value: _dynamic,
                onChanged: (value) => setState(() => _dynamic = value),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.sliders),
                title: const Text('动态参数'),
                subtitle: Text('$_threshold 次 / $_window 秒 / 保持 $_duration 秒'),
                onTap: _dynamic ? _editParameters : null,
              ),
            ],
            footer: '正常客户端会缓存 NODATA 响应。动态策略主要用于持续重试或'
                '忽略负缓存的请求。',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _editParameters() async {
    final result = await showFloatingDialog<({int threshold, int window, int duration})>(
      context: context,
      child: _DynamicParameterDialog(
        threshold: _threshold,
        window: _window,
        duration: _duration,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _threshold = result.threshold;
      _window = result.window;
      _duration = result.duration;
    });
  }
}

class _DynamicParameterDialog extends StatefulWidget {
  const _DynamicParameterDialog({
    required this.threshold,
    required this.window,
    required this.duration,
  });

  final int threshold;
  final int window;
  final int duration;

  @override
  State<_DynamicParameterDialog> createState() => _DynamicParameterDialogState();
}

class _DynamicParameterDialogState extends State<_DynamicParameterDialog> {
  late final _threshold = TextEditingController(text: '${widget.threshold}');
  late final _window = TextEditingController(text: '${widget.window}');
  late final _duration = TextEditingController(text: '${widget.duration}');
  String? _error;

  @override
  void dispose() {
    _threshold.dispose();
    _window.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _save() {
    final threshold = int.tryParse(_threshold.text);
    final window = int.tryParse(_window.text);
    final duration = int.tryParse(_duration.text);
    String? error;
    if (threshold == null || threshold < 2 || threshold > 50) {
      error = '请求次数需在 2–50 之间';
    } else if (window == null || window < 5 || window > 600) {
      error = '统计窗口需在 5–600 秒之间';
    } else if (duration == null || duration < 60 || duration > 86400) {
      error = '保持时长需在 60–86400 秒之间';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop((
      threshold: threshold!,
      window: window!,
      duration: duration!,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: '动态参数',
      hasFields: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          TextField(
            controller: _threshold,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '请求次数',
              helperText: '2–50 次；第 N+1 次开始升级',
            ),
          ),
          TextField(
            controller: _window,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '统计窗口（秒）',
              helperText: '5–600 秒',
            ),
          ),
          TextField(
            controller: _duration,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'NXDOMAIN 保持时长（秒）',
              helperText: '60–86400 秒；首次升级起固定计时',
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: AppTextStyle.footnote.of(context).copyWith(
                color: context.colorScheme.error,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}

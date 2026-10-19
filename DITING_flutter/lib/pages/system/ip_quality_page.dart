/// IP 质量浮层（上游 `features/ip_quality/ip_quality_sheet.dart`，229 行）。
///
/// 上游是浮层而不是页面：它从首页/工具页的一个按钮弹出，看完即走。本仓路由表
/// 里登记的是 `/ip-quality`，所以这里做成「页面形式打开同一个内容」，并把内容
/// 本身抽成 `IpQualitySheet`，两种入口共用一份——浮层与整页的差别只在容器。
library;

import 'package:diting/data/mock_forms.dart';
import 'package:diting/state/system_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// IP 类型徽标的四个取值（上游 `IpType`）。
enum IpType {
  residential('住宅', AppGlyphs.account),
  mobile('移动', AppGlyphs.devices),
  business('商业', AppGlyphs.profiles),
  hosting('机房', AppGlyphs.cpu);

  const IpType(this.label, this.glyph);

  final String label;
  final Glyph glyph;
}

/// IP 质量等级（上游 `IpQualityLevel`，三档配色与上游一致）。
enum IpQualityLevel {
  good('优秀'),
  normal('一般'),
  risky('风险');

  const IpQualityLevel(this.label);

  final String label;
}

/// 单个来源的结果（上游 `IpQualitySourceStatus`）。
enum IpQualitySourceStatus {
  ok('命中'),
  noType('无类型'),
  timeout('超时'),
  rateLimited('限流'),
  failed('失败'),
  ipMismatch('IP 不一致');

  const IpQualitySourceStatus(this.label);

  final String label;

  bool get isError => this != ok;
}

/// 解析数据层的字符串枚举；未知值按失败处理（数据与枚举不同步时别崩）。
IpQualitySourceStatus _statusOf(String raw) => switch (raw) {
  '命中' => IpQualitySourceStatus.ok,
  '无类型' => IpQualitySourceStatus.noType,
  '超时' => IpQualitySourceStatus.timeout,
  '限流' => IpQualitySourceStatus.rateLimited,
  'IP 不一致' => IpQualitySourceStatus.ipMismatch,
  _ => IpQualitySourceStatus.failed,
};

IpType _typeOf(String raw) => switch (raw) {
  '住宅' => IpType.residential,
  '移动' => IpType.mobile,
  '商业' => IpType.business,
  _ => IpType.hosting,
};

IpQualityLevel _levelOf(String raw) => switch (raw) {
  '优秀' => IpQualityLevel.good,
  '一般' => IpQualityLevel.normal,
  _ => IpQualityLevel.risky,
};

/// IP 质量页（整页容器）。
class IpQualityPage extends ConsumerStatefulWidget {
  const IpQualityPage({super.key});

  @override
  ConsumerState<IpQualityPage> createState() => _IpQualityPageState();
}

class _IpQualityPageState extends ConsumerState<IpQualityPage> {
  @override
  void initState() {
    super.initState();
    // 进页面就重测一次：IP 可能已经变了，而不重测的话用户看到的是上次结果。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(ipQualityProvider.notifier).detect(mockIpQualityReport.ip);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ipQualityProvider);
    return CommonScaffold(
      title: 'IP 质量',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.refresh,
          tooltip: '重新检测',
          isLoading: state.stage == IpQualityStage.loading,
          onPressed: () =>
              ref.read(ipQualityProvider.notifier).detect(state.ip),
        ),
      ],
      body: PageBody(
        children: [
          IpQualitySheet(
            report: mockIpQualityReport,
            stage: state.stage,
            onRetry: () =>
                ref.read(ipQualityProvider.notifier).detect(state.ip),
          ),
        ],
      ),
    );
  }
}

/// IP 质量内容本体：地址 + 类型徽标 + 风险等级 + 来源列表。
///
/// 做成 `StatelessWidget` 而不是浮层函数，这样可以同时被页面与
/// `showIpQualitySheet` 使用，且不依赖调用方的 `BuildContext` 生命周期。
class IpQualitySheet extends StatelessWidget {
  const IpQualitySheet({
    super.key,
    required this.report,
    required this.stage,
    this.onRetry,
  });

  final MockIpQualityReport report;
  final IpQualityStage stage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final type = _typeOf(report.ipType);
    final level = _levelOf(report.level);
    final levelColor = switch (level) {
      IpQualityLevel.good => colorScheme.success,
      IpQualityLevel.normal => colorScheme.onSurfaceVariant,
      IpQualityLevel.risky => colorScheme.error,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: CommonCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Row(
                  spacing: 10,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 4,
                        children: [
                          Text('当前出口地址', style: context.listCaptionStyle),
                          Text(
                            report.ip,
                            style: AppTextStyle.title2
                                .of(context, emphasized: true)
                                .copyWith(fontFamily: 'JetBrainsMono'),
                          ),
                        ],
                      ),
                    ),
                    if (stage == IpQualityStage.loading)
                      const CommonCircleLoading()
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: ShapeDecoration(
                          color: levelColor.withValues(alpha: 0.14),
                          shape: AppShape.full,
                        ),
                        child: Text(
                          level.label,
                          style: AppTextStyle.subheadline
                              .of(context, emphasized: true)
                              .copyWith(color: levelColor),
                        ),
                      ),
                  ],
                ),
                Row(
                  spacing: 8,
                  children: [
                    _TypeBadge(type: type),
                    MetaChip(label: report.asn),
                    const Spacer(),
                    Text(
                      report.organization,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.listCaptionStyle,
                    ),
                  ],
                ),
                if (stage == IpQualityStage.loading)
                  ClipRSuperellipse(
                    borderRadius: AppRadius.full,
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      backgroundColor: context.raisedSurfaceLevel.colorOf(
                        colorScheme,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        generateSection(
          title: '来源',
          items: [
            for (final source in report.sources)
              _SourceRow(source: source),
          ],
          footer: '各来源对「住宅 / 机房」的判断经常互相矛盾：'
              '命中数越多越可信，但单一来源的「风险」标签不足以作为结论。',
        ),
        if (stage == IpQualityStage.loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text('正在向 5 个来源查询…', style: context.listCaptionStyle),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: TonalButton(
            label: stage == IpQualityStage.loading ? '检测中…' : '重新检测',
            glyph: AppGlyphs.refresh,
            size: TonalButtonSize.section,
            onPressed: stage == IpQualityStage.loading ? null : onRetry,
          ),
        ),
      ],
    );
  }
}

/// IP 类型徽标。
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final IpType type;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(
        color: colorScheme.secondaryContainer,
        shape: AppShape.full,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          GlyphIcon(type.glyph, size: 14, color: colorScheme.onSecondaryContainer),
          Text(
            type.label,
            style: AppTextStyle.caption1
                .of(context)
                .copyWith(color: colorScheme.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}

/// 一个来源行：名称 + 延迟 + 状态徽标。
class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source});

  final MockIpQualitySource source;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final status = _statusOf(source.status);
    final color = status.isError ? colorScheme.error : colorScheme.success;
    final ipType = source.ipType;
    final latency = source.latencyMs;
    return ListItem(
      leading: GlyphIcon(
        status.isError ? AppGlyphs.warning : AppGlyphs.checkCircle,
        color: color,
      ),
      title: Text(source.name),
      subtitle: Row(
        spacing: 8,
        children: [
          Text(status.label, style: context.listCaptionStyle.copyWith(color: color)),
          if (ipType != null)
            Text(
              '判定为${_typeOf(ipType).label}',
              style: context.listCaptionStyle,
            ),
          if (latency != null)
            Text(
              '${latency}ms',
              style: context.listCaptionStyle.copyWith(
                fontFamily: 'JetBrainsMono',
              ),
            ),
        ],
      ),
      trailing: status.isError
          ? TonalChip(
              label: '未采用',
              color: colorScheme.errorContainer,
              foregroundColor: colorScheme.onErrorContainer,
            )
          : TonalChip(
              label: '已采用',
              color: colorScheme.successContainer,
              foregroundColor: colorScheme.onSuccessContainer,
            ),
    );
  }
}

/// IP quality (upstream `features/ip_quality/ip_quality_sheet.dart`).
library;

import 'package:diting/data/tools/ip_quality_checker.dart';
import 'package:diting/state/system_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The four IP type badge values (upstream `IpType`).
enum IpType {
  residential('住宅', AppGlyphs.account),
  mobile('移动', AppGlyphs.devices),
  business('商业', AppGlyphs.profiles),
  hosting('机房', AppGlyphs.cpu);

  const IpType(this.label, this.glyph);

  final String label;
  final Glyph glyph;
}

/// IP quality level (upstream `IpQualityLevel`, with matching three-tier colors).
enum IpQualityLevel {
  good('优秀'),
  normal('一般'),
  risky('风险');

  const IpQualityLevel(this.label);

  final String label;
}

/// Result of one source (upstream `IpQualitySourceStatus`).
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

/// Parses a string enum; unknown values become failures instead of crashing.
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

class IpQualityPage extends ConsumerStatefulWidget {
  const IpQualityPage({super.key});

  @override
  ConsumerState<IpQualityPage> createState() => _IpQualityPageState();
}

class _IpQualityPageState extends ConsumerState<IpQualityPage> {
  @override
  void initState() {
    super.initState();
    // Re-probe on entry: the egress IP may have changed since the last run.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(ipQualityProvider.notifier).detect();
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
          onPressed: () => ref.read(ipQualityProvider.notifier).detect(),
        ),
      ],
      body: PageBody(
        children: [
          IpQualitySheet(
            report: state.report,
            stage: state.stage,
            error: state.error,
            onRetry: () => ref.read(ipQualityProvider.notifier).detect(),
          ),
        ],
      ),
    );
  }
}

/// `StatelessWidget` so both the page and `showIpQualitySheet` can use it.
class IpQualitySheet extends StatelessWidget {
  const IpQualitySheet({
    super.key,
    required this.report,
    required this.stage,
    this.error,
    this.onRetry,
  });

  /// The real probe result; `null` means no successful probe yet.
  final IpQualityReport? report;
  final IpQualityStage stage;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    if (report == null) {
      // Without a report, speak per stage: spinner, reason and retry, or a hint. No
      // hard-coded sample is shown.
      return _EmptyReport(
        stage: stage,
        error: error,
        onRetry: onRetry,
      );
    }
    final current = report!;
    final type = _typeOf(current.ipType);
    final level = _levelOf(current.level);
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
                            current.ip,
                            style: AppTextStyle.title2
                                .of(context, emphasized: true)
                                .copyWith(fontFamily: appMonospaceFontFamily),
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
                    // The ASN is capped and may ellipsize, otherwise a long org name
                    // overflows the card (`RIGHT OVERFLOWED BY 51 PIXELS`).
                    if (current.asn.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: MetaChip(label: current.asn),
                      ),
                    // The org name must be `Expanded`: `Spacer` only distributes leftover
                    // space, so an unconstrained `Text` overflows the `Row`.
                    Expanded(
                      child: Text(
                        current.organization,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.listCaptionStyle,
                      ),
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
            for (final source in current.sources) _SourceRow(source: source),
          ],
          footer:
              '各来源对「住宅 / 机房」的判断经常互相矛盾：'
              '命中数越多越可信，但单一来源的「风险」标签不足以作为结论。',
        ),
        if (stage == IpQualityStage.loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text('正在查询出口 IP 与 3 个情报源…', style: context.listCaptionStyle),
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

/// Placeholder before any report exists; no constant sample is rendered.
class _EmptyReport extends StatelessWidget {
  const _EmptyReport({required this.stage, this.error, this.onRetry});

  final IpQualityStage stage;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final loading = stage == IpQualityStage.loading;
    final failed = stage == IpQualityStage.failed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: CommonCard(
            padding: const EdgeInsets.all(16),
            isError: failed,
            child: Row(
              spacing: 12,
              children: [
                if (loading)
                  const CommonCircleLoading()
                else
                  GlyphIcon(
                    failed ? AppGlyphs.error : AppGlyphs.cloudSync,
                    size: 22,
                    color: failed
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(
                        loading
                            ? '正在检测'
                            : (failed ? '检测失败' : '尚未检测'),
                        style: context.listTitleStyle,
                      ),
                      Text(
                        error ??
                            (loading
                                ? '正在获取出口 IP 并查询情报源，请稍候'
                                : '点下方按钮开始检测当前出口 IP 的质量'),
                        style: context.listCaptionStyle.copyWith(
                          color: failed ? colorScheme.error : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: TonalButton(
            label: loading ? '检测中…' : '开始检测',
            glyph: AppGlyphs.refresh,
            size: TonalButtonSize.section,
            onPressed: loading ? null : onRetry,
          ),
        ),
      ],
    );
  }
}

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
          GlyphIcon(
            type.glyph,
            size: 14,
            color: colorScheme.onSecondaryContainer,
          ),
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

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source});

  final IpSourceResult source;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final status = _statusOf(source.status);
    final color = status.isError ? colorScheme.error : colorScheme.success;
    final ipType = source.ipType;
    final latency = source.latencyMs;
    final detail = source.detail;
    return ListItem(
      leading: GlyphIcon(
        status.isError ? AppGlyphs.warning : AppGlyphs.checkCircle,
        color: color,
      ),
      title: Text(source.name),
      // `Wrap` rather than `Row`: four text segments overflow a `Row` on narrow screens
      // with large text.
      subtitle: Wrap(
        spacing: 8,
        runSpacing: 2,
        children: [
          Text(
            status.label,
            style: context.listCaptionStyle.copyWith(color: color),
          ),
          if (ipType != null)
            Text('判定为${_typeOf(ipType).label}', style: context.listCaptionStyle),
          if (latency != null)
            Text(
              '${latency}ms',
              style: context.listCaptionStyle.copyWith(
                fontFamily: appMonospaceFontFamily,
              ),
            ),
          // The reason is shown: "failed" alone cannot tell rate limiting apart.
          if (detail != null && detail.isNotEmpty)
            Text(detail, style: context.listCaptionStyle),
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
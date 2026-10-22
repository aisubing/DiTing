/// IP 质量浮层（上游 `features/ip_quality/ip_quality_sheet.dart`，229 行）。
///
/// 上游是浮层而不是页面：它从首页/工具页的一个按钮弹出，看完即走。本仓路由表
/// 里登记的是 `/ip-quality`，所以这里做成「页面形式打开同一个内容」，并把内容
/// 本身抽成 `IpQualitySheet`，两种入口共用一份——浮层与整页的差别只在容器。
library;

import 'package:diting/data/tools/ip_quality_checker.dart';
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
    // 进页面就重测一次：出口 IP 可能已经变了，不重测的话用户看到的是上次结果。
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

/// IP 质量内容本体：地址 + 类型徽标 + 风险等级 + 来源列表。
///
/// 做成 `StatelessWidget` 而不是浮层函数，这样可以同时被页面与
/// `showIpQualitySheet` 使用，且不依赖调用方的 `BuildContext` 生命周期。
class IpQualitySheet extends StatelessWidget {
  const IpQualitySheet({
    super.key,
    required this.report,
    required this.stage,
    this.error,
    this.onRetry,
  });

  /// 真实检测结果；`null` 表示还没成功检测过。
  final IpQualityReport? report;
  final IpQualityStage stage;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    if (report == null) {
      // 没有报告时按阶段说话：检测中转圈、失败给原因与重试、未检测给提示。
      // 不再像上一轮那样先把一份写死的「样例报告」摆在页面上。
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
                    // ASN 由响应决定长度（`AS15169` 与空串都可能），给它一个上限并
                    // 允许省略：`MetaChip` 本身不省略，真机上 `AS9808` 加长机构名
                    // 会直接把整行撑出卡片（`RIGHT OVERFLOWED BY 51 PIXELS`）。
                    if (current.asn.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: MetaChip(label: current.asn),
                      ),
                    // 机构名必须 `Expanded`：`Spacer` 只能分配**剩余**空间，而
                    // 未约束的 `Text` 会先按自身宽度占位，`Row` 于是溢出。
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

/// 还没有报告时的样子：按阶段说话，不摆一份写死的样例。
///
/// 上一轮页面一进来就渲染 `mockIpQualityReport`（`203.0.113.24` / `AS64500` /
/// 「风险」），看起来像检测结果，其实是常量。现在没有真实数据就明说没有。
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

/// 一个来源行：名称 + 延迟 + 状态徽标。
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
      // `Wrap` 而不是 `Row`：一条来源最多有四段文字（状态/判定/延迟/失败原因），
      // 窄屏加上大字号会超出卡片宽度。`Row` 溢出时只是印一句调试条纹，用户看到的是
      // 一行字被截断；`Wrap` 会换行，信息不会丢。
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
                fontFamily: 'JetBrainsMono',
              ),
            ),
          // 失败原因必须显示：只写「失败」用户无从判断是限流、地址错还是网络问题。
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

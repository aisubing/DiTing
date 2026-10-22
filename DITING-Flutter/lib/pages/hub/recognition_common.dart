/// 名单页的公共实现：头像、行、列表骨架。
///
/// 赞助者名单与共建者名单在旧版是两块几乎一样的界面（同一份 JSON、同一套
/// 头像仓库、同一个列表组件），差异只有标题、说明文案与「能否按时间排序」。
/// 因此抽成 [RecognitionListPage] 一个实现，两个页面各自传参即可——两份复制
/// 的列表代码早就开始漂移（一处有徽标、一处没有），是显示不一致的根源。
///
/// ## 头像从哪来
///
/// 只从云端 `avatars/<name>_avatar.jpg` 下载（本地磁盘缓存，见
/// `RecognitionMembersRepository`）。**不在 APK 里内置头像**：头像与名单一样
/// 由维护者在 GitHub 上更新，内置副本只会固化成发版那一刻的旧图。
library;

import 'package:diting/data/recognition/recognition_members.dart';
import 'package:diting/state/recognition_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/empty_state.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 圆形头像：从云端下载（本地磁盘缓存），拿不到时画人形占位。
///
/// 占位符不写成「昵称首字」的彩色圆圈：那会让人误以为头像已经加载成功，也
/// 让不同成员之间只能靠颜色区分。这里统一用人形 glyph + 中性底色，一眼就能
/// 看出「这张头像还没到」。
class RecognitionAvatar extends ConsumerWidget {
  const RecognitionAvatar({super.key, required this.member, this.size = 48});

  final RecognitionMember member;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileName = member.avatarFileName;
    if (fileName == null) {
      return _frame(context, _placeholder(context));
    }
    final bytes = ref.watch(recognitionAvatarProvider(fileName)).value;
    if (bytes == null) {
      return _frame(context, _placeholder(context));
    }
    return _frame(
      context,
      Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final dimension = constraints.biggest.shortestSide;
      return Center(
        child: GlyphIcon(
          AppGlyphs.account,
          size: dimension * 0.55,
          color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
        ),
      );
    },
  );

  Widget _frame(BuildContext context, Widget child) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colorScheme.surfaceContainerHigh,
      ),
      child: child,
    );
  }
}

/// 一位成员的一行：头像 + 昵称。
class RecognitionMemberRow extends StatelessWidget {
  const RecognitionMemberRow({super.key, required this.member});

  final RecognitionMember member;

  @override
  Widget build(BuildContext context) {
    return ListItem(
      leading: RecognitionAvatar(member: member),
      title: Text(member.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// 名单页骨架。两个名单页只差 [title]、[intro]、[sectionTitle]、[select]
/// 与 [sortable]。
class RecognitionListPage extends ConsumerStatefulWidget {
  const RecognitionListPage({
    super.key,
    required this.title,
    required this.intro,
    required this.sectionTitle,
    required this.select,
    this.sortable = false,
  });

  final String title;
  final String intro;
  final String sectionTitle;

  /// 从整份配置里取出本页要展示的成员（赞助者 / 共建者）。
  final List<RecognitionMember> Function(RecognitionMembers) select;

  /// 是否在顶栏提供「由早到晚 / 由晚到早」切换。
  final bool sortable;

  @override
  ConsumerState<RecognitionListPage> createState() =>
      _RecognitionListPageState();
}

class _RecognitionListPageState extends ConsumerState<RecognitionListPage> {
  bool _newestFirst = false;
  bool _requestedFirstLoad = false;

  @override
  void initState() {
    super.initState();
    // 缓存为空时也要主动拉一次，否则首次安装会一直停在「暂无名单」。
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureFresh());
  }

  void _ensureFresh() {
    if (!mounted) return;
    if (ref.read(recognitionMembersProvider).value == null) return;
    _requestedFirstLoad = true;
    ref.read(recognitionMembersProvider.notifier).ensureFresh();
  }

  Future<void> _refresh() async {
    await ref.read(recognitionMembersProvider.notifier).refresh();
    if (!mounted) return;
    final state = ref.read(recognitionMembersProvider).value;
    _toast(context, state?.error ?? '名单已更新');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recognitionMembersProvider);
    final data = async.value;
    final state = data ?? const RecognitionState();
    // 数据首次到达后触发一次静默刷新（缓存超过 freshWindow 才会真的联网）。
    if (!_requestedFirstLoad && data != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureFresh());
    }
    final members = state.members;
    final visible = members == null
        ? const <RecognitionMember>[]
        : () {
            final list = widget.select(members);
            return widget.sortable && _newestFirst
                ? list.reversed.toList(growable: false)
                : list;
          }();

    return CommonScaffold(
      title: widget.title,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.refresh,
          tooltip: '刷新名单',
          isLoading: state.isRefreshing,
          onPressed: _refresh,
        ),
        if (widget.sortable)
          IconButtonData(
            glyph: AppGlyphs.sort,
            tooltip: _newestFirst ? '切换为由早到晚' : '切换为由晚到早',
            isSelected: _newestFirst,
            onPressed: () => setState(() => _newestFirst = !_newestFirst),
          ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(16),
              child: Text(widget.intro, style: context.listSubtitleStyle),
            ),
          ),
          if (!state.hasMembers && (state.isRefreshing || data == null))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CommonCircleLoading()),
            )
          else if (!state.hasMembers)
            EmptyStateBox(
              minHeight: 320,
              child: NullStatus(
                label: state.error == null ? '暂时没有名单' : '名单加载失败',
                description: state.error ?? '名单由云端下发，点这里拉取一次。',
                illustration: state.error == null
                    ? NullStatusIllustration.data
                    : NullStatusIllustration.error,
                action: TextButton(
                  onPressed: _refresh,
                  child: Text(state.error == null ? '加载名单' : '重试'),
                ),
              ),
            )
          else if (visible.isEmpty)
            EmptyStateBox(
              minHeight: 280,
              child: NullStatus(
                label: '暂时还没有成员',
                description: '名单会随云端配置更新，稍后再来看看。',
                illustration: NullStatusIllustration.data,
                action: TextButton(
                  onPressed: _refresh,
                  child: const Text('刷新'),
                ),
              ),
            )
          else
            generateSection(
              title: '${widget.sectionTitle}（${visible.length}）',
              items: [
                for (final member in visible) RecognitionMemberRow(member: member),
              ],
            ),
          if (state.hasMembers) _StatusFooter(state: state),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 页脚：说明当前数据来自哪里、上次何时更新。
///
/// 刷新失败时如实写「正在显示本地缓存」，而不是静默当作成功——上一轮顶栏
/// 刷新只弹一句「已更新」，服务器根本没连上也照弹。
class _StatusFooter extends StatelessWidget {
  const _StatusFooter({required this.state});

  final RecognitionState state;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (state.error != null) {
      parts.add(state.error!);
    } else if (state.fromCache) {
      parts.add('正在显示本地缓存的名单');
    }
    final updatedAt = state.updatedAt;
    if (updatedAt != null) {
      parts.add('上次更新：${_formatTime(updatedAt)}');
    }
    if (parts.isEmpty) {
      parts.add('名单由云端下发，进入页面时自动检查更新');
    }
    return ListFooter(text: parts.join(' · '));
  }

  static String _formatTime(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 2000),
    ),
  );
}

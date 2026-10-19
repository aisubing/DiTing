import 'package:diting/data/mock_profiles.dart';
import 'package:diting/routes/profiles_routes.dart';
import 'package:diting/state/profiles_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

part 'edit_profile_fields.dart';

/// 编辑档案页（上游 `views/profiles/edit.dart`，598 行）。
///
/// 上游是一个大表单：名称、URL、AGE 密钥、自动更新开关 + 分钟数、文件条目
/// （可改可上传）。这里保留前四组，文件条目换成「文件信息 + 预览/替换」两个
/// 只读动作——演示版没有文件系统，上传入口只能是假的。
///
/// 校验错误集中在页首的 `ErrorBanner` 里，不写在字段下面：上游同样只在第一次
/// 提交后才报错，且一次只报第一条，避免四个红框同时出现让用户不知先改哪个。
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _userAgent = TextEditingController();
  var _autoUpdate = AutoUpdateInterval.off;
  var _loaded = false;
  var _attempted = false;

  /// 覆写开关：演示里只存页面状态，返回时不落库（真实实现要写进档案）。
  final _overrides = <ProfileOverride>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final profile = _profileOf();
    if (profile == null) {
      _loaded = true;
      return;
    }
    _name.text = profile.name;
    _url.text = profile.url;
    _userAgent.text = profile.userAgent;
    _autoUpdate = profile.autoUpdate;
    _loaded = true;
  }

  MockProfile? _profileOf() {
    for (final profile in ref.read(profilesProvider).profiles) {
      if (profile.id == widget.profileId) {
        return profile;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _userAgent.dispose();
    super.dispose();
  }

  /// 返回第一条校验错误；`null` 表示可以保存。
  ({String field, String message})? get _issue {
    if (_name.text.trim().isEmpty) {
      return (field: '名称', message: '名称不能为空');
    }
    final profile = _profileOf();
    if (profile != null && profile.kind.isRemote) {
      final url = _url.text.trim();
      if (url.isEmpty) {
        return (field: '订阅地址', message: '订阅地址不能为空');
      }
      if (!url.startsWith('http')) {
        return (field: '订阅地址', message: '订阅地址需以 http 开头');
      }
    }
    return null;
  }

  void _save() {
    final issue = _issue;
    if (issue != null) {
      setState(() => _attempted = true);
      return;
    }
    final ok = ref
        .read(profilesProvider.notifier)
        .update(
          widget.profileId,
          name: _name.text,
          url: _url.text,
          autoUpdate: _autoUpdate,
          userAgent: _userAgent.text,
        );
    if (!ok) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('已有同名档案'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1600),
        ),
      );
      return;
    }
    context.safeNestedPop();
  }

  Future<void> _delete() async {
    final localizations = UiLocalizations.of(context);
    final profile = _profileOf();
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '删除配置档案',
        destructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.cancel),
          ),
          const _DangerAction(),
        ],
        child: Text(
          '删除「${profile?.name ?? '该档案'}」后，来自它的节点与规则会一起移除。'
          '此操作不可撤销。',
        ),
      ),
    );
    if ((confirmed ?? false) && mounted) {
      ref.read(profilesProvider.notifier).delete(widget.profileId);
      context.safeNestedPop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profileOf();
    final issue = _attempted ? _issue : null;
    if (!_loaded || profile == null) {
      return CommonScaffold(
        title: '编辑档案',
        body: const SizedBox(
          height: 320,
          child: NullStatus(
            label: '档案不存在',
            description: '它可能已被删除',
            illustration: NullStatusIllustration.profile,
          ),
        ),
      );
    }
    final isRemote = profile.kind.isRemote;
    return CommonScaffold(
      title: '编辑档案',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '保存',
        onPressed: _save,
      ),
      menuItems: [
        CommonPopupMenuItem(
          label: '查看运行配置',
          glyph: AppGlyphs.eye,
          onPressed: () =>
              context.push(ProfilesPaths.previewOf(widget.profileId)),
        ),
        if (isRemote)
          CommonPopupMenuItem(
            label: '立即更新',
            glyph: AppGlyphs.sync,
            onPressed: () {
              ref.read(profilesProvider.notifier).startUpdate(widget.profileId);
              context.safeNestedPop();
            },
          ),
      ],
      body: PageBody(
        children: [
          if (issue != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _ErrorBanner(message: '${issue.field}：${issue.message}'),
            ),
          Padding(
            // 横向 16 交给 `generateSection`，外层再加会让组头缩进 32。
            padding: EdgeInsets.only(top: issue == null ? 8 : 12),
            child: generateSection(
              title: '基本信息',
              items: [
                _ProfileTextField(
                  label: '名称',
                  controller: _name,
                  invalid: issue?.field == '名称',
                  onChanged: (_) => _onChanged(),
                ),
                if (isRemote)
                  _ProfileTextField(
                    label: '订阅地址',
                    controller: _url,
                    invalid: issue?.field == '订阅地址',
                    monospace: true,
                    keyboardType: TextInputType.url,
                    onChanged: (_) => _onChanged(),
                  )
                else
                  _ProfileFileItem(
                    profile: profile,
                    onPreview: () =>
                        context.push(ProfilesPaths.previewOf(widget.profileId)),
                  ),
              ],
            ),
          ),
          Padding(
            // 横向 16 交给 `generateSection`，外层再加会让组头缩进 32。
            padding: const EdgeInsets.only(top: 24),
            child: generateSection(
              title: '更新',
              items: [
                if (isRemote) ...[
                  ListItem<AutoUpdateInterval>.options(
                    title: const Text('自动更新'),
                    subtitle: const Text('到点自动拉取，失败会保留旧配置'),
                    options: AutoUpdateInterval.values,
                    value: _autoUpdate,
                    textBuilder: (interval) => interval.label,
                    onChanged: (interval) =>
                        setState(() => _autoUpdate = interval),
                  ),
                  _ProfileTextField(
                    label: 'User-Agent',
                    controller: _userAgent,
                    monospace: true,
                    hintText: '留空则用默认 UA',
                    onChanged: (_) => _onChanged(),
                  ),
                ] else
                  const ListItem(
                    title: Text('自动更新'),
                    subtitle: Text('只有远程订阅能自动更新'),
                    trailing: Text('不适用'),
                  ),
              ],
            ),
          ),
          Padding(
            // 横向 16 交给 `generateSection`，外层再加会让组头缩进 32。
            padding: const EdgeInsets.only(top: 24),
            child: generateSection(
              title: '覆写项',
              items: [
                for (final override in ProfileOverride.values)
                  ListItem.toggle(
                    title: Text(override.label),
                    subtitle: Text(override.description),
                    value: _overrides.contains(override),
                    onChanged: (value) => setState(() {
                      if (value) {
                        _overrides.add(override);
                      } else {
                        _overrides.remove(override);
                      }
                    }),
                  ),
              ],
              footer: '覆写项只影响这一份档案，全局设置里同名的项会被它盖住。',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16)
                .copyWith(top: 24),
            child: CommonCard(
              isError: true,
              onPressed: _delete,
              child: ListItem(
                leading: GlyphIcon(
                  AppGlyphs.delete,
                  color: context.colorScheme.error,
                ),
                title: Text(
                  '删除这份档案',
                  style: context.listTitleStyle.copyWith(
                    color: context.colorScheme.error,
                  ),
                ),
                subtitle: Text(
                  '节点与规则会一起移除，不可撤销',
                  style: context.listCaptionStyle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onChanged() {
    if (_attempted) {
      setState(() {});
    }
  }
}

/// 删除按钮：用错误色而不是纯文本按钮，因为它是对话框里唯一有破坏性的动作。
class _DangerAction extends StatelessWidget {
  const _DangerAction();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.of(context).pop(true),
      style: TextButton.styleFrom(foregroundColor: context.colorScheme.error),
      child: const Text('删除'),
    );
  }
}

/// 页首错误条：一次只报一条，位置在表单上方而不是字段下方。
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colorScheme.errorContainer,
        shape: AppShape.md,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          spacing: 8,
          children: [
            GlyphIcon(
              AppGlyphs.warning,
              size: 18,
              color: colorScheme.onErrorContainer,
            ),
            Expanded(
              child: Text(
                message,
                style: context.listCaptionStyle.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

part of 'backup_page.dart';

/// WebDAV 表单（上游 `WebDAVForm`，第 339 行）。
///
/// 上游用 `FormRow` + `FormRowTextField`（右侧内嵌输入框）。本仓的可复用表单
/// 组件在 `lib/pages/forms/`，这里直接用它们：WebDAV 表单本身就是表单族组件的
/// 第一个真实使用者，演示页顺带验证了那套 API 够不够用。
class WebDavForm extends ConsumerWidget {
  const WebDavForm({super.key, required this.onTest, required this.onReset});

  final VoidCallback onTest;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dav = ref.watch(davProvider);
    final colorScheme = context.colorScheme;
    final field = ref.read(davProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        const ListHeader(title: 'WebDAV'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CommonCard(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            child: FormPage(
              title: '',
              padding: EdgeInsets.zero,
              onSave: dav.isConfigured ? onTest : null,
              saveLabel: '测试连接',
              children: [
                FormRowTextField(
                  title: '服务器',
                  value: dav.server,
                  hintText: 'https://dav.example.com',
                  keyboardType: TextInputType.url,
                  invalid: dav.status == DavStatus.failed &&
                      dav.server.isEmpty,
                  onChanged: (value) => field.update(
                    (state) => state.copyWith(
                      server: value,
                      status: DavStatus.idle,
                    ),
                  ),
                ),
                FormRowTextField(
                  title: '用户名',
                  value: dav.username,
                  invalid: dav.status == DavStatus.failed &&
                      dav.username.isEmpty,
                  onChanged: (value) => field.update(
                    (state) => state.copyWith(
                      username: value,
                      status: DavStatus.idle,
                    ),
                  ),
                ),
                FormRowSecretTextField(
                  title: '密码',
                  controller: _passwordController(ref),
                  onChanged: (value) => field.update(
                    (state) => state.copyWith(password: value),
                  ),
                ),
                FormRowTextField(
                  title: '远端路径',
                  value: dav.path,
                  hintText: '/diting/',
                  monospace: true,
                  onChanged: (value) =>
                      field.update((state) => state.copyWith(path: value)),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            spacing: 10,
            children: [
              Expanded(
                child: TonalButton(
                  label: '测试连接',
                  glyph: AppGlyphs.sync,
                  size: TonalButtonSize.section,
                  onPressed: dav.status == DavStatus.connecting ? null : onTest,
                ),
              ),
              Expanded(
                child: TonalButton(
                  label: '清空',
                  glyph: AppGlyphs.broom,
                  size: TonalButtonSize.section,
                  onPressed: onReset,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Text(
            '演示层不发起真实请求：点「测试连接」会先转 1.2 秒，'
            '服务器地址里含 `fail` 时返回失败，其余返回成功——'
            '这样两种状态都能复现。密码只存在内存里，不落盘。',
            style: context.listCaptionStyle,
          ),
        ),
        if (dav.status == DavStatus.failed)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              spacing: 8,
              children: [
                GlyphIcon(AppGlyphs.error, size: 16, color: colorScheme.error),
                Expanded(
                  child: Text(
                    dav.message ?? '连接失败',
                    style: context.listCaptionStyle.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 密码控制器挂在 provider 之外：`TextEditingController` 是可变对象，
  /// 每次 build 新建会把光标重置。这里用一个按 provider 生命周期缓存的包装。
  TextEditingController _passwordController(WidgetRef ref) {
    final cached = ref.watch(_passwordControllerProvider);
    if (cached.text != ref.read(davProvider).password) {
      cached.value = TextEditingValue(
        text: ref.read(davProvider).password,
        selection: TextSelection.collapsed(
          offset: ref.read(davProvider).password.length,
        ),
      );
    }
    return cached;
  }
}

/// 供 `WebDavForm` 复用的密码控制器；页面销毁时 `TextEditingController`
/// 由 Riverpod 的 `onDispose` 释放。
final _passwordControllerProvider = Provider<TextEditingController>((ref) {
  final controller = TextEditingController();
  ref.onDispose(controller.dispose);
  return controller;
});

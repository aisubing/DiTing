/// WebDAV 云同步（自 `backup_page.dart` 的 `WebDavForm` 迁入功能中心）。
///
/// 旧版 1.4.3 没有独立的「备份」主页：WebDAV 只是备份页里的一张表单。本轮把
/// 备份主页整页删掉，但用户要求保留 WebDAV 能力，因此把那张表单原样搬成
/// 「功能中心 → 备份与迁移 → WebDAV 云同步」下面的一页。
///
/// 交互与样式沿用原实现：`davProvider`（`lib/state/system_providers.dart`）仍是
/// 唯一状态源，`DavStatus` 三态照用；密码只存在内存里，不落盘。
///
/// **演示层不发起真实请求**：`DavNotifier.test()` 只转 1.2 秒并按地址里有没有
/// `fail` 决定成败，页面底部如实说明这一点——比伪造「连接成功」诚实。
library;

import 'package:diting/pages/forms/form_page.dart';
import 'package:diting/state/system_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// WebDAV 云同步页。
class ConfigTransferWebdavPage extends ConsumerWidget {
  const ConfigTransferWebdavPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dav = ref.watch(davProvider);
    final field = ref.read(davProvider.notifier);
    return CommonScaffold(
      title: 'WebDAV 云同步',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.reset,
          tooltip: '清空配置',
          onPressed: dav.status == DavStatus.connecting
              ? null
              : () => ref.read(davProvider.notifier).reset(),
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _DavStatusCard(status: dav.status, message: dav.message),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
              child: FormPage(
                title: '',
                padding: EdgeInsets.zero,
                onSave: dav.isConfigured
                    ? () => ref.read(davProvider.notifier).test()
                    : null,
                saving: dav.status == DavStatus.connecting,
                saveLabel: '测试连接',
                children: [
                  FormRowTextField(
                    title: '服务器',
                    value: dav.server,
                    hintText: 'https://dav.example.com',
                    keyboardType: TextInputType.url,
                    invalid:
                        dav.status == DavStatus.failed && dav.server.isEmpty,
                    onChanged: (value) => field.update(
                      (state) =>
                          state.copyWith(server: value, status: DavStatus.idle),
                    ),
                  ),
                  FormRowTextField(
                    title: '用户名',
                    value: dav.username,
                    invalid:
                        dav.status == DavStatus.failed && dav.username.isEmpty,
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              spacing: 10,
              children: [
                Expanded(
                  child: TonalButton(
                    label: '测试连接',
                    glyph: AppGlyphs.sync,
                    size: TonalButtonSize.section,
                    onPressed: dav.status == DavStatus.connecting
                        ? null
                        : () => ref.read(davProvider.notifier).test(),
                  ),
                ),
                Expanded(
                  child: TonalButton(
                    label: '清空',
                    glyph: AppGlyphs.broom,
                    size: TonalButtonSize.section,
                    onPressed: dav.status == DavStatus.connecting
                        ? null
                        : () => ref.read(davProvider.notifier).reset(),
                  ),
                ),
              ],
            ),
          ),
          const ListFooter(
            text:
                '演示层不发起真实请求：点「测试连接」会先转 1.2 秒，'
                '服务器地址里含 `fail` 时返回失败，其余返回成功——这样两种状态都能'
                '复现。密码只存在内存里，不落盘。',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 密码控制器挂在 provider 之外：`TextEditingController` 是可变对象，
  /// 每次 build 新建会把光标重置。这里用一个按 provider 生命周期缓存的包装。
  TextEditingController _passwordController(WidgetRef ref) {
    final cached = ref.watch(_passwordControllerProvider);
    final password = ref.read(davProvider).password;
    if (cached.text != password) {
      cached.value = TextEditingValue(
        text: password,
        selection: TextSelection.collapsed(offset: password.length),
      );
    }
    return cached;
  }
}

/// 供 [ConfigTransferWebdavPage] 复用的密码控制器；页面销毁时由 Riverpod 释放。
final _passwordControllerProvider = Provider<TextEditingController>((ref) {
  final controller = TextEditingController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// 连接状态徽标（上游 `_DavConnectionIndicator`）。
///
/// 三态各有颜色与字形：只看颜色分不清「连接中」和「未连接」（两者都不显眼），
/// 所以配了不同的字形与文案。
class _DavStatusCard extends StatelessWidget {
  const _DavStatusCard({required this.status, this.message});

  final DavStatus status;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final (color, glyph) = switch (status) {
      DavStatus.idle => (colorScheme.onSurfaceVariant, AppGlyphs.cloudSync),
      DavStatus.connecting => (colorScheme.warning, AppGlyphs.sync),
      DavStatus.connected => (colorScheme.success, AppGlyphs.checkCircle),
      DavStatus.failed => (colorScheme.error, AppGlyphs.error),
    };
    return CommonCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      isError: status == DavStatus.failed,
      child: Row(
        spacing: 10,
        children: [
          if (status == DavStatus.connecting)
            CommonCircleLoading(color: color)
          else
            GlyphIcon(glyph, size: 20, color: color),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  status.label,
                  style: context.listTitleStyle.copyWith(color: color),
                ),
                Text(
                  message ?? _hintOf(status),
                  style: context.listCaptionStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _hintOf(DavStatus status) => switch (status) {
    DavStatus.idle => '配置服务器信息后可测试连接',
    DavStatus.connecting => '正在握手，请稍候',
    DavStatus.connected => '配置可上传到该地址（演示层不实际传输）',
    DavStatus.failed => '检查地址、账号与证书后重试',
  };
}

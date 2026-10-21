// ignore_for_file: sort_child_properties_last
import 'package:diting/data/cleanup/cleanup_models.dart';
import 'package:diting/state/cleanup_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 数据清理（上游 `DataCleanupScreen`，1.4.3 `DataCleanupManager`）。
///
/// 十六个动作**全部真实执行**。上一轮这一页每个动作都只弹一句
/// 「已删除 X」然后什么都不做——那是本仓最坏的一种占位：文案描述的是后果，
/// 用户据此以为数据没了，实际磁盘上一个字节都没动。
///
/// 每个动作的确认文案逐字照抄旧版（`CleanupAction` 的 `message`），因为用户
/// 实际同意的是这段文本。
///
/// ## 为什么动作清单在 `state/cleanup_providers.dart`
///
/// 分组顺序与「哪些动作要动引擎」都是数据，不是布局。放在页面里会让
/// `DataCleanupService` 的对照关系（哪个枚举值对应哪个 DAO 操作）散落到 UI 层。
class DataCleanupPage extends ConsumerWidget {
  const DataCleanupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(cleanupProgressProvider);
    return CommonScaffold(
      title: '数据清理',
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Text(
                    '以下操作会立即删除本机数据，删除后无法恢复。'
                    '重要规则或配置请在执行前备份。',
                    style: context.listSubtitleStyle,
                  ),
                  if (running != null)
                    Row(
                      spacing: 8,
                      children: [
                        const CommonCircleLoading(size: 16),
                        Expanded(
                          child: Text(
                            '正在执行：${running.title}',
                            style: context.listCaptionStyle,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          for (final group in cleanupGroups.entries)
            generateSection(
              title: group.key,
              items: [
                for (final action in group.value)
                  ListItem(
                    leading: GlyphIcon(
                      AppGlyphs.delete,
                      size: 20,
                      color: context.colorScheme.error,
                    ),
                    title: Text(
                      action.title,
                      style: TextStyle(color: context.colorScheme.error),
                    ),
                    subtitle: Text(_descriptionOf(action)),
                    // 执行中禁用整张列表：两个动作并发删同一张表会让
                    // `DELETE` 互相阻塞，也让「已删除 N 项」的数字失去意义。
                    onTap: running == null
                        ? () => _confirm(context, ref, action)
                        : null,
                  ),
              ],
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    CleanupAction action,
  ) async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: action.title,
        destructive: true,
        child: Text(_confirmTextOf(action)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref.read(cleanupRunnerProvider).run(action);
    if (!context.mounted) return;

    // 失败与「可清理项为 0」都用 SnackBar 说明原因：静默成功是最坏的结果，
    // 用户下次打开还会看到同样的数据，却不知道自己被提示过「已删除」。
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(result.message),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // 旧版这两个动作 `onExitApp()`：它们清掉了首启协议标记，留在前台会出现
    // 「应用还在跑，但下次启动要重新同意协议」的分裂状态。
    if (action.exitsApp && context.mounted) {
      await _exitApp(context);
    }
  }

  /// 退出应用（旧版 `onExitApp`）。
  ///
  /// 用 `SystemNavigator.pop()` 而不是 `exit(0)`：后者跳过 Android 的生命周期
  /// 回调，前台服务不会被正常停止，通知栏会留下一条指向已退出进程的常驻项。
  Future<void> _exitApp(BuildContext context) async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '需要重启应用',
        child: const Text(
          '清理已完成。新手引导与使用协议已重置，应用需要重新启动才会生效。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('立即退出'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await SystemNavigator.pop();
    }
  }

  /// 每行的副标题（逐字照抄旧版 `CleanupAction` 的表意）。
  static String _descriptionOf(CleanupAction action) => switch (action) {
    CleanupAction.logs => '清除 DNS、HTTP 请求日志、竞速统计及 Bootstrap 解析日志',
    CleanupAction.traffic => '清除所有应用的历史流量统计记录与实时统计状态',
    CleanupAction.crash => '清除本地保存的所有 Java 与 Native 异常崩溃日志',
    CleanupAction.dnsCache => '移除已缓存的解析结果，下次访问会重新查询',
    CleanupAction.providerWeights => '清除智能选择的健康样本，让它重新按默认权重分配流量',
    CleanupAction.bootstrapWeights => '清除 Bootstrap DNS 解析健康样本，重新按默认权重选择',
    CleanupAction.domainRules => '清除域名屏蔽、白名单、IPv4/IPv6 覆写及对应订阅，恢复预设白名单',
    CleanupAction.addressRules => '清除 URL 屏蔽、放行和 CNAME 覆写规则，不影响域名规则',
    CleanupAction.subscriptions => '清除所有网络与本地规则订阅、订阅分组及自动更新任务',
    CleanupAction.appRules => '清空分应用排除、禁止联网应用、应用白名单及抓包名单',
    CleanupAction.outboundProxy => '清空出站代理协议、服务器与鉴权信息，恢复直连',
    CleanupAction.caCertificate => '清除本地生成的 MITM CA 根证书与私钥',
    CleanupAction.downloadCache => '删除更新安装包、下载临时文件及应用临时缓存',
    CleanupAction.customBackground => '清除已配置的自定义壁纸图片缓存及路径记录，恢复默认背景',
    CleanupAction.settingsGuides => '让所有首次进入说明再次显示，需要重新同意使用协议',
    CleanupAction.allData => '深度清空所有日志、缓存、规则、订阅、证书与配置，应用将退出',
  };

  /// 确认框正文（逐字照抄旧版 `CleanupAction` 的 `message`）。
  static String _confirmTextOf(CleanupAction action) => switch (action) {
    CleanupAction.logs =>
      '确定要删除所有 DNS、HTTP 请求日志、竞速统计和 Bootstrap DNS 解析统计吗？',
    CleanupAction.traffic => '确定要清除所有应用的历史流量统计记录与实时统计状态吗？',
    CleanupAction.crash => '确定要删除所有本地崩溃日志和崩溃统计状态吗？',
    CleanupAction.dnsCache => '确定要删除所有本地 DNS 缓存吗？下次访问域名时会重新查询。',
    CleanupAction.providerWeights =>
      '确定要清除所有服务商健康样本并恢复竞速模式默认权重吗？',
    CleanupAction.bootstrapWeights =>
      '确定要清除 Bootstrap DNS 解析健康样本并恢复默认权重吗？',
    CleanupAction.domainRules =>
      '确定要删除全部域名规则吗？域名屏蔽、白名单、IPv4/IPv6 覆写规则及对应订阅都会被移除，'
          '地址规则不受影响。',
    CleanupAction.addressRules =>
      '确定要删除全部地址规则吗？URL 屏蔽、放行和 CNAME 覆写规则都会被移除，'
          '域名规则不受影响。',
    CleanupAction.subscriptions =>
      '确定要删除所有规则订阅吗？所有订阅链接、分组与订阅导入的规则都会被移除，'
          '手动添加的规则不受影响。',
    CleanupAction.appRules =>
      '确定要重置所有应用控制名单吗？分应用代理排除、禁止联网应用、应用独立白名单以及 '
          'HTTP/HTTPS 抓包应用配置都将被清空并恢复默认。',
    CleanupAction.outboundProxy =>
      '确定要重置出站代理配置吗？出站代理将被禁用，服务器地址、端口及账号密码将被清除。',
    CleanupAction.caCertificate =>
      '确定要清除本地生成的 HTTPS 抓包 CA 证书和私钥吗？如果系统已安装此证书，'
          '清除后需重新生成并导入系统方可继续解密抓包。',
    CleanupAction.downloadCache => '确定要删除下载的更新安装包和临时缓存文件吗？',
    CleanupAction.customBackground => '确定要清除自定义壁纸缓存并恢复默认外观背景吗？',
    CleanupAction.settingsGuides =>
      '确定要重置所有应用设置新手引导和首次使用协议吗？这不会删除任何配置、规则、缓存、'
          '日志或证书。操作完成后应用将退出；下次打开时需要重新同意使用协议，'
          '所有新手引导也会再次显示。',
    CleanupAction.allData =>
      '确定要执行全面数据清理吗？将依次清理所有日志、流量统计、崩溃记录、DNS 缓存、'
          '服务商权重、域名及地址规则、规则订阅、临时缓存及抓包证书。'
          '所有自定义配置与规则将被清空，新手引导也将重置，操作完成后应用将退出。',
  };
}

// ignore_for_file: sort_child_properties_last
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

/// 数据清理（上游 `DataCleanupScreen`）。
///
/// 全部动作都会二次确认；演示层只弹提示，不真正删数据。
class DataCleanupPage extends StatelessWidget {
  const DataCleanupPage({super.key});

  static const _groups = <String, List<_CleanupAction>>{
    '运行数据': [
      _CleanupAction(
        '删除请求日志',
        '清除 DNS、HTTP 请求日志、竞速统计及 Bootstrap 解析日志',
        '确定要删除所有 DNS、HTTP 请求日志、竞速统计和 Bootstrap DNS 解析统计吗？',
      ),
      _CleanupAction(
        '删除流量统计',
        '清除所有应用的历史流量统计记录与实时统计状态',
        '确定要清除所有应用的历史流量统计记录与实时统计状态吗？',
      ),
      _CleanupAction(
        '删除崩溃日志',
        '清除本地保存的所有 Java 与 Native 异常崩溃日志',
        '确定要删除所有本地崩溃日志和崩溃统计状态吗？',
      ),
      _CleanupAction(
        '删除 DNS 缓存',
        '移除已缓存的解析结果，下次访问会重新查询',
        '确定要删除所有本地 DNS 缓存吗？下次访问域名时会重新查询。',
      ),
    ],
    '权重数据': [
      _CleanupAction(
        '恢复 DNS 默认权重',
        '清除智能选择的健康样本，让它重新按默认权重分配流量',
        '确定要清除所有服务商健康样本并恢复竞速模式默认权重吗？',
      ),
      _CleanupAction(
        '恢复 Bootstrap 权重',
        '清除 Bootstrap DNS 解析健康样本，重新按默认权重选择',
        '确定要清除 Bootstrap DNS 解析健康样本并恢复默认权重吗？',
      ),
    ],
    '规则与订阅': [
      _CleanupAction(
        '删除全部域名规则',
        '清除域名屏蔽、白名单、IPv4/IPv6 覆写及对应订阅，恢复预设白名单',
        '确定要删除全部域名规则吗？域名屏蔽、白名单、IPv4/IPv6 覆写规则及对应订阅都会被移除，地址规则不受影响。',
      ),
      _CleanupAction(
        '删除全部地址规则',
        '清除 URL 屏蔽、放行和 CNAME 覆写规则，不影响域名规则',
        '确定要删除全部地址规则吗？URL 屏蔽、放行和 CNAME 覆写规则都会被移除，域名规则不受影响。',
      ),
      _CleanupAction(
        '删除全部规则订阅',
        '清除所有网络与本地规则订阅、订阅分组及自动更新任务',
        '确定要删除所有规则订阅吗？所有订阅链接、分组与订阅导入的规则都会被移除，手动添加的规则不受影响。',
      ),
      _CleanupAction(
        '重置应用控制名单',
        '清空分应用排除、禁止联网应用、应用白名单及抓包名单',
        '确定要重置所有应用控制名单吗？分应用代理排除、禁止联网应用、应用独立白名单以及 HTTP/HTTPS 抓包应用配置都将被清空并恢复默认。',
      ),
    ],
    '存储与安全': [
      _CleanupAction(
        '重置出站代理配置',
        '清空出站代理协议、服务器与鉴权信息，恢复直连',
        '确定要重置出站代理配置吗？出站代理将被禁用，服务器地址、端口及账号密码将被清除。',
      ),
      _CleanupAction(
        '重置 HTTPS 抓包证书',
        '清除本地生成的 MITM CA 根证书与私钥',
        '确定要清除本地生成的 HTTPS 抓包 CA 证书和私钥吗？如果系统已安装此证书，清除后需重新生成并导入系统方可继续解密抓包。',
      ),
      _CleanupAction(
        '清理下载与临时缓存',
        '删除更新安装包、下载临时文件及应用临时缓存',
        '确定要删除下载的更新安装包和临时缓存文件吗？',
      ),
      _CleanupAction(
        '清除自定义背景缓存',
        '清除已配置的自定义壁纸图片缓存及路径记录，恢复默认背景',
        '确定要清除自定义壁纸缓存并恢复默认外观背景吗？',
      ),
    ],
    '引导与重置': [
      _CleanupAction(
        '重置所有新手引导',
        '让所有首次进入说明再次显示，需要重新同意使用协议',
        '确定要重置所有应用设置新手引导和首次使用协议吗？这不会删除任何配置、规则、缓存、日志或证书。操作完成后应用将退出；下次打开时需要重新同意使用协议，所有新手引导也会再次显示。',
      ),
      _CleanupAction(
        '清理全部本地数据',
        '深度清空所有日志、缓存、规则、订阅、证书与配置，应用将退出',
        '确定要执行全面数据清理吗？将依次清理所有日志、流量统计、崩溃记录、DNS 缓存、服务商权重、域名及地址规则、规则订阅、临时缓存及抓包证书。所有自定义配置与规则将被清空，新手引导也将重置，操作完成后应用将退出。',
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '数据清理',
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(16),
              child: Text(
                '以下操作会立即删除本机数据，删除后无法恢复。'
                '重要规则或配置请在执行前备份。',
                style: context.listSubtitleStyle,
              ),
            ),
          ),
          for (final group in _groups.entries)
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
                    subtitle: Text(action.subtitle),
                    onTap: () => _confirm(context, action),
                  ),
              ],
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _confirm(BuildContext context, _CleanupAction action) async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: action.title,
        destructive: true,
        child: Text(action.message),
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
    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('已${action.title}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _CleanupAction {
  const _CleanupAction(this.title, this.subtitle, this.message);

  final String title;
  final String subtitle;
  final String message;
}

// ignore_for_file: sort_child_properties_last
import 'package:diting/routes/hub_routes.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 备份与迁移（上游 `ConfigTransferScreen`）。
///
/// 统计概览 + 分组勾选 + 导出/导入。演示层不读写文件，导入会弹出一份
/// 与上游结构相同的「新增 / 跳过 / 更新」明细。
///
/// 页尾一组「WebDAV 云同步」：旧版的 WebDAV 是备份页里的一张表单，本仓把它
/// 拆成独立页面后从这里下钻（`HubPaths.configTransferWebdav`）。
class ConfigTransferPage extends StatefulWidget {
  const ConfigTransferPage({super.key});

  @override
  State<ConfigTransferPage> createState() => _ConfigTransferPageState();
}

class _ConfigTransferPageState extends State<ConfigTransferPage> {
  final Map<String, bool> _selected = {
    'providers': true,
    'bootstrap': true,
    'cache': true,
    'outbound': true,
    'subscriptions': true,
    'domainRules': true,
    'rewriteDomain': true,
    'rewriteCname': true,
    'addressRules': true,
    'excluded': true,
    'blocked': true,
    'allowlist': true,
    'httpInspection': true,
    'appearance': true,
    'system': true,
  };

  bool get _allSelected => _selected.values.every((value) => value);
  bool get _noneSelected => _selected.values.every((value) => !value);

  void _toggleAll() {
    final target = !_allSelected;
    setState(() {
      for (final key in _selected.keys.toList()) {
        _selected[key] = target;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '备份与迁移',
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(child: _metric(context, 'DNS 服务商', '6')),
                const SizedBox(width: 10),
                Expanded(child: _metric(context, '规则订阅', '5')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Expanded(child: _metric(context, '自定义规则', '23')),
                const SizedBox(width: 10),
                Expanded(child: _metric(context, '名单应用', '8')),
              ],
            ),
          ),
          generateSection(
            title: '应用配置备份',
            actions: [
              IconButtonData(
                glyph: _allSelected ? AppGlyphs.deselect : AppGlyphs.selectAll,
                tooltip: _allSelected ? '全不选' : '全选',
                onPressed: _toggleAll,
              ),
            ],
            items: [
              _checkbox('providers', '自定义 DNS 服务商', 'DoH、DoT 服务商与解析配置'),
              _checkbox('bootstrap', '自定义 Bootstrap IP', '引导 DNS 节点与启用状态'),
              _checkbox('cache', 'DNS 缓存策略', 'DNS 缓存开关、预设与 TTL 控制'),
              _checkbox('outbound', '出站代理配置', 'SOCKS5 / HTTP 代理与代理应用，不含账号密码'),
            ],
          ),
          generateSection(
            title: '规则与订阅配置',
            items: [
              _checkbox('subscriptions', '网络规则订阅', '订阅源链接、镜像加速与自动更新'),
              _checkbox('domainRules', '自定义屏蔽域名规则', '手动添加的域名屏蔽规则及状态'),
              _checkbox(
                'rewriteDomain',
                '自定义复写域名规则',
                '手动添加的 IPv4 / IPv6 域名覆写规则',
              ),
              _checkbox('rewriteCname', '自定义复写 CNAME 规则', '手动添加的 CNAME 域名覆写规则'),
              _checkbox('addressRules', '自定义屏蔽地址规则', '手动添加的 URL 路径屏蔽规则'),
            ],
          ),
          generateSection(
            title: '应用控制与流量管理',
            items: [
              _checkbox('excluded', '排除应用名单', '绕过过滤使用系统 DNS 的应用'),
              _checkbox('blocked', '禁止联网名单', '服务运行时禁止联网的应用'),
              _checkbox('allowlist', '应用独立规则与放行', '单应用放行规则与域名白名单'),
              _checkbox('httpInspection', 'HTTPS 抓包检测配置', '流量抓包开关与目标应用名单'),
            ],
          ),
          generateSection(
            title: '个性化与通用设置',
            items: [
              _checkbox('appearance', '外观与界面个性化', '主题风格、组件透明度与标语'),
              _checkbox('system', '系统与通用设置', '局域网绕行、日志模式、语言与通知'),
            ],
          ),
          generateSection(
            title: '导入导出',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.export),
                title: const Text('导出应用配置 (JSON)'),
                subtitle: const Text('将勾选的自定义配置打包保存为 JSON 文件'),
                onTap: _noneSelected ? null : _export,
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.importFile),
                title: const Text('导入应用配置 (JSON)'),
                subtitle: const Text('从备份文件合并配置，自动跳过本机已存在项目'),
                onTap: _import,
              ),
            ],
            footer:
                '导出的配置文件包含个人自定义设置，请妥善保管；导入时将合并配置并'
                '自动跳过已存在的条目。',
          ),
          generateSection(
            title: '云端备份',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.cloudSync),
                title: const Text('WebDAV 云同步'),
                subtitle: const Text('配置 WebDAV 服务器并把备份传到该地址'),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 18),
                onTap: () => context.push(HubPaths.configTransferWebdav),
              ),
            ],
            footer:
                'WebDAV 表单搬迁自原「备份与恢复」页；演示层不发起真实网络请求，'
                '只演示连接状态与表单校验。',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    return CommonCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(value, style: AppTextStyle.title2.of(context, emphasized: true)),
          Text(label, style: context.listSubtitleStyle),
        ],
      ),
    );
  }

  Widget _checkbox(String key, String title, String subtitle) {
    final value = _selected[key] ?? false;
    return ListItem(
      leading: const GlyphIcon(AppGlyphs.layers, size: 20),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: CommonCheckBox(
        value: value,
        onChanged: (next) => setState(() => _selected[key] = next ?? false),
      ),
      onTap: () => setState(() => _selected[key] = !value),
    );
  }

  void _export() {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('已导出 DITING-config.json'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _import() {
    showFloatingDialog<void>(
      context: context,
      child: const _ImportResultDialog(),
    );
  }
}

class _ImportResultDialog extends StatelessWidget {
  const _ImportResultDialog();

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: '导入应用配置',
      trailing: const MetaChip(label: '导入完成'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: const [
          Text('导入汇总：新增 9 项，跳过 3 项'),
          Text('【新增项目】'),
          Text('  + 自定义 DNS 服务商 · 2 个'),
          Text('  + 网络规则订阅 · 1 个'),
          Text('  + 自定义屏蔽域名规则 · 4 条'),
          Text('  + 应用独立放行 · 2 个'),
          Text('【跳过项目】'),
          Text('  - 出站代理配置（本机已存在）'),
          Text('  - 主题外观（保持本机设置）'),
          Text('包含 1 个订阅，请进入订阅管理执行规则更新。'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('完成'),
        ),
      ],
    );
  }
}

/// 通用设置（上游 `views/config/general.dart`，485 行）。
///
/// 上游分「启动与后台 / 请求与更新 / 入站 / 连接 / 内核 / 日志」六组，其中
/// 「启动与后台」大半是桌面专属（开机自启、静默启动、最小化到托盘）。本仓是
/// 移动端演示，这一组只保留移动端真实存在的项，其余在页尾用一句说明交代
/// 取舍——摆一排点了没反应的开关比不摆更糟。
library;

import 'package:diting/data/mock_config.dart';
import 'package:diting/pages/config/config_common.dart';
import 'package:diting/state/config_providers.dart';
import 'package:diting/ui/support/input_limits.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'general_port_form.dart';
part 'general_hosts_editor.dart';

/// 通用设置页。
class GeneralConfigPage extends ConsumerWidget {
  const GeneralConfigPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(generalConfigProvider);
    final notifier = ref.read(generalConfigProvider.notifier);
    return CommonScaffold(
      title: '通用',
      body: PageBody(
        children: [
          generateSection(
            title: '核心',
            items: [
              ListItem<LogLevel>.options(
                leading: const GlyphIcon(AppGlyphs.logs),
                title: const Text('日志级别'),
                subtitle: Text(_logLevelHint(config.logLevel)),
                options: LogLevel.values,
                value: config.logLevel,
                textBuilder: (level) => level.label,
                onChanged: notifier.setLogLevel,
              ),
              ListItem.input(
                leading: const GlyphIcon(AppGlyphs.target),
                title: const Text('测试地址'),
                subtitle: Text(config.testUrl),
                dialogTitle: '测试地址',
                value: config.testUrl,
                maxLength: TextInputLimits.url,
                resetValue: defaultTestUrl,
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) {
                    return '测试地址不能为空';
                  }
                  if (!text.startsWith('http')) {
                    return '需要以 http 开头';
                  }
                  return null;
                },
                onChanged: (value) {
                  if (value != null) {
                    notifier.setTestUrl(value.trim());
                  }
                },
              ),
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.toggle),
                title: const Text('统一延迟'),
                subtitle: const Text('两次握手取平均，读数更稳但更慢'),
                value: config.unifiedDelay,
                onChanged: notifier.setUnifiedDelay,
              ),
            ],
            footer: '测试地址用于延迟测速与连通性检查；返回 204 的地址最省流量。',
          ),
          generateSection(
            title: '入站',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.link),
                title: const Text('端口'),
                subtitle: Text(_portsSummary(config.ports)),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 16),
                onTap: () => showPortForm(context, ref),
              ),
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.devices),
                title: const Text('允许局域网连接'),
                subtitle: const Text('同一网络下的其他设备可以连入代理端口'),
                value: config.allowLan,
                onChanged: notifier.setAllowLan,
              ),
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.settings),
                title: const Text('外部控制器'),
                subtitle: const Text('开放内核控制接口，供面板与快捷指令调用'),
                value: config.externalController,
                onChanged: notifier.setExternalController,
              ),
              ListItem.input(
                leading: const GlyphIcon(AppGlyphs.key),
                title: const Text('控制器密钥'),
                subtitle: Text(config.controllerSecret.isEmpty ? '未设置' : '已设置'),
                dialogTitle: '控制器密钥',
                value: config.controllerSecret,
                maxLength: TextInputLimits.password,
                onChanged: (value) {
                  if (!config.externalController) {
                    showConfigHint(context, '请先开启外部控制器');
                    return;
                  }
                  notifier.setControllerSecret(value ?? '');
                },
              ),
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.lock),
                title: const Text('入站鉴权'),
                subtitle: const Text('连接代理端口时要求用户名与密码'),
                value: config.authentication,
                onChanged: notifier.setAuthentication,
              ),
              ListItem.input(
                leading: const GlyphIcon(AppGlyphs.account),
                title: const Text('鉴权账号'),
                subtitle: Text(config.account),
                dialogTitle: '鉴权账号',
                value: config.account,
                maxLength: TextInputLimits.userName,
                onChanged: (value) {
                  if (!config.authentication) {
                    showConfigHint(context, '请先开启入站鉴权');
                    return;
                  }
                  notifier.setAccount(value ?? '');
                },
              ),
              ListItem.input(
                leading: const GlyphIcon(AppGlyphs.password),
                title: const Text('鉴权密码'),
                subtitle: Text(config.password.isEmpty ? '未设置' : '已设置'),
                dialogTitle: '鉴权密码',
                value: config.password,
                maxLength: TextInputLimits.password,
                onChanged: (value) {
                  if (!config.authentication) {
                    showConfigHint(context, '请先开启入站鉴权');
                    return;
                  }
                  notifier.setPassword(value ?? '');
                },
              ),
            ],
            footer:
                '外部控制器与入站鉴权都会扩大内核暴露面：密钥请勿外传，'
                '公共网络下建议保持鉴权开启。',
          ),
          generateSection(
            title: 'Hosts',
            actions: [
              IconButtonData(
                glyph: AppGlyphs.add,
                tooltip: '添加 Hosts 记录',
                onPressed: () => showHostEditor(context, ref),
              ),
            ],
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.dns),
                title: const Text('Hosts 记录'),
                subtitle: Text(
                  config.hosts.isEmpty
                      ? '未设置自定义解析'
                      : '共 ${config.hosts.length} 条',
                ),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 16),
                onTap: () => showHostsSheet(context, ref),
              ),
            ],
            footer: 'Hosts 优先于 DNS 生效，适合把内网域名指到固定地址。',
          ),
          generateSection(
            title: '连接',
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.speed),
                title: const Text('TCP 并发'),
                subtitle: const Text('同时发起多条连接以加快建连'),
                value: config.tcpConcurrent,
                onChanged: notifier.setTcpConcurrent,
              ),
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.appsList),
                title: const Text('查找进程'),
                subtitle: const Text('按进程名匹配规则；部分系统不可用'),
                value: config.findProcess,
                onChanged: notifier.setFindProcess,
              ),
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.connections),
                title: const Text('切换时关闭连接'),
                subtitle: const Text('切换节点或模式时断开已有连接'),
                value: config.closeConnections,
                onChanged: notifier.setCloseConnections,
              ),
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.dataUsage),
                title: const Text('只统计代理流量'),
                subtitle: const Text('直连流量不计入首页统计'),
                value: config.onlyStatisticsProxy,
                onChanged: notifier.setOnlyStatisticsProxy,
              ),
            ],
          ),
          generateSection(
            title: '内核',
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.verified),
                title: const Text('校验证书'),
                subtitle: const Text('拒绝证书不匹配的 TLS 连接'),
                value: config.checkCertificate,
                onChanged: notifier.setCheckCertificate,
              ),
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.sync),
                title: const Text('自动检查更新'),
                subtitle: const Text('启动时检查一次新版本'),
                value: config.autoCheckUpdate,
                onChanged: notifier.setAutoCheckUpdate,
              ),
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.vpn),
                title: const Text('IPv6'),
                subtitle: const Text('允许内核解析与转发 IPv6'),
                value: config.ipv6,
                onChanged: notifier.setIpv6,
              ),
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.dns),
                title: const Text('附加系统 DNS'),
                subtitle: const Text('把系统 DNS 追加到服务商列表末尾'),
                value: config.appendSystemDns,
                onChanged: notifier.setAppendSystemDns,
              ),
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.memory),
                title: const Text('省内存 Geo 数据'),
                subtitle: const Text('按需加载 GeoIP / GeoSite，占用更低'),
                value: config.geodataMemconservative,
                onChanged: notifier.setGeodataMemconservative,
              ),
            ],
            footer: '关闭证书校验只应作为排查手段：它让中间人可以伪装成任意站点。',
          ),
          generateSection(
            title: '日志与诊断',
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.code),
                title: const Text('记录内核日志'),
                subtitle: const Text('关闭后日志页只剩内核原始输出'),
                value: config.openLogs,
                onChanged: notifier.setOpenLogs,
              ),
            ],
            footer:
                '开机自启、静默启动、最小化到托盘属于桌面端能力，'
                '移动端没有对应入口，这里不提供。',
          ),
        ],
      ),
    );
  }
}

String _logLevelHint(LogLevel level) => switch (level) {
  LogLevel.silent => '不输出任何日志',
  LogLevel.error => '只记录错误',
  LogLevel.warning => '记录错误与警告',
  LogLevel.info => '记录常规运行信息',
  LogLevel.debug => '记录全部细节，日志量最大',
};

String _portsSummary(MockPorts ports) =>
    '混合 ${ports.mixed} · HTTP ${ports.port} · SOCKS ${ports.socks}';

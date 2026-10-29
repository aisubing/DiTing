// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppL10nZh extends AppL10n {
  AppL10nZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '谛听 DITING';

  @override
  String get uiBack => '返回';

  @override
  String get uiCancel => '取消';

  @override
  String get uiClearSearch => '清除搜索';

  @override
  String get uiClose => '关闭';

  @override
  String get uiHidePassword => '隐藏密码';

  @override
  String get uiMore => '更多';

  @override
  String get uiNoSearchResults => '无搜索结果';

  @override
  String get uiReset => '重置';

  @override
  String get uiSearch => '搜索';

  @override
  String get uiShowLess => '收起';

  @override
  String get uiShowMore => '展开';

  @override
  String get uiShowPassword => '显示密码';

  @override
  String get uiSort => '排序';

  @override
  String get uiSubmit => '提交';

  @override
  String get languageTitle => '语言设置';

  @override
  String get languageInterfaceSection => '界面语言';

  @override
  String get languageInterfaceFooter => '选择应用界面语言。「跟随系统」会跟随设备语言，非中文或英文的系统显示中文。';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get commonFollowSystem => '跟随系统';

  @override
  String get commonSelectAll => '全选';

  @override
  String get commonClear => '清除';

  @override
  String get commonInvertSelection => '反选';

  @override
  String get commonFilter => '过滤';

  @override
  String get commonSort => '排序';

  @override
  String get commonSave => '保存';

  @override
  String get commonDiscard => '不保存';

  @override
  String get commonSaveChangesTitle => '保存更改？';

  @override
  String get commonSaveChangesMessage => '你的选择还没保存。保存后离开，还是放弃这些修改？';

  @override
  String commonSaveChangesMessageFor(Object name) {
    return '「$name」的选择还没保存。保存后离开，还是放弃这些修改？';
  }

  @override
  String get commonGrantPermission => '去授权';

  @override
  String get palettePurple => '鸢尾紫';

  @override
  String get paletteBlue => '睡莲蓝';

  @override
  String get paletteCyan => '池水青';

  @override
  String get paletteGreen => '柳叶绿';

  @override
  String get paletteOrange => '暮光赭';

  @override
  String get paletteRed => '罂粟红';

  @override
  String get palettePink => '暮霞粉';

  @override
  String get paletteGold => '麦穗金';

  @override
  String get themeModeLight => '浅色模式';

  @override
  String get themeModeDark => '深色模式';

  @override
  String get appListUnavailable => '读不到应用列表';

  @override
  String get appListFilterAll => '全部应用';

  @override
  String get appListFilterSystem => '系统应用';

  @override
  String get appListFilterUser => '用户应用';

  @override
  String get appListFilterSelected => '已勾选应用';

  @override
  String get appListSortLabelAsc => '应用名称 A-Z';

  @override
  String get appListSortLabelDesc => '应用名称 Z-A';

  @override
  String get appListSortPackageAsc => '包名 A-Z';

  @override
  String get appListSortPackageDesc => '包名 Z-A';

  @override
  String get appListNotRegistered => '未注册';

  @override
  String appListChannelUnavailable(Object detail) {
    return '应用列表通道不可用：$detail';
  }

  @override
  String appListReadFailed(Object detail) {
    return '读取应用列表失败：$detail';
  }

  @override
  String appListReadFailedCode(Object code) {
    return '读取应用列表失败（$code）';
  }

  @override
  String dbWriteUnhealthy(Object dropped, Object failures) {
    return '日志写入异常：已丢弃 $dropped 条、打开失败 $failures 次，可在「故障排查」查看详情';
  }

  @override
  String get agreementDeclinedTitle => '已拒绝使用须知';

  @override
  String get agreementDeclinedMessage =>
      '未同意使用须知与免责声明，无法继续使用谛听。你可以直接退出应用，或重新查看条款后再决定。';

  @override
  String get agreementReviewAgain => '重新查看';

  @override
  String get agreementTitle => '使用须知与免责声明';

  @override
  String get agreementDecline => '不同意并退出';

  @override
  String get agreementAccept => '同意并继续';

  @override
  String get agreementMessage =>
      '软件说明\n谛听是一款专注于本地 DNS 解析优化与网络规则过滤的开源工具。提供三种工作模式：普通模式（全隧道深度管控）、极速模式（纯 Kotlin 原生轻量窄路由）与独立服务器模式（局域网免 VPN 服务）。本软件完全在设备本地闭环运行，无任何远程数据上传与隐私追踪。\n\n运行机制与注意事项\n普通模式与极速模式依赖 Android 本地 VPN 接口接管 DNS 解析，不连接任何远程 VPN 服务器；独立服务器模式无需 VPN 权限，直接监听本地 1053 端口供局域网设备接入。规则与日志完整保存在本机，启用高级扩展功能前请了解其具体影响。\n\n免责条款\n本软件按现状提供。使用者须遵守相关法律法规，自行确认规则与上游解析来源的合法性及安全性。严禁将本软件用于任何违法用途；使用者因自行配置或使用本软件所产生的后果由使用者自行承担。';

  @override
  String get homeProviderSingleLabel => '解析服务商';

  @override
  String get homeProviderRaceLabel => '竞速服务商';

  @override
  String get homeChartEmptyLabel => '还没有采到样本';

  @override
  String durationHours(Object hours) {
    return '$hours 小时';
  }

  @override
  String durationMinutes(Object minutes) {
    return '$minutes 分钟';
  }

  @override
  String durationSeconds(Object seconds) {
    return '$seconds 秒';
  }

  @override
  String get dashboardDetailTooltip => '详情';

  @override
  String get dashboardEmptyLabel => '仪表盘还没有卡片';

  @override
  String get dashboardEmptyDescription => '进入编辑模式，从「添加卡片」里挑几个放上来。';

  @override
  String get dashboardEnterEditMode => '进入编辑模式';

  @override
  String get dashboardEditHint => '拖动手柄排序，点右上角移除；改完点右上角「完成」。';

  @override
  String get dashboardAllRemovedLabel => '卡片都移除了';

  @override
  String get dashboardAllRemovedDescription => '点下面的「添加卡片」挑一个。';

  @override
  String get dashboardAddCard => '添加卡片';

  @override
  String get providerSheetSingleTitle => '选择解析服务商';

  @override
  String get providerSheetRaceTitle => '选择竞速服务商';

  @override
  String get providerSheetSingleOptions => '可选服务商';

  @override
  String get providerSheetRaceMinimum => '至少选 2 个';

  @override
  String get providerSheetManage => '管理服务...';

  @override
  String get providerSheetVisibility => '服务显示...';

  @override
  String get providerSheetSingleFooter => '延迟取自上一次解析的健康记录，不是实时值。';

  @override
  String get providerSheetRaceFooter => '竞速模式下每个查询会并发发往所有选中服务商。';

  @override
  String get powerButtonStop => '停止';

  @override
  String get powerButtonStart => '开启';

  @override
  String get powerButtonStarting => '启动中';

  @override
  String get homeEditDashboard => '编辑仪表盘';

  @override
  String get homeDone => '完成';

  @override
  String get homeSwitchWorkMode => '切换工作模式';

  @override
  String get homeTitleNormal => '谛听 · 普通';

  @override
  String get homeTitleServer => '谛听 · 服务器';

  @override
  String get homeTitleExpress => '谛听 · 极速';

  @override
  String get logRequestsOverview => '请求概览';

  @override
  String get logTodayRequests => '今日请求';

  @override
  String get logPassed => '通过';

  @override
  String get logFiltered => '过滤';

  @override
  String get logCacheHits => '缓存命中';

  @override
  String get logHighlights => '重点记录';

  @override
  String get logBlocked => '过滤拦截';

  @override
  String get logFailed => '异常失败';

  @override
  String get logBypassed => '旁路直连';

  @override
  String get logOffModeTitle => '解析服务概况';

  @override
  String get logCacheEntries => '有效缓存';

  @override
  String get logCacheHitsTotal => '累计缓存命中';

  @override
  String get logRaceRequests => '并发竞速请求';

  @override
  String get logBootstrapAttempts => 'Bootstrap 尝试';

  @override
  String get logRecentRequests => '最近请求';

  @override
  String get logRecentRequestsEmpty => '暂无请求日志';

  @override
  String get logRecentBlocked => '最近拦截与错误';

  @override
  String get logRecentBlockedEmpty => '暂无拦截或错误记录';

  @override
  String get logCacheHotspots => '缓存热点';

  @override
  String get logCacheHotspotsEmpty => '暂无有效缓存';

  @override
  String logExpiresIn(Object duration) {
    return '$duration 后过期';
  }

  @override
  String logTimes(Object count) {
    return '$count 次';
  }

  @override
  String get logRaceWinners => '竞速胜出';

  @override
  String get logRaceWinnersEmpty => '暂无竞速数据';

  @override
  String logAverageWinLatency(Object latency) {
    return '平均胜出耗时 $latency';
  }

  @override
  String get logBootstrapDnsEmpty => '暂无 Bootstrap 数据';

  @override
  String logBootstrapRow(Object ip, Object latency, Object percent) {
    return '$ip · 成功 $percent · $latency';
  }

  @override
  String get logRuleBlocks => '规则拦截';

  @override
  String get logRuleBlocksEmpty => '暂无规则拦截数据';

  @override
  String logShareRow(Object percent, Object status) {
    return '$status · 占全部请求 $percent';
  }

  @override
  String get logPrivacyMode => '隐私模式保护中';

  @override
  String get logLoggingOff => '日志已关闭';

  @override
  String get logPrivacyModeBody =>
      '重新开启日志后，仪表盘将从新产生的请求开始统计。当前各类解析服务与缓存热点均正常工作。';

  @override
  String get logPerfTitle => '解析效能概况';

  @override
  String get logTodayStats => '今日统计';

  @override
  String get logAverageLatency => '平均解析耗时';

  @override
  String get logNoTimingSamples => '— · 今日暂无计时样本';

  @override
  String logSampleValue(Object count, Object value) {
    return '$value · $count 个样本';
  }

  @override
  String get logCacheHitRate => '缓存命中率';

  @override
  String logCacheHitRateValue(Object percent) {
    return '$percent · 分母为通过 + 失败';
  }

  @override
  String get logRaceSuccessRate => '竞速成功率';

  @override
  String get logBootstrapSuccessRate => 'Bootstrap 成功率';

  @override
  String logRateValue(Object count, Object latency, Object percent) {
    return '$percent · $count 次 · $latency';
  }

  @override
  String get dashboardRestoreDefaults => '恢复默认';

  @override
  String get dashboardAllCardsAdded => '卡片都放上来了';

  @override
  String get dashboardAllCardsAddedDescription => '想减少卡片，请回到编辑模式点卡片右上角的移除。';

  @override
  String get dashboardAvailableCards => '可添加的卡片';

  @override
  String get dashboardOrderHint => '卡片顺序可在编辑模式下拖拽调整。';

  @override
  String get dashboardCardProviderDescription => '当前解析服务商，点开即可切换或调整竞速列表';

  @override
  String get dashboardCardResolutionDescription => '解析模式选择、一句话说明与当前生效的 DNS 地址';

  @override
  String get dashboardCardStatusDescription => '内核状态、运行时长、当前服务商与今日查询';

  @override
  String get dashboardCardSpeedDescription => '上下行实时速率曲线与今日累计流量';

  @override
  String get dashboardCardSiteLatencyDescription => '自定义 4 个站点的实测延迟，详情页可按分类测速';

  @override
  String get dashboardCardMemoryDescription => '本进程 PSS 与 Java / 原生堆构成';

  @override
  String get dashboardCardIntranetDescription => '当前局域网地址、监听状态与复制入口';

  @override
  String get intranetIpTitle => '内网 IP';

  @override
  String get intranetCopyAddress => '复制地址';

  @override
  String get intranetReading => '读取中…';

  @override
  String get intranetNoActiveNetwork => '无活动网络';

  @override
  String get intranetLanAccess => '局域网接入';

  @override
  String get intranetConnectHint => '连上 Wi-Fi 或以太网后这里会显示可用地址';

  @override
  String get memoryTitle => '内存信息';

  @override
  String get memoryJavaHeap => 'Java 堆';

  @override
  String get memoryNativeHeap => '原生堆';

  @override
  String get memorySystemAvailable => '整机可用';

  @override
  String get speedTitle => '网络速度';

  @override
  String get speedUpload => '上传';

  @override
  String get speedDownload => '下载';

  @override
  String get speedExpressNoStats => '极速模式不统计';

  @override
  String get speedNoChannel => '当前环境无速率通道';

  @override
  String get resolutionModeTitle => '解析模式';

  @override
  String get resolutionNoProvider => '未选择服务商';

  @override
  String get resolutionSingleSummary => '只用当前选中的服务商，最快但可用性取决于它。';

  @override
  String get resolutionSmartSummary => '按历史成功率挑一个，失败后自动换下一个。';

  @override
  String get resolutionParallelSummary => '同时向所有服务商发起，取最先返回的结果。';

  @override
  String get resolutionPrimaryBackupSummary => '主服务商优先，超时后才动备用。';

  @override
  String get siteLatencyTesting => '测速中…';

  @override
  String get siteLatencyNotTested => '尚未测速';

  @override
  String get siteLatencyTitle => '网络测速';

  @override
  String get siteLatencyRetest => '重新测速';

  @override
  String get commonFailed => '失败';

  @override
  String get siteLatencyNoReply => '无回包';

  @override
  String get statusTitle => '状态';

  @override
  String get statusUptime => '运行时长';

  @override
  String get statusActiveProvider => '当前服务商';

  @override
  String get statusNotSelected => '未选择';

  @override
  String get statusTodayQueries => '今日查询';

  @override
  String get statusDetailTitle => '状态详情';

  @override
  String get statusNotTiming => '未计时';

  @override
  String get statusCoreSection => '内核';

  @override
  String get statusWorkMode => '工作模式';

  @override
  String get statusCoreState => '内核状态';

  @override
  String get statusListenPort => '监听端口';

  @override
  String get statusNotListening => '未监听';

  @override
  String get statusProviderFooter => '延迟是该服务商的最近一次实测值，不是本机到目标的往返。';

  @override
  String get statusNoProviderHint => '还没有选择服务商。在服务商管理里挑一个，解析才会走真实上游。';

  @override
  String get statusTodayCounts => '今日计数';

  @override
  String get statusCountsFooter =>
      '计数从本次内核启动开始累计，重启或切换工作模式后归零；已在服务器模式里做的重置也只清计数，不动规则与缓存。';

  @override
  String get statusQueries => '查询';

  @override
  String get statusBlocked => '已拦截';

  @override
  String get statusAverageLatency => '平均时延';

  @override
  String get statusCacheHitRate => '缓存命中率';

  @override
  String get statusServerPortReady => '本机 DNS 端口可用，局域网设备可把它当作 DNS';

  @override
  String get statusTunnelActive => '本机流量已经过谛听，解析与规则都在生效';

  @override
  String get statusServerPortClosed => 'DNS 端口未监听，服务器模式当前不提供解析';

  @override
  String get statusCoreStopped => '内核未运行，本机流量按系统默认网络走';

  @override
  String get siteLatencySheetLatency => '延迟';

  @override
  String get siteLatencySheetCategory => '分类';

  @override
  String get siteLatencySheetTarget => '目标';

  @override
  String get siteLatencySheetAverage => '平均往返';

  @override
  String get siteLatencySheetMinMax => '最小 / 最大';

  @override
  String get siteLatencySheetJitter => '抖动';

  @override
  String get siteLatencySheetLoss => '丢包';

  @override
  String get siteLatencySheetDns => '解析地址';

  @override
  String get siteLatencySheetLastRun => '最近测速';

  @override
  String get siteLatencySheetNotTested => '尚未测速。点测速按钮开始测量。';

  @override
  String get siteLatencySheetNoReply => '三个回显请求都没有收到应答，可能是站点限流或当前网络不通。';

  @override
  String get siteLatencySheetFallbackFooter =>
      '系统 ping 不可用，这次数值来自 TCP 握手 / isReachable，衡量的是建连时延而不是 ICMP 回显，会略高于真实往返。';

  @override
  String get siteLatencySheetIcmpFooter =>
      '数值来自系统 ping 的 ICMP 回显（3 次取平均）。本应用自身流量不经过 VPN，测的是物理网络。';

  @override
  String get trafficStructureLive => '实时汇总';

  @override
  String get trafficStructureFocused => '重点流量结构';

  @override
  String get trafficStructureToday => '今日流量结构';

  @override
  String get trafficStructureBypass => '旁路';

  @override
  String get trafficStructureCache => '缓存';

  @override
  String get trafficStructureRaceRate => '竞速成功率';

  @override
  String get trafficStructureBootstrapRate => 'Bootstrap 成功率';

  @override
  String get trafficStructureBlockedShare => '拦截占比';

  @override
  String get trafficStructureBlockRate => '拦截率';

  @override
  String get trafficStructureCacheRate => '缓存率';

  @override
  String get dashboardSitesTitle => '仪表盘站点';

  @override
  String get dashboardSitesCardSection => '仪表盘卡片';

  @override
  String get dashboardSitesAtLeastOne => '卡片至少保留 1 个站点';

  @override
  String get dashboardSitesFooter => '这四张卡片用的是同一个仪表盘卡片，改动立刻生效；测速在详情页按分类手动触发。';

  @override
  String get trafficMonitorTitle => '流量监控';

  @override
  String get trafficMonitorToday => '今日代理流量';

  @override
  String get trafficMonitorLiveRate => '实时速率';

  @override
  String get trafficMonitorNoStats => '本模式不统计';

  @override
  String get memoryDetailTitle => '内存详情';

  @override
  String get memoryResample => '重新采样';

  @override
  String get memoryProcessPss => '本进程 PSS';

  @override
  String get memoryUnavailable => '不可用';

  @override
  String get memoryOther => '其它';

  @override
  String get memoryComposition => '进程构成';

  @override
  String get memoryCompositionFooter =>
      'PSS 按共享页的比例计入本进程，因此 Java 堆与原生堆之和小于 PSS，差额是代码、图形缓冲与共享库。';

  @override
  String get memoryOtherCode => '其它（代码 / 共享库）';

  @override
  String get memorySystemSection => '整机内存';

  @override
  String get memorySystemFooter => '整机占用 = 总量 - 可用量，包含系统与所有应用；本进程只是其中一份。';

  @override
  String get memorySystemUsed => '整机已用';

  @override
  String get memoryRecentPss => '最近 PSS';

  @override
  String get memorySampling => '正在采样…';

  @override
  String get memoryRecentPssCaption =>
      '打开本页后每 2 秒采样一次，最多保留 60 个点；曲线持续上扬说明有内存未释放。';

  @override
  String get memorySourceFooter =>
      '数据来自 ActivityManager 的 MemoryInfo；切到后台或系统回收后数值会明显下降。';

  @override
  String get siteLatencyDetailTitle => '测速详情';

  @override
  String get siteLatencyTestAll => '测全部';

  @override
  String get siteLatencyCustomSites => '自定义仪表盘站点';

  @override
  String get siteLatencyConnectivity => '站点连通性';

  @override
  String get siteLatencyTestingShort => '测速中';

  @override
  String get siteLatencyNoTest => '未测速';

  @override
  String get siteLatencyInProgress => '进行中';

  @override
  String get siteLatencyPending => '待测';

  @override
  String get siteLatencyAllReachable => '全部通畅';

  @override
  String get siteLatencyTestingEach => '正在逐个站点测速…';

  @override
  String get siteLatencyPickCategory => '选一个分类点测速，或点右上角测全部。';

  @override
  String get siteLatencyThisRun => '本次结果';

  @override
  String get siteLatencyReachable => '通畅';

  @override
  String get siteLatencyMeasuredSites => '已测站点';

  @override
  String get siteLatencyDetailFooter =>
      '每个站点发 3 个 ICMP 回显，取平均值；系统 ping 不可用时退回 TCP 握手，会标上 * 号，数值略高于真实往返。本应用自身流量不经过 VPN，测的是物理网络。';

  @override
  String get intranetDetailTitle => '内网 IP 详情';

  @override
  String get intranetRefresh => '刷新网络信息';

  @override
  String get intranetLocalAddress => '本机局域网地址';

  @override
  String get intranetUsableAsDns => '可作 DNS';

  @override
  String get intranetLocalOnly => '仅本机';

  @override
  String get intranetSameSubnetHint => '同网段设备把 DNS 指到这个地址即可走本机解析。';

  @override
  String get intranetNetworkOverview => '网络概况';

  @override
  String get commonEnabled => '已启用';

  @override
  String get commonDisabled => '未启用';

  @override
  String get intranetDnsServers => 'DNS 服务器';

  @override
  String get intranetInterfaces => '接口';

  @override
  String get intranetNoInterface => '系统没有报告活动网络接口，可能是飞行模式或未联网。';

  @override
  String get intranetAdapter => '网卡';

  @override
  String get intranetGateway => '网关';

  @override
  String get intranetPrivateDnsOff => '系统私人 DNS 未开启，解析请求由本机与代理按模式处理。';

  @override
  String get intranetNoDnsServer => '没有读到 DNS 服务器：接口未下发 DNS，或当前环境没有诊断通道。';

  @override
  String get intranetPrimaryDns => '首选';

  @override
  String get intranetPrivateDns => '私人 DNS';

  @override
  String get intranetPortFooter =>
      '端口只在服务启动时绑定，改动端口后需要重启服务；把同网段设备的 DNS 指向上面的地址即可让它们走本机解析。';

  @override
  String get intranetCopyAddressWithPort => '复制地址（含端口）';

  @override
  String get speedDetailTitle => '网速详情';

  @override
  String get speedCurrentDownload => '当前下载';

  @override
  String get speedSamplingPaused => '暂停采样';

  @override
  String get speedLive => '实时';

  @override
  String get speedSamplingHint => '每秒采样一次，下图是最近一分钟。';

  @override
  String get speedCurrentUpload => '当前上传';

  @override
  String get speedDownloadPeak => '下行峰值';

  @override
  String get speedUploadPeak => '上行峰值';

  @override
  String get speedSamples => '样本';

  @override
  String get speedTodayTotal => '今日累计';

  @override
  String get speedNoTrafficToday => '流量库还没有今天的记录。';

  @override
  String get speedTotal => '合计';

  @override
  String get speedRateFooter =>
      '速率来自内核数据面的实时计数，只包含经过隧道转发的流量；本应用自身的探测与测速不计入。今日累计来自应用流量统计，与「流量统计」页同一份数据。';

  @override
  String get speedExpressSource => '极速模式不经过内核数据面，因此没有逐秒速率；切回普通模式后恢复。';

  @override
  String get speedNoChannelSource => '当前环境没有速率通道（桌面环境或纯 Dart 测试），读不到实时速率。';

  @override
  String get speedNoDataInMode => '当前模式下没有速率数据';

  @override
  String get speedWaitingSample => '正在等待第一个样本';

  @override
  String get commonNoData => '无数据';

  @override
  String intranetModeNotListening(Object mode) {
    return '$mode不监听局域网，其他设备无法把这里当 DNS';
  }

  @override
  String intranetListeningOn(Object port) {
    return '已监听 0.0.0.0:$port，其他设备把 DNS 指到上面的地址';
  }

  @override
  String intranetServiceStopped(Object port) {
    return '服务未启动：启动后才会绑定 $port 端口';
  }

  @override
  String commonCopied(Object text) {
    return '已复制 $text';
  }

  @override
  String intranetGatewaySuffix(Object gateway) {
    return ' · 网关 $gateway';
  }

  @override
  String get speedTotalDash => '累计 —';

  @override
  String siteLatencyAliveRatio(Object alive, Object total) {
    return '$alive / $total 通畅';
  }

  @override
  String siteLatencyLastRun(Object ago) {
    return '最近测速 $ago';
  }

  @override
  String siteLatencyProviderSuffix(Object name) {
    return ' · 解析服务商 $name';
  }

  @override
  String siteLatencySitesCount(Object count) {
    return '$count 个站点';
  }

  @override
  String siteLatencyTestCategory(Object category) {
    return '测速$category';
  }

  @override
  String memorySystemShare(Object percent) {
    return '占整机 $percent';
  }

  @override
  String memorySystemUsedOf(Object total, Object used) {
    return '整机已用 $used / $total';
  }

  @override
  String get memoryNoChannel => '当前环境读不到内存数据（桌面环境或纯 Dart 测试）。';

  @override
  String trafficStructureRateValue(
    Object count,
    Object latency,
    Object percent,
  ) {
    return '$percent · $count 次 · $latency';
  }

  @override
  String trafficStructureShareValue(Object count, Object percent) {
    return '$percent · $count 次';
  }

  @override
  String statusPausedSummary(Object core, Object mode) {
    return '$mode$core，计时已暂停';
  }

  @override
  String speedTotalsDown(Object percent) {
    return '下行 $percent';
  }

  @override
  String speedTotalsUp(Object percent) {
    return '上行 $percent';
  }

  @override
  String speedPeakAverage(Object average, Object peak) {
    return '峰值 $peak · 平均 $average';
  }

  @override
  String get intranetConnectHintSentence => '连上 Wi-Fi 或以太网后这里会显示可用地址。';

  @override
  String intranetModeNotListeningSentence(Object mode) {
    return '$mode不监听局域网，其它设备无法把这里当 DNS。';
  }

  @override
  String intranetPrivateDnsOn(Object dns) {
    return '系统开启了私人 DNS（$dns），系统解析会走加密通道，可能绕过本地服务。';
  }

  @override
  String intranetSecondaryDns(Object index) {
    return '备用 $index';
  }

  @override
  String intranetCopyAddressSemantics(Object address) {
    return '复制地址 $address';
  }

  @override
  String speedTotalAccumulated(Object value) {
    return '累计 $value';
  }

  @override
  String dashboardSitesFull(Object count) {
    return '卡片只能放 $count 个站点，先点掉一个再换别的。';
  }

  @override
  String dashboardSitesRemaining(Object count) {
    return '还可以再放 $count 个站点。';
  }

  @override
  String dashboardSitesMax(Object count) {
    return '卡片最多放 $count 个站点，先取消一个再选。';
  }

  @override
  String dashboardSitesPosition(Object index) {
    return '第 $index 位';
  }

  @override
  String siteLatencyFailedCount(Object count) {
    return '$count 个失败';
  }

  @override
  String get siteLatencyDetailFooterLong =>
      '每个站点发 3 个 ICMP 回显，取平均值；系统 ping 不可用时退回 TCP 握手，会标上 * 号，数值略高于真实往返。本应用自身流量不经过 VPN，测的是物理网络。';
}

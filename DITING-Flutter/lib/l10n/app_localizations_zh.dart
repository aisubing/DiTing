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

  @override
  String get homeLayerPowerButton => '启动按钮';

  @override
  String get homeLayerPoem => '首页古诗';

  @override
  String get bottomBarHome => '首页';

  @override
  String get bottomBarFeatureHub => '功能中心';

  @override
  String get bottomBarLogDashboard => '日志仪表盘';

  @override
  String get bottomBarAppTraffic => '应用流量';

  @override
  String get bottomBarNetworkTools => '网络工具';

  @override
  String get bottomBarSettings => '设置';

  @override
  String get bottomBarStyleFloating => '浮条';

  @override
  String get bottomBarStyleDocked => '普通';

  @override
  String get tabTransitionNone => '无';

  @override
  String get tabTransitionFade => '淡入';

  @override
  String get tabTransitionSlide => '滑动';

  @override
  String get tabTransitionScale => '缩放';

  @override
  String get commonOff => '关闭';

  @override
  String get glassModeStandard => '标准';

  @override
  String get glassModeUltra => '极致';

  @override
  String get previewBrightnessLight => '浅色';

  @override
  String get previewBrightnessDark => '深色';

  @override
  String get resolutionModeSingle => '单服务商';

  @override
  String get resolutionModeSmart => '智能选择';

  @override
  String get resolutionModeParallel => '并行竞速';

  @override
  String get resolutionModePrimaryBackup => '主备切换';

  @override
  String get workModeNormalTitle => '普通模式';

  @override
  String get workModeNormalBadge => '推荐';

  @override
  String get workModeNormalSummary => '全量域名解析、黑白名单、HTTPS 检查、网络管控';

  @override
  String get workModeServerTitle => '服务器模式';

  @override
  String get workModeServerBadge => '轻量';

  @override
  String get workModeServerSummary => '纯 DNS 代理与解析加速、低功耗';

  @override
  String get workModeExpressTitle => '极速模式';

  @override
  String get workModeExpressBadge => '极速';

  @override
  String get workModeExpressSummary => '纯 Kotlin、DNS 加速与规则过滤、Android 7+（64 位）';

  @override
  String get stateStopped => '已停止';

  @override
  String get stateStarting => '启动中';

  @override
  String get stateRunning => '运行中';

  @override
  String get stateStopping => '停止中';

  @override
  String get powerStateError => '启动失败';

  @override
  String get serverStatusError => '异常';

  @override
  String get logModeAllLabel => '记录全部';

  @override
  String get logModeAllDescription => '请求、命中、竞速与拦截都进日志';

  @override
  String get logModeBlockedLabel => '仅拦截与错误';

  @override
  String get logModeBlockedDescription => '只记录被拦截与出错的请求';

  @override
  String get logModeOffLabel => '关闭日志';

  @override
  String get logModeOffDescription => '不记录任何请求，节省空间';

  @override
  String get ipv6AutoLabel => '自动';

  @override
  String get ipv6AutoDescription => '按当前网络能力决定是否启用';

  @override
  String get ipv6DisableLabel => '关闭';

  @override
  String get ipv6DisableDescription => '隧道内不启用 IPv6';

  @override
  String get ipv6PreferLabel => '优先';

  @override
  String get ipv6PreferDescription => '尽量走 IPv6，失败再回落';

  @override
  String get commonToday => '今日';

  @override
  String get logWindowSevenDays => '7 天';

  @override
  String get logWindowSevenDaysRecent => '近 7 天';

  @override
  String get commonAll => '全部';

  @override
  String get trafficWindowWeek => '本周';

  @override
  String get trafficWindowMonth => '本月';

  @override
  String get trafficSortTotal => '按总流量';

  @override
  String get trafficSortDownload => '按下载流量';

  @override
  String get trafficSortUpload => '按上传流量';

  @override
  String get davStatusIdle => '未连接';

  @override
  String get davStatusConnecting => '连接中';

  @override
  String get davStatusConnected => '连接成功';

  @override
  String get davStatusFailed => '连接失败';

  @override
  String get updateStageIdle => '未检查';

  @override
  String get updateStageChecking => '检查中';

  @override
  String get updateStageUpToDate => '已是最新';

  @override
  String get updateStageAvailable => '发现新版本';

  @override
  String get updateStageDownloading => '下载中';

  @override
  String get updateStageDownloaded => '下载完成';

  @override
  String get ipQualityStageIdle => '未检测';

  @override
  String get ipQualityStageLoading => '检测中';

  @override
  String get ipQualityStageLoaded => '检测完成';

  @override
  String get ipQualityStageFailed => '检测失败';

  @override
  String get subscriptionDeleted => '已删除';

  @override
  String get subscriptionDisabled => '已禁用';

  @override
  String get subscriptionUngrouped => '未分组';

  @override
  String get providerNotTested => '未测速';

  @override
  String get elapsedJustNow => '刚刚';

  @override
  String elapsedSecondsAgo(Object count) {
    return '$count 秒前';
  }

  @override
  String elapsedMinutesAgo(Object count) {
    return '$count 分钟前';
  }

  @override
  String elapsedHoursAgo(Object count) {
    return '$count 小时前';
  }

  @override
  String elapsedDaysAgo(Object count) {
    return '$count 天前';
  }

  @override
  String providerRaceSummary(Object count, Object names) {
    return '已选 $count 个：$names';
  }

  @override
  String get rulesDbUnavailable => '当前环境无法读写规则库';

  @override
  String get agentApiKeyMissing => '尚未配置可用的 API Key，请先在「AI 厂商管理」里填写并选中该厂商。';

  @override
  String get agentNoExtraInfo => '（无附加信息）';

  @override
  String get agentNoLegacyDatabase => '未找到旧版数据库，无法读取 DNS 与 HTTPS 日志；请先启动一次服务。';

  @override
  String get agentExpressNoHttps => '极速模式只做窄路由 DNS 加速，不产生 HTTPS 检查记录';

  @override
  String get autoUpdateDisabled => '自动更新已关闭';

  @override
  String get autoUpdateNoSubscriptions => '没有可自动更新的订阅';

  @override
  String get autoUpdateNotDue => '未到更新时间';

  @override
  String get autoUpdateBusy => '正在手动更新，本轮跳过';

  @override
  String get cleanupGroupRuntime => '运行数据';

  @override
  String get cleanupGroupWeights => '权重数据';

  @override
  String get cleanupGroupRules => '规则与订阅';

  @override
  String get cleanupGroupStorage => '存储与安全';

  @override
  String get cleanupGroupGuides => '引导与重置';

  @override
  String get backupReadFileFailed => '无法读取所选文件';

  @override
  String get caChannelUnavailable => '证书通道不可用';

  @override
  String get caInstallUnavailable => '无法调起证书安装界面';

  @override
  String get caDownloadDirUnavailable => '无法写入下载目录';

  @override
  String get fontSystemDefault => '系统默认';

  @override
  String get diagnosticsChannelUnavailable => '诊断通道不可用（当前平台没有原生实现）';

  @override
  String get diagnosticsUnsupported => '当前环境不支持该诊断能力';

  @override
  String get diagnosticsPingUnsupported => '当前环境不支持 Ping 探测';

  @override
  String get diagnosticsTraceUnsupported => '当前环境不支持路由追踪';

  @override
  String get diagnosticsDnsUnsupported => '当前环境不支持 DNS 查询';

  @override
  String get diagnosticsEmptyTarget => '请输入探测目标';

  @override
  String get diagnosticsTargetHasSpace => '目标不能包含空格';

  @override
  String get diagnosticsAnswerUpstream => '上游解析';

  @override
  String get diagnosticsAnswerCache => '缓存命中';

  @override
  String get diagnosticsAnswerRewrite => '覆写规则';

  @override
  String get diagnosticsAnswerBlocked => '被规则拦截';

  @override
  String get diagnosticsAnswerFailed => '查询失败';

  @override
  String get diagnosticsNoActiveNetwork => '无活动网络';

  @override
  String get aiPresetMainland => '国内厂商';

  @override
  String get aiPresetOverseas => '海外厂商';

  @override
  String get aiPresetAggregator => '聚合与本地部署';

  @override
  String get aiProviderConfigured => '已配置厂商';

  @override
  String get logSubscriptionDeleted => '已删除订阅';

  @override
  String get logRaceFastest => '最快响应';

  @override
  String get logRaceSmart => '智能选择';

  @override
  String get logRaceSequential => '依次尝试';

  @override
  String get logRaceSingle => '单服务商';

  @override
  String get providerNoProviderSelected => '未选择服务商';

  @override
  String get onDemandDisabled => '按需连接已关闭，未做改动';

  @override
  String get onDemandServerMode => '服务器模式不使用隧道，未做改动';

  @override
  String get onDemandUnknownSsid => '无法读取当前 Wi-Fi，未做改动';

  @override
  String get onDemandSameNetwork => '网络未变化，保持当前 VPN 状态';

  @override
  String get onDemandNoWifi => '当前不在 Wi-Fi 上，已断开 VPN';

  @override
  String get onDemandStarted => '已匹配白名单，VPN 已启动';

  @override
  String get onDemandAlreadyRunning => '已匹配白名单，VPN 正在运行';

  @override
  String get onDemandStopped => '当前网络不在白名单，已断开 VPN';

  @override
  String get onDemandAlreadyStopped => '当前网络不在白名单，VPN 未启动';

  @override
  String get onDemandBusy => 'VPN 正在切换状态，稍后再试';

  @override
  String get onDemandNeedsConsent => '已匹配白名单，等待系统 VPN 授权';

  @override
  String get speedTestSelectProvider => '请先选择至少一个测速服务商';

  @override
  String get speedTestEmptyDomain => '请输入用于测速的域名';

  @override
  String get imagePickerUnavailable => '当前设备没有可用的图片选择器';

  @override
  String get serverModeRequired => '请先切换到服务器模式';

  @override
  String get serverStartFailed => 'DNS 服务启动失败';

  @override
  String get serverStartTimeout => 'DNS 服务启动超时';

  @override
  String get recognitionInvalidConfig => '云端名单配置无效';

  @override
  String get recognitionGithubInterrupted => '与 GitHub 的连接被中断，请稍后重试';

  @override
  String get recognitionGithubTimeout => '连接 GitHub 超时，请检查网络后重试';

  @override
  String get recognitionNetworkUnavailable => '网络不可用，无法更新名单';

  @override
  String get recognitionUpdateFailed => '名单更新失败';

  @override
  String get subscriptionNotFound => '订阅不存在或数据库不可用';

  @override
  String get subscriptionDatabaseUnavailable => '订阅数据库不可用';

  @override
  String get subscriptionRuleDbUnavailable => '规则库不可用，下载的规则无法入库';

  @override
  String get subscriptionUpdateFailed => '更新失败';

  @override
  String get subscriptionLocalFileUnreadable => '无法读取本地文件';

  @override
  String get subscriptionLocalRuleDbUnavailable => '规则库不可用，本地规则无法入库';

  @override
  String get subscriptionNothingToUpdate => '没有可更新的订阅';

  @override
  String get subscriptionPickRuleFile => '请选择一个规则文件';

  @override
  String get subscriptionPickTxtFile => '请选择扩展名为 .txt 的规则文件';

  @override
  String get subscriptionLegacyDatabaseMissing => '订阅数据库不可用（未找到 1.4.3 数据库）';

  @override
  String get subscriptionThisFile => '该文件';

  @override
  String get subscriptionThisLink => '该订阅链接';

  @override
  String get subscriptionLocalRuleFile => '本地规则文件';

  @override
  String get webdavEmptyCredentials => '服务器地址与用户名不能为空';

  @override
  String get webdavDirectoryCreated => '目录不存在，已自动创建';

  @override
  String get webdavUploaded => '已上传到云端';

  @override
  String get webdavNoBackup => '云端还没有备份文件';

  @override
  String get webdavDownloaded => '已从云端取回备份';

  @override
  String get updateCheckFirst => '请先检查更新';

  @override
  String get updateDownloadFirst => '请先下载更新包';

  @override
  String get updateInstallerUnavailable => '无法调起系统安装器，请稍后重试';

  @override
  String get workModeNoDataPlane => '当前工作模式尚未接入数据面';

  @override
  String get workModeNoVpnConsent => '没有获得 VPN 授权';

  @override
  String get workModeStartTimeout => '服务启动超时';

  @override
  String get workModeVpnStartFailed => 'VPN 启动失败';

  @override
  String get aiProviderZhipu => '智谱 GLM';

  @override
  String get aiProviderMoonshot => 'Kimi（月之暗面）';

  @override
  String get aiProviderDashscope => '阿里云百炼（通义千问）';

  @override
  String get aiProviderVolcengine => '火山方舟（豆包）';

  @override
  String get aiProviderQianfan => '百度千帆（ERNIE）';

  @override
  String get aiProviderStepfun => '阶跃星辰';

  @override
  String get aiProviderSiliconflow => '硅基流动';

  @override
  String get aiProviderOllamaLocal => 'Ollama（本机）';

  @override
  String rulesReadFailed(Object detail) {
    return '读取应用规则失败：$detail';
  }

  @override
  String autoUpdateChecked(Object count) {
    return '已检查 $count 个订阅';
  }

  @override
  String caChannelUnavailableDetail(Object detail) {
    return '证书通道不可用：$detail';
  }

  @override
  String caReadFailedCode(Object code) {
    return '读取根证书失败（$code）';
  }

  @override
  String caReadFailed(Object detail) {
    return '读取根证书失败：$detail';
  }

  @override
  String agentAnalysisFailed(Object detail) {
    return '分析失败：$detail';
  }

  @override
  String diagnosticsFailedCode(Object code) {
    return '诊断执行失败（$code）';
  }

  @override
  String diagnosticsFailed(Object detail) {
    return '诊断执行失败：$detail';
  }

  @override
  String subscriptionDeletedWithId(Object id) {
    return '已删除订阅 #$id';
  }

  @override
  String providerLatencyValue(Object value) {
    return '${value}ms';
  }

  @override
  String providerRaceSummaryNames(Object count, Object names) {
    return '已选 $count 个：$names';
  }

  @override
  String get providerNamesSeparator => '、';

  @override
  String recognitionInvalidConfigKept(Object detail) {
    return '云端名单配置无效（$detail），已保留本地缓存';
  }

  @override
  String recognitionFetchFailed(Object detail) {
    return '云端名单拉取失败（$detail）';
  }

  @override
  String recognitionUpdateFailedDetail(Object detail) {
    return '名单更新失败：$detail';
  }

  @override
  String subscriptionAlreadyExists(Object kind, Object what) {
    return '$what已作为$kind存在';
  }

  @override
  String subscriptionUpdatedCount(Object count) {
    return '$count 个已更新';
  }

  @override
  String subscriptionUnchangedCount(Object count) {
    return '$count 个未变化';
  }

  @override
  String subscriptionFailedCount(Object count) {
    return '$count 个失败';
  }

  @override
  String subscriptionAlreadyExistsNamed(Object kind, Object name, Object what) {
    return '$what已作为$kind存在（「$name」）';
  }

  @override
  String get commonBypass => '旁路';

  @override
  String get commonRewrite => '覆写';

  @override
  String get cleanupLogs => '删除请求日志';

  @override
  String get cleanupTraffic => '删除流量统计';

  @override
  String get cleanupCrash => '删除崩溃日志';

  @override
  String get cleanupDnsCache => '删除 DNS 缓存';

  @override
  String get cleanupProviderWeights => '恢复 DNS 默认权重';

  @override
  String get cleanupBootstrapWeights => '恢复 Bootstrap 权重';

  @override
  String get cleanupDomainRules => '删除全部域名规则';

  @override
  String get cleanupAddressRules => '删除全部地址规则';

  @override
  String get cleanupSubscriptions => '删除全部规则订阅';

  @override
  String get cleanupAppRules => '重置应用控制名单';

  @override
  String get cleanupOutboundProxy => '重置出站代理配置';

  @override
  String get cleanupCaCertificate => '重置 HTTPS 抓包证书';

  @override
  String get cleanupDownloadCache => '清理下载与临时缓存';

  @override
  String get cleanupCustomBackground => '清除自定义背景缓存';

  @override
  String get cleanupSettingsGuides => '重置所有新手引导';

  @override
  String get cleanupAllData => '清理全部本地数据';

  @override
  String cleanupDoneItems(Object action, Object count, Object detail) {
    return '已$action：$count 项$detail';
  }

  @override
  String cleanupDoneEmpty(Object action) {
    return '已$action：没有可清理的数据';
  }

  @override
  String get blockResponseNxdomain => '返回 NXDOMAIN';

  @override
  String get blockResponseNxdomainDescription => '返回域名不存在，并提供 5 分钟负缓存以减少重复查询';

  @override
  String get blockResponseNodata => '返回 NODATA';

  @override
  String get blockResponseNodataDescription => '返回域名存在但没有该记录，并提供 5 分钟负缓存';

  @override
  String get blockResponseRefused => '返回 REFUSED';

  @override
  String get blockResponseRefusedDescription => '返回服务器拒绝该查询，不提供缓存记录';

  @override
  String get blockResponseZeroAddress => '返回 0.0.0.0 / ::';

  @override
  String get blockResponseZeroAddressDescription =>
      'A 返回 0.0.0.0，AAAA 返回 ::，其他类型返回空结果';

  @override
  String get subscriptionSourceRemote => '网络订阅';

  @override
  String get subscriptionSourceLocal => '本地文件';

  @override
  String get subscriptionKindDomain => '黑白名单规则';

  @override
  String get subscriptionKindHosts => 'hosts 规则';

  @override
  String logRowDirect(Object protocol) {
    return '$protocol 直连';
  }

  @override
  String logRowDirectWithPackage(Object package, Object protocol) {
    return '$protocol 直连 · $package';
  }

  @override
  String get logRowCacheHit => '命中缓存';

  @override
  String get logRowNoAuthority => '未取得 authority';

  @override
  String get cachePresetConservativeName => '保守';

  @override
  String get cachePresetConservativeSummary => '遵从服务器有效期 (TTL)';

  @override
  String get cachePresetConservativeDescription =>
      '遵从 DNS 服务器返回的有效期，不主动延长缓存时间，适合经常切换网络或对实时性敏感的场景。';

  @override
  String get cachePresetStandardName => '标准';

  @override
  String get cachePresetStandardSummary => '最长 1 小时，短记录至少 1 分钟';

  @override
  String get cachePresetStandardDescription =>
      '减少重复查询，同时避免记录过期滞后。解析失败时可短暂使用 5 分钟内的旧记录应急。';

  @override
  String get cachePresetAggressiveName => '高命中';

  @override
  String get cachePresetAggressiveSummary => '最长 6 小时，短记录至少 2 分钟';

  @override
  String get cachePresetAggressiveDescription =>
      '更偏向降低网络请求次数和提升弱网可用性。域名变更时更新可能会稍慢一些。';

  @override
  String get cacheDisabledSummary => '已关闭 · 每次解析都会请求上游';

  @override
  String get upstreamNameRequired => '请填写名称';

  @override
  String get upstreamAddressRequired => '请填写地址';

  @override
  String get upstreamDohNeedsHttps => 'DoH 地址必须以 https:// 开头';

  @override
  String get upstreamDohInvalidUrl => 'DoH 地址不是合法的 URL';

  @override
  String get upstreamPortRange => '端口需在 1–65535 之间';

  @override
  String get upstreamIpv6Invalid => 'IPv6 地址格式不正确';

  @override
  String get upstreamPresetAliyun => '阿里云';

  @override
  String get upstreamPresetTencent => '腾讯云 DNSPod';

  @override
  String get upstreamPresetByteDance => '字节跳动';

  @override
  String cleanupFailed(Object detail) {
    return '清理失败：$detail';
  }

  @override
  String get cleanupProxyRestored => '已恢复直连';

  @override
  String get cleanupCaNeedsReimport => '需重新生成并导入系统证书';

  @override
  String get hubCategoryDns => 'DNS 服务';

  @override
  String get hubProviderManagement => '服务商管理';

  @override
  String get hubProviderManagementDescription => '配置与管理 DoH、DoT 与传统 DNS 解析服务商';

  @override
  String get hubBootstrap => '引导解析设置';

  @override
  String get hubBootstrapDescription => '配置用于首次解析加密上游域名的引导 DNS 节点';

  @override
  String get hubResolution => '解析模式';

  @override
  String get hubResolutionDescription => '选择单一服务、智能选择、最快响应或依次尝试策略';

  @override
  String get hubCache => '缓存设置';

  @override
  String get hubCacheDescription => '配置 DNS 缓存开关、缓存策略与最大最小生存时间 (TTL)';

  @override
  String get hubCategoryRules => '策略与规则';

  @override
  String get hubRuleControl => '规则控制';

  @override
  String get hubRuleControlDescription => '统一管理拦截策略开关与在线网络规则订阅';

  @override
  String get hubBlocklist => '黑名单';

  @override
  String get hubBlocklistDescription => '自定义屏蔽域名列表，匹配时返回拦截响应';

  @override
  String get hubAllowlist => '白名单';

  @override
  String get hubAllowlistDescription => '自定义放行域名列表，豁免所有规则直接放行';

  @override
  String get hubRewrite => '覆写名单';

  @override
  String get hubRewriteDescription => '自定义域名覆写指向特定 IPv4/IPv6 或 CNAME';

  @override
  String get hubCategoryNetwork => '网络控制';

  @override
  String get hubAppTraffic => '应用流量统计';

  @override
  String get hubAppTrafficDescription => '统计各应用的网络连接数、上传与下载流量明细';

  @override
  String get hubAppRules => '应用独立规则';

  @override
  String get hubAppRulesDescription => '为特定应用单独指定专属域名放行与网络规则';

  @override
  String get hubBlockedApps => '禁止联网应用';

  @override
  String get hubBlockedAppsDescription => '在本地隧道层拦截指定应用的全部网络外联';

  @override
  String get hubExcludedApps => '排除应用';

  @override
  String get hubExcludedAppsDescription => '允许指定应用绕过本软件直连网络';

  @override
  String get hubCategoryAdvanced => '高级与诊断';

  @override
  String get hubHttpsInspection => 'HTTPS 流量检查';

  @override
  String get hubHttpsInspectionDescription =>
      '解密并检查特定应用的 HTTP(S) 流量，支持域名与 URL 过滤';

  @override
  String get hubOutboundProxy => '出站代理';

  @override
  String get hubOutboundProxyDescription => '将过滤后的流量转发到本地 SOCKS5 或 HTTP 代理';

  @override
  String get hubDiagnostics => '网络诊断';

  @override
  String get hubDiagnosticsDescription => '提供 DNS 查询、Ping 延迟测试与网络连通性诊断工具';

  @override
  String get hubAiAnalysis => 'AI 分析';

  @override
  String get hubAiAnalysisDescription => '配置大语言模型接口与密钥，用于日志研判与网络流量分析';

  @override
  String get hubCategoryInterface => '界面与设置';

  @override
  String get hubAppearance => '外观调整';

  @override
  String get hubAppearanceDescription => '自定义日夜模式、主题色彩、组件透明度与软件壁纸背景';

  @override
  String get hubProviderVisibility => '服务显示';

  @override
  String get hubProviderVisibilityDescription => '自定义在首页解析服务下拉列表中显示的服务商';

  @override
  String get hubHiddenFeatures => '隐藏功能';

  @override
  String get hubHiddenFeaturesDescription => '自定义在功能中心显示的功能卡片，不改后台运行';

  @override
  String get hubOtherSettings => '其他设置';

  @override
  String get hubOtherSettingsDescription => '语言切换、前后台行为、通知设置等全局配置';

  @override
  String get hubCategoryData => '数据与维护';

  @override
  String get hubLogs => '日志';

  @override
  String get hubLogsDescription => '实时解析统计、请求明细查询与日志导出';

  @override
  String get hubBackup => '备份与迁移';

  @override
  String get hubBackupDescription => '导出与导入服务商、规则订阅及个性化设置';

  @override
  String get hubDataCleanup => '数据清理';

  @override
  String get hubDataCleanupDescription => '删除缓存、日志或域名与地址过滤规则';

  @override
  String get hubTroubleshooting => '故障排查';

  @override
  String get hubTroubleshootingDescription => '导出崩溃日志，手动抓取并导出运行日志发给开发者';

  @override
  String get hubCategoryAbout => '关于谛听';

  @override
  String get hubAbout => '关于';

  @override
  String get hubAboutDescription => '查看版本信息、检查更新、开源地址与贡献者名单';

  @override
  String get hubSponsor => '赞助';

  @override
  String get hubSponsorDescription => '支持谛听项目持续维护与开发';

  @override
  String get hubSponsors => '赞助者名单';

  @override
  String get hubSponsorsDescription => '鸣谢支持谛听项目的赞助者';

  @override
  String get hubContributors => '共建者名单';

  @override
  String get hubContributorsDescription => '感谢为谛听贡献代码与建议的共建者';

  @override
  String get fontSizeSmall => '小';

  @override
  String get fontSizeStandard => '标准';

  @override
  String get fontSizeLarge => '大';

  @override
  String get fontSizeExtraLarge => '特大';

  @override
  String get fontSizeFooter => '字号会同时放大正文、标题与列表行，不会改变系统设置；界面已按所选比例排版，无需重启。';

  @override
  String get fontSizePreview => '实时预览';

  @override
  String get appearancePoem => '谛听万象，明察清浊';

  @override
  String get appearancePoemBody => '网络连通性、规则命中与设备状态，都在这一页里说清楚。';

  @override
  String get appearanceTitle => '外观设置';

  @override
  String get appearanceInterfaceSection => '界面显示';

  @override
  String get appearanceHomeOpacitySubtitle => '交互组件与文字的透明度';

  @override
  String get appearancePureBlackOn => '深色表面折叠为纯黑，OLED 更省电';

  @override
  String get appearancePureBlackOff => '切到深色模式后才可开启';

  @override
  String get appearanceHomeSection => '首页内容';

  @override
  String get appearanceHomeSentenceSubtitle => '运行与停止两种状态各一句';

  @override
  String get appearanceNotification => '通知栏设置';

  @override
  String get appearanceNotificationSubtitle => '常驻通知、实时速率与自定义文案';

  @override
  String get appearanceBackgroundSection => '背景与动效';

  @override
  String get appearanceHapticSubtitle => '切换 tab 时给一次轻震';

  @override
  String get appearanceBottomBarStyleFloating => '浮在页面之上';

  @override
  String get appearanceBottomBarStyleDocked => '贴底排列';

  @override
  String get appearanceTabTransitionSubtitle => '切换底部标签时的动画方式';

  @override
  String get appearanceMotionFooter => '底栏样式、动画与玻璃只作用于浮条；普通底栏始终是实色。';

  @override
  String get appearancePaletteGoldLegacy => '落盘值沿用旧版的 indigo';

  @override
  String get appearancePaletteFooter =>
      '色板只提供种子，上屏的是 HCT 推导出的整套角色色。旧版没有自定义取色，因此这里也不提供。';

  @override
  String fontFamilySizeSubtitle(Object percent) {
    return '当前 $percent%';
  }

  @override
  String get fontFamilySystemDefault => '跟随宿主平台的中文界面字体，最稳妥的选择';

  @override
  String get fontFamilyImported => '已导入的第三方字体';

  @override
  String get fontFamilyEmpty => '还没有导入字体。导入后即可在这里切换，字体文件只保存在本机。';

  @override
  String get fontFamilyFooter => '导入的字体只影响本机显示，删除后会自动回退到系统默认。';

  @override
  String get fontFamilyLocalOnly => '选择只影响本机显示，不改动服务端规则。';

  @override
  String get fontFamilyImportFailed => '导入失败';

  @override
  String get fontFamilyDeleteTitle => '删除字体';

  @override
  String get commonCancel => '取消';

  @override
  String get commonDelete => '删除';

  @override
  String fontFamilyDeleteConfirm(Object name) {
    return '删除「$name」后，使用该字体的界面会回退到系统默认。';
  }

  @override
  String get fontFamilyImport => '导入字体';

  @override
  String get fontFamilyReading => '正在读取字体文件…';

  @override
  String get fontFamilyPickFile => '选择本机的 TTF / OTF 文件';

  @override
  String get notificationPersistentSection => '常驻通知';

  @override
  String get notificationPersistentFooter => '关闭后服务运行时不再显示常驻通知，系统可能因此更快回收进程。';

  @override
  String get notificationPersistent => '通知常驻';

  @override
  String get notificationPersistentSubtitle => '服务运行时保留一条不可划掉的通知';

  @override
  String get notificationShowSpeed => '显示实时速率';

  @override
  String get notificationShowSpeedSubtitle => '在通知里显示当前上下行速率';

  @override
  String get notificationTextRunning => 'DNS 服务开启时';

  @override
  String get notificationTextStopped => 'DNS 服务关闭时';

  @override
  String get notificationTextHint => '留空则使用默认文案';

  @override
  String get notificationTextFooter => '留空则使用默认文案；文案只影响通知栏，不改变服务行为。';

  @override
  String get notificationPermissions => '权限';

  @override
  String get notificationSystemPermission => '系统通知权限';

  @override
  String get notificationSystemPermissionSubtitle => '打开系统的通知设置页';

  @override
  String get backgroundTitle => '软件背景';

  @override
  String get backgroundSection => '自定义背景';

  @override
  String get backgroundFooter => '壁纸只保存在本机，不随备份导出。';

  @override
  String get backgroundEnable => '启用自定义背景';

  @override
  String get backgroundPickFirst => '请先添加一张图片';

  @override
  String get backgroundBehindPages => '在全部页面下垫一层壁纸';

  @override
  String get backgroundAddImage => '添加图片';

  @override
  String get backgroundAddImageSubtitle => '从相册选择一张';

  @override
  String get backgroundAdded => '已添加壁纸';

  @override
  String get backgroundAddedFooter => '点一下切换，长按删除。';

  @override
  String get backgroundEmpty => '还没有背景图';

  @override
  String get backgroundEmptyDescription => '点「添加图片」从相册里挑一张。';

  @override
  String get backgroundDeleteTitle => '删除壁纸';

  @override
  String get backgroundDeleteConfirm => '确定删除这张已添加的壁纸吗？';

  @override
  String get foregroundTitle => '前后台行为';

  @override
  String get foregroundPrivacySection => '后台与隐私';

  @override
  String get foregroundPrivacyFooter => '「后台隐藏」会从最近任务列表里移除本应用；下次从桌面图标进入即可。';

  @override
  String get foregroundHide => '后台隐藏';

  @override
  String get foregroundHideSubtitle => '不在最近任务列表中显示';

  @override
  String get foregroundRouting => '路由';

  @override
  String get foregroundBypassLan => '绕过局域网';

  @override
  String get foregroundBypassLanSubtitle => '本地网段与本机地址不走隧道';

  @override
  String get foregroundStability => '稳定性';

  @override
  String get foregroundBatteryFooter => '关闭电池优化后，系统在后台更不容易回收服务进程。';

  @override
  String get foregroundIgnoreBattery => '忽略电池优化';

  @override
  String get foregroundIgnoreBatterySubtitle => '请求把本应用加入系统白名单';

  @override
  String get dayNightTitle => '日夜模式';

  @override
  String get dayNightFollowSystemDescription => '系统切换深色时一起切换';

  @override
  String get dayNightFooter => '纯黑只在深色模式下生效，开关在「外观设置」的界面显示组里。';

  @override
  String get homeOpacityTitle => '首页透明度';

  @override
  String get homeOpacityComponents => '交互组件';

  @override
  String get homeOpacityComponentsFooter => '透明度只影响可见度，不影响这些组件的点击区域。';

  @override
  String get homeOpacityText => '文字';

  @override
  String get bottomBarHomeSubtitle => '首页与仪表盘';

  @override
  String get bottomBarFeatureHubSubtitle => '全部功能入口';

  @override
  String get bottomBarLogDashboardSubtitle => '日志仪表盘';

  @override
  String get bottomBarAppTrafficSubtitle => '应用流量排行';

  @override
  String get bottomBarNetworkToolsSubtitle => '测速与网络诊断';

  @override
  String get bottomBarSettingsSubtitle => '全部设置项';

  @override
  String get bottomBarMinimumHint => '底栏至少保留 2 项';

  @override
  String get bottomBarCustomTitle => '底栏自定义';

  @override
  String bottomBarItemsHeader(Object count, Object max) {
    return '底栏项（$count/$max）';
  }

  @override
  String bottomBarDragHint(Object max) {
    return '按住右侧把手或长按整行拖动排序，顺序即底栏从左到右的顺序。至少 2 项、最多 $max 项：浮条按项数等比分配宽度，再多就挤到看不清图标。';
  }

  @override
  String get bottomBarDisabled => '未启用';

  @override
  String get bottomBarNewItemFooter => '新启用的项排在底栏最右侧。';

  @override
  String get bottomBarFeel => '手感';

  @override
  String get homeSentenceTitle => '首页句子';

  @override
  String get homeSentenceFooter => '两项均可留空；留空后对应状态下首页不显示句子，句子只在首页电源区下方出现一次。';

  @override
  String get appearancePaletteTitle => '主题色配置';

  @override
  String get appearancePaletteInfoLabel => '色板';

  @override
  String get appearancePaletteBody =>
      '色板只提供种子，上屏的是 HCT 推导出的整套角色色。旧版没有自定义取色，因此这里也不提供。';

  @override
  String get dayNightInfoLabel => '模式';

  @override
  String get appearanceFontSizeLabel => '字号';

  @override
  String appearanceFontSizeCurrent(Object percent) {
    return '当前 $percent%';
  }

  @override
  String get appearanceFontSection => '字体';

  @override
  String appearanceFontImported(Object name) {
    return '已导入 $name';
  }

  @override
  String appearanceFontDeleted(Object name) {
    return '已删除 $name';
  }

  @override
  String appearanceBottomBarMax(Object max) {
    return '底栏最多 $max 项';
  }

  @override
  String appearanceBottomBarHeader(Object count, Object max) {
    return '底栏项（$count/$max）';
  }

  @override
  String appearanceBottomBarDragBody(Object max) {
    return '按住右侧把手或长按整行拖动排序，顺序即底栏从左到右的顺序。至少 2 项、最多 $max 项：浮条按项数等比分配宽度，再多就挤到看不清图标。';
  }

  @override
  String appearanceBottomBarSelected(Object count) {
    return '已选 $count 项，可配置 2–4 项';
  }

  @override
  String get appearanceHaptic => '底栏触感反馈';

  @override
  String get appearancePureBlack => '纯黑';

  @override
  String get appearanceBottomBarStyle => '底栏样式';

  @override
  String get appearanceTabTransition => 'tab 切换动画';

  @override
  String get appearanceLiquidGlass => 'Liquid 玻璃';

  @override
  String get fontFamilyTitle => '字体设置';

  @override
  String get fontSizeRestoreDefaults => '恢复默认';

  @override
  String get fontFamilyHapticSubtitle => '切换 tab 时给一次轻震';

  @override
  String get ruleKindBlockTitle => '黑名单';

  @override
  String get ruleKindBlockSummary => '拦截匹配的域名';

  @override
  String get ruleKindAllowTitle => '白名单';

  @override
  String get ruleKindAllowSummary => '放行匹配的域名';

  @override
  String get ruleKindRewriteTitle => '覆写';

  @override
  String get ruleKindRewriteSummary => '改写域名解析结果';

  @override
  String get ruleSourceUser => '用户自定义';

  @override
  String get ruleSourceSubscription => '规则订阅';

  @override
  String get ruleSourcePreset => '内置预设';

  @override
  String get rulePatternRequired => '规则内容不能为空';

  @override
  String get ruleAllowNeedsAllowlist => '该规则为放行规则，请在白名单中添加';

  @override
  String get ruleAlreadyExists => '该规则已存在';

  @override
  String get ruleDomainHint => '域名，如 cdn.example.com';

  @override
  String get ruleTargetRequired => '目标值不能为空';

  @override
  String get ruleTargetHint => '目标值，如 10.0.0.8';

  @override
  String get ruleImportant => '重要';

  @override
  String get ruleReadOnly => '只读';

  @override
  String get ruleEdit => '编辑规则';

  @override
  String get ruleDelete => '删除规则';

  @override
  String get batchImportDone => '导入完成';

  @override
  String get batchAddTitle => '批量添加规则';

  @override
  String get batchTarget => '导入到';

  @override
  String get batchTargetTable => '目标规则表';

  @override
  String get batchTargetTableSubtitle => '导入的规则将写入所选规则表';

  @override
  String get batchPlaceholder =>
      '每行一条规则，例如：\n||ads.example.com^\n\n空行会被忽略，重复规则自动跳过。';

  @override
  String get batchImportable => '可导入';

  @override
  String get batchDuplicated => '重复';

  @override
  String get batchInvalid => '无效';

  @override
  String get batchInvalidHeader => '以下规则未通过校验';

  @override
  String get batchDuplicateHeader => '已存在，将跳过';

  @override
  String get ruleClearCustomTitle => '清空自定义规则';

  @override
  String get commonClearAll => '清空';

  @override
  String get ruleResetDefault => '重置默认白名单';

  @override
  String get commonReset => '重置';

  @override
  String get rulePresetProtectedTitle => '预设规则受保护';

  @override
  String get ruleAllowEditTitle => '允许编辑默认白名单？';

  @override
  String get ruleAllowEditConfirm => '仍然开启';

  @override
  String get ruleTotal => '规则总数';

  @override
  String get ruleEnabled => '已启用';

  @override
  String get ruleRewriteEntries => '覆写条目';

  @override
  String get ruleCustom => '自定义';

  @override
  String get ruleAllowEditDefault => '允许编辑默认白名单';

  @override
  String get ruleAllowEditDefaultSubtitle => '关闭时预设规则只读，避免误放宽放行范围';

  @override
  String get ruleNoMatch => '没有匹配的规则';

  @override
  String get ruleNoMatchDescription => '换个关键词或筛选条件再试';

  @override
  String get ruleAll => '全部';

  @override
  String get formIssuesTitle => '有几点需要先修正';

  @override
  String get formSave => '保存';

  @override
  String get formProcessing => '处理中…';

  @override
  String get formAdd => '添加';

  @override
  String get formDelete => '删除';

  @override
  String get formHelp => '说明';

  @override
  String get formGotIt => '知道了';

  @override
  String get rulePatternHint => '规则内容，如 ||ads.example.com^';

  @override
  String ruleBatchImported(Object count, Object kind) {
    return '已向$kind导入 $count 条规则。';
  }

  @override
  String ruleBatchSkippedDuplicates(Object count) {
    return '跳过 $count 条重复规则。';
  }

  @override
  String ruleBatchAllowRejected(Object count) {
    return '$count 条放行规则（含 #@#）未导入：该规则为放行规则，请在白名单中添加。';
  }

  @override
  String ruleBatchImportCount(Object count) {
    return '导入 $count 条';
  }

  @override
  String ruleBatchMoreDuplicates(Object count) {
    return '等 $count 条';
  }

  @override
  String ruleAddForKind(Object kind) {
    return '添加$kind规则';
  }

  @override
  String get ruleEditDefaultPreset => '编辑默认预设规则';

  @override
  String ruleEditForKind(Object kind) {
    return '编辑$kind规则';
  }

  @override
  String ruleDeletePresetMessage(Object pattern) {
    return '「$pattern」是内置预设规则，删除后可通过重置默认恢复。';
  }

  @override
  String ruleDeleteSubscriptionMessage(Object name, Object pattern) {
    return '「$pattern」来自订阅「$name」，删除后下次更新订阅可能重新出现。';
  }

  @override
  String ruleDeleteUserMessage(Object pattern) {
    return '确定删除「$pattern」吗？此操作不可撤销。';
  }

  @override
  String ruleClearCustomMessage(Object kind) {
    return '将删除全部用户自定义的$kind规则，订阅与预设规则不受影响。';
  }

  @override
  String get ruleResetMessage => '将内置预设规则恢复为初始内容，你自己添加与订阅带来的规则保留。';

  @override
  String get rulePresetProtectedMessage =>
      '默认白名单规则处于只读状态。请先开启页面顶部的「允许编辑默认白名单」开关，再修改或删除这些规则。';

  @override
  String get ruleAllowEditMessage => '白名单是放行名单，改动它可能让本应被拦截的流量通过。确认你清楚这条风险后再开启。';

  @override
  String ruleTally(Object enabled, Object matched) {
    return '共 $matched 条 · 启用 $enabled';
  }

  @override
  String ruleNoRulesForKind(Object kind) {
    return '还没有$kind规则';
  }

  @override
  String ruleClearCustomForKind(Object kind) {
    return '清空自定义$kind';
  }

  @override
  String get subsPickTxt => '请选择扩展名为 .txt 的规则文件';

  @override
  String get subsNoPersistPermission => '系统未授予长期读取权限，更新时需要重新选择文件';

  @override
  String get subsGroupNameRequired => '分组名称不能为空';

  @override
  String get subsEdit => '编辑订阅';

  @override
  String get subsAdd => '添加订阅';

  @override
  String get subsSaveTooltip => '保存订阅';

  @override
  String get subsInfoSection => '订阅信息';

  @override
  String get subsSourceType => '订阅方式';

  @override
  String get subsSourceLocalPick => '从存储中选择一个 .txt 文件';

  @override
  String get subsSourceRemoteDownload => '从网络地址下载规则正文';

  @override
  String get subsLocalRuleFile => '本地规则文件';

  @override
  String get subsLocalFileSubscription => '本地文件订阅';

  @override
  String get subsPickFile => '选择规则文件';

  @override
  String get subsLocalFileHint => '仅支持 .txt，点击从存储中选择';

  @override
  String get subsLocalFileRepick => '点击可重新选择文件';

  @override
  String get subsChoose => '选择';

  @override
  String get subsNameOptional => '名称（可选）';

  @override
  String get subsNameEmptyFileName => '留空则取文件名';

  @override
  String get subsUrl => '订阅地址';

  @override
  String get subsNameEmptyUrlTail => '留空则取链接末段';

  @override
  String get subsRuleType => '规则类型';

  @override
  String get subsKindHostsHint => '仅导入 hosts 地址与 CNAME 覆写规则';

  @override
  String get subsKindDomainHint => '导入域名规则与黑白名单';

  @override
  String get subsGroupHint => '分组只影响订阅页的筛选与批量更新，可稍后调整。';

  @override
  String get subsNewGroupShort => '+ 新建';

  @override
  String get subsMirrorTemplateFooter =>
      '镜像地址会把原始订阅地址改写成镜像前缀，常用于加速 GitHub 等慢速源。';

  @override
  String get subsAddMirrorTemplate => '添加镜像站模板';

  @override
  String get subsAddMirrorTemplateSubtitle => '还没有模板，先去保存一个常用的镜像前缀';

  @override
  String get subsMirrorFooter => '下载时先请求镜像地址；镜像失败且开启回退时，再试原始地址。';

  @override
  String get subsUseMirrorTemplate => '使用镜像站模板';

  @override
  String get subsUseMirrorTemplateSubtitle => '订阅源较慢或被限速时，改写下载地址';

  @override
  String get subsMirrorTemplate => '镜像模板';

  @override
  String get subsMirrorFallback => '失败后回退直连';

  @override
  String get subsMirrorFallbackSubtitle => '镜像请求失败时，改用原始订阅地址';

  @override
  String get subsEffectiveUrl => '实际请求地址';

  @override
  String get subsNothingToUpdate => '没有可更新的远程订阅';

  @override
  String get subsDeleteTitle => '删除订阅';

  @override
  String get subsRenameTitle => '重命名订阅';

  @override
  String get subsNameRequired => '名称不能为空';

  @override
  String get subsTitle => '订阅';

  @override
  String get subsUpdateAll => '更新全部订阅';

  @override
  String get subsCount => '订阅数';

  @override
  String get subsRuleCount => '已入库规则';

  @override
  String get subsAbnormal => '异常';

  @override
  String get subsUpdating => '正在更新订阅…';

  @override
  String get subsEmptyLabel => '还没有订阅';

  @override
  String get subsEmptyDescription => '订阅可以批量维护规则；更新会下载正文、解析并写入规则库，拦截随之生效。';

  @override
  String get subsUpdateFooter =>
      '更新会下载正文、解析成黑/白名单与覆写规则并写入规则库，同时替换该订阅上一次贡献的规则；元素隐藏规则本仓不注入，不计入条数。';

  @override
  String get subsAllGroups => '全部';

  @override
  String get subsNewGroupTitle => '新建分组';

  @override
  String get subsEditRemoteHint =>
      '修改链接或收录类型后会立即重新下载，并替换该订阅原有的规则；订阅方式与本地文件不可更改。';

  @override
  String get subsEditLocalHint =>
      '本地文件通过系统文件选择器读取，应用只保留读取权限；同名的黑白名单与 hosts 订阅互不影响。';

  @override
  String get subsAddRemoteHint =>
      '同一条链接可以为黑白名单和 hosts 各建一条订阅（唯一性按「链接 + 类型」判定），保存后会立即下载一次正文并写入规则库。';

  @override
  String get subsKindLabel => '收录类型';

  @override
  String get subsGroupLabel => '所属分组';

  @override
  String get subsMirrorTitle => '镜像加速';

  @override
  String subsDeleteMessage(Object name) {
    return '删除「$name」后不可撤销。\n\n删除会同时移除这条订阅贡献的全部规则（来源标签 sub_<id>）。';
  }

  @override
  String subsTotal(Object count) {
    return '共 $count 个订阅';
  }

  @override
  String subsGroupTotal(Object count, Object group) {
    return '「$group」下 $count 个订阅';
  }

  @override
  String get subsUpdateNow => '立即更新';

  @override
  String get subsReimport => '重新导入文件';

  @override
  String get subsRename => '重命名';

  @override
  String subsConsecutiveFailures(Object count) {
    return '连续失败 $count 次';
  }

  @override
  String get subsMirrorFallbackShort => '镜像 · 可回退';

  @override
  String get subsMirrorNoFallback => '镜像 · 不回退';

  @override
  String get subsLastUpdateFailed => '上次更新失败';

  @override
  String get subsNeverUpdated => '从未成功更新';

  @override
  String subsRuleCountValue(Object count) {
    return '$count 条';
  }

  @override
  String subsRulesStored(Object action, Object count) {
    return '已入库 $count 条规则；$action该订阅贡献的规则。';
  }

  @override
  String get subsActionRemote => '更新会重新下载并替换';

  @override
  String get subsActionLocal => '重新导入会重新读取该文件并替换';

  @override
  String get subsPickRuleFile => '请选择一个规则文件';

  @override
  String get subsChange => '更换';

  @override
  String get subsGroupShort => '+ 分组';

  @override
  String subsMirrorName(Object mirror) {
    return '镜像 $mirror';
  }
}

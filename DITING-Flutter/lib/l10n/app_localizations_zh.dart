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

  @override
  String get trafficPackageName => '包名';

  @override
  String get trafficAppName => '应用名';

  @override
  String get trafficDown => '下行流量';

  @override
  String get trafficUp => '上行流量';

  @override
  String get trafficTotal => '合计';

  @override
  String get trafficShare => '占比';

  @override
  String get trafficStartDate => '统计起始日';

  @override
  String get trafficLastUpdate => '最后更新';

  @override
  String get trafficAttributionFooter =>
      '流量按 UID 归因到应用（上游 TrafficAttributionDialog 的口径）；同一应用的多进程流量合并计算。';

  @override
  String get trafficAttributionTitle => '流量归因说明';

  @override
  String get trafficScopeTitle => '统计口径';

  @override
  String get trafficScopeBody =>
      '流量按 UID 归因：每个应用的上下行字节数由引擎按 UID 累计后按天落库（表 app_traffic_daily，主键是「日期 + 包名」），不走包名匹配，因此共享 UID 的应用会合并成一项。';

  @override
  String get trafficWhyLowerTitle => '为什么数字比系统设置里少';

  @override
  String get trafficWhyLowerBody =>
      '这里只统计经过本机隧道处理的流量，未进入隧道的直连流量不计入；系统设置里的统计包含全部网卡流量。';

  @override
  String get trafficWhyNoRateTitle => '为什么没有实时速率';

  @override
  String get trafficWhyNoRateBody =>
      '实时速率需要内核每秒回报的速率序列；本仓的按天流量表只有「日期 + 包名 + 上下行累计字节」，没有速率列。因此「本次会话」窗口与「按实时速率」排序不可用，页面上也没有速率曲线——页面里出现的每个数字都是真实字节数。';

  @override
  String get trafficRetentionTitle => '记录保留多久';

  @override
  String get trafficRetentionBody => '按天保留，由原生侧的清理策略删除过期行；「全部历史」档位汇总表里现存的全部日期。';

  @override
  String get trafficSystemAppsTitle => '系统应用怎么识别';

  @override
  String get trafficSystemAppsBody =>
      '流量表里没有系统应用标记，页面按旧版 SystemAppClassifier 的同一份前缀表识别（android、com.android.*、各厂商预装前缀等）。「隐藏系统应用」开关的状态落在 traffic_stats_hide_system_apps。';

  @override
  String get trafficUpstreamFooter =>
      '上游对应 ui/traffic/TrafficAttributionDialog.kt 与 AppTrafficDetailDialog.kt；本页数字来自 app_traffic_daily。';

  @override
  String get trafficTitle => '流量统计';

  @override
  String get trafficClearHistory => '清除历史';

  @override
  String get trafficRefresh => '刷新';

  @override
  String get trafficAttribution => '归因说明';

  @override
  String get trafficLoadFailed => '无法读取流量记录';

  @override
  String get trafficLoading => '正在读取流量记录';

  @override
  String get trafficAppCount => '应用数';

  @override
  String get trafficAppCountUnit => '个';

  @override
  String get trafficNoData => '暂无流量数据';

  @override
  String get trafficNoMatchingApps => '没有匹配的应用';

  @override
  String get trafficRankingTitle => '应用流量排行';

  @override
  String trafficShareFooter(Object range, Object window) {
    return '占比按$window总字节数（下行 + 上行）计算；$range。点按一行查看该应用的上下行明细。';
  }

  @override
  String get trafficClearTitle => '清除全部流量记录？';

  @override
  String get trafficConfirmClear => '确认清除';

  @override
  String get trafficClearBody => '此操作将清空所有已持久化的应用历史流量统计，清除后无法恢复。';

  @override
  String get trafficRangeAllHistory => '范围为全部历史记录';

  @override
  String get trafficSessionRange => '本次会话';

  @override
  String get trafficSessionUnavailable => '「本次会话」需要内核按会话回报流量，本仓只有按天落库的历史记录';

  @override
  String get trafficLiveRate => '按实时速率';

  @override
  String get trafficHideSystemApps => '隐藏系统应用';

  @override
  String get trafficSearchHint => '搜索应用名或包名';

  @override
  String get trafficAllHistory => '全部历史';

  @override
  String get trafficLiveRateUnavailable => '「按实时网速」需要每秒速率，本仓的按天表里没有速率列';

  @override
  String get trafficHideSystemAppsSubtitle => '按系统应用标记与厂商预装前缀识别，隐藏后不计入排行';

  @override
  String trafficWindowLabelDate(Object date) {
    return '统计日期 $date';
  }

  @override
  String trafficWindowLabelRange(Object end, Object start) {
    return '统计范围 $start 至 $end';
  }

  @override
  String trafficShareWindow(Object range, Object window) {
    return '占比按$window总字节数（下行 + 上行）计算；$range。点按一行查看该应用的上下行明细。';
  }

  @override
  String trafficTotalApps(Object count, Object total) {
    return '共 $count 个应用产生流量 · 合计 $total';
  }

  @override
  String trafficSearchEmpty(Object search) {
    return '没有应用名或包名包含「$search」。';
  }

  @override
  String trafficHiddenCount(Object count) {
    return '本次共有 $count 个应用被「隐藏系统应用」过滤掉，关闭该开关即可看到。';
  }

  @override
  String get trafficNoRecordsBody =>
      '流量按天由原生侧汇总落库；启动隧道并产生流量后，这里会出现各应用的下行 / 上行字节数。';

  @override
  String trafficNoRecordsForWindow(Object window) {
    return '「$window」还没有流量记录。流量按天由原生侧汇总落库，换个时间窗口或启动隧道产生流量后再看。';
  }

  @override
  String trafficOptionUnavailable(Object label, Object reason) {
    return '「$label」不可用：$reason';
  }

  @override
  String get trafficNoSourceReason => '本仓没有对应的数据来源';

  @override
  String trafficCleared(Object count) {
    return '已清除 $count 条流量记录';
  }

  @override
  String trafficClearFailed(Object detail) {
    return '清除失败：$detail';
  }

  @override
  String trafficShareBarTooltip(Object sort, Object value) {
    return '占比条长度是这一行按「$sort」在当前窗口总量里的份额（当前 $value），与列表排序一致。';
  }

  @override
  String get trafficWhyDaemonTitle => '为什么系统设置将全部流量算给谛听？';

  @override
  String get trafficWhyDaemonBody =>
      '因 Android VPN 机制，系统将代理出站归属于守护进程。谛听自身不偷跑流量，点按查看统计口径。';

  @override
  String get trafficLiveRateTitle => '实时速率';

  @override
  String trafficNoLiveRate(Object window) {
    return '本模式不统计实时速率：极速模式的窄路由不经过引擎的流量计数器，本仓也没有它的累计表。上面的 $window 下行 / 上行与下方排行都是真实数字。';
  }

  @override
  String trafficLiveRateBody(Object window) {
    return '来自引擎的每秒速率（本次会话），与常驻通知里的读数同源；上面的 $window 下行 / 上行是 `app_traffic_daily` 的累计字节，两者口径不同，数字不必相等。';
  }

  @override
  String get trafficSearchPlaceholder => '搜索应用或包名...';

  @override
  String trafficWindowDown(Object window) {
    return '$window下行';
  }

  @override
  String trafficWindowUp(Object window) {
    return '$window上行';
  }

  @override
  String get obsRequestsTitle => '请求';

  @override
  String get obsSource => '来源';

  @override
  String get obsStatus => '状态';

  @override
  String get obsRefresh => '刷新';

  @override
  String get obsClearFilter => '清除筛选';

  @override
  String get obsLoadFailed => '无法读取请求记录';

  @override
  String get obsLoading => '正在读取请求记录';

  @override
  String get obsNoRecords => '还没有请求记录';

  @override
  String get obsNoMatchingRequests => '没有符合条件的请求';

  @override
  String get obsNoRecordsBody => '应用发出请求后会在这里留下记录；HTTPS 记录需要开启流量检查。';

  @override
  String get obsResetFilter => '重置筛选条件';

  @override
  String get obsRecordsHeader => '请求记录';

  @override
  String get obsRetry => '重试';

  @override
  String get obsBypassedDns => '直连，未经过 DNS 解析流程';

  @override
  String get obsBlockedDns => '被过滤规则拦截，未发出查询';

  @override
  String get obsRewrittenDns => '命中了覆写规则，返回改写后的结果';

  @override
  String get obsErrorDns => '解析过程出错，未取得应答';

  @override
  String get obsPassedDns => '按规则解析并正常返回';

  @override
  String get obsPassedHttps => '按规则转发成功';

  @override
  String get obsRewrittenHttps => '命中了覆写规则，返回改写后的请求';

  @override
  String get obsBlockedHttps => '被过滤规则拦截，未建立连接';

  @override
  String get obsBypassedHttps => '未解密直接转发（旁路）';

  @override
  String get obsErrorHttps => '处理过程出错';

  @override
  String get obsNoRuleHttps => '未命中规则（或未记录规则）';

  @override
  String get obsNone => '无';

  @override
  String get obsRequestDetailTitle => '请求详情';

  @override
  String get obsCachedChip => '缓存';

  @override
  String get obsBasicInfo => '基础信息';

  @override
  String get obsTime => '时间';

  @override
  String get obsProtocol => '协议';

  @override
  String get obsAppPackage => '应用包名';

  @override
  String get obsResolved => '解析结果';

  @override
  String get obsElapsed => '耗时';

  @override
  String get obsBlockingSubscription => '拦截订阅';

  @override
  String get obsRuleMatch => '规则命中';

  @override
  String get obsRule => '规则';

  @override
  String get obsHandling => '处理方式';

  @override
  String get obsError => '错误';

  @override
  String get obsAiAnalysis => 'AI 分析';

  @override
  String get obsRawRecord => '原始记录';

  @override
  String get obsRawRecordFooter => '引擎写入 message 字段的原文，未经改写。';

  @override
  String get obsFailedHint => '处理失败的请求可在「连接」页配合查看对应的活动连接。';

  @override
  String get obsRulesHint => '加入的黑白名单可在「规则」页查看和撤销。';

  @override
  String get obsCacheHit => '缓存命中';

  @override
  String obsCopied(Object text) {
    return '已复制 $text';
  }

  @override
  String get obsCopyAddress => '复制地址';

  @override
  String get obsCopyDomain => '复制域名';

  @override
  String get obsInBlocklist => '已在黑名单';

  @override
  String get obsAddToBlocklist => '加入黑名单';

  @override
  String get obsInAllowlist => '已在白名单';

  @override
  String get obsAddToAllowlist => '加入白名单';

  @override
  String get obsIpOnlyFooter => '该记录只有 IP 地址，域名规则无法匹配，因此不能加入黑白名单。';

  @override
  String get obsAnalyzeRequest => '分析这条请求';

  @override
  String get obsAnalyzeRequestBody => '用配置的模型研判归属、风险与处置建议';

  @override
  String obsCopiedHost(Object host) {
    return '已复制 $host';
  }

  @override
  String obsAddedToKind(Object domain, Object kind) {
    return '已将 $domain 加入$kind';
  }

  @override
  String obsAlreadyInKind(Object domain, Object kind) {
    return '$domain 已在$kind中';
  }

  @override
  String obsCurrentFilter(Object filter) {
    return '当前筛选：$filter。';
  }

  @override
  String obsFooterCount(
    Object count,
    Object failed,
    Object filter,
    Object more,
  ) {
    return '共 $count 条，其中 $failed 条处理失败$filter$more。点按一行查看规则命中与处理结果。';
  }

  @override
  String obsFooterFilter(Object filter) {
    return '（筛选：$filter）';
  }

  @override
  String get obsFooterMore => '；继续下滑加载更多';

  @override
  String get obsFooterAll => '；已加载全部';

  @override
  String get logsSubStatsTitle => '订阅拦截率';

  @override
  String get logsRefresh => '刷新';

  @override
  String get logsTimeRange => '时间范围';

  @override
  String get logsSubStatsFooter =>
      '拦截率为所选时间范围内，该订阅拦截请求数占全部已记录请求（DNS + HTTPS）的比例。';

  @override
  String get logsOverview => '概览';

  @override
  String get logsSubStatsLoadFailed => '无法读取拦截统计';

  @override
  String get logsLoadingStats => '正在加载统计数据';

  @override
  String get logsBlockingSubs => '屏蔽订阅';

  @override
  String get logsMissingSubColumn => '当前数据库缺少订阅标记列';

  @override
  String get logsMissingSubColumnBody =>
      '这张库是在加入「订阅拦截统计」之前创建的，日志行里没有记录 blockSubscriptionId。重新产生请求日志后即可统计，历史数据无法补算。';

  @override
  String get logsAllRecordedRequests => '全部已记录请求';

  @override
  String get logsAllRecordedFooter => 'DNS 与 HTTPS 日志合计，含通过、屏蔽和失败。';

  @override
  String get logsNoBlockingSubs => '暂无屏蔽订阅';

  @override
  String get logsNoBlockingSubsBody => '导入屏蔽订阅并产生 DNS 或 HTTPS 请求后，此处将显示其拦截率。';

  @override
  String get logsBlockingSubsFooter => '按拦截次数排序；「已删除」表示订阅已移除，但历史命中仍保留。';

  @override
  String get logsExpired => '已过期';

  @override
  String get logsRaceTitle => '竞速统计';

  @override
  String get logsRaceFooter => '只统计真实发出过 DoH 请求的竞速解析；本机缓存命中的查询不进这张表。';

  @override
  String get logsRaceLoadFailed => '无法读取竞速记录';

  @override
  String get logsLoadingRace => '正在读取竞速记录';

  @override
  String logsRaceSummary(Object count, Object range) {
    return '$range内共 $count 次竞速解析。';
  }

  @override
  String get logsRaceEmptyRange => '所选时间范围内还没有竞速记录。';

  @override
  String get logsRaceRequests => '竞速请求';

  @override
  String get logsSuccess => '成功';

  @override
  String get logsAverageElapsed => '平均耗时';

  @override
  String get logsStrategyOverview => '策略概览';

  @override
  String get logsStrategyFooter =>
      '缓存命中的请求不触发竞速，因此不进这张表；首选命中率 = 首选服务商即胜出且成功的比例。';

  @override
  String get logsWinnerProviders => '胜出服务商';

  @override
  String get logsNoWinners => '还没有胜出记录';

  @override
  String get logsNoWinnersBody => '竞速解析成功后，胜出的服务商会在这里按次数排序。';

  @override
  String get logsWinnerFooter => '按胜出次数排序；平均耗时是该服务商胜出时的耗时均值。';

  @override
  String logsAverageWinLatency(Object latency) {
    return '平均胜出耗时 $latency';
  }

  @override
  String get logsSmartPrimary => '智能选择首选';

  @override
  String get logsSmartPrimaryFooter =>
      '只有智能选择策略下才有意义；首选命中率统计「首选服务商就是胜出者」的比例，兜底救回的查询不计入。';

  @override
  String logsPrimaryHit(Object latency, Object percent) {
    return '首选命中 $percent · 平均首选耗时 $latency';
  }

  @override
  String get logsDashboardTitle => '日志仪表盘';

  @override
  String get logsModeTooltip => '日志模式';

  @override
  String get logsRequestsDashboard => '请求日志仪表盘';

  @override
  String get logsRequestsDashboardBody => '全部 DNS、HTTPS、缓存、竞速与规则拦截的实时概览';

  @override
  String get logsFocusedDashboard => '重点请求仪表盘';

  @override
  String get logsFocusedDashboardBody => 'DNS 与 HTTPS 拦截、错误、旁路记录及解析状态概览';

  @override
  String get logsServiceOverview => '服务状态与解析概览';

  @override
  String get logsPrivacyBody => '当前处于隐私模式，不记录请求明细。DNS 缓存、并发竞速与网络流量监控仍正常运行。';

  @override
  String get logsCacheTableTitle => 'DNS 缓存表';

  @override
  String logsCacheLoadFailed(Object detail) {
    return '无法读取缓存表：$detail';
  }

  @override
  String get logsLoadingCache => '正在读取缓存表';

  @override
  String get logsCacheEmpty => '缓存表还没有条目';

  @override
  String get logsCacheNoMatch => '没有匹配的缓存';

  @override
  String get logsCacheEmptyBody =>
      '引擎解析成功后会把应答写进 dns_cache；全新安装或隧道刚启动时这张表可能还是空的。';

  @override
  String logsCurrentSearch(Object query) {
    return '当前搜索：$query';
  }

  @override
  String get logsLiveCache => '有效缓存';

  @override
  String get logsNeverHit => '尚未命中';

  @override
  String logsCacheFooter(Object count) {
    return '共 $count 条，按命中次数与过期时间排序。剩余 TTL 少于 30 秒的条目标橙色。点按一行查看详情，可复制域名、加入黑白名单或用 AI 分析。';
  }

  @override
  String get logsBootstrapTitle => 'Bootstrap 统计';

  @override
  String get logsBootstrapFooter => '成功率为成功次数 ÷ 尝试次数；平均耗时按各节点的尝试次数加权。';

  @override
  String get logsBootstrapLoadFailed => '无法读取 Bootstrap 记录';

  @override
  String get logsLoadingBootstrap => '正在读取 Bootstrap 记录';

  @override
  String logsBootstrapSummary(Object count, Object range) {
    return '$range内共 $count 次 Bootstrap 探测。';
  }

  @override
  String get logsBootstrapEmptyRange => '所选时间范围内还没有 Bootstrap 探测记录。';

  @override
  String get logsAttempts => '尝试次数';

  @override
  String get logsSuccessRate => '成功率';

  @override
  String get logsNodes => '节点';

  @override
  String get logsNoProbes => '还没有探测记录';

  @override
  String get logsNoProbesBody => '开启「启用 Bootstrap IP」并产生解析后，各节点的尝试与成功率会出现在这里。';

  @override
  String get logsNodesFooter => '按尝试次数排序；显示最近窗口内的聚合值。';

  @override
  String get logsCacheDetailTitle => '缓存详情';

  @override
  String get logsCacheExpiringBody => '缓存即将过期，过期后下一次查询会重新向上游解析';

  @override
  String get logsCacheValidBody => '缓存有效，命中时直接返回应答，不再请求上游';

  @override
  String get logsExpiring => '即将过期';

  @override
  String get logsValid => '有效';

  @override
  String logsHitTimes(Object count) {
    return '命中 $count 次';
  }

  @override
  String get logsCacheInfo => '缓存信息';

  @override
  String get logsRecordType => '记录类型';

  @override
  String get logsRemainingTtl => '剩余 TTL';

  @override
  String get logsOriginalTtl => '原始 TTL';

  @override
  String get logsExpiry => '过期时间';

  @override
  String get logsHitCount => '命中次数';

  @override
  String get logsLastHit => '最后命中';

  @override
  String get logsResponseSize => '应答大小';

  @override
  String get logsAnalyzeDomain => '分析这个域名';

  @override
  String get logsCacheDetailFooter =>
      '缓存表每 10 秒从引擎内存同步一次，这里是打开时的快照。加入的黑白名单可在「规则」页查看和撤销。';

  @override
  String get logsAiInsight => 'AI 研判';

  @override
  String get logsNotAnalysed => '未分析';

  @override
  String get logsHasReport => '已有结论';

  @override
  String get logsAiInsightBody =>
      '把最近的 DNS 与 HTTPS 记录交给配置的模型，汇总异常请求、防护效果与优化建议。';

  @override
  String get logsAnalyseTraffic => '用 AI 研判最近流量';

  @override
  String get logsViewFullReport => '查看完整报告';

  @override
  String logsModelName(Object model) {
    return '模型 $model';
  }

  @override
  String logsSuccessWith(Object percent) {
    return '成功 $percent';
  }

  @override
  String logsAverageWith(Object latency) {
    return '平均 $latency';
  }

  @override
  String logsPrimaryHitOnly(Object percent) {
    return '首选命中 $percent';
  }

  @override
  String logsFallbackUses(Object count) {
    return '兜底 $count 次';
  }

  @override
  String logsBootstrapRow(
    Object failures,
    Object ip,
    Object latency,
    Object percent,
  ) {
    return '$ip · 成功 $percent · 平均 $latency$failures';
  }

  @override
  String logsBootstrapFailures(Object count) {
    return ' · 失败 $count 次';
  }

  @override
  String logsEntryCount(Object count) {
    return '$count 条';
  }

  @override
  String logsCacheRow(Object count, Object size, Object ttl) {
    return '$ttl · 命中 $count 次 · $size B';
  }

  @override
  String logsLastHitAt(Object time) {
    return '最后命中 $time';
  }

  @override
  String logsCacheFooterCount(Object count) {
    return '共 $count 条，按命中次数与过期时间排序。剩余 TTL 少于 30 秒的条目标橙色。点按一行查看详情，可复制域名、加入黑白名单或用 AI 分析。';
  }

  @override
  String logsSubStatsRow(Object count, Object percent, Object status) {
    return '$status | 拦截 $count 次 | $percent';
  }

  @override
  String get aboutTitle => '关于';

  @override
  String get aboutMore => '更多';

  @override
  String get aboutProject => '项目';

  @override
  String get aboutJoinQq => '加入 QQ 群';

  @override
  String aboutQqGroup(Object number) {
    return '群号 $number';
  }

  @override
  String get aboutSponsor => '赞助';

  @override
  String get aboutCredits => '开源致谢';

  @override
  String get aboutCreditsUi => '界面组件与交互实现复用自该项目';

  @override
  String get aboutCreditsCore => 'Go 隧道内核最初魔改自该项目';

  @override
  String get aboutCreditsBody =>
      '上述两个项目均以 GPL-3.0 协议开源，相关代码与设计的版权归各自作者所有。谛听的界面层大量借鉴了 FlClash 的实现思路，隧道内核也源自 blockads-android 的早期改造；在此向它们的作者与所有贡献者致以诚挚谢意。';

  @override
  String get aboutSettings => '设置';

  @override
  String get aboutStartupCheck => '关闭启动时检查更新';

  @override
  String get aboutStartupCheckOn => '应用启动时不自动检查，可随时手动检查';

  @override
  String get aboutStartupCheckOff => '应用启动时自动检查新版本';

  @override
  String get aboutDisclaimerEntry => '使用须知与免责声明';

  @override
  String get aboutDisclaimerEntryBody => '软件说明、运行机制与免责条款全文';

  @override
  String get aboutOtherContributors => '其他贡献者';

  @override
  String get aboutSponsorList => '赞助者名单';

  @override
  String get aboutSponsorListBody => '鸣谢支持谛听项目的赞助者';

  @override
  String get aboutBuilderList => '共建者名单';

  @override
  String get aboutBuilderListBody => '感谢为谛听贡献代码与建议的共建者';

  @override
  String get aboutInstallerFailed => '无法调起系统安装器';

  @override
  String get aboutAppName => '谛听';

  @override
  String get aboutTagline =>
      '基于 Android VpnService 的本地优先 DNS 加速与流量过滤工具，简单易用，开源无广告。';

  @override
  String get aboutChecking => '检查中…';

  @override
  String get aboutCheckUpdate => '检查更新';

  @override
  String get aboutDownloading => '下载中…';

  @override
  String get aboutInstall => '安装';

  @override
  String get aboutDownload => '下载';

  @override
  String get aboutCheckingRelease => '正在检查 GitHub Release';

  @override
  String aboutUpToDate(Object version) {
    return '当前已是最新版本$version';
  }

  @override
  String aboutVersionSuffix(Object version) {
    return '（$version）';
  }

  @override
  String aboutFoundVersion(Object version) {
    return '发现 $version版本';
  }

  @override
  String aboutCurrentSuffix(Object version) {
    return '（当前 $version）';
  }

  @override
  String get aboutNew => '新';

  @override
  String get aboutNewVersion => '新版本';

  @override
  String aboutUpdatePackage(Object version) {
    return '$version 更新包';
  }

  @override
  String aboutLinkCopyFallback(Object url) {
    return '未能打开浏览器，链接已复制：$url';
  }

  @override
  String get devStressLogs => '日志压测';

  @override
  String devStressLogsBody(Object count) {
    return '向当前模式的日志库真实写入 $count 条 DNS 日志';
  }

  @override
  String get devErrorReport => '错误上报自检';

  @override
  String get devErrorReportBody => '通过 FlutterError 上报一条测试异常，验证错误链路';

  @override
  String get devClearAll => '清空全部数据';

  @override
  String get devClearAllBody => '删除配置、规则与日志，恢复出厂状态';

  @override
  String get devVacuum => '压缩数据库';

  @override
  String get devVacuumBody => '对三个本地库执行 VACUUM，回收已删除记录占用的空间';

  @override
  String get devCancel => '取消';

  @override
  String get devRun => '执行';

  @override
  String devConfirmBody(Object action) {
    return '$action\n\n该操作会真正改写本机数据，无法撤销。';
  }

  @override
  String devActionFailed(Object action, Object error) {
    return '$action失败：$error';
  }

  @override
  String get devStressNoDb => '日志压测失败：无法打开日志数据库';

  @override
  String devStressDone(Object count, Object file) {
    return '日志压测完成：写入 $count 条到 $file';
  }

  @override
  String get devTestException => '开发者选项触发的测试异常';

  @override
  String get devErrorReported => '已上报一条 FlutterError：开发者选项触发的测试异常';

  @override
  String get devVacuumNoDb => '压缩数据库失败：本机还没有数据库文件';

  @override
  String devVacuumDone(Object files, Object kb) {
    return '已压缩 $files，回收 $kb KB';
  }

  @override
  String get devRestartNeeded => '需要重启';

  @override
  String get devLater => '稍后';

  @override
  String get devQuitNow => '立即退出';

  @override
  String get devClearAllDone => '全部数据已清空，需要重新启动应用才能从出厂状态进入。';

  @override
  String get devOptions => '开发者选项';

  @override
  String get devDiagnostics => '诊断与观测';

  @override
  String get devIpQuality => 'IP 质量';

  @override
  String get devIpQualityBody => '实测出口地址与三个公开情报源的类型判断';

  @override
  String get devRequestLogs => '请求日志';

  @override
  String get devRequestLogsBody => '合并 http_request_log 与 dns_log 的实时请求记录';

  @override
  String get devLogRetention => '日志保留';

  @override
  String get devLogRetentionBody => '日志容量上限与 DNS 请求日志的记录范围';

  @override
  String get devTroubleshoot => '故障排查';

  @override
  String get devTroubleshootBody => '导出崩溃日志，手动抓取并导出运行日志';

  @override
  String get devDataCleanup => '数据清理';

  @override
  String get devUnlocked => '实验动作已解锁';

  @override
  String get devLocked => '关闭时下面的动作不可用';

  @override
  String get devWarning =>
      '这里的动作会真的改写本机数据（日志库、prefs、数据库文件），其中「清空全部数据」不可撤销，不要在生产环境打开。';

  @override
  String get devRunning => '执行中…';

  @override
  String get sponsorGithub => '在 GitHub 查看赞助方式';

  @override
  String get sponsorReadme => '查看 README 中的赞助说明';

  @override
  String get sponsorReadmeCopied => '未能打开浏览器，README 地址已复制';

  @override
  String get sponsorThanks => '致谢名单';

  @override
  String get sponsorThanksBody => '感谢每一位支持项目的朋友';

  @override
  String get sponsorBuildersBody => '感谢提出建议与帮助测试的伙伴';

  @override
  String get sponsorUsage => '你的每一笔支持都会用于';

  @override
  String get sponsorUsageNewFeatures => '持续开发新功能';

  @override
  String get sponsorUsageBugs => '修复 Bug';

  @override
  String get sponsorUsageTokens => '购买词元';

  @override
  String get sponsorFreeWays => '即使不捐赠，也欢迎';

  @override
  String get sponsorFreeStar => '点一个 Star⭐';

  @override
  String get sponsorFreeIssue => '提交 Issue';

  @override
  String get sponsorFreePr => '提交 PR';

  @override
  String get sponsorFreeShare => '分享给更多人';

  @override
  String get sponsorFooter => '感谢每一位支持项目的朋友！';

  @override
  String get sponsorBuyDrink => '请作者喝杯蜜雪 🧋';

  @override
  String get sponsorNote => '如果这个项目帮助到了你，欢迎请作者喝杯蜜雪。付款时请备注昵称，以便同步加入赞助者名单。';

  @override
  String get sponsorAlipay => '支付宝';

  @override
  String get sponsorWechat => '微信支付';

  @override
  String get sponsorNickname => '备注昵称';

  @override
  String get sponsorScan => '扫码赞助';

  @override
  String sponsorQrCode(Object label) {
    return '$label 收款码';
  }

  @override
  String get sponsorClose => '关闭';

  @override
  String get sponsorNoteShort => '付款时请备注昵称，以便同步加入赞助者名单。';

  @override
  String aboutQqCopied(Object number) {
    return '未检测到 QQ，群号已复制：$number';
  }

  @override
  String get disclaimerTitle => '免责声明';

  @override
  String get disclaimerTerms => '条款全文';

  @override
  String get disclaimerSource => '正式条款以仓库 NOTICE.md 与随包 LICENSE 为准。';

  @override
  String get ipQualityRedetect => '重新检测';

  @override
  String get ipQualityEgress => '当前出口地址';

  @override
  String get ipQualitySources => '来源';

  @override
  String get ipQualitySourcesFooter =>
      '各来源对「住宅 / 机房」的判断经常互相矛盾：命中数越多越可信，但单一来源的「风险」标签不足以作为结论。';

  @override
  String get ipQualityQuerying => '正在查询出口 IP 与 3 个情报源…';

  @override
  String get ipQualityChecking => '检测中…';

  @override
  String get ipQualityDetecting => '正在检测';

  @override
  String get ipQualityFailed => '检测失败';

  @override
  String get ipQualityNotYet => '尚未检测';

  @override
  String get ipQualityDetectingBody => '正在获取出口 IP 并查询情报源，请稍候';

  @override
  String get ipQualityStartBody => '点下方按钮开始检测当前出口 IP 的质量';

  @override
  String get ipQualityStart => '开始检测';

  @override
  String ipQualityJudgedAs(Object type) {
    return '判定为$type';
  }

  @override
  String get ipQualityNotUsed => '未采用';

  @override
  String get ipQualityUsed => '已采用';

  @override
  String devFooterWarning(Object count) {
    return '这些动作直接作用于本机的数据库、prefs 与 native 通道：日志压测会真的写入 $count 条日志，压缩数据库执行的是 SQLite VACUUM，清空全部数据会删除所有本地数据并要求重启。';
  }

  @override
  String get devDataCleanupBody => '按类别删除日志、权重、规则与缓存';

  @override
  String get devConfigSection => '配置与资源';

  @override
  String get devCustomResources => '自定义资源';

  @override
  String get devCustomResourcesBody => 'User-Agent、按需连接等配置资源入口';

  @override
  String get devUserAgentBody => '订阅下载与测速请求携带的 UA';

  @override
  String get devOnDemand => '按需连接';

  @override
  String get devOnDemandBody => '按 SSID 决定是否启动 VPN';

  @override
  String get devWebdav => 'WebDAV 云同步';

  @override
  String get devWebdavBody => '把备份真实上传到自建的 WebDAV 服务';

  @override
  String get devUiSection => '界面与外观保留项';

  @override
  String get devFontFamilyBody => '选择界面字体族，独立页';

  @override
  String get devFontSizeBody => '全局文字缩放；在外观设置「界面显示」组内联滑杆';

  @override
  String get devTabAnimation => 'Tab 动画';

  @override
  String get devTabAnimationBody => '切换底部标签时的入场动画；在外观设置「背景与动效」组内联选项';

  @override
  String get devExperimental => '实验动作';

  @override
  String get devLegacyFooter =>
      '以上「诊断与观测」「配置与资源」「界面与外观保留项」里的页面都不属于旧版 1.4.3 的界面，保留供调试与组件验收；旧版对应的功能仍按旧版菜单进入，不经过本页。';

  @override
  String get unknownRouteTitle => '页面不存在';

  @override
  String get unknownRouteBody => '找不到这个页面';

  @override
  String get unknownRouteBack => '返回';

  @override
  String get disclaimerReadFirst => '使用前请阅读';

  @override
  String get disclaimerIntro =>
      '谛听是一款开源的本地域名解析与流量观测工具。软件本身不提供、不代理、也不转发任何网络接入服务，全部数据都在本机处理。';

  @override
  String get disclaimerLawful =>
      '请在遵守所在地法律法规的前提下使用本软件。将本软件用于任何未经授权的网络环境，后果由使用者自行承担。';

  @override
  String get disclaimerFirstRun => '首次启动时确认的文本';

  @override
  String get disclaimerImmutable => '不可修改';

  @override
  String get devFontFamily => '字体';

  @override
  String get devFontSize => '字号';

  @override
  String get devWarningTitle => '开发者模式';

  @override
  String get devFooterLegacy =>
      '以上「诊断与观测」「配置与资源」「界面与外观保留项」里的页面都不属于旧版 1.4.3 的界面，保留供调试与组件验收；旧版对应的功能仍按旧版菜单进入，不经过本页。';

  @override
  String get ipTypeResidential => '住宅';

  @override
  String get ipTypeMobile => '移动';

  @override
  String get ipTypeBusiness => '商业';

  @override
  String get ipTypeHosting => '机房';

  @override
  String get ipLevelGood => '优秀';

  @override
  String get ipLevelNormal => '一般';

  @override
  String get ipLevelRisky => '风险';

  @override
  String get ipStatusOk => '命中';

  @override
  String get ipStatusNoType => '无类型';

  @override
  String get ipStatusTimeout => '超时';

  @override
  String get ipStatusRateLimited => '限流';

  @override
  String get ipStatusMismatch => 'IP 不一致';

  @override
  String get modeSelectTitle => '选择工作模式';

  @override
  String get modeContinue => '继续';

  @override
  String get modeSwitchNote => '随时可以在设置里重新选择；切换模式会先停止当前模式的服务，两个模式不会同时运行。';

  @override
  String get modeSharedNote =>
      '三种模式共用一套规则与缓存，区别在接管方式：普通模式走全隧道，服务器模式只做局域网 DNS，极速模式是纯 Kotlin 窄路由。';

  @override
  String get modeNormalFeature1 => '全隧道接管';

  @override
  String get modeNormalFeature1Body => 'Go 栈接管全部流量，可按应用分流';

  @override
  String get modeNormalFeature2 => '全功能规则';

  @override
  String get modeNormalFeature2Body => '黑白名单、覆写、HTTPS 检查全部可用';

  @override
  String get modeNormalFeature3 => '可选 HTTPS 检查';

  @override
  String get modeNormalFeature3Body => '需要安装并信任本地 CA 证书';

  @override
  String get modeNormalFeature4 => '应用流量统计';

  @override
  String get modeNormalFeature4Body => '按应用记录上下行与查询数';

  @override
  String get modeServerFeature1 => '局域网 DNS 服务';

  @override
  String get modeServerFeature1Body => '监听 0.0.0.0，供同一网段设备使用';

  @override
  String get modeServerFeature2 => '不占 VPN 槽位';

  @override
  String get modeServerFeature2Body => '本机不建立隧道，可与其它 VPN 共存';

  @override
  String get modeServerFeature3 => '共享规则与缓存';

  @override
  String get modeServerFeature3Body => '与普通模式共用同一套规则库';

  @override
  String get modeServerFeature4 => '低功耗';

  @override
  String get modeServerFeature4Body => '只处理 DNS 查询，无流量转发';

  @override
  String get modeExpressFeature1 => '纯 Kotlin 实现';

  @override
  String get modeExpressFeature1Body => '窄路由，启动与切换都更快';

  @override
  String get modeExpressFeature2 => '四种上游调度';

  @override
  String get modeExpressFeature2Body => '单服务商 / 智能 / 竞速 / 主备';

  @override
  String get modeExpressFeature3 => '64 分片 LRU 缓存';

  @override
  String get modeExpressFeature3Body => '命中率高、内存占用可控';

  @override
  String get modeExpressFeature4 => '兼容更旧系统';

  @override
  String get modeExpressFeature4Body => 'Android 7+（需 64 位）';

  @override
  String get onboardingTitle => '引导';

  @override
  String get onboardingSkip => '跳过引导';

  @override
  String get onboardingPrev => '上一步';

  @override
  String get onboardingStart => '开始使用';

  @override
  String get onboardingNext => '下一步';

  @override
  String onboardingChosen(Object mode) {
    return '你选择了$mode';
  }

  @override
  String get onboardingChangeable => '之后还能改';

  @override
  String get onboardingChangeableBody => '设置 → 重新选择工作模式，随时可以切换。切换会先停止当前模式的服务。';

  @override
  String get onboardingSharedRules => '规则与缓存共用';

  @override
  String get onboardingSharedRulesBody => '三种模式共享同一套黑白名单与 DNS 缓存，不必为每个模式重配一遍。';

  @override
  String get onboardingExclusive => '模式互斥';

  @override
  String get onboardingExclusiveBody => '同一时刻只有一个模式在运行；离开时会先停掉上一个模式。';

  @override
  String get permVpn => 'VPN 连接';

  @override
  String get permNotification => '通知';

  @override
  String get permAppList => '应用列表';

  @override
  String get permBattery => '忽略电池优化';

  @override
  String get permRequired => '必需';

  @override
  String get permOptional => '可选';

  @override
  String get permVpnNormalBody => '建立本地隧道接管流量；拒绝则无法启动';

  @override
  String get permNotificationBody => '前台服务常驻通知；拒绝则服务可能被系统回收';

  @override
  String get permAppListBody => '按应用分流与统计；拒绝则只能按域名规则';

  @override
  String get permBatteryBody => '避免后台被杀；拒绝则长时间待机可能断开';

  @override
  String get permBatteryServerBody => '避免后台被杀；拒绝则局域网内会间歇不可用';

  @override
  String get permVpnExpressBody => '建立窄路由隧道；拒绝则无法启动';

  @override
  String get permNeeded => '需要这些权限';

  @override
  String get permAllLocal => '全部权限只在本机使用，不会上传任何数据。';

  @override
  String permGrantedCount(Object granted, Object total) {
    return '已授予 $granted / $total 项；全部权限只在本机使用，不会上传任何数据。';
  }

  @override
  String get onboardingTipNormal1 => '点首页的大圆钮启动服务，第一次会弹出系统 VPN 授权。';

  @override
  String get onboardingTipNormal2 => '黑名单 / 白名单在「功能中心 → 规则与订阅」里维护。';

  @override
  String get onboardingTipNormal3 => '首页句子和透明度都能在设置里改。';

  @override
  String get onboardingTipServer1 => '启动后把同网段设备的 DNS 指向「局域网接入」里显示的地址。';

  @override
  String get onboardingTipServer2 => '端口可在「服务器模式」页改，默认 5353。';

  @override
  String get onboardingTipServer3 => '本模式不建立 VPN，可与其它 VPN 同时运行。';

  @override
  String get onboardingTipExpress1 => '极速模式启动更快，但功能是普通模式的子集。';

  @override
  String get onboardingTipExpress2 => '多路竞速至少要选 2 家服务商。';

  @override
  String get onboardingTipExpress3 => '需要 HTTPS 检查或应用管控时请切回普通模式。';

  @override
  String get onboardingReady => '可以开始了';

  @override
  String get onboardingReadyBody => '下面是三条最常用的上手要点。';

  @override
  String onboardingTipIndex(Object index) {
    return '第 $index 条';
  }

  @override
  String permStillDenied(Object name) {
    return '$name 仍未授予，请在系统设置里允许后返回本页';
  }

  @override
  String get permGranted => '已授予';

  @override
  String get permDenied => '未授予';

  @override
  String get permUnknown => '状态未知';

  @override
  String get permGrant => '去授予';

  @override
  String get toolSpeedTest => '测速';

  @override
  String get toolPing => 'Ping 测试';

  @override
  String get toolDnsLookup => 'DNS 解析';

  @override
  String get toolTraceroute => '路由追踪';

  @override
  String get toolDiagnostics => '网络诊断';

  @override
  String get toolRefreshInfo => '刷新网络信息';

  @override
  String get toolActiveInterface => '活动接口';

  @override
  String get toolLocalAddress => '本机地址';

  @override
  String get toolDnsServers => 'DNS 服务器';

  @override
  String get toolCountUnit => '个';

  @override
  String toolPrivateDnsProbe(Object dns) {
    return '探测走物理网络（本应用流量不经过隧道）；系统私人 DNS：$dns';
  }

  @override
  String get toolPhysicalProbe => '探测走物理网络：本应用自身流量被排除在隧道外，下面四个工具测的都是物理链路的真实时延。';

  @override
  String get toolInputHostOrIp => '输入 IP 或域名';

  @override
  String get toolPingCount4 => '4 次';

  @override
  String get toolPingCount10 => '10 次';

  @override
  String get toolPingOptions => '探测选项';

  @override
  String get toolViaTunnel => '通过 Go 隧道解析';

  @override
  String get toolViaTunnelPingBody => '域名经运行中的 Go 隧道解析（应用覆写与过滤规则），探测仍走物理网络';

  @override
  String get toolStartPing => '开始 Ping';

  @override
  String get toolPinging => '正在探测…';

  @override
  String get toolTcpFallback =>
      '系统 ICMP 受限，已用 TCP 回退测量。此时的时延是连接建立耗时，不能与 ICMP 往返时延直接比较。';

  @override
  String get toolPingFailed => '探测失败：未收到任何回复';

  @override
  String get toolTarget => '目标';

  @override
  String get toolResolvedAddress => '解析地址';

  @override
  String get toolAddressFamily => '地址族';

  @override
  String get toolSentReceived => '发送 / 接收';

  @override
  String get toolPacketLoss => '丢包率';

  @override
  String get toolMinAvgMax => '最小 / 平均 / 最大';

  @override
  String get toolJitter => '抖动';

  @override
  String get toolJitterFooter => '抖动按各包时延与均值的平均绝对偏差计算。';

  @override
  String toolPacketN(Object n) {
    return '第 $n 个包';
  }

  @override
  String get toolTimeout => '超时';

  @override
  String toolPingSummary(Object failed, Object sent) {
    return '本次共发送 $sent 个探测包，失败 $failed 个。';
  }

  @override
  String get toolPingFooter =>
      'Ping 由原生侧执行：优先调用系统 ping 二进制，不可用时回退到地址可达性与 TCP 端口握手计时，并会明确标注。';

  @override
  String get toolDnsSystem => '跟随系统';

  @override
  String get toolDnsCustom => '自定义';

  @override
  String get toolCustomDnsError => '请输入自定义 DNS 服务器 IP';

  @override
  String get toolInputDomain => '输入要解析的域名';

  @override
  String get toolCustomDnsHint => '自定义 DNS 服务器 IP（如 1.1.1.1）';

  @override
  String get toolQueryOptions => '查询选项';

  @override
  String get toolViaTunnelDnsBody => '开启后由隧道引擎解析，会套用拦截规则与缓存；关闭时直接问系统解析器';

  @override
  String get toolStartQuery => '开始查询';

  @override
  String get toolQuerying => '查询中…';

  @override
  String get toolQueryDomain => '查询域名';

  @override
  String get toolRecordType => '记录类型';

  @override
  String get toolAnswerSource => '答案来源';

  @override
  String get toolElapsed => '耗时';

  @override
  String get toolAnswerCount => '答案条数';

  @override
  String get toolDnsBlockedBody => '该域名被隧道规则拦截，因此没有真实上游应答。';

  @override
  String get toolDnsNoAnswers => '没有返回任何应答记录。若来源是「被规则拦截」，说明该域名在本机规则里被拦掉了。';

  @override
  String get toolDnsFooter =>
      '「走隧道查询」问的是本软件的解析链路（含规则与缓存），此时服务器由隧道决定；关闭后可选择跟随系统或指定一台 DNS 服务器，两者结果可能不同。';

  @override
  String get toolTunnelEngine => '隧道引擎';

  @override
  String get toolSpeedChecking => '正在检查测速通道…';

  @override
  String get toolSpeedUnsupported =>
      '当前设备不支持测速：本机没有提供 DNS 查询耗时测量的原生通道，页面不会显示任何模拟耗时。';

  @override
  String get toolSpeedDomainHint => '用于测速的域名';

  @override
  String get toolSpeedProviders => '测速服务商';

  @override
  String toolNoProviders(Object protocol) {
    return '暂无 $protocol DNS 服务商';
  }

  @override
  String get toolNoProvidersBody => '在「服务商管理」里添加后即可参与测速';

  @override
  String get toolSpeedSelectionNote =>
      '可选择 1 个或多个服务商；这里的选择只用于 DNS 查询测速，不影响竞速模式。';

  @override
  String get toolTestQueryTime => '测试查询耗时';

  @override
  String get toolSpeedRunning => '测速中…';

  @override
  String get toolSpeedEmpty =>
      '尚未测速。选好服务商后点上面的按钮，本应用会直接向每个服务商发送 3 次真实 DNS 查询并记录往返耗时。';

  @override
  String get toolSpeedResults => '查询耗时结果';

  @override
  String toolSpeedResultsFooter(Object domain) {
    return '测速结果按成功优先、平均耗时从低到高排序；结果只反映本次查询时的网络状态。域名当前为「$domain」。';
  }

  @override
  String get toolSpeedFooter =>
      '测速由原生侧执行：向每个服务商分别发送真实的 DoH / DoT / 明文 DNS 查询，只有拿到成功应答的样本才计入耗时。';

  @override
  String get toolFastest => '最快';

  @override
  String toolSampleCount(Object count, Object rate) {
    return '$rate · 样本 $count';
  }

  @override
  String toolAllFailed(Object count) {
    return '全部失败（$count 次）';
  }

  @override
  String get toolTraceOptions => '追踪选项';

  @override
  String get toolStartTrace => '开始追踪';

  @override
  String get toolTracing => '追踪中…';

  @override
  String get toolTraceFailed => '追踪失败：未收到任何回应';

  @override
  String get toolTraceCancelled => '追踪已取消。';

  @override
  String get toolHopCount => '跳数';

  @override
  String toolHopCountValue(Object count, Object max) {
    return '$count / 最多 $max';
  }

  @override
  String get toolNoResponse => '无响应';

  @override
  String get toolTraceFooter =>
      '星号表示该跳在超时时间内没有回包——不代表链路断了，很多路由器不响应探测包。绿色一行表示已到达目标。';

  @override
  String get toolTraceHops15 => '15 跳';

  @override
  String get toolTraceHops30 => '30 跳';

  @override
  String get uaDeleteTitle => '删除 User-Agent';

  @override
  String get uaDeleteBody => '确定删除这一条吗？只删候选，不影响当前已选中的 UA。';

  @override
  String get uaAdd => '添加 User-Agent';

  @override
  String get uaEdit => '编辑 User-Agent';

  @override
  String get uaNote => 'UA 会随订阅下载、规则集拉取与订阅测速请求一起发送；部分服务端按 UA 拒绝请求，改这里可以绕过。';

  @override
  String get uaCurrent => '当前选择';

  @override
  String get uaNoOverride => '不覆写';

  @override
  String get uaNoOverrideBody => '沿用订阅或内核自带的 UA';

  @override
  String get uaBuiltin => '内置';

  @override
  String get uaCustom => '自定义';

  @override
  String get uaBuiltinNote => '内置 UA 不可删除：删掉之后内核回落到默认值，用户会误以为「设置没生效」。';

  @override
  String get uaHint => '如：clash-verge/v2.0.0';

  @override
  String get uaEmptyError => 'UA 不能为空';

  @override
  String get uaDuplicateError => '该 UA 已存在';

  @override
  String get ssidInvalid => 'SSID 不能为空或已存在';

  @override
  String get ssidAdd => '添加 SSID';

  @override
  String get ssidEdit => '编辑 SSID';

  @override
  String get ssidSave => '保存 SSID';

  @override
  String get ssidHint => '区分大小写，与系统 Wi-Fi 列表里的名字完全一致';

  @override
  String get ssidExample => '如：Home-5G';

  @override
  String get ssidEmptyError => 'SSID 不能为空';

  @override
  String get ssidConnection => '连接方式';

  @override
  String get ssidCellular => '蜂窝网络';

  @override
  String get ssidCellularBody => '在该网络下也启动 VPN';

  @override
  String get ssidWifiBody => '连上该 SSID 时启动 VPN';

  @override
  String get ssidBothOff => '两种都关掉，等于把这条 SSID 从白名单里排除（VPN 不会启动）。';

  @override
  String get ssidDelay => '延迟';

  @override
  String get ssidStartDelay => '启动延迟';

  @override
  String get ssidStartDelayBody => '等待网络就绪后再启动 VPN';

  @override
  String get ssidImmediate => '立即连接';

  @override
  String get odTitle => '按需连接';

  @override
  String get odApplyNow => '立即应用';

  @override
  String get odEnable => '启用按需连接';

  @override
  String get odEnableBody => '连上白名单里的 SSID 时自动启动 VPN';

  @override
  String get odDisableBody => '关闭时 VPN 始终在线，不随网络切换';

  @override
  String get odNote =>
      '开启后，只有连上白名单里的 SSID 时才会自动启动 VPN；其余网络保持断开，省电也更可控。自动判定只在网络变化时启停 VPN，不会覆盖手动开关的结果；点右上角「立即应用」可立即按当前网络重新判定。';

  @override
  String get odAllowlist => 'SSID 白名单';

  @override
  String get odNoSsid => '还没有 SSID';

  @override
  String get odNoSsidBody => '没有白名单时按需连接不会触发';

  @override
  String get odDelayNote => '延迟用于等 Wi-Fi 完成认证与 DHCP；过早启动 VPN 会让首个请求落到尚未就绪的网络上。';

  @override
  String get odCellular => '蜂窝';

  @override
  String get odKindsNone => '不启用';

  @override
  String odDelayValue(Object ms) {
    return '延迟 $ms ms';
  }

  @override
  String get odStateDisabled => '按需连接已关闭';

  @override
  String get odStateUnknown => '无法读取当前 Wi-Fi，白名单不会触发';

  @override
  String get odStateNoWifi => '当前不在 Wi-Fi 上，VPN 保持断开';

  @override
  String odStateMatched(Object ssid) {
    return '已匹配 $ssid，VPN 会自动启动';
  }

  @override
  String get odStateUnmatched => '当前 Wi-Fi 不在白名单，VPN 保持断开';

  @override
  String get odDisabledHint => '按需连接已关闭，VPN 不再随网络切换';

  @override
  String get odPillDisabled => '未启用';

  @override
  String get odPillUnknown => '无法判断';

  @override
  String get odPillNoWifi => '未连接 Wi-Fi';

  @override
  String get odPillWillStart => '会启动 VPN';

  @override
  String get odPillWillNotStart => '不会启动 VPN';

  @override
  String get odDecision => '当前判定';

  @override
  String get odDecisionFooter => '判定按当前网络实时计算：切换 Wi-Fi 后重新读取即可看到结果。SSID 区分大小写。';

  @override
  String get odCurrentNetwork => '当前网络';

  @override
  String get odWifiName => 'Wi-Fi 名称';

  @override
  String get odReadAgain => '重新读取';

  @override
  String get odPermission => '读取权限';

  @override
  String get odPermissionBody => 'Android 10 起读取 Wi-Fi 名称需要位置权限';

  @override
  String get odNotGranted => '未授权';

  @override
  String get odWifiUnreadable => '本机当前无法读取 Wi-Fi 名称：请在系统设置里授予本应用位置权限后重新读取。';

  @override
  String get odSsidPrivacy => 'SSID 只用于匹配白名单，不会被上传；手动添加的 SSID 在无法读取时仍然可用。';

  @override
  String get odBatteryJoined => '已加入';

  @override
  String get odBatteryNotJoined => '未加入';

  @override
  String get odBatteryUnavailable => '不可用';

  @override
  String get odPrerequisites => '前置条件';

  @override
  String get odIgnoreBattery => '忽略电池优化';

  @override
  String get odBatteryOk => '系统不会在后台冻结 VPN 进程';

  @override
  String get odBatteryAsk => '未加入时后台 VPN 可能被系统冻结，点击申请';

  @override
  String get odBatteryNoChannel => '当前构建没有提供电池优化通道';

  @override
  String get odBatteryFooter => '点击「未加入」会打开系统授权页；返回后会重新读取真实状态，取消则保持未加入。';

  @override
  String get odBatteryJoinedHint => '已加入电池优化白名单';

  @override
  String get odBatteryStillOff => '仍未加入，VPN 可能被系统冻结';

  @override
  String get odBatteryUnsupportedHint => '当前构建不支持该授权';

  @override
  String get odCapNoPermission => '无法读取：需要位置权限';

  @override
  String odCapCurrent(Object name) {
    return '当前连接：$name';
  }

  @override
  String get customResourcesTitle => '自定义资源';

  @override
  String get customResourcesNote =>
      '这些资源按名字被引用：改名字等于断开引用，改内容则在下一次加载配置时生效。它们不属于旧版 1.4.3 的界面，保留在此供调试使用。';

  @override
  String get customResourcesSection => '资源';

  @override
  String get configDelete => '删除';

  @override
  String get configCancel => '取消';

  @override
  String get configNotSet => '未设置';

  @override
  String configItemCount(Object count) {
    return '共 $count 项';
  }

  @override
  String odEditSsidTooltip(Object ssid) {
    return '编辑 $ssid';
  }

  @override
  String odDeleteSsidTooltip(Object ssid) {
    return '删除 $ssid';
  }
}

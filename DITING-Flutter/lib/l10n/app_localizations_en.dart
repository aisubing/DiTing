// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DITING';

  @override
  String get uiBack => 'Back';

  @override
  String get uiCancel => 'Cancel';

  @override
  String get uiClearSearch => 'Clear search';

  @override
  String get uiClose => 'Close';

  @override
  String get uiHidePassword => 'Hide password';

  @override
  String get uiMore => 'More';

  @override
  String get uiNoSearchResults => 'No results';

  @override
  String get uiReset => 'Reset';

  @override
  String get uiSearch => 'Search';

  @override
  String get uiShowLess => 'Show less';

  @override
  String get uiShowMore => 'Show more';

  @override
  String get uiShowPassword => 'Show password';

  @override
  String get uiSort => 'Sort';

  @override
  String get uiSubmit => 'Submit';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageInterfaceSection => 'Interface language';

  @override
  String get languageInterfaceFooter =>
      'Choose the interface language. \"Follow system\" uses the device language and falls back to Chinese for other languages.';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get commonFollowSystem => 'Follow system';

  @override
  String get commonSelectAll => 'Select all';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonInvertSelection => 'Invert selection';

  @override
  String get commonFilter => 'Filter';

  @override
  String get commonSort => 'Sort';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDiscard => 'Don\'t save';

  @override
  String get commonSaveChangesTitle => 'Save changes?';

  @override
  String get commonSaveChangesMessage =>
      'Your changes have not been saved yet. Save them before leaving, or discard them?';

  @override
  String commonSaveChangesMessageFor(Object name) {
    return 'The selection for \"$name\" has not been saved yet. Save it before leaving, or discard the changes?';
  }

  @override
  String get commonGrantPermission => 'Grant access';

  @override
  String get palettePurple => 'Iris purple';

  @override
  String get paletteBlue => 'Water lily blue';

  @override
  String get paletteCyan => 'Pool cyan';

  @override
  String get paletteGreen => 'Willow green';

  @override
  String get paletteOrange => 'Dusk ochre';

  @override
  String get paletteRed => 'Poppy red';

  @override
  String get palettePink => 'Sunset pink';

  @override
  String get paletteGold => 'Wheat gold';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get appListUnavailable => 'Can\'t read the app list';

  @override
  String get appListFilterAll => 'All apps';

  @override
  String get appListFilterSystem => 'System apps';

  @override
  String get appListFilterUser => 'User apps';

  @override
  String get appListFilterSelected => 'Selected apps';

  @override
  String get appListSortLabelAsc => 'App name A-Z';

  @override
  String get appListSortLabelDesc => 'App name Z-A';

  @override
  String get appListSortPackageAsc => 'Package A-Z';

  @override
  String get appListSortPackageDesc => 'Package Z-A';

  @override
  String get appListNotRegistered => 'not registered';

  @override
  String appListChannelUnavailable(Object detail) {
    return 'App list channel unavailable: $detail';
  }

  @override
  String appListReadFailed(Object detail) {
    return 'Failed to read the app list: $detail';
  }

  @override
  String appListReadFailedCode(Object code) {
    return 'Failed to read the app list ($code)';
  }

  @override
  String dbWriteUnhealthy(Object dropped, Object failures) {
    return 'Log writes are failing: $dropped rows dropped and $failures failed opens. See Troubleshooting for details.';
  }

  @override
  String get agreementDeclinedTitle => 'Notice declined';

  @override
  String get agreementDeclinedMessage =>
      'DITING can\'t be used without accepting the notice and disclaimer. You can quit the app, or review the terms again and then decide.';

  @override
  String get agreementReviewAgain => 'Review again';

  @override
  String get agreementTitle => 'Notice and disclaimer';

  @override
  String get agreementDecline => 'Decline and exit';

  @override
  String get agreementAccept => 'Accept and continue';

  @override
  String get agreementMessage =>
      'About the app\nDITING is an open-source tool focused on local DNS resolution optimisation and network rule filtering. It offers three work modes: Normal (full-tunnel control), Turbo (a lightweight pure-Kotlin narrow route) and Standalone server (a LAN service that needs no VPN). Everything runs locally on the device: no remote data upload and no privacy tracking.\n\nHow it works\nNormal and Turbo modes take over DNS resolution through the Android local VPN interface and never connect to a remote VPN server; Standalone server mode needs no VPN permission and listens on local port 1053 for LAN devices. Rules and logs stay on the device. Please understand the impact before enabling advanced extensions.\n\nDisclaimer\nThis software is provided as is. Users must comply with applicable laws and verify the legality and safety of the rules and upstream resolvers they configure. Any illegal use is strictly forbidden, and users bear all consequences of their own configuration or use of this software.';

  @override
  String get homeProviderSingleLabel => 'Resolver';

  @override
  String get homeProviderRaceLabel => 'Racing resolvers';

  @override
  String get homeChartEmptyLabel => 'No samples yet';

  @override
  String durationHours(Object hours) {
    return '$hours h';
  }

  @override
  String durationMinutes(Object minutes) {
    return '$minutes min';
  }

  @override
  String durationSeconds(Object seconds) {
    return '$seconds s';
  }

  @override
  String get dashboardDetailTooltip => 'Details';

  @override
  String get dashboardEmptyLabel => 'No dashboard cards yet';

  @override
  String get dashboardEmptyDescription =>
      'Enter edit mode and pick a few cards from \"Add card\".';

  @override
  String get dashboardEnterEditMode => 'Enter edit mode';

  @override
  String get dashboardEditHint =>
      'Drag the handle to reorder, tap the top-right corner to remove; tap \"Done\" when finished.';

  @override
  String get dashboardAllRemovedLabel => 'All cards removed';

  @override
  String get dashboardAllRemovedDescription =>
      'Tap \"Add card\" below to pick one.';

  @override
  String get dashboardAddCard => 'Add card';

  @override
  String get providerSheetSingleTitle => 'Choose a resolver';

  @override
  String get providerSheetRaceTitle => 'Choose racing resolvers';

  @override
  String get providerSheetSingleOptions => 'Available resolvers';

  @override
  String get providerSheetRaceMinimum => 'Pick at least 2';

  @override
  String get providerSheetManage => 'Manage resolvers...';

  @override
  String get providerSheetVisibility => 'Resolver visibility...';

  @override
  String get providerSheetSingleFooter =>
      'Latency comes from the last resolution health record, not a live measurement.';

  @override
  String get providerSheetRaceFooter =>
      'In racing mode every query is sent to all selected resolvers concurrently.';

  @override
  String get powerButtonStop => 'Stop';

  @override
  String get powerButtonStart => 'Start';

  @override
  String get powerButtonStarting => 'Starting';

  @override
  String get homeEditDashboard => 'Edit dashboard';

  @override
  String get homeDone => 'Done';

  @override
  String get homeSwitchWorkMode => 'Switch work mode';

  @override
  String get homeTitleNormal => 'DITING · Normal';

  @override
  String get homeTitleServer => 'DITING · Server';

  @override
  String get homeTitleExpress => 'DITING · Express';

  @override
  String get logRequestsOverview => 'Request overview';

  @override
  String get logTodayRequests => 'Requests today';

  @override
  String get logPassed => 'Passed';

  @override
  String get logFiltered => 'Filtered';

  @override
  String get logCacheHits => 'Cache hits';

  @override
  String get logHighlights => 'Key records';

  @override
  String get logBlocked => 'Blocked';

  @override
  String get logFailed => 'Failed';

  @override
  String get logBypassed => 'Bypassed';

  @override
  String get logOffModeTitle => 'Resolution overview';

  @override
  String get logCacheEntries => 'Live cache entries';

  @override
  String get logCacheHitsTotal => 'Total cache hits';

  @override
  String get logRaceRequests => 'Concurrent race queries';

  @override
  String get logBootstrapAttempts => 'Bootstrap attempts';

  @override
  String get logRecentRequests => 'Recent requests';

  @override
  String get logRecentRequestsEmpty => 'No requests yet';

  @override
  String get logRecentBlocked => 'Recent blocks and errors';

  @override
  String get logRecentBlockedEmpty => 'No blocks or errors yet';

  @override
  String get logCacheHotspots => 'Cache hotspots';

  @override
  String get logCacheHotspotsEmpty => 'No live cache entries';

  @override
  String logExpiresIn(Object duration) {
    return 'expires in $duration';
  }

  @override
  String logTimes(Object count) {
    return '$count times';
  }

  @override
  String get logRaceWinners => 'Race winners';

  @override
  String get logRaceWinnersEmpty => 'No race data yet';

  @override
  String logAverageWinLatency(Object latency) {
    return 'Won in $latency on average';
  }

  @override
  String get logBootstrapDnsEmpty => 'No Bootstrap data yet';

  @override
  String logBootstrapRow(Object ip, Object latency, Object percent) {
    return '$ip · $percent success · $latency';
  }

  @override
  String get logRuleBlocks => 'Rule blocks';

  @override
  String get logRuleBlocksEmpty => 'No rule blocks yet';

  @override
  String logShareRow(Object percent, Object status) {
    return '$status · $percent of all requests';
  }

  @override
  String get logPrivacyMode => 'Privacy mode is on';

  @override
  String get logLoggingOff => 'Logging off';

  @override
  String get logPrivacyModeBody =>
      'After logging is turned back on the dashboard counts from the requests recorded from then on. Resolution services and cache hotspots keep working meanwhile.';

  @override
  String get logPerfTitle => 'Resolution performance';

  @override
  String get logTodayStats => 'Today';

  @override
  String get logAverageLatency => 'Average resolution time';

  @override
  String get logNoTimingSamples => '— · No timing samples today';

  @override
  String logSampleValue(Object count, Object value) {
    return '$value · $count samples';
  }

  @override
  String get logCacheHitRate => 'Cache hit rate';

  @override
  String logCacheHitRateValue(Object percent) {
    return '$percent · denominator is passed + failed';
  }

  @override
  String get logRaceSuccessRate => 'Race success rate';

  @override
  String get logBootstrapSuccessRate => 'Bootstrap success rate';

  @override
  String logRateValue(Object count, Object latency, Object percent) {
    return '$percent · $count times · $latency';
  }

  @override
  String get dashboardRestoreDefaults => 'Restore defaults';

  @override
  String get dashboardAllCardsAdded => 'All cards are on the dashboard';

  @override
  String get dashboardAllCardsAddedDescription =>
      'To remove one, go back to edit mode and tap the remove button in its top-right corner.';

  @override
  String get dashboardAvailableCards => 'Available cards';

  @override
  String get dashboardOrderHint =>
      'Drag cards in edit mode to change their order.';

  @override
  String get dashboardCardProviderDescription =>
      'The active resolver; open it to switch or adjust the racing list';

  @override
  String get dashboardCardResolutionDescription =>
      'Resolution mode, a one-line summary and the DNS address in effect';

  @override
  String get dashboardCardStatusDescription =>
      'Core state, uptime, active resolver and today\'s queries';

  @override
  String get dashboardCardSpeedDescription =>
      'Live up/down rate curves and today\'s total traffic';

  @override
  String get dashboardCardSiteLatencyDescription =>
      'Measured latency of four custom sites; the detail page tests each category';

  @override
  String get dashboardCardMemoryDescription =>
      'This process\'s PSS split into Java and native heap';

  @override
  String get dashboardCardIntranetDescription =>
      'Current LAN address, listening state and a copy action';

  @override
  String get intranetIpTitle => 'LAN IP';

  @override
  String get intranetCopyAddress => 'Copy address';

  @override
  String get intranetReading => 'Reading…';

  @override
  String get intranetNoActiveNetwork => 'No active network';

  @override
  String get intranetLanAccess => 'LAN access';

  @override
  String get intranetConnectHint =>
      'Connect to Wi-Fi or Ethernet to see a usable address here';

  @override
  String get memoryTitle => 'Memory';

  @override
  String get memoryJavaHeap => 'Java heap';

  @override
  String get memoryNativeHeap => 'Native heap';

  @override
  String get memorySystemAvailable => 'System available';

  @override
  String get speedTitle => 'Network speed';

  @override
  String get speedUpload => 'Upload';

  @override
  String get speedDownload => 'Download';

  @override
  String get speedExpressNoStats => 'Not measured in express mode';

  @override
  String get speedNoChannel => 'No rate channel in this environment';

  @override
  String get resolutionModeTitle => 'Resolution mode';

  @override
  String get resolutionNoProvider => 'No resolver selected';

  @override
  String get resolutionSingleSummary =>
      'Uses only the selected resolver: fastest, but availability depends on it.';

  @override
  String get resolutionSmartSummary =>
      'Picks one by historical success rate and falls back to the next on failure.';

  @override
  String get resolutionParallelSummary =>
      'Asks every resolver at once and takes the first answer.';

  @override
  String get resolutionPrimaryBackupSummary =>
      'Primary first, backups only after a timeout.';

  @override
  String get siteLatencyTesting => 'Testing…';

  @override
  String get siteLatencyNotTested => 'Not tested yet';

  @override
  String get siteLatencyTitle => 'Site latency';

  @override
  String get siteLatencyRetest => 'Test again';

  @override
  String get commonFailed => 'Failed';

  @override
  String get siteLatencyNoReply => 'No reply';

  @override
  String get statusTitle => 'Status';

  @override
  String get statusUptime => 'Uptime';

  @override
  String get statusActiveProvider => 'Active resolver';

  @override
  String get statusNotSelected => 'None';

  @override
  String get statusTodayQueries => 'Queries today';

  @override
  String get statusDetailTitle => 'Status details';

  @override
  String get statusNotTiming => 'Not counting';

  @override
  String get statusCoreSection => 'Core';

  @override
  String get statusWorkMode => 'Work mode';

  @override
  String get statusCoreState => 'Core state';

  @override
  String get statusListenPort => 'Listening port';

  @override
  String get statusNotListening => 'Not listening';

  @override
  String get statusProviderFooter =>
      'Latency is the resolver\'s last measured value, not this device\'s round trip to the target.';

  @override
  String get statusNoProviderHint =>
      'No resolver selected yet. Pick one in resolver management so resolution uses a real upstream.';

  @override
  String get statusTodayCounts => 'Today\'s counts';

  @override
  String get statusCountsFooter =>
      'Counts accumulate from this core start and reset when it restarts or the work mode changes; the reset in server mode clears only the counts, never rules or cache.';

  @override
  String get statusQueries => 'Queries';

  @override
  String get statusBlocked => 'Blocked';

  @override
  String get statusAverageLatency => 'Average latency';

  @override
  String get statusCacheHitRate => 'Cache hit rate';

  @override
  String get statusServerPortReady =>
      'The local DNS port is available; LAN devices can use it as their DNS';

  @override
  String get statusTunnelActive =>
      'This device\'s traffic goes through DITING, so resolution and rules are in effect';

  @override
  String get statusServerPortClosed =>
      'The DNS port is not listening, so server mode is not serving resolution';

  @override
  String get statusCoreStopped =>
      'The core is not running, so this device uses the system\'s default network';

  @override
  String get siteLatencySheetLatency => 'Latency';

  @override
  String get siteLatencySheetCategory => 'Category';

  @override
  String get siteLatencySheetTarget => 'Target';

  @override
  String get siteLatencySheetAverage => 'Average RTT';

  @override
  String get siteLatencySheetMinMax => 'Min / max';

  @override
  String get siteLatencySheetJitter => 'Jitter';

  @override
  String get siteLatencySheetLoss => 'Loss';

  @override
  String get siteLatencySheetDns => 'Resolved address';

  @override
  String get siteLatencySheetLastRun => 'Last test';

  @override
  String get siteLatencySheetNotTested =>
      'Not tested yet. Tap the test button to start.';

  @override
  String get siteLatencySheetNoReply =>
      'None of the three echo requests was answered: the site may be rate limiting or the network is down.';

  @override
  String get siteLatencySheetFallbackFooter =>
      'System ping is unavailable, so these numbers come from the TCP handshake / isReachable: they measure connection setup, not ICMP echo, and read slightly higher than the real round trip.';

  @override
  String get siteLatencySheetIcmpFooter =>
      'Numbers come from ICMP echo via system ping (average of three). This app\'s own traffic bypasses the VPN, so the physical network is measured.';

  @override
  String get trafficStructureLive => 'Live summary';

  @override
  String get trafficStructureFocused => 'Key traffic structure';

  @override
  String get trafficStructureToday => 'Today\'s traffic structure';

  @override
  String get trafficStructureBypass => 'Bypass';

  @override
  String get trafficStructureCache => 'Cache';

  @override
  String get trafficStructureRaceRate => 'Race success rate';

  @override
  String get trafficStructureBootstrapRate => 'Bootstrap success rate';

  @override
  String get trafficStructureBlockedShare => 'Blocked share';

  @override
  String get trafficStructureBlockRate => 'Block rate';

  @override
  String get trafficStructureCacheRate => 'Cache rate';

  @override
  String get dashboardSitesTitle => 'Dashboard sites';

  @override
  String get dashboardSitesCardSection => 'Dashboard card';

  @override
  String get dashboardSitesAtLeastOne => 'Keep at least one site on the card';

  @override
  String get dashboardSitesFooter =>
      'These four cards share one dashboard card, so changes apply immediately; tests run per category from the detail page.';

  @override
  String get trafficMonitorTitle => 'Traffic monitor';

  @override
  String get trafficMonitorToday => 'Proxy traffic today';

  @override
  String get trafficMonitorLiveRate => 'Live rate';

  @override
  String get trafficMonitorNoStats => 'Not measured in this mode';

  @override
  String get memoryDetailTitle => 'Memory details';

  @override
  String get memoryResample => 'Resample';

  @override
  String get memoryProcessPss => 'This process PSS';

  @override
  String get memoryUnavailable => 'Unavailable';

  @override
  String get memoryOther => 'Other';

  @override
  String get memoryComposition => 'Process composition';

  @override
  String get memoryCompositionFooter =>
      'PSS counts shared pages proportionally, so the Java and native heaps add up to less than the PSS; the remainder is code, graphics buffers and shared libraries.';

  @override
  String get memoryOtherCode => 'Other (code / shared libraries)';

  @override
  String get memorySystemSection => 'System memory';

  @override
  String get memorySystemFooter =>
      'System usage = total - available, covering the system and every app; this process is only one part of it.';

  @override
  String get memorySystemUsed => 'System used';

  @override
  String get memoryRecentPss => 'Recent PSS';

  @override
  String get memorySampling => 'Sampling…';

  @override
  String get memoryRecentPssCaption =>
      'This page samples every 2 seconds and keeps at most 60 points; a curve that keeps climbing means memory is not being released.';

  @override
  String get memorySourceFooter =>
      'Data comes from ActivityManager\'s MemoryInfo; the numbers drop noticeably after the app is backgrounded or the system reclaims memory.';

  @override
  String get siteLatencyDetailTitle => 'Latency details';

  @override
  String get siteLatencyTestAll => 'Test all';

  @override
  String get siteLatencyCustomSites => 'Custom dashboard sites';

  @override
  String get siteLatencyConnectivity => 'Site connectivity';

  @override
  String get siteLatencyTestingShort => 'Testing';

  @override
  String get siteLatencyNoTest => 'Not tested';

  @override
  String get siteLatencyInProgress => 'In progress';

  @override
  String get siteLatencyPending => 'Pending';

  @override
  String get siteLatencyAllReachable => 'All reachable';

  @override
  String get siteLatencyTestingEach => 'Testing the sites one by one…';

  @override
  String get siteLatencyPickCategory =>
      'Pick a category and start a test, or tap the top-right corner to test everything.';

  @override
  String get siteLatencyThisRun => 'This run';

  @override
  String get siteLatencyReachable => 'Reachable';

  @override
  String get siteLatencyMeasuredSites => 'Sites tested';

  @override
  String get siteLatencyDetailFooter =>
      'Each site gets three ICMP echo requests and the average is used; when system ping is unavailable the TCP handshake is used instead, marked with *, and reads slightly higher than the real round trip. This app\'s own traffic bypasses the VPN, so the physical network is measured.';

  @override
  String get intranetDetailTitle => 'LAN IP details';

  @override
  String get intranetRefresh => 'Refresh network info';

  @override
  String get intranetLocalAddress => 'Local LAN address';

  @override
  String get intranetUsableAsDns => 'Usable as DNS';

  @override
  String get intranetLocalOnly => 'Local only';

  @override
  String get intranetSameSubnetHint =>
      'Point devices on the same subnet at this address to use local resolution.';

  @override
  String get intranetNetworkOverview => 'Network overview';

  @override
  String get commonEnabled => 'Enabled';

  @override
  String get commonDisabled => 'Disabled';

  @override
  String get intranetDnsServers => 'DNS servers';

  @override
  String get intranetInterfaces => 'Interfaces';

  @override
  String get intranetNoInterface =>
      'The system reports no active network interface: airplane mode may be on or there is no connection.';

  @override
  String get intranetAdapter => 'Adapter';

  @override
  String get intranetGateway => 'Gateway';

  @override
  String get intranetPrivateDnsOff =>
      'System Private DNS is off, so requests are handled locally and by the proxy according to the mode.';

  @override
  String get intranetNoDnsServer =>
      'No DNS server was read: the interface provides none, or there is no diagnostic channel here.';

  @override
  String get intranetPrimaryDns => 'Primary';

  @override
  String get intranetPrivateDns => 'Private DNS';

  @override
  String get intranetPortFooter =>
      'The port is bound only when the service starts, so restart it after changing the port; point devices on the same subnet at the address above to use local resolution.';

  @override
  String get intranetCopyAddressWithPort => 'Copy address (with port)';

  @override
  String get speedDetailTitle => 'Speed details';

  @override
  String get speedCurrentDownload => 'Current download';

  @override
  String get speedSamplingPaused => 'Sampling paused';

  @override
  String get speedLive => 'Live';

  @override
  String get speedSamplingHint =>
      'Sampled once per second; the chart shows the last minute.';

  @override
  String get speedCurrentUpload => 'Current upload';

  @override
  String get speedDownloadPeak => 'Download peak';

  @override
  String get speedUploadPeak => 'Upload peak';

  @override
  String get speedSamples => 'Samples';

  @override
  String get speedTodayTotal => 'Today\'s total';

  @override
  String get speedNoTrafficToday =>
      'The traffic store has no records for today yet.';

  @override
  String get speedTotal => 'Total';

  @override
  String get speedRateFooter =>
      'Rates come from the core data plane\'s live counters and cover only tunneled traffic; this app\'s own probes and speed tests are excluded. Today\'s totals come from the app traffic statistics, the same data as the Traffic page.';

  @override
  String get speedExpressSource =>
      'Express mode bypasses the core data plane, so there is no per-second rate; switch back to normal mode to restore it.';

  @override
  String get speedNoChannelSource =>
      'This environment has no rate channel (desktop or pure Dart tests), so no live rate can be read.';

  @override
  String get speedNoDataInMode => 'No rate data in this mode';

  @override
  String get speedWaitingSample => 'Waiting for the first sample';

  @override
  String get commonNoData => 'No data';

  @override
  String intranetModeNotListening(Object mode) {
    return '$mode does not listen on the LAN, so other devices cannot use this as their DNS';
  }

  @override
  String intranetListeningOn(Object port) {
    return 'Listening on 0.0.0.0:$port; point other devices\' DNS at the address above';
  }

  @override
  String intranetServiceStopped(Object port) {
    return 'Service not started: port $port is bound once it starts';
  }

  @override
  String commonCopied(Object text) {
    return 'Copied $text';
  }

  @override
  String intranetGatewaySuffix(Object gateway) {
    return ' · Gateway $gateway';
  }

  @override
  String get speedTotalDash => 'Total —';

  @override
  String siteLatencyAliveRatio(Object alive, Object total) {
    return '$alive / $total reachable';
  }

  @override
  String siteLatencyLastRun(Object ago) {
    return 'Last test $ago';
  }

  @override
  String siteLatencyProviderSuffix(Object name) {
    return ' · Resolver $name';
  }

  @override
  String siteLatencySitesCount(Object count) {
    return '$count sites';
  }

  @override
  String siteLatencyTestCategory(Object category) {
    return 'Test $category';
  }

  @override
  String memorySystemShare(Object percent) {
    return '$percent of the system';
  }

  @override
  String memorySystemUsedOf(Object total, Object used) {
    return 'System used $used / $total';
  }

  @override
  String get memoryNoChannel =>
      'Memory data is unavailable here (desktop or pure Dart tests).';

  @override
  String trafficStructureRateValue(
    Object count,
    Object latency,
    Object percent,
  ) {
    return '$percent · $count times · $latency';
  }

  @override
  String trafficStructureShareValue(Object count, Object percent) {
    return '$percent · $count times';
  }

  @override
  String statusPausedSummary(Object core, Object mode) {
    return '$mode $core, timing paused';
  }

  @override
  String speedTotalsDown(Object percent) {
    return 'Down $percent';
  }

  @override
  String speedTotalsUp(Object percent) {
    return 'Up $percent';
  }

  @override
  String speedPeakAverage(Object average, Object peak) {
    return 'Peak $peak · Average $average';
  }

  @override
  String get intranetConnectHintSentence =>
      'Connect to Wi-Fi or Ethernet to see a usable address here.';

  @override
  String intranetModeNotListeningSentence(Object mode) {
    return '$mode does not listen on the LAN, so other devices cannot use this as their DNS.';
  }

  @override
  String intranetPrivateDnsOn(Object dns) {
    return 'System Private DNS is on ($dns); system lookups use an encrypted channel and may bypass the local service.';
  }

  @override
  String intranetSecondaryDns(Object index) {
    return 'Secondary $index';
  }

  @override
  String intranetCopyAddressSemantics(Object address) {
    return 'Copy address $address';
  }

  @override
  String speedTotalAccumulated(Object value) {
    return 'Total $value';
  }

  @override
  String dashboardSitesFull(Object count) {
    return 'The card holds $count sites; turn one off before adding another.';
  }

  @override
  String dashboardSitesRemaining(Object count) {
    return 'You can add $count more sites.';
  }

  @override
  String dashboardSitesMax(Object count) {
    return 'The card holds at most $count sites; deselect one first.';
  }

  @override
  String dashboardSitesPosition(Object index) {
    return 'Position $index';
  }

  @override
  String siteLatencyFailedCount(Object count) {
    return '$count failed';
  }

  @override
  String get siteLatencyDetailFooterLong =>
      'Each site gets three ICMP echo requests and the average is used; when system ping is unavailable the TCP handshake is used instead, marked with *, and reads slightly higher than the real round trip. This app\'s own traffic bypasses the VPN, so the physical network is measured.';

  @override
  String get homeLayerPowerButton => 'Start button';

  @override
  String get homeLayerPoem => 'Home poem';

  @override
  String get bottomBarHome => 'Home';

  @override
  String get bottomBarFeatureHub => 'Feature hub';

  @override
  String get bottomBarLogDashboard => 'Log dashboard';

  @override
  String get bottomBarAppTraffic => 'App traffic';

  @override
  String get bottomBarNetworkTools => 'Network tools';

  @override
  String get bottomBarSettings => 'Settings';

  @override
  String get bottomBarStyleFloating => 'Floating';

  @override
  String get bottomBarStyleDocked => 'Docked';

  @override
  String get tabTransitionNone => 'None';

  @override
  String get tabTransitionFade => 'Fade';

  @override
  String get tabTransitionSlide => 'Slide';

  @override
  String get tabTransitionScale => 'Scale';

  @override
  String get commonOff => 'Off';

  @override
  String get glassModeStandard => 'Standard';

  @override
  String get glassModeUltra => 'Ultra';

  @override
  String get previewBrightnessLight => 'Light';

  @override
  String get previewBrightnessDark => 'Dark';

  @override
  String get resolutionModeSingle => 'Single resolver';

  @override
  String get resolutionModeSmart => 'Smart selection';

  @override
  String get resolutionModeParallel => 'Parallel race';

  @override
  String get resolutionModePrimaryBackup => 'Primary + backup';

  @override
  String get workModeNormalTitle => 'Normal mode';

  @override
  String get workModeNormalBadge => 'Recommended';

  @override
  String get workModeNormalSummary =>
      'Full DNS resolution, block/allow lists, HTTPS inspection and network control';

  @override
  String get workModeServerTitle => 'Server mode';

  @override
  String get workModeServerBadge => 'Lightweight';

  @override
  String get workModeServerSummary =>
      'Pure DNS proxy with resolution acceleration, low power';

  @override
  String get workModeExpressTitle => 'Express mode';

  @override
  String get workModeExpressBadge => 'Express';

  @override
  String get workModeExpressSummary =>
      'Pure Kotlin DNS acceleration and rule filtering, Android 7+ (64-bit)';

  @override
  String get stateStopped => 'Stopped';

  @override
  String get stateStarting => 'Starting';

  @override
  String get stateRunning => 'Running';

  @override
  String get stateStopping => 'Stopping';

  @override
  String get powerStateError => 'Failed to start';

  @override
  String get serverStatusError => 'Error';

  @override
  String get logModeAllLabel => 'Log everything';

  @override
  String get logModeAllDescription =>
      'Requests, cache hits, races and blocks all go to the log';

  @override
  String get logModeBlockedLabel => 'Blocks and errors only';

  @override
  String get logModeBlockedDescription =>
      'Only blocked and failed requests are recorded';

  @override
  String get logModeOffLabel => 'Logging off';

  @override
  String get logModeOffDescription => 'Nothing is recorded, saving space';

  @override
  String get ipv6AutoLabel => 'Auto';

  @override
  String get ipv6AutoDescription => 'Enable depending on the current network';

  @override
  String get ipv6DisableLabel => 'Off';

  @override
  String get ipv6DisableDescription => 'No IPv6 inside the tunnel';

  @override
  String get ipv6PreferLabel => 'Prefer';

  @override
  String get ipv6PreferDescription => 'Prefer IPv6 and fall back when it fails';

  @override
  String get commonToday => 'Today';

  @override
  String get logWindowSevenDays => '7 days';

  @override
  String get logWindowSevenDaysRecent => 'Last 7 days';

  @override
  String get commonAll => 'All';

  @override
  String get trafficWindowWeek => 'This week';

  @override
  String get trafficWindowMonth => 'This month';

  @override
  String get trafficSortTotal => 'By total traffic';

  @override
  String get trafficSortDownload => 'By download traffic';

  @override
  String get trafficSortUpload => 'By upload traffic';

  @override
  String get davStatusIdle => 'Not connected';

  @override
  String get davStatusConnecting => 'Connecting';

  @override
  String get davStatusConnected => 'Connected';

  @override
  String get davStatusFailed => 'Connection failed';

  @override
  String get updateStageIdle => 'Not checked';

  @override
  String get updateStageChecking => 'Checking';

  @override
  String get updateStageUpToDate => 'Up to date';

  @override
  String get updateStageAvailable => 'Update available';

  @override
  String get updateStageDownloading => 'Downloading';

  @override
  String get updateStageDownloaded => 'Downloaded';

  @override
  String get ipQualityStageIdle => 'Not tested';

  @override
  String get ipQualityStageLoading => 'Checking';

  @override
  String get ipQualityStageLoaded => 'Check complete';

  @override
  String get ipQualityStageFailed => 'Check failed';

  @override
  String get subscriptionDeleted => 'Deleted';

  @override
  String get subscriptionDisabled => 'Disabled';

  @override
  String get subscriptionUngrouped => 'Ungrouped';

  @override
  String get providerNotTested => 'Not tested';

  @override
  String get elapsedJustNow => 'just now';

  @override
  String elapsedSecondsAgo(Object count) {
    return '${count}s ago';
  }

  @override
  String elapsedMinutesAgo(Object count) {
    return '${count}m ago';
  }

  @override
  String elapsedHoursAgo(Object count) {
    return '${count}h ago';
  }

  @override
  String elapsedDaysAgo(Object count) {
    return '${count}d ago';
  }

  @override
  String providerRaceSummary(Object count, Object names) {
    return '$count selected: $names';
  }

  @override
  String get rulesDbUnavailable =>
      'The rule database is not readable in this environment';

  @override
  String get agentApiKeyMissing =>
      'No usable API key yet. Fill one in under AI provider management and select that provider.';

  @override
  String get agentNoExtraInfo => '(no extra information)';

  @override
  String get agentNoLegacyDatabase =>
      'The legacy database was not found, so DNS and HTTPS logs cannot be read. Start the service once first.';

  @override
  String get agentExpressNoHttps =>
      'Express mode only accelerates DNS on a narrow route and produces no HTTPS inspection records';

  @override
  String get autoUpdateDisabled => 'Automatic updates are off';

  @override
  String get autoUpdateNoSubscriptions =>
      'No subscriptions to update automatically';

  @override
  String get autoUpdateNotDue => 'Not due yet';

  @override
  String get autoUpdateBusy =>
      'A manual update is running; this round is skipped';

  @override
  String get cleanupGroupRuntime => 'Runtime data';

  @override
  String get cleanupGroupWeights => 'Weight data';

  @override
  String get cleanupGroupRules => 'Rules and subscriptions';

  @override
  String get cleanupGroupStorage => 'Storage and security';

  @override
  String get cleanupGroupGuides => 'Guides and reset';

  @override
  String get backupReadFileFailed => 'The selected file cannot be read';

  @override
  String get caChannelUnavailable => 'The certificate channel is unavailable';

  @override
  String get caInstallUnavailable =>
      'The certificate installer cannot be opened';

  @override
  String get caDownloadDirUnavailable =>
      'The download directory is not writable';

  @override
  String get fontSystemDefault => 'System default';

  @override
  String get diagnosticsChannelUnavailable =>
      'The diagnostics channel is unavailable (no native implementation on this platform)';

  @override
  String get diagnosticsUnsupported => 'This diagnostic is not supported here';

  @override
  String get diagnosticsPingUnsupported => 'Ping probing is not supported here';

  @override
  String get diagnosticsTraceUnsupported =>
      'Route tracing is not supported here';

  @override
  String get diagnosticsDnsUnsupported => 'DNS queries are not supported here';

  @override
  String get diagnosticsEmptyTarget => 'Enter a target to probe';

  @override
  String get diagnosticsTargetHasSpace => 'The target cannot contain spaces';

  @override
  String get diagnosticsAnswerUpstream => 'Upstream resolution';

  @override
  String get diagnosticsAnswerCache => 'Cache hit';

  @override
  String get diagnosticsAnswerRewrite => 'Rewrite rule';

  @override
  String get diagnosticsAnswerBlocked => 'Blocked by a rule';

  @override
  String get diagnosticsAnswerFailed => 'Query failed';

  @override
  String get diagnosticsNoActiveNetwork => 'No active network';

  @override
  String get aiPresetMainland => 'Mainland providers';

  @override
  String get aiPresetOverseas => 'Overseas providers';

  @override
  String get aiPresetAggregator => 'Aggregators and local deployments';

  @override
  String get aiProviderConfigured => 'Configured providers';

  @override
  String get logSubscriptionDeleted => 'Deleted subscription';

  @override
  String get logRaceFastest => 'Fastest response';

  @override
  String get logRaceSmart => 'Smart selection';

  @override
  String get logRaceSequential => 'Try in order';

  @override
  String get logRaceSingle => 'Single resolver';

  @override
  String get providerNoProviderSelected => 'No resolver selected';

  @override
  String get onDemandDisabled => 'On-demand connection is off; nothing changed';

  @override
  String get onDemandServerMode =>
      'Server mode uses no tunnel; nothing changed';

  @override
  String get onDemandUnknownSsid =>
      'The current Wi-Fi cannot be read; nothing changed';

  @override
  String get onDemandSameNetwork =>
      'The network has not changed; the VPN state stays as it is';

  @override
  String get onDemandNoWifi => 'Not on Wi-Fi, so the VPN was disconnected';

  @override
  String get onDemandStarted => 'Matched the allow list; the VPN was started';

  @override
  String get onDemandAlreadyRunning =>
      'Matched the allow list; the VPN is running';

  @override
  String get onDemandStopped =>
      'This network is not on the allow list; the VPN was disconnected';

  @override
  String get onDemandAlreadyStopped =>
      'This network is not on the allow list; the VPN is not running';

  @override
  String get onDemandBusy => 'The VPN is switching state; try again later';

  @override
  String get onDemandNeedsConsent =>
      'Matched the allow list; waiting for system VPN consent';

  @override
  String get speedTestSelectProvider => 'Select at least one resolver to test';

  @override
  String get speedTestEmptyDomain => 'Enter a domain to test';

  @override
  String get imagePickerUnavailable =>
      'No image picker is available on this device';

  @override
  String get serverModeRequired => 'Switch to server mode first';

  @override
  String get serverStartFailed => 'The DNS service failed to start';

  @override
  String get serverStartTimeout => 'The DNS service timed out starting';

  @override
  String get recognitionInvalidConfig =>
      'The cloud roster configuration is invalid';

  @override
  String get recognitionGithubInterrupted =>
      'The connection to GitHub was interrupted; try again later';

  @override
  String get recognitionGithubTimeout =>
      'Connecting to GitHub timed out; check the network and retry';

  @override
  String get recognitionNetworkUnavailable =>
      'No network, so the roster cannot be updated';

  @override
  String get recognitionUpdateFailed => 'The roster update failed';

  @override
  String get subscriptionNotFound =>
      'The subscription does not exist or the database is unavailable';

  @override
  String get subscriptionDatabaseUnavailable =>
      'The subscription database is unavailable';

  @override
  String get subscriptionRuleDbUnavailable =>
      'The rule database is unavailable, so downloaded rules cannot be stored';

  @override
  String get subscriptionUpdateFailed => 'Update failed';

  @override
  String get subscriptionLocalFileUnreadable => 'The local file cannot be read';

  @override
  String get subscriptionLocalRuleDbUnavailable =>
      'The rule database is unavailable, so local rules cannot be stored';

  @override
  String get subscriptionNothingToUpdate => 'No subscriptions to update';

  @override
  String get subscriptionPickRuleFile => 'Pick a rule file';

  @override
  String get subscriptionPickTxtFile =>
      'Pick a rule file with the .txt extension';

  @override
  String get subscriptionLegacyDatabaseMissing =>
      'The subscription database is unavailable (the 1.4.3 database was not found)';

  @override
  String get subscriptionThisFile => 'This file';

  @override
  String get subscriptionThisLink => 'This subscription link';

  @override
  String get subscriptionLocalRuleFile => 'Local rule file';

  @override
  String get webdavEmptyCredentials =>
      'The server address and user name cannot be empty';

  @override
  String get webdavDirectoryCreated =>
      'The directory did not exist and was created';

  @override
  String get webdavUploaded => 'Uploaded to the cloud';

  @override
  String get webdavNoBackup => 'There is no backup file in the cloud yet';

  @override
  String get webdavDownloaded => 'The backup was retrieved from the cloud';

  @override
  String get updateCheckFirst => 'Check for updates first';

  @override
  String get updateDownloadFirst => 'Download the update package first';

  @override
  String get updateInstallerUnavailable =>
      'The system installer cannot be opened; try again later';

  @override
  String get workModeNoDataPlane => 'This work mode has no data plane yet';

  @override
  String get workModeNoVpnConsent => 'VPN consent was not granted';

  @override
  String get workModeStartTimeout => 'The service timed out starting';

  @override
  String get workModeVpnStartFailed => 'The VPN failed to start';

  @override
  String get aiProviderZhipu => 'Zhipu GLM';

  @override
  String get aiProviderMoonshot => 'Kimi (Moonshot)';

  @override
  String get aiProviderDashscope => 'Aliyun Bailian (Qwen)';

  @override
  String get aiProviderVolcengine => 'Volcengine Ark (Doubao)';

  @override
  String get aiProviderQianfan => 'Baidu Qianfan (ERNIE)';

  @override
  String get aiProviderStepfun => 'StepFun';

  @override
  String get aiProviderSiliconflow => 'SiliconFlow';

  @override
  String get aiProviderOllamaLocal => 'Ollama (local)';

  @override
  String rulesReadFailed(Object detail) {
    return 'Failed to read app rules: $detail';
  }

  @override
  String autoUpdateChecked(Object count) {
    return 'Checked $count subscriptions';
  }

  @override
  String caChannelUnavailableDetail(Object detail) {
    return 'The certificate channel is unavailable: $detail';
  }

  @override
  String caReadFailedCode(Object code) {
    return 'Failed to read the root certificate ($code)';
  }

  @override
  String caReadFailed(Object detail) {
    return 'Failed to read the root certificate: $detail';
  }

  @override
  String agentAnalysisFailed(Object detail) {
    return 'Analysis failed: $detail';
  }

  @override
  String diagnosticsFailedCode(Object code) {
    return 'The diagnostic failed ($code)';
  }

  @override
  String diagnosticsFailed(Object detail) {
    return 'The diagnostic failed: $detail';
  }

  @override
  String subscriptionDeletedWithId(Object id) {
    return 'Deleted subscription #$id';
  }

  @override
  String providerLatencyValue(Object value) {
    return '${value}ms';
  }

  @override
  String providerRaceSummaryNames(Object count, Object names) {
    return '$count selected: $names';
  }

  @override
  String get providerNamesSeparator => ', ';

  @override
  String recognitionInvalidConfigKept(Object detail) {
    return 'The cloud roster configuration is invalid ($detail); the local cache is kept';
  }

  @override
  String recognitionFetchFailed(Object detail) {
    return 'Fetching the cloud roster failed ($detail)';
  }

  @override
  String recognitionUpdateFailedDetail(Object detail) {
    return 'The roster update failed: $detail';
  }

  @override
  String subscriptionAlreadyExists(Object kind, Object what) {
    return '$what already exists as $kind';
  }

  @override
  String subscriptionUpdatedCount(Object count) {
    return '$count updated';
  }

  @override
  String subscriptionUnchangedCount(Object count) {
    return '$count unchanged';
  }

  @override
  String subscriptionFailedCount(Object count) {
    return '$count failed';
  }

  @override
  String subscriptionAlreadyExistsNamed(Object kind, Object name, Object what) {
    return '$what already exists as $kind (\"$name\")';
  }
}

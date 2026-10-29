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

  @override
  String get commonBypass => 'Bypass';

  @override
  String get commonRewrite => 'Rewrite';

  @override
  String get cleanupLogs => 'Delete request logs';

  @override
  String get cleanupTraffic => 'Delete traffic statistics';

  @override
  String get cleanupCrash => 'Delete crash logs';

  @override
  String get cleanupDnsCache => 'Delete DNS cache';

  @override
  String get cleanupProviderWeights => 'Restore default DNS weights';

  @override
  String get cleanupBootstrapWeights => 'Restore Bootstrap weights';

  @override
  String get cleanupDomainRules => 'Delete all domain rules';

  @override
  String get cleanupAddressRules => 'Delete all address rules';

  @override
  String get cleanupSubscriptions => 'Delete all rule subscriptions';

  @override
  String get cleanupAppRules => 'Reset the app control list';

  @override
  String get cleanupOutboundProxy => 'Reset the outbound proxy settings';

  @override
  String get cleanupCaCertificate => 'Reset the HTTPS inspection certificate';

  @override
  String get cleanupDownloadCache => 'Clear download and temporary caches';

  @override
  String get cleanupCustomBackground => 'Clear the custom background cache';

  @override
  String get cleanupSettingsGuides => 'Reset every onboarding guide';

  @override
  String get cleanupAllData => 'Clear all local data';

  @override
  String cleanupDoneItems(Object action, Object count, Object detail) {
    return '$action: $count items$detail';
  }

  @override
  String cleanupDoneEmpty(Object action) {
    return '$action: nothing to clean up';
  }

  @override
  String get blockResponseNxdomain => 'Return NXDOMAIN';

  @override
  String get blockResponseNxdomainDescription =>
      'Answers that the domain does not exist, with a 5-minute negative cache to reduce repeated queries';

  @override
  String get blockResponseNodata => 'Return NODATA';

  @override
  String get blockResponseNodataDescription =>
      'Answers that the domain exists but has no such record, with a 5-minute negative cache';

  @override
  String get blockResponseRefused => 'Return REFUSED';

  @override
  String get blockResponseRefusedDescription =>
      'Answers that the server refused the query, with no cached record';

  @override
  String get blockResponseZeroAddress => 'Return 0.0.0.0 / ::';

  @override
  String get blockResponseZeroAddressDescription =>
      'A answers 0.0.0.0, AAAA answers ::, other types get an empty answer';

  @override
  String get subscriptionSourceRemote => 'Remote subscription';

  @override
  String get subscriptionSourceLocal => 'Local file';

  @override
  String get subscriptionKindDomain => 'Domain list rules';

  @override
  String get subscriptionKindHosts => 'Hosts rules';

  @override
  String logRowDirect(Object protocol) {
    return '$protocol direct';
  }

  @override
  String logRowDirectWithPackage(Object package, Object protocol) {
    return '$protocol direct · $package';
  }

  @override
  String get logRowCacheHit => 'cache hit';

  @override
  String get logRowNoAuthority => 'no authority';

  @override
  String get cachePresetConservativeName => 'Conservative';

  @override
  String get cachePresetConservativeSummary => 'Follow the server\'s TTL';

  @override
  String get cachePresetConservativeDescription =>
      'Uses the TTL the DNS server returns and never extends it. Best for people who switch networks often or need real-time answers.';

  @override
  String get cachePresetStandardName => 'Standard';

  @override
  String get cachePresetStandardSummary =>
      'At most 1 hour, short records at least 1 minute';

  @override
  String get cachePresetStandardDescription =>
      'Cuts repeated queries without letting records lag behind. When resolution fails, records up to 5 minutes old may be reused as a stopgap.';

  @override
  String get cachePresetAggressiveName => 'High hit rate';

  @override
  String get cachePresetAggressiveSummary =>
      'At most 6 hours, short records at least 2 minutes';

  @override
  String get cachePresetAggressiveDescription =>
      'Favours fewer network requests and better usability on weak networks. Domain changes may take longer to show up.';

  @override
  String get cacheDisabledSummary => 'Off · every lookup goes upstream';

  @override
  String get upstreamNameRequired => 'Enter a name';

  @override
  String get upstreamAddressRequired => 'Enter an address';

  @override
  String get upstreamDohNeedsHttps => 'A DoH address must start with https://';

  @override
  String get upstreamDohInvalidUrl => 'The DoH address is not a valid URL';

  @override
  String get upstreamPortRange => 'The port must be between 1 and 65535';

  @override
  String get upstreamIpv6Invalid => 'The IPv6 address is not valid';

  @override
  String get upstreamPresetAliyun => 'Aliyun';

  @override
  String get upstreamPresetTencent => 'Tencent Cloud DNSPod';

  @override
  String get upstreamPresetByteDance => 'ByteDance';

  @override
  String cleanupFailed(Object detail) {
    return 'Cleanup failed: $detail';
  }

  @override
  String get cleanupProxyRestored => 'Direct connection restored';

  @override
  String get cleanupCaNeedsReimport =>
      'The certificate must be regenerated and installed again';

  @override
  String get hubCategoryDns => 'DNS services';

  @override
  String get hubProviderManagement => 'Resolver management';

  @override
  String get hubProviderManagementDescription =>
      'Configure and manage DoH, DoT and classic DNS resolvers';

  @override
  String get hubBootstrap => 'Bootstrap DNS';

  @override
  String get hubBootstrapDescription =>
      'Configure the bootstrap DNS nodes used to resolve encrypted upstream hostnames';

  @override
  String get hubResolution => 'Resolution mode';

  @override
  String get hubResolutionDescription =>
      'Pick single, smart, fastest-response or try-in-order resolution';

  @override
  String get hubCache => 'Cache settings';

  @override
  String get hubCacheDescription =>
      'Configure the DNS cache switch, policy and TTL bounds';

  @override
  String get hubCategoryRules => 'Policy and rules';

  @override
  String get hubRuleControl => 'Rule control';

  @override
  String get hubRuleControlDescription =>
      'Manage the blocking switches and online rule subscriptions in one place';

  @override
  String get hubBlocklist => 'Block list';

  @override
  String get hubBlocklistDescription =>
      'Your own blocked domains; matches get the block response';

  @override
  String get hubAllowlist => 'Allow list';

  @override
  String get hubAllowlistDescription =>
      'Your own allowed domains, exempt from every rule';

  @override
  String get hubRewrite => 'Rewrite list';

  @override
  String get hubRewriteDescription =>
      'Point custom domains at a specific IPv4/IPv6 address or CNAME';

  @override
  String get hubCategoryNetwork => 'Network control';

  @override
  String get hubAppTraffic => 'App traffic';

  @override
  String get hubAppTrafficDescription =>
      'Connection counts and up/down traffic per app';

  @override
  String get hubAppRules => 'Per-app rules';

  @override
  String get hubAppRulesDescription =>
      'Give one app its own domain allow list and network rules';

  @override
  String get hubBlockedApps => 'Blocked apps';

  @override
  String get hubBlockedAppsDescription =>
      'Block all outbound traffic of the chosen apps at the local tunnel';

  @override
  String get hubExcludedApps => 'Excluded apps';

  @override
  String get hubExcludedAppsDescription =>
      'Let the chosen apps bypass DITING and use the network directly';

  @override
  String get hubCategoryAdvanced => 'Advanced and diagnostics';

  @override
  String get hubHttpsInspection => 'HTTPS inspection';

  @override
  String get hubHttpsInspectionDescription =>
      'Decrypt and inspect HTTP(S) traffic of selected apps, with domain and URL filtering';

  @override
  String get hubOutboundProxy => 'Outbound proxy';

  @override
  String get hubOutboundProxyDescription =>
      'Forward filtered traffic to a local SOCKS5 or HTTP proxy';

  @override
  String get hubDiagnostics => 'Network diagnostics';

  @override
  String get hubDiagnosticsDescription =>
      'DNS queries, ping latency tests and connectivity diagnostics';

  @override
  String get hubAiAnalysis => 'AI analysis';

  @override
  String get hubAiAnalysisDescription =>
      'Configure an LLM endpoint and key for log review and traffic analysis';

  @override
  String get hubCategoryInterface => 'Interface and settings';

  @override
  String get hubAppearance => 'Appearance';

  @override
  String get hubAppearanceDescription =>
      'Customise the day/night mode, palette, component opacity and wallpaper';

  @override
  String get hubProviderVisibility => 'Resolver visibility';

  @override
  String get hubProviderVisibilityDescription =>
      'Choose which resolvers appear in the home resolver list';

  @override
  String get hubHiddenFeatures => 'Hidden features';

  @override
  String get hubHiddenFeaturesDescription =>
      'Choose which cards the feature hub shows; nothing changes at runtime';

  @override
  String get hubOtherSettings => 'Other settings';

  @override
  String get hubOtherSettingsDescription =>
      'Global options such as language, foreground/background behaviour and notifications';

  @override
  String get hubCategoryData => 'Data and maintenance';

  @override
  String get hubLogs => 'Logs';

  @override
  String get hubLogsDescription =>
      'Live resolution statistics, request details and log export';

  @override
  String get hubBackup => 'Backup and migration';

  @override
  String get hubBackupDescription =>
      'Export and import resolvers, rule subscriptions and personal settings';

  @override
  String get hubDataCleanup => 'Data cleanup';

  @override
  String get hubDataCleanupDescription =>
      'Delete caches, logs or domain and address filter rules';

  @override
  String get hubTroubleshooting => 'Troubleshooting';

  @override
  String get hubTroubleshootingDescription =>
      'Export crash logs and capture runtime logs to send to the developer';

  @override
  String get hubCategoryAbout => 'About DITING';

  @override
  String get hubAbout => 'About';

  @override
  String get hubAboutDescription =>
      'Version information, update checks, source links and contributor lists';

  @override
  String get hubSponsor => 'Sponsor';

  @override
  String get hubSponsorDescription =>
      'Support the ongoing maintenance and development of DITING';

  @override
  String get hubSponsors => 'Sponsors';

  @override
  String get hubSponsorsDescription =>
      'Thanks to everyone who supports the project';

  @override
  String get hubContributors => 'Contributors';

  @override
  String get hubContributorsDescription =>
      'Thanks to everyone who contributed code and ideas';

  @override
  String get fontSizeSmall => 'Small';

  @override
  String get fontSizeStandard => 'Standard';

  @override
  String get fontSizeLarge => 'Large';

  @override
  String get fontSizeExtraLarge => 'Extra large';

  @override
  String get fontSizeFooter =>
      'The text size scales body copy, titles and list rows together without touching system settings; the layout follows it immediately, no restart needed.';

  @override
  String get fontSizePreview => 'Live preview';

  @override
  String get appearancePoem => 'Hear every sound, tell clear from murky';

  @override
  String get appearancePoemBody =>
      'Connectivity, rule matches and device state, all explained on one page.';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get appearanceInterfaceSection => 'Interface';

  @override
  String get appearanceHomeOpacitySubtitle =>
      'Opacity of interactive components and text';

  @override
  String get appearancePureBlackOn =>
      'Dark surfaces collapse to pure black, saving power on OLED';

  @override
  String get appearancePureBlackOff => 'Available once dark mode is on';

  @override
  String get appearanceHomeSection => 'Home content';

  @override
  String get appearanceHomeSentenceSubtitle =>
      'One sentence each for running and stopped';

  @override
  String get appearanceNotification => 'Notification';

  @override
  String get appearanceNotificationSubtitle =>
      'Persistent notification, live rate and custom text';

  @override
  String get appearanceBackgroundSection => 'Background and motion';

  @override
  String get appearanceHapticSubtitle =>
      'A short vibration when switching tabs';

  @override
  String get appearanceBottomBarStyleFloating => 'Floating above the page';

  @override
  String get appearanceBottomBarStyleDocked => 'Docked at the bottom';

  @override
  String get appearanceTabTransitionSubtitle =>
      'Animation used when switching tabs';

  @override
  String get appearanceMotionFooter =>
      'Style, animation and glass only apply to the floating bar; the docked bar stays solid.';

  @override
  String get appearancePaletteGoldLegacy =>
      'Stored value keeps the legacy indigo';

  @override
  String get appearancePaletteFooter =>
      'The palette only supplies a seed; the screen shows the full HCT-derived role set. The legacy app had no custom picker, so there is none here.';

  @override
  String fontFamilySizeSubtitle(Object percent) {
    return '$percent% now';
  }

  @override
  String get fontFamilySystemDefault =>
      'Follows the host platform\'s interface font; the safest choice';

  @override
  String get fontFamilyImported => 'Imported third-party font';

  @override
  String get fontFamilyEmpty =>
      'No imported fonts yet. Once imported you can switch here; font files stay on this device.';

  @override
  String get fontFamilyFooter =>
      'Imported fonts only affect this device and fall back to the system default when deleted.';

  @override
  String get fontFamilyLocalOnly =>
      'The choice only affects this device and never changes server-side rules.';

  @override
  String get fontFamilyImportFailed => 'Import failed';

  @override
  String get fontFamilyDeleteTitle => 'Delete font';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String fontFamilyDeleteConfirm(Object name) {
    return 'After deleting \"$name\", the interface falls back to the system default font.';
  }

  @override
  String get fontFamilyImport => 'Import font';

  @override
  String get fontFamilyReading => 'Reading the font file…';

  @override
  String get fontFamilyPickFile => 'Pick a TTF / OTF file on this device';

  @override
  String get notificationPersistentSection => 'Persistent notification';

  @override
  String get notificationPersistentFooter =>
      'When off, no persistent notification is shown while the service runs, so the system may reclaim the process sooner.';

  @override
  String get notificationPersistent => 'Persistent notification';

  @override
  String get notificationPersistentSubtitle =>
      'Keeps an unswipeable notification while the service runs';

  @override
  String get notificationShowSpeed => 'Show live rate';

  @override
  String get notificationShowSpeedSubtitle =>
      'Shows the current up/down rate in the notification';

  @override
  String get notificationTextRunning => 'When the DNS service is on';

  @override
  String get notificationTextStopped => 'When the DNS service is off';

  @override
  String get notificationTextHint => 'Leave empty to use the default text';

  @override
  String get notificationTextFooter =>
      'Empty fields use the default text; the wording only affects the notification, never the service.';

  @override
  String get notificationPermissions => 'Permissions';

  @override
  String get notificationSystemPermission => 'System notification permission';

  @override
  String get notificationSystemPermissionSubtitle =>
      'Opens the system notification settings';

  @override
  String get backgroundTitle => 'App background';

  @override
  String get backgroundSection => 'Custom background';

  @override
  String get backgroundFooter =>
      'Wallpapers stay on this device and are never exported with backups.';

  @override
  String get backgroundEnable => 'Enable custom background';

  @override
  String get backgroundPickFirst => 'Add an image first';

  @override
  String get backgroundBehindPages => 'Puts a wallpaper behind every page';

  @override
  String get backgroundAddImage => 'Add image';

  @override
  String get backgroundAddImageSubtitle => 'Pick one from the gallery';

  @override
  String get backgroundAdded => 'Added wallpapers';

  @override
  String get backgroundAddedFooter => 'Tap to switch, long-press to delete.';

  @override
  String get backgroundEmpty => 'No background image yet';

  @override
  String get backgroundEmptyDescription =>
      'Tap \"Add image\" and pick one from the gallery.';

  @override
  String get backgroundDeleteTitle => 'Delete wallpaper';

  @override
  String get backgroundDeleteConfirm => 'Delete this wallpaper?';

  @override
  String get foregroundTitle => 'Foreground and background';

  @override
  String get foregroundPrivacySection => 'Background and privacy';

  @override
  String get foregroundPrivacyFooter =>
      'Hiding in the background removes the app from the recent tasks list; open it again from the home screen.';

  @override
  String get foregroundHide => 'Hide in background';

  @override
  String get foregroundHideSubtitle => 'Not shown in the recent tasks list';

  @override
  String get foregroundRouting => 'Routing';

  @override
  String get foregroundBypassLan => 'Bypass LAN';

  @override
  String get foregroundBypassLanSubtitle =>
      'Local subnets and this device stay off the tunnel';

  @override
  String get foregroundStability => 'Stability';

  @override
  String get foregroundBatteryFooter =>
      'With battery optimisation off, the system is less likely to reclaim the service process.';

  @override
  String get foregroundIgnoreBattery => 'Ignore battery optimisation';

  @override
  String get foregroundIgnoreBatterySubtitle =>
      'Ask to whitelist this app in the system';

  @override
  String get dayNightTitle => 'Day/night mode';

  @override
  String get dayNightFollowSystemDescription =>
      'Switches together with the system dark mode';

  @override
  String get dayNightFooter =>
      'Pure black only applies in dark mode; its switch lives in the Interface group of Appearance.';

  @override
  String get homeOpacityTitle => 'Home opacity';

  @override
  String get homeOpacityComponents => 'Interactive components';

  @override
  String get homeOpacityComponentsFooter =>
      'Opacity only affects visibility, not the tap targets of these components.';

  @override
  String get homeOpacityText => 'Text';

  @override
  String get bottomBarHomeSubtitle => 'Home and dashboard';

  @override
  String get bottomBarFeatureHubSubtitle => 'Every feature entry point';

  @override
  String get bottomBarLogDashboardSubtitle => 'Log dashboard';

  @override
  String get bottomBarAppTrafficSubtitle => 'App traffic ranking';

  @override
  String get bottomBarNetworkToolsSubtitle => 'Speed tests and diagnostics';

  @override
  String get bottomBarSettingsSubtitle => 'All settings';

  @override
  String get bottomBarMinimumHint => 'Keep at least 2 items in the bottom bar';

  @override
  String get bottomBarCustomTitle => 'Bottom bar';

  @override
  String bottomBarItemsHeader(Object count, Object max) {
    return 'Bottom bar items ($count/$max)';
  }

  @override
  String bottomBarDragHint(Object max) {
    return 'Drag by the handle on the right or long-press a row to reorder; the order is the bottom bar order from left to right. Keep 2 to $max items: the floating bar splits its width evenly and more would squeeze the icons.';
  }

  @override
  String get bottomBarDisabled => 'Not in use';

  @override
  String get bottomBarNewItemFooter =>
      'Newly enabled items go to the far right.';

  @override
  String get bottomBarFeel => 'Feel';

  @override
  String get homeSentenceTitle => 'Home sentences';

  @override
  String get homeSentenceFooter =>
      'Both fields may stay empty; when empty, no sentence is shown in that state. The sentence appears once, below the power button.';

  @override
  String get appearancePaletteTitle => 'Palette';

  @override
  String get appearancePaletteInfoLabel => 'Palette';

  @override
  String get appearancePaletteBody =>
      'The palette only supplies a seed; the screen shows the full HCT-derived role set. The legacy app had no custom picker, so there is none here.';

  @override
  String get dayNightInfoLabel => 'Mode';

  @override
  String get appearanceFontSizeLabel => 'Text size';

  @override
  String appearanceFontSizeCurrent(Object percent) {
    return '$percent% now';
  }

  @override
  String get appearanceFontSection => 'Font';

  @override
  String appearanceFontImported(Object name) {
    return 'Imported $name';
  }

  @override
  String appearanceFontDeleted(Object name) {
    return 'Deleted $name';
  }

  @override
  String appearanceBottomBarMax(Object max) {
    return 'At most $max bottom bar items';
  }

  @override
  String appearanceBottomBarHeader(Object count, Object max) {
    return 'Bottom bar items ($count/$max)';
  }

  @override
  String appearanceBottomBarDragBody(Object max) {
    return 'Drag by the handle on the right or long-press a row to reorder; the order is the bottom bar order from left to right. Keep 2 to $max items: the floating bar splits its width evenly and more would squeeze the icons.';
  }

  @override
  String appearanceBottomBarSelected(Object count) {
    return '$count selected; 2–4 are allowed';
  }

  @override
  String get appearanceHaptic => 'Bottom bar haptics';

  @override
  String get appearancePureBlack => 'Pure black';

  @override
  String get appearanceBottomBarStyle => 'Bottom bar style';

  @override
  String get appearanceTabTransition => 'Tab transition';

  @override
  String get appearanceLiquidGlass => 'Liquid glass';

  @override
  String get fontFamilyTitle => 'Font settings';

  @override
  String get fontSizeRestoreDefaults => 'Restore defaults';

  @override
  String get fontFamilyHapticSubtitle =>
      'A short vibration when switching tabs';

  @override
  String get ruleKindBlockTitle => 'Block list';

  @override
  String get ruleKindBlockSummary => 'Block matching domains';

  @override
  String get ruleKindAllowTitle => 'Allow list';

  @override
  String get ruleKindAllowSummary => 'Let matching domains through';

  @override
  String get ruleKindRewriteTitle => 'Rewrite';

  @override
  String get ruleKindRewriteSummary => 'Rewrite DNS answers';

  @override
  String get ruleSourceUser => 'User defined';

  @override
  String get ruleSourceSubscription => 'Rule subscription';

  @override
  String get ruleSourcePreset => 'Built-in preset';

  @override
  String get rulePatternRequired => 'The rule cannot be empty';

  @override
  String get ruleAllowNeedsAllowlist =>
      'This is an allow rule; add it to the allow list instead';

  @override
  String get ruleAlreadyExists => 'This rule already exists';

  @override
  String get ruleDomainHint => 'Domain, e.g. cdn.example.com';

  @override
  String get ruleTargetRequired => 'The target cannot be empty';

  @override
  String get ruleTargetHint => 'Target, e.g. 10.0.0.8';

  @override
  String get ruleImportant => 'Important';

  @override
  String get ruleReadOnly => 'Read only';

  @override
  String get ruleEdit => 'Edit rule';

  @override
  String get ruleDelete => 'Delete rule';

  @override
  String get batchImportDone => 'Import finished';

  @override
  String get batchAddTitle => 'Add rules in bulk';

  @override
  String get batchTarget => 'Import into';

  @override
  String get batchTargetTable => 'Target rule list';

  @override
  String get batchTargetTableSubtitle =>
      'Imported rules go into the selected list';

  @override
  String get batchPlaceholder =>
      'One rule per line, for example:\n||ads.example.com^\n\nBlank lines are ignored and duplicates are skipped automatically.';

  @override
  String get batchImportable => 'Importable';

  @override
  String get batchDuplicated => 'Duplicated';

  @override
  String get batchInvalid => 'Invalid';

  @override
  String get batchInvalidHeader => 'These rules failed validation';

  @override
  String get batchDuplicateHeader => 'Already present, will be skipped';

  @override
  String get ruleClearCustomTitle => 'Clear custom rules';

  @override
  String get commonClearAll => 'Clear';

  @override
  String get ruleResetDefault => 'Reset the default allow list';

  @override
  String get commonReset => 'Reset';

  @override
  String get rulePresetProtectedTitle => 'Preset rules are protected';

  @override
  String get ruleAllowEditTitle => 'Allow editing the default allow list?';

  @override
  String get ruleAllowEditConfirm => 'Enable anyway';

  @override
  String get ruleTotal => 'Total rules';

  @override
  String get ruleEnabled => 'Enabled';

  @override
  String get ruleRewriteEntries => 'Rewrite entries';

  @override
  String get ruleCustom => 'Custom';

  @override
  String get ruleAllowEditDefault => 'Allow editing the default allow list';

  @override
  String get ruleAllowEditDefaultSubtitle =>
      'When off, preset rules are read-only so the allow list cannot widen by accident';

  @override
  String get ruleNoMatch => 'No matching rules';

  @override
  String get ruleNoMatchDescription => 'Try another keyword or filter';

  @override
  String get ruleAll => 'All';

  @override
  String get formIssuesTitle => 'A few things need fixing';

  @override
  String get formSave => 'Save';

  @override
  String get formProcessing => 'Working…';

  @override
  String get formAdd => 'Add';

  @override
  String get formDelete => 'Delete';

  @override
  String get formHelp => 'Help';

  @override
  String get formGotIt => 'Got it';

  @override
  String get rulePatternHint => 'Rule text, e.g. ||ads.example.com^';

  @override
  String ruleBatchImported(Object count, Object kind) {
    return 'Imported $count rules into $kind.';
  }

  @override
  String ruleBatchSkippedDuplicates(Object count) {
    return 'Skipped $count duplicate rules.';
  }

  @override
  String ruleBatchAllowRejected(Object count) {
    return '$count allow rules (with #@#) were not imported: allow rules belong in the allow list.';
  }

  @override
  String ruleBatchImportCount(Object count) {
    return 'Import $count';
  }

  @override
  String ruleBatchMoreDuplicates(Object count) {
    return 'and $count more';
  }

  @override
  String ruleAddForKind(Object kind) {
    return 'Add a $kind rule';
  }

  @override
  String get ruleEditDefaultPreset => 'Edit a default preset rule';

  @override
  String ruleEditForKind(Object kind) {
    return 'Edit a $kind rule';
  }

  @override
  String ruleDeletePresetMessage(Object pattern) {
    return '\"$pattern\" is a built-in preset rule; resetting the defaults restores it.';
  }

  @override
  String ruleDeleteSubscriptionMessage(Object name, Object pattern) {
    return '\"$pattern\" comes from the subscription \"$name\" and may return on the next update.';
  }

  @override
  String ruleDeleteUserMessage(Object pattern) {
    return 'Delete \"$pattern\"? This cannot be undone.';
  }

  @override
  String ruleClearCustomMessage(Object kind) {
    return 'All user-defined $kind rules will be deleted; subscription and preset rules are untouched.';
  }

  @override
  String get ruleResetMessage =>
      'Restores the built-in preset rules; rules you added and subscription rules are kept.';

  @override
  String get rulePresetProtectedMessage =>
      'Default allow list rules are read-only. Turn on \"Allow editing the default allow list\" at the top of the page before changing or deleting them.';

  @override
  String get ruleAllowEditMessage =>
      'The allow list lets traffic through, so changing it may pass traffic that should be blocked. Enable this only if you understand the risk.';

  @override
  String ruleTally(Object enabled, Object matched) {
    return '$matched total · $enabled enabled';
  }

  @override
  String ruleNoRulesForKind(Object kind) {
    return 'No $kind rules yet';
  }

  @override
  String ruleClearCustomForKind(Object kind) {
    return 'Clear custom $kind';
  }

  @override
  String get subsPickTxt => 'Pick a rule file with the .txt extension';

  @override
  String get subsNoPersistPermission =>
      'The system did not grant persistent read access, so the file must be picked again on update';

  @override
  String get subsGroupNameRequired => 'The group name cannot be empty';

  @override
  String get subsEdit => 'Edit subscription';

  @override
  String get subsAdd => 'Add subscription';

  @override
  String get subsSaveTooltip => 'Save subscription';

  @override
  String get subsInfoSection => 'Subscription details';

  @override
  String get subsSourceType => 'Source type';

  @override
  String get subsSourceLocalPick => 'Pick a .txt file from storage';

  @override
  String get subsSourceRemoteDownload => 'Download the rule body from a URL';

  @override
  String get subsLocalRuleFile => 'Local rule file';

  @override
  String get subsLocalFileSubscription => 'Local file subscription';

  @override
  String get subsPickFile => 'Pick a rule file';

  @override
  String get subsLocalFileHint => 'Only .txt; tap to pick from storage';

  @override
  String get subsLocalFileRepick => 'Tap to pick another file';

  @override
  String get subsChoose => 'Choose';

  @override
  String get subsNameOptional => 'Name (optional)';

  @override
  String get subsNameEmptyFileName => 'Leave empty to use the file name';

  @override
  String get subsUrl => 'Subscription URL';

  @override
  String get subsNameEmptyUrlTail =>
      'Leave empty to use the last part of the URL';

  @override
  String get subsRuleType => 'Rule type';

  @override
  String get subsKindHostsHint =>
      'Only hosts entries and CNAME rewrites are imported';

  @override
  String get subsKindDomainHint =>
      'Domain rules and allow/block lists are imported';

  @override
  String get subsGroupHint =>
      'Groups only affect filtering and bulk updates on this page; you can change them later.';

  @override
  String get subsNewGroupShort => '+ New';

  @override
  String get subsMirrorTemplateFooter =>
      'A mirror rewrites the subscription URL with its prefix, which speeds up slow sources such as GitHub.';

  @override
  String get subsAddMirrorTemplate => 'Add a mirror template';

  @override
  String get subsAddMirrorTemplateSubtitle =>
      'No templates yet; save a commonly used mirror prefix first';

  @override
  String get subsMirrorFooter =>
      'Downloads try the mirror first and fall back to the original URL when enabled.';

  @override
  String get subsUseMirrorTemplate => 'Use a mirror template';

  @override
  String get subsUseMirrorTemplateSubtitle =>
      'Rewrite the download URL when the source is slow or rate limited';

  @override
  String get subsMirrorTemplate => 'Mirror template';

  @override
  String get subsMirrorFallback => 'Fall back to direct';

  @override
  String get subsMirrorFallbackSubtitle =>
      'Use the original URL when the mirror fails';

  @override
  String get subsEffectiveUrl => 'Requested URL';

  @override
  String get subsNothingToUpdate => 'No remote subscriptions to update';

  @override
  String get subsDeleteTitle => 'Delete subscription';

  @override
  String get subsRenameTitle => 'Rename subscription';

  @override
  String get subsNameRequired => 'The name cannot be empty';

  @override
  String get subsTitle => 'Subscriptions';

  @override
  String get subsUpdateAll => 'Update all';

  @override
  String get subsCount => 'Subscriptions';

  @override
  String get subsRuleCount => 'Stored rules';

  @override
  String get subsAbnormal => 'Errors';

  @override
  String get subsUpdating => 'Updating subscriptions…';

  @override
  String get subsEmptyLabel => 'No subscriptions yet';

  @override
  String get subsEmptyDescription =>
      'Subscriptions maintain rules in bulk: an update downloads the body, parses it into the rule database and blocking follows.';

  @override
  String get subsUpdateFooter =>
      'An update downloads the body, parses it into block/allow and rewrite rules and stores them, replacing what the subscription contributed last time. Element-hiding rules are not injected by this app and are not counted.';

  @override
  String get subsAllGroups => 'All';

  @override
  String get subsNewGroupTitle => 'New group';

  @override
  String get subsEditRemoteHint =>
      'Changing the URL or rule type downloads again immediately and replaces this subscription\'s rules; the source type and local file cannot be changed.';

  @override
  String get subsEditLocalHint =>
      'Local files are read through the system picker and the app only keeps read access; allow/block and hosts subscriptions with the same name do not affect each other.';

  @override
  String get subsAddRemoteHint =>
      'One URL can back both an allow/block and a hosts subscription (uniqueness is URL + type); saving downloads the body once and stores it.';

  @override
  String get subsKindLabel => 'Rule type';

  @override
  String get subsGroupLabel => 'Group';

  @override
  String get subsMirrorTitle => 'Mirror';

  @override
  String subsDeleteMessage(Object name) {
    return 'Deleting \"$name\" cannot be undone.\n\nIt also removes every rule this subscription contributed (source tag sub_<id>).';
  }

  @override
  String subsTotal(Object count) {
    return '$count subscriptions';
  }

  @override
  String subsGroupTotal(Object count, Object group) {
    return '$count subscriptions in \"$group\"';
  }

  @override
  String get subsUpdateNow => 'Update now';

  @override
  String get subsReimport => 'Re-import file';

  @override
  String get subsRename => 'Rename';

  @override
  String subsConsecutiveFailures(Object count) {
    return 'Failed $count times in a row';
  }

  @override
  String get subsMirrorFallbackShort => 'Mirror · fallback on';

  @override
  String get subsMirrorNoFallback => 'Mirror · no fallback';

  @override
  String get subsLastUpdateFailed => 'Last update failed';

  @override
  String get subsNeverUpdated => 'Never updated successfully';

  @override
  String subsRuleCountValue(Object count) {
    return '$count rules';
  }

  @override
  String subsRulesStored(Object action, Object count) {
    return '$count rules stored; $action the rules this subscription contributed.';
  }

  @override
  String get subsActionRemote => 'an update downloads again and replaces';

  @override
  String get subsActionLocal =>
      're-importing reads the file again and replaces';

  @override
  String get subsPickRuleFile => 'Pick a rule file';

  @override
  String get subsChange => 'Change';

  @override
  String get subsGroupShort => '+ Group';

  @override
  String subsMirrorName(Object mirror) {
    return 'Mirror $mirror';
  }

  @override
  String get trafficPackageName => 'Package';

  @override
  String get trafficAppName => 'App name';

  @override
  String get trafficDown => 'Download';

  @override
  String get trafficUp => 'Upload';

  @override
  String get trafficTotal => 'Total';

  @override
  String get trafficShare => 'Share';

  @override
  String get trafficStartDate => 'First day';

  @override
  String get trafficLastUpdate => 'Last updated';

  @override
  String get trafficAttributionFooter =>
      'Traffic is attributed to apps by UID (the upstream TrafficAttributionDialog rule); processes of one app are merged.';

  @override
  String get trafficAttributionTitle => 'How traffic is attributed';

  @override
  String get trafficScopeTitle => 'What is counted';

  @override
  String get trafficScopeBody =>
      'Traffic is attributed by UID: the engine accumulates each app\'s bytes by UID and stores them per day (table app_traffic_daily, keyed by date + package). No package matching is involved, so apps sharing a UID are merged.';

  @override
  String get trafficWhyLowerTitle =>
      'Why the numbers are lower than in system settings';

  @override
  String get trafficWhyLowerBody =>
      'Only traffic that goes through the local tunnel is counted; direct traffic outside the tunnel is not. System settings cover all interfaces.';

  @override
  String get trafficWhyNoRateTitle => 'Why there is no live rate';

  @override
  String get trafficWhyNoRateBody =>
      'A live rate needs a per-second series from the core; the daily table only holds date, package and cumulative bytes, with no rate column. That is why the session window and the live-rate sort are unavailable and there is no rate chart: every number shown is a real byte count.';

  @override
  String get trafficRetentionTitle => 'How long records are kept';

  @override
  String get trafficRetentionBody =>
      'Rows are kept per day and expired ones are removed by the native cleanup policy; the all-history window sums every date still in the table.';

  @override
  String get trafficSystemAppsTitle => 'How system apps are recognised';

  @override
  String get trafficSystemAppsBody =>
      'The traffic table has no system-app flag, so the page uses the same prefix list as the legacy SystemAppClassifier (android, com.android.*, vendor preinstalls and so on). The hide-system-apps switch is stored in traffic_stats_hide_system_apps.';

  @override
  String get trafficUpstreamFooter =>
      'Upstream equivalents are ui/traffic/TrafficAttributionDialog.kt and AppTrafficDetailDialog.kt; the numbers here come from app_traffic_daily.';

  @override
  String get trafficTitle => 'Traffic';

  @override
  String get trafficClearHistory => 'Clear history';

  @override
  String get trafficRefresh => 'Refresh';

  @override
  String get trafficAttribution => 'Attribution';

  @override
  String get trafficLoadFailed => 'Traffic records cannot be read';

  @override
  String get trafficLoading => 'Reading traffic records';

  @override
  String get trafficAppCount => 'Apps';

  @override
  String get trafficAppCountUnit => '';

  @override
  String get trafficNoData => 'No traffic data yet';

  @override
  String get trafficNoMatchingApps => 'No matching apps';

  @override
  String get trafficRankingTitle => 'App traffic ranking';

  @override
  String trafficShareFooter(Object range, Object window) {
    return 'Shares use the total bytes (download + upload) for $window; $range. Tap a row to see that app\'s breakdown.';
  }

  @override
  String get trafficClearTitle => 'Clear all traffic records?';

  @override
  String get trafficConfirmClear => 'Clear';

  @override
  String get trafficClearBody =>
      'This clears every stored per-app traffic record and cannot be undone.';

  @override
  String get trafficRangeAllHistory => 'covering all history';

  @override
  String get trafficSessionRange => 'This session';

  @override
  String get trafficSessionUnavailable =>
      'The session window needs per-session traffic from the core; only daily records exist here';

  @override
  String get trafficLiveRate => 'By live rate';

  @override
  String get trafficHideSystemApps => 'Hide system apps';

  @override
  String get trafficSearchHint => 'Search by app name or package';

  @override
  String get trafficAllHistory => 'All history';

  @override
  String get trafficLiveRateUnavailable =>
      'The live-rate sort needs per-second rates; the daily table has no rate column';

  @override
  String get trafficHideSystemAppsSubtitle =>
      'Recognised by system flag and vendor preinstall prefixes; hidden apps are left out of the ranking';

  @override
  String trafficWindowLabelDate(Object date) {
    return 'Statistics for $date';
  }

  @override
  String trafficWindowLabelRange(Object end, Object start) {
    return 'Statistics from $start to $end';
  }

  @override
  String trafficShareWindow(Object range, Object window) {
    return 'Shares use the total bytes (download + upload) for $window; $range. Tap a row to see that app\'s breakdown.';
  }

  @override
  String trafficTotalApps(Object count, Object total) {
    return '$count apps generated traffic · $total total';
  }

  @override
  String trafficSearchEmpty(Object search) {
    return 'No app name or package contains \"$search\".';
  }

  @override
  String trafficHiddenCount(Object count) {
    return '$count apps are hidden by \"Hide system apps\"; turn it off to see them.';
  }

  @override
  String get trafficNoRecordsBody =>
      'Traffic is summed per day by the native side; once the tunnel runs and carries traffic, each app\'s download and upload bytes appear here.';

  @override
  String trafficNoRecordsForWindow(Object window) {
    return 'No traffic records for \"$window\" yet. Records are summed per day, so try another window or run the tunnel first.';
  }

  @override
  String trafficOptionUnavailable(Object label, Object reason) {
    return '\"$label\" is unavailable: $reason';
  }

  @override
  String get trafficNoSourceReason => 'no matching data source here';

  @override
  String trafficCleared(Object count) {
    return 'Cleared $count traffic records';
  }

  @override
  String trafficClearFailed(Object detail) {
    return 'Clearing failed: $detail';
  }

  @override
  String trafficShareBarTooltip(Object sort, Object value) {
    return 'The bar length is this row\'s share of the window total under \"$sort\" (currently $value), matching the list order.';
  }

  @override
  String get trafficWhyDaemonTitle =>
      'Why do system settings attribute all traffic to DITING?';

  @override
  String get trafficWhyDaemonBody =>
      'Android\'s VPN model attributes proxied outbound traffic to the daemon. DITING does not use traffic behind your back; tap to see what is counted.';

  @override
  String get trafficLiveRateTitle => 'Live rate';

  @override
  String trafficNoLiveRate(Object window) {
    return 'This mode does not measure a live rate: express mode\'s narrow route bypasses the engine\'s traffic counters and there is no cumulative table for it. The $window download/upload figures and the ranking below are still real numbers.';
  }

  @override
  String trafficLiveRateBody(Object window) {
    return 'Per-second rates from the engine (this session), the same source as the persistent notification. The $window download/upload figures are cumulative bytes from `app_traffic_daily`; the two use different scopes and need not match.';
  }

  @override
  String get trafficSearchPlaceholder => 'Search app or package...';

  @override
  String trafficWindowDown(Object window) {
    return '$window download';
  }

  @override
  String trafficWindowUp(Object window) {
    return '$window upload';
  }

  @override
  String get obsRequestsTitle => 'Requests';

  @override
  String get obsSource => 'Source';

  @override
  String get obsStatus => 'Status';

  @override
  String get obsRefresh => 'Refresh';

  @override
  String get obsClearFilter => 'Clear filters';

  @override
  String get obsLoadFailed => 'Request records cannot be read';

  @override
  String get obsLoading => 'Reading request records';

  @override
  String get obsNoRecords => 'No request records yet';

  @override
  String get obsNoMatchingRequests => 'No requests match the filter';

  @override
  String get obsNoRecordsBody =>
      'Requests made by apps are recorded here; HTTPS records need traffic inspection enabled.';

  @override
  String get obsResetFilter => 'Reset filters';

  @override
  String get obsRecordsHeader => 'Request records';

  @override
  String get obsRetry => 'Retry';

  @override
  String get obsBypassedDns => 'Direct, bypassing the DNS resolution flow';

  @override
  String get obsBlockedDns =>
      'Blocked by a filter rule before any query was sent';

  @override
  String get obsRewrittenDns =>
      'Matched a rewrite rule and returned the rewritten answer';

  @override
  String get obsErrorDns => 'The lookup failed and produced no answer';

  @override
  String get obsPassedDns => 'Resolved by the rules and answered normally';

  @override
  String get obsPassedHttps => 'Forwarded successfully';

  @override
  String get obsRewrittenHttps =>
      'Matched a rewrite rule and forwarded the rewritten request';

  @override
  String get obsBlockedHttps => 'Blocked by a filter rule before connecting';

  @override
  String get obsBypassedHttps => 'Forwarded without decryption (bypass)';

  @override
  String get obsErrorHttps => 'Handling failed';

  @override
  String get obsNoRuleHttps => 'No rule matched (or none was recorded)';

  @override
  String get obsNone => 'None';

  @override
  String get obsRequestDetailTitle => 'Request details';

  @override
  String get obsCachedChip => 'Cache';

  @override
  String get obsBasicInfo => 'Basics';

  @override
  String get obsTime => 'Time';

  @override
  String get obsProtocol => 'Protocol';

  @override
  String get obsAppPackage => 'Package';

  @override
  String get obsResolved => 'Resolved';

  @override
  String get obsElapsed => 'Elapsed';

  @override
  String get obsBlockingSubscription => 'Blocking subscription';

  @override
  String get obsRuleMatch => 'Rule match';

  @override
  String get obsRule => 'Rule';

  @override
  String get obsHandling => 'Handling';

  @override
  String get obsError => 'Error';

  @override
  String get obsAiAnalysis => 'AI analysis';

  @override
  String get obsRawRecord => 'Raw record';

  @override
  String get obsRawRecordFooter =>
      'The verbatim message field written by the engine.';

  @override
  String get obsFailedHint =>
      'For failed requests, check the matching active connections on the Connections page.';

  @override
  String get obsRulesHint =>
      'Rules added here can be reviewed and undone on the Rules page.';

  @override
  String get obsCacheHit => 'Cache hit';

  @override
  String obsCopied(Object text) {
    return 'Copied $text';
  }

  @override
  String get obsCopyAddress => 'Copy address';

  @override
  String get obsCopyDomain => 'Copy domain';

  @override
  String get obsInBlocklist => 'Already blocked';

  @override
  String get obsAddToBlocklist => 'Block it';

  @override
  String get obsInAllowlist => 'Already allowed';

  @override
  String get obsAddToAllowlist => 'Allow it';

  @override
  String get obsIpOnlyFooter =>
      'This record only has an IP address, which domain rules cannot match, so it cannot be added to the lists.';

  @override
  String get obsAnalyzeRequest => 'Analyse this request';

  @override
  String get obsAnalyzeRequestBody =>
      'Use the configured model to judge ownership, risk and next steps';

  @override
  String obsCopiedHost(Object host) {
    return 'Copied $host';
  }

  @override
  String obsAddedToKind(Object domain, Object kind) {
    return 'Added $domain to $kind';
  }

  @override
  String obsAlreadyInKind(Object domain, Object kind) {
    return '$domain is already in $kind';
  }

  @override
  String obsCurrentFilter(Object filter) {
    return 'Filtered by: $filter.';
  }

  @override
  String obsFooterCount(
    Object count,
    Object failed,
    Object filter,
    Object more,
  ) {
    return '$count records, $failed failed$filter$more. Tap a row to see the rule match and outcome.';
  }

  @override
  String obsFooterFilter(Object filter) {
    return ' (filtered by: $filter)';
  }

  @override
  String get obsFooterMore => '; scroll for more';

  @override
  String get obsFooterAll => '; all loaded';

  @override
  String get logsSubStatsTitle => 'Subscription block rate';

  @override
  String get logsRefresh => 'Refresh';

  @override
  String get logsTimeRange => 'Time range';

  @override
  String get logsSubStatsFooter =>
      'The block rate is this subscription\'s blocked requests as a share of all recorded requests (DNS + HTTPS) in the selected range.';

  @override
  String get logsOverview => 'Overview';

  @override
  String get logsSubStatsLoadFailed => 'Block statistics cannot be read';

  @override
  String get logsLoadingStats => 'Loading statistics';

  @override
  String get logsBlockingSubs => 'Blocking subscriptions';

  @override
  String get logsMissingSubColumn =>
      'The database has no subscription tag column';

  @override
  String get logsMissingSubColumnBody =>
      'This database predates subscription block statistics, so log rows have no blockSubscriptionId. New requests can be counted; history cannot be backfilled.';

  @override
  String get logsAllRecordedRequests => 'All recorded requests';

  @override
  String get logsAllRecordedFooter =>
      'DNS and HTTPS logs combined, including passed, blocked and failed.';

  @override
  String get logsNoBlockingSubs => 'No blocking subscriptions';

  @override
  String get logsNoBlockingSubsBody =>
      'Once a blocking subscription is imported and DNS or HTTPS requests arrive, its block rate appears here.';

  @override
  String get logsBlockingSubsFooter =>
      'Sorted by block count; \"Deleted\" means the subscription is gone but its history is kept.';

  @override
  String get logsExpired => 'Expired';

  @override
  String get logsRaceTitle => 'Race statistics';

  @override
  String get logsRaceFooter =>
      'Only races that actually sent DoH requests are counted; cache hits never appear here.';

  @override
  String get logsRaceLoadFailed => 'Race records cannot be read';

  @override
  String get logsLoadingRace => 'Reading race records';

  @override
  String logsRaceSummary(Object count, Object range) {
    return '$count races in $range.';
  }

  @override
  String get logsRaceEmptyRange => 'No races in the selected range yet.';

  @override
  String get logsRaceRequests => 'Races';

  @override
  String get logsSuccess => 'Succeeded';

  @override
  String get logsAverageElapsed => 'Average time';

  @override
  String get logsStrategyOverview => 'Strategy overview';

  @override
  String get logsStrategyFooter =>
      'Cache hits do not trigger a race and never appear here; the primary hit rate is the share where the primary resolver won and succeeded.';

  @override
  String get logsWinnerProviders => 'Winning resolvers';

  @override
  String get logsNoWinners => 'No winners yet';

  @override
  String get logsNoWinnersBody =>
      'After a successful race the winning resolvers are ranked here by count.';

  @override
  String get logsWinnerFooter =>
      'Sorted by wins; the average time is the mean when that resolver won.';

  @override
  String logsAverageWinLatency(Object latency) {
    return 'Won in $latency on average';
  }

  @override
  String get logsSmartPrimary => 'Smart primary';

  @override
  String get logsSmartPrimaryFooter =>
      'Only meaningful for the smart strategy: the primary hit rate counts queries where the primary resolver won; queries rescued by a fallback are excluded.';

  @override
  String logsPrimaryHit(Object latency, Object percent) {
    return 'Primary hit $percent · average $latency';
  }

  @override
  String get logsDashboardTitle => 'Log dashboard';

  @override
  String get logsModeTooltip => 'Log mode';

  @override
  String get logsRequestsDashboard => 'Request log dashboard';

  @override
  String get logsRequestsDashboardBody =>
      'A live overview of DNS, HTTPS, cache, races and rule blocks';

  @override
  String get logsFocusedDashboard => 'Key request dashboard';

  @override
  String get logsFocusedDashboardBody =>
      'An overview of blocked, failed and bypassed DNS and HTTPS records plus resolution state';

  @override
  String get logsServiceOverview => 'Service and resolution overview';

  @override
  String get logsPrivacyBody =>
      'Privacy mode is on, so no request details are recorded. DNS cache, racing and traffic monitoring keep running.';

  @override
  String get logsCacheTableTitle => 'DNS cache table';

  @override
  String logsCacheLoadFailed(Object detail) {
    return 'The cache table cannot be read: $detail';
  }

  @override
  String get logsLoadingCache => 'Reading the cache table';

  @override
  String get logsCacheEmpty => 'The cache table is empty';

  @override
  String get logsCacheNoMatch => 'No matching cache entries';

  @override
  String get logsCacheEmptyBody =>
      'Successful lookups are written to dns_cache; on a fresh install or right after the tunnel starts the table may still be empty.';

  @override
  String logsCurrentSearch(Object query) {
    return 'Searching: $query';
  }

  @override
  String get logsLiveCache => 'Live cache entries';

  @override
  String get logsNeverHit => 'Never hit';

  @override
  String logsCacheFooter(Object count) {
    return '$count entries sorted by hits and expiry. Entries with less than 30 seconds of TTL are orange. Tap a row for details, to copy the domain, add it to the lists or analyse it with AI.';
  }

  @override
  String get logsBootstrapTitle => 'Bootstrap statistics';

  @override
  String get logsBootstrapFooter =>
      'The success rate is successes ÷ attempts; the average time is weighted by each node\'s attempts.';

  @override
  String get logsBootstrapLoadFailed => 'Bootstrap records cannot be read';

  @override
  String get logsLoadingBootstrap => 'Reading Bootstrap records';

  @override
  String logsBootstrapSummary(Object count, Object range) {
    return '$count Bootstrap probes in $range.';
  }

  @override
  String get logsBootstrapEmptyRange =>
      'No Bootstrap probes in the selected range yet.';

  @override
  String get logsAttempts => 'Attempts';

  @override
  String get logsSuccessRate => 'Success rate';

  @override
  String get logsNodes => 'Nodes';

  @override
  String get logsNoProbes => 'No probes yet';

  @override
  String get logsNoProbesBody =>
      'Enable \"Bootstrap IP\" and generate lookups; each node\'s attempts and success rate appear here.';

  @override
  String get logsNodesFooter =>
      'Sorted by attempts; values are aggregated over the window.';

  @override
  String get logsCacheDetailTitle => 'Cache details';

  @override
  String get logsCacheExpiringBody =>
      'This entry is about to expire; the next lookup will go upstream again';

  @override
  String get logsCacheValidBody =>
      'The entry is valid; hits are answered without going upstream';

  @override
  String get logsExpiring => 'Expiring';

  @override
  String get logsValid => 'Valid';

  @override
  String logsHitTimes(Object count) {
    return '$count hits';
  }

  @override
  String get logsCacheInfo => 'Cache entry';

  @override
  String get logsRecordType => 'Record type';

  @override
  String get logsRemainingTtl => 'Remaining TTL';

  @override
  String get logsOriginalTtl => 'Original TTL';

  @override
  String get logsExpiry => 'Expires at';

  @override
  String get logsHitCount => 'Hits';

  @override
  String get logsLastHit => 'Last hit';

  @override
  String get logsResponseSize => 'Response size';

  @override
  String get logsAnalyzeDomain => 'Analyse this domain';

  @override
  String get logsCacheDetailFooter =>
      'The cache table syncs from engine memory every 10 seconds; this is a snapshot from when the page opened. Rules added here can be reviewed and undone on the Rules page.';

  @override
  String get logsAiInsight => 'AI insight';

  @override
  String get logsNotAnalysed => 'Not analysed';

  @override
  String get logsHasReport => 'Report ready';

  @override
  String get logsAiInsightBody =>
      'Send recent DNS and HTTPS records to the configured model for a summary of anomalies, protection and improvements.';

  @override
  String get logsAnalyseTraffic => 'Analyse recent traffic with AI';

  @override
  String get logsViewFullReport => 'View the full report';

  @override
  String logsModelName(Object model) {
    return 'Model $model';
  }

  @override
  String logsSuccessWith(Object percent) {
    return '$percent succeeded';
  }

  @override
  String logsAverageWith(Object latency) {
    return 'Average $latency';
  }

  @override
  String logsPrimaryHitOnly(Object percent) {
    return 'Primary hit $percent';
  }

  @override
  String logsFallbackUses(Object count) {
    return '$count fallbacks';
  }

  @override
  String logsBootstrapRow(
    Object failures,
    Object ip,
    Object latency,
    Object percent,
  ) {
    return '$ip · $percent succeeded · average $latency$failures';
  }

  @override
  String logsBootstrapFailures(Object count) {
    return ' · $count failed';
  }

  @override
  String logsEntryCount(Object count) {
    return '$count entries';
  }

  @override
  String logsCacheRow(Object count, Object size, Object ttl) {
    return '$ttl · $count hits · $size B';
  }

  @override
  String logsLastHitAt(Object time) {
    return 'Last hit $time';
  }

  @override
  String logsCacheFooterCount(Object count) {
    return '$count entries sorted by hits and expiry. Entries with less than 30 seconds of TTL are orange. Tap a row for details, to copy the domain, add it to the lists or analyse it with AI.';
  }

  @override
  String logsSubStatsRow(Object count, Object percent, Object status) {
    return '$status | $count blocks | $percent';
  }

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutMore => 'More';

  @override
  String get aboutProject => 'Project';

  @override
  String get aboutJoinQq => 'Join the QQ group';

  @override
  String aboutQqGroup(Object number) {
    return 'Group $number';
  }

  @override
  String get aboutSponsor => 'Sponsor';

  @override
  String get aboutCredits => 'Open-source credits';

  @override
  String get aboutCreditsUi =>
      'UI components and interactions are reused from this project';

  @override
  String get aboutCreditsCore =>
      'The Go tunnel core was initially forked from this project';

  @override
  String get aboutCreditsBody =>
      'Both projects are open source under GPL-3.0, and the copyright of their code and design belongs to their authors. Diting\'s UI layer borrows heavily from FlClash, and its tunnel core derives from an early fork of blockads-android; our sincere thanks to their authors and all contributors.';

  @override
  String get aboutSettings => 'Settings';

  @override
  String get aboutStartupCheck => 'Skip the update check at startup';

  @override
  String get aboutStartupCheckOn =>
      'Updates are not checked automatically at startup; you can check manually anytime';

  @override
  String get aboutStartupCheckOff =>
      'New versions are checked automatically at startup';

  @override
  String get aboutDisclaimerEntry => 'Terms and disclaimer';

  @override
  String get aboutDisclaimerEntryBody =>
      'The full software description, how it works and the disclaimer';

  @override
  String get aboutOtherContributors => 'Other contributors';

  @override
  String get aboutSponsorList => 'Sponsors';

  @override
  String get aboutSponsorListBody => 'Thanks to everyone who supported Diting';

  @override
  String get aboutBuilderList => 'Contributors';

  @override
  String get aboutBuilderListBody =>
      'Thanks to everyone who contributed code and ideas';

  @override
  String get aboutInstallerFailed => 'The system installer cannot be launched';

  @override
  String get aboutAppName => 'Diting';

  @override
  String get aboutTagline =>
      'A local-first DNS accelerator and traffic filter built on Android VpnService: simple, open source and ad-free.';

  @override
  String get aboutChecking => 'Checking…';

  @override
  String get aboutCheckUpdate => 'Check for updates';

  @override
  String get aboutDownloading => 'Downloading…';

  @override
  String get aboutInstall => 'Install';

  @override
  String get aboutDownload => 'Download';

  @override
  String get aboutCheckingRelease => 'Checking GitHub Releases';

  @override
  String aboutUpToDate(Object version) {
    return 'You are on the latest version$version';
  }

  @override
  String aboutVersionSuffix(Object version) {
    return ' ($version)';
  }

  @override
  String aboutFoundVersion(Object version) {
    return 'Version $version found';
  }

  @override
  String aboutCurrentSuffix(Object version) {
    return ' (current $version)';
  }

  @override
  String get aboutNew => 'new ';

  @override
  String get aboutNewVersion => 'a new version';

  @override
  String aboutUpdatePackage(Object version) {
    return '$version update package';
  }

  @override
  String aboutLinkCopyFallback(Object url) {
    return 'The browser could not be opened; the link was copied: $url';
  }

  @override
  String get devStressLogs => 'Log stress test';

  @override
  String devStressLogsBody(Object count) {
    return 'Write $count DNS logs into the active log database for real';
  }

  @override
  String get devErrorReport => 'Error reporting self-check';

  @override
  String get devErrorReportBody =>
      'Report a test exception through FlutterError to verify the error pipeline';

  @override
  String get devClearAll => 'Clear all data';

  @override
  String get devClearAllBody =>
      'Delete settings, rules and logs to restore the factory state';

  @override
  String get devVacuum => 'Compact databases';

  @override
  String get devVacuumBody =>
      'Run VACUUM on the three local databases to reclaim space from deleted rows';

  @override
  String get devCancel => 'Cancel';

  @override
  String get devRun => 'Run';

  @override
  String devConfirmBody(Object action) {
    return '$action\n\nThis operation really rewrites local data and cannot be undone.';
  }

  @override
  String devActionFailed(Object action, Object error) {
    return '$action failed: $error';
  }

  @override
  String get devStressNoDb =>
      'Stress test failed: the log database cannot be opened';

  @override
  String devStressDone(Object count, Object file) {
    return 'Stress test finished: $count rows written to $file';
  }

  @override
  String get devTestException =>
      'Test exception triggered from developer options';

  @override
  String get devErrorReported =>
      'A FlutterError was reported: test exception triggered from developer options';

  @override
  String get devVacuumNoDb =>
      'Compaction failed: there are no database files yet';

  @override
  String devVacuumDone(Object files, Object kb) {
    return 'Compacted $files, reclaimed $kb KB';
  }

  @override
  String get devRestartNeeded => 'Restart required';

  @override
  String get devLater => 'Later';

  @override
  String get devQuitNow => 'Quit now';

  @override
  String get devClearAllDone =>
      'All data has been cleared; restart the app to start from the factory state.';

  @override
  String get devOptions => 'Developer options';

  @override
  String get devDiagnostics => 'Diagnostics';

  @override
  String get devIpQuality => 'IP quality';

  @override
  String get devIpQualityBody =>
      'Probe the egress address and how three public sources classify it';

  @override
  String get devRequestLogs => 'Request logs';

  @override
  String get devRequestLogsBody =>
      'Live request records merged from http_request_log and dns_log';

  @override
  String get devLogRetention => 'Log retention';

  @override
  String get devLogRetentionBody =>
      'Log capacity limits and what DNS request logs record';

  @override
  String get devTroubleshoot => 'Troubleshooting';

  @override
  String get devTroubleshootBody =>
      'Export crash logs, or capture and export runtime logs manually';

  @override
  String get devDataCleanup => 'Data cleanup';

  @override
  String get devUnlocked => 'Experimental actions unlocked';

  @override
  String get devLocked => 'The actions below are unavailable while off';

  @override
  String get devWarning =>
      'These actions really rewrite local data (log database, prefs, database files), and \"Clear all data\" cannot be undone; do not enable this in production.';

  @override
  String get devRunning => 'Running…';

  @override
  String get sponsorGithub => 'See sponsorship options on GitHub';

  @override
  String get sponsorReadme => 'Read the sponsorship section in the README';

  @override
  String get sponsorReadmeCopied =>
      'The browser could not be opened; the README link was copied';

  @override
  String get sponsorThanks => 'Acknowledgements';

  @override
  String get sponsorThanksBody => 'Thanks to everyone who supports the project';

  @override
  String get sponsorBuildersBody =>
      'Thanks to everyone who shared ideas and helped test';

  @override
  String get sponsorUsage => 'Every contribution goes towards';

  @override
  String get sponsorUsageNewFeatures => 'Ongoing feature development';

  @override
  String get sponsorUsageBugs => 'Fixing bugs';

  @override
  String get sponsorUsageTokens => 'Buying tokens';

  @override
  String get sponsorFreeWays => 'Even without donating, you can';

  @override
  String get sponsorFreeStar => 'Star the project⭐';

  @override
  String get sponsorFreeIssue => 'File an issue';

  @override
  String get sponsorFreePr => 'Open a pull request';

  @override
  String get sponsorFreeShare => 'Share it with others';

  @override
  String get sponsorFooter => 'Thanks to everyone who supports the project!';

  @override
  String get sponsorBuyDrink => 'Buy the author a drink 🧋';

  @override
  String get sponsorNote =>
      'If this project helps you, you are welcome to buy the author a drink. Please add your nickname in the payment note so you can be added to the sponsor list.';

  @override
  String get sponsorAlipay => 'Alipay';

  @override
  String get sponsorWechat => 'WeChat Pay';

  @override
  String get sponsorNickname => 'Add your nickname';

  @override
  String get sponsorScan => 'Scan to sponsor';

  @override
  String sponsorQrCode(Object label) {
    return '$label QR code';
  }

  @override
  String get sponsorClose => 'Close';

  @override
  String get sponsorNoteShort =>
      'Please add your nickname in the payment note so you can be added to the sponsor list.';

  @override
  String aboutQqCopied(Object number) {
    return 'QQ was not found; the group number was copied: $number';
  }

  @override
  String get disclaimerTitle => 'Disclaimer';

  @override
  String get disclaimerTerms => 'Full terms';

  @override
  String get disclaimerSource =>
      'The authoritative terms are NOTICE.md in the repository and the LICENSE shipped with the app.';

  @override
  String get ipQualityRedetect => 'Check again';

  @override
  String get ipQualityEgress => 'Current egress address';

  @override
  String get ipQualitySources => 'Sources';

  @override
  String get ipQualitySourcesFooter =>
      'Sources often disagree on residential vs. hosting: more hits means more confidence, but one source\'s \"risky\" label is not conclusive.';

  @override
  String get ipQualityQuerying =>
      'Looking up the egress IP and three intelligence sources…';

  @override
  String get ipQualityChecking => 'Checking…';

  @override
  String get ipQualityDetecting => 'Detecting';

  @override
  String get ipQualityFailed => 'Check failed';

  @override
  String get ipQualityNotYet => 'Not checked yet';

  @override
  String get ipQualityDetectingBody =>
      'Fetching the egress IP and querying the sources, please wait';

  @override
  String get ipQualityStartBody =>
      'Tap the button below to check the quality of the current egress IP';

  @override
  String get ipQualityStart => 'Start checking';

  @override
  String ipQualityJudgedAs(Object type) {
    return 'Classified as $type';
  }

  @override
  String get ipQualityNotUsed => 'Not used';

  @override
  String get ipQualityUsed => 'Used';

  @override
  String devFooterWarning(Object count) {
    return 'These actions work directly on the local databases, prefs and native channels: the stress test really writes $count rows, compaction runs SQLite VACUUM, and clearing all data deletes everything locally and requires a restart.';
  }

  @override
  String get devDataCleanupBody =>
      'Delete logs, weights, rules and cache by category';

  @override
  String get devConfigSection => 'Configuration and resources';

  @override
  String get devCustomResources => 'Custom resources';

  @override
  String get devCustomResourcesBody =>
      'Entry points for configuration resources such as User-Agent and on-demand';

  @override
  String get devUserAgentBody =>
      'The UA sent with subscription downloads and speed tests';

  @override
  String get devOnDemand => 'On-demand connection';

  @override
  String get devOnDemandBody => 'Start the VPN depending on the SSID';

  @override
  String get devWebdav => 'WebDAV sync';

  @override
  String get devWebdavBody => 'Upload backups to your own WebDAV server';

  @override
  String get devUiSection => 'UI and appearance extras';

  @override
  String get devFontFamilyBody => 'Choose the UI font family on its own page';

  @override
  String get devFontSizeBody =>
      'Global text scaling; an inline slider in the appearance settings';

  @override
  String get devTabAnimation => 'Tab animation';

  @override
  String get devTabAnimationBody =>
      'The entrance animation when switching bottom tabs; an inline option in the appearance settings';

  @override
  String get devExperimental => 'Experimental actions';

  @override
  String get devLegacyFooter =>
      'None of the pages under Diagnostics, Configuration and resources or UI and appearance belong to the 1.4.3 interface; they are kept for debugging and component review. The legacy features are still reached through the legacy menus, not this page.';

  @override
  String get unknownRouteTitle => 'Page not found';

  @override
  String get unknownRouteBody => 'This page cannot be found';

  @override
  String get unknownRouteBack => 'Back';

  @override
  String get disclaimerReadFirst => 'Read before use';

  @override
  String get disclaimerIntro =>
      'Diting is an open-source local DNS and traffic observability tool. It does not provide, proxy or relay any network access service, and all data is processed on the device.';

  @override
  String get disclaimerLawful =>
      'Use this software in compliance with the laws of your jurisdiction. Using it on any unauthorised network is at your own risk.';

  @override
  String get disclaimerFirstRun => 'The text confirmed at first launch';

  @override
  String get disclaimerImmutable => 'Not editable';

  @override
  String get devFontFamily => 'Font';

  @override
  String get devFontSize => 'Text size';

  @override
  String get devWarningTitle => 'Developer mode';

  @override
  String get devFooterLegacy =>
      'The pages under Diagnostics, Configuration and resources, and UI and appearance do not belong to the 1.4.3 interface; they are kept for debugging and component review. Legacy features are still reached through the legacy menus, not this page.';

  @override
  String get ipTypeResidential => 'Residential';

  @override
  String get ipTypeMobile => 'Mobile';

  @override
  String get ipTypeBusiness => 'Business';

  @override
  String get ipTypeHosting => 'Hosting';

  @override
  String get ipLevelGood => 'Good';

  @override
  String get ipLevelNormal => 'Fair';

  @override
  String get ipLevelRisky => 'Risky';

  @override
  String get ipStatusOk => 'Matched';

  @override
  String get ipStatusNoType => 'No type';

  @override
  String get ipStatusTimeout => 'Timed out';

  @override
  String get ipStatusRateLimited => 'Rate limited';

  @override
  String get ipStatusMismatch => 'IP mismatch';

  @override
  String get modeSelectTitle => 'Choose a work mode';

  @override
  String get modeContinue => 'Continue';

  @override
  String get modeSwitchNote =>
      'You can choose again in settings at any time; switching stops the current mode\'s service first, so two modes never run together.';

  @override
  String get modeSharedNote =>
      'All three modes share one set of rules and cache; they differ in how they take over traffic: normal mode uses a full tunnel, server mode only serves LAN DNS, and express mode is a pure-Kotlin narrow route.';

  @override
  String get modeNormalFeature1 => 'Full tunnel';

  @override
  String get modeNormalFeature1Body =>
      'The Go stack handles all traffic, with per-app routing';

  @override
  String get modeNormalFeature2 => 'All rule features';

  @override
  String get modeNormalFeature2Body =>
      'Blocklists, allowlists, rewrites and HTTPS inspection are all available';

  @override
  String get modeNormalFeature3 => 'Optional HTTPS inspection';

  @override
  String get modeNormalFeature3Body =>
      'Requires installing and trusting the local CA certificate';

  @override
  String get modeNormalFeature4 => 'Per-app traffic stats';

  @override
  String get modeNormalFeature4Body =>
      'Records upload, download and query counts per app';

  @override
  String get modeServerFeature1 => 'LAN DNS service';

  @override
  String get modeServerFeature1Body =>
      'Listens on 0.0.0.0 for devices on the same subnet';

  @override
  String get modeServerFeature2 => 'No VPN slot needed';

  @override
  String get modeServerFeature2Body =>
      'No tunnel is created locally, so other VPNs can run at the same time';

  @override
  String get modeServerFeature3 => 'Shared rules and cache';

  @override
  String get modeServerFeature3Body =>
      'Uses the same rule library as normal mode';

  @override
  String get modeServerFeature4 => 'Low power';

  @override
  String get modeServerFeature4Body =>
      'Handles DNS queries only, without forwarding traffic';

  @override
  String get modeExpressFeature1 => 'Pure Kotlin';

  @override
  String get modeExpressFeature1Body =>
      'A narrow route, so starting and switching are faster';

  @override
  String get modeExpressFeature2 => 'Four upstream strategies';

  @override
  String get modeExpressFeature2Body =>
      'Single provider / smart / race / primary-backup';

  @override
  String get modeExpressFeature3 => '64-shard LRU cache';

  @override
  String get modeExpressFeature3Body =>
      'A high hit rate with predictable memory use';

  @override
  String get modeExpressFeature4 => 'Works on older systems';

  @override
  String get modeExpressFeature4Body => 'Android 7+ (64-bit required)';

  @override
  String get onboardingTitle => 'Setup';

  @override
  String get onboardingSkip => 'Skip setup';

  @override
  String get onboardingPrev => 'Back';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get onboardingNext => 'Next';

  @override
  String onboardingChosen(Object mode) {
    return 'You chose $mode';
  }

  @override
  String get onboardingChangeable => 'You can change it later';

  @override
  String get onboardingChangeableBody =>
      'Settings → choose the work mode again at any time. Switching stops the current mode\'s service first.';

  @override
  String get onboardingSharedRules => 'Rules and cache are shared';

  @override
  String get onboardingSharedRulesBody =>
      'All three modes share one set of lists and DNS cache, so nothing needs to be configured twice.';

  @override
  String get onboardingExclusive => 'Modes are exclusive';

  @override
  String get onboardingExclusiveBody =>
      'Only one mode runs at a time; leaving stops the previous one first.';

  @override
  String get permVpn => 'VPN connection';

  @override
  String get permNotification => 'Notifications';

  @override
  String get permAppList => 'App list';

  @override
  String get permBattery => 'Ignore battery optimisation';

  @override
  String get permRequired => 'Required';

  @override
  String get permOptional => 'Optional';

  @override
  String get permVpnNormalBody =>
      'Creates the local tunnel that handles traffic; denying it prevents startup';

  @override
  String get permNotificationBody =>
      'The foreground service needs a persistent notification; denying it lets the system reclaim the service';

  @override
  String get permAppListBody =>
      'Per-app routing and stats; denying it leaves only domain rules';

  @override
  String get permBatteryBody =>
      'Prevents the app from being killed; denying it may drop the tunnel after long standby';

  @override
  String get permBatteryServerBody =>
      'Prevents the app from being killed; denying it makes the LAN service intermittent';

  @override
  String get permVpnExpressBody =>
      'Creates the narrow-route tunnel; denying it prevents startup';

  @override
  String get permNeeded => 'These permissions are needed';

  @override
  String get permAllLocal =>
      'All permissions are used on this device only; no data is uploaded.';

  @override
  String permGrantedCount(Object granted, Object total) {
    return '$granted of $total granted; all permissions are used on this device only and no data is uploaded.';
  }

  @override
  String get onboardingTipNormal1 =>
      'Tap the big button on the home page to start the service; the system VPN prompt appears the first time.';

  @override
  String get onboardingTipNormal2 =>
      'Maintain the blocklists and allowlists under Feature hub → Rules and subscriptions.';

  @override
  String get onboardingTipNormal3 =>
      'The home page sentence and opacity can both be changed in settings.';

  @override
  String get onboardingTipServer1 =>
      'After starting, point devices on the same subnet to the address shown under LAN access.';

  @override
  String get onboardingTipServer2 =>
      'The port can be changed on the Server mode page; the default is 5353.';

  @override
  String get onboardingTipServer3 =>
      'This mode creates no VPN, so it can run alongside other VPNs.';

  @override
  String get onboardingTipExpress1 =>
      'Express mode starts faster but is a subset of normal mode.';

  @override
  String get onboardingTipExpress2 => 'Racing needs at least two providers.';

  @override
  String get onboardingTipExpress3 =>
      'Switch back to normal mode when you need HTTPS inspection or app control.';

  @override
  String get onboardingReady => 'You are ready';

  @override
  String get onboardingReadyBody =>
      'Here are the three most useful tips to start with.';

  @override
  String onboardingTipIndex(Object index) {
    return 'Tip $index';
  }

  @override
  String permStillDenied(Object name) {
    return '$name is still denied; allow it in system settings and return to this page';
  }

  @override
  String get permGranted => 'Granted';

  @override
  String get permDenied => 'Denied';

  @override
  String get permUnknown => 'Unknown';

  @override
  String get permGrant => 'Grant';
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'谛听 DITING'**
  String get appTitle;

  /// No description provided for @uiBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get uiBack;

  /// No description provided for @uiCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get uiCancel;

  /// No description provided for @uiClearSearch.
  ///
  /// In zh, this message translates to:
  /// **'清除搜索'**
  String get uiClearSearch;

  /// No description provided for @uiClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get uiClose;

  /// No description provided for @uiHidePassword.
  ///
  /// In zh, this message translates to:
  /// **'隐藏密码'**
  String get uiHidePassword;

  /// No description provided for @uiMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get uiMore;

  /// No description provided for @uiNoSearchResults.
  ///
  /// In zh, this message translates to:
  /// **'无搜索结果'**
  String get uiNoSearchResults;

  /// No description provided for @uiReset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get uiReset;

  /// No description provided for @uiSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get uiSearch;

  /// No description provided for @uiShowLess.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get uiShowLess;

  /// No description provided for @uiShowMore.
  ///
  /// In zh, this message translates to:
  /// **'展开'**
  String get uiShowMore;

  /// No description provided for @uiShowPassword.
  ///
  /// In zh, this message translates to:
  /// **'显示密码'**
  String get uiShowPassword;

  /// No description provided for @uiSort.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get uiSort;

  /// No description provided for @uiSubmit.
  ///
  /// In zh, this message translates to:
  /// **'提交'**
  String get uiSubmit;

  /// No description provided for @languageTitle.
  ///
  /// In zh, this message translates to:
  /// **'语言设置'**
  String get languageTitle;

  /// No description provided for @languageInterfaceSection.
  ///
  /// In zh, this message translates to:
  /// **'界面语言'**
  String get languageInterfaceSection;

  /// No description provided for @languageInterfaceFooter.
  ///
  /// In zh, this message translates to:
  /// **'选择应用界面语言。「跟随系统」会跟随设备语言，非中文或英文的系统显示中文。'**
  String get languageInterfaceFooter;

  /// No description provided for @languageChinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @commonFollowSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get commonFollowSystem;

  /// No description provided for @commonSelectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get commonSelectAll;

  /// No description provided for @commonClear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get commonClear;

  /// No description provided for @commonInvertSelection.
  ///
  /// In zh, this message translates to:
  /// **'反选'**
  String get commonInvertSelection;

  /// No description provided for @commonFilter.
  ///
  /// In zh, this message translates to:
  /// **'过滤'**
  String get commonFilter;

  /// No description provided for @commonSort.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get commonSort;

  /// No description provided for @commonSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// No description provided for @commonDiscard.
  ///
  /// In zh, this message translates to:
  /// **'不保存'**
  String get commonDiscard;

  /// No description provided for @commonSaveChangesTitle.
  ///
  /// In zh, this message translates to:
  /// **'保存更改？'**
  String get commonSaveChangesTitle;

  /// No description provided for @commonSaveChangesMessage.
  ///
  /// In zh, this message translates to:
  /// **'你的选择还没保存。保存后离开，还是放弃这些修改？'**
  String get commonSaveChangesMessage;

  /// No description provided for @commonSaveChangesMessageFor.
  ///
  /// In zh, this message translates to:
  /// **'「{name}」的选择还没保存。保存后离开，还是放弃这些修改？'**
  String commonSaveChangesMessageFor(Object name);

  /// No description provided for @commonGrantPermission.
  ///
  /// In zh, this message translates to:
  /// **'去授权'**
  String get commonGrantPermission;

  /// No description provided for @palettePurple.
  ///
  /// In zh, this message translates to:
  /// **'鸢尾紫'**
  String get palettePurple;

  /// No description provided for @paletteBlue.
  ///
  /// In zh, this message translates to:
  /// **'睡莲蓝'**
  String get paletteBlue;

  /// No description provided for @paletteCyan.
  ///
  /// In zh, this message translates to:
  /// **'池水青'**
  String get paletteCyan;

  /// No description provided for @paletteGreen.
  ///
  /// In zh, this message translates to:
  /// **'柳叶绿'**
  String get paletteGreen;

  /// No description provided for @paletteOrange.
  ///
  /// In zh, this message translates to:
  /// **'暮光赭'**
  String get paletteOrange;

  /// No description provided for @paletteRed.
  ///
  /// In zh, this message translates to:
  /// **'罂粟红'**
  String get paletteRed;

  /// No description provided for @palettePink.
  ///
  /// In zh, this message translates to:
  /// **'暮霞粉'**
  String get palettePink;

  /// No description provided for @paletteGold.
  ///
  /// In zh, this message translates to:
  /// **'麦穗金'**
  String get paletteGold;

  /// No description provided for @themeModeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色模式'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色模式'**
  String get themeModeDark;

  /// No description provided for @appListUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'读不到应用列表'**
  String get appListUnavailable;

  /// No description provided for @appListFilterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部应用'**
  String get appListFilterAll;

  /// No description provided for @appListFilterSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统应用'**
  String get appListFilterSystem;

  /// No description provided for @appListFilterUser.
  ///
  /// In zh, this message translates to:
  /// **'用户应用'**
  String get appListFilterUser;

  /// No description provided for @appListFilterSelected.
  ///
  /// In zh, this message translates to:
  /// **'已勾选应用'**
  String get appListFilterSelected;

  /// No description provided for @appListSortLabelAsc.
  ///
  /// In zh, this message translates to:
  /// **'应用名称 A-Z'**
  String get appListSortLabelAsc;

  /// No description provided for @appListSortLabelDesc.
  ///
  /// In zh, this message translates to:
  /// **'应用名称 Z-A'**
  String get appListSortLabelDesc;

  /// No description provided for @appListSortPackageAsc.
  ///
  /// In zh, this message translates to:
  /// **'包名 A-Z'**
  String get appListSortPackageAsc;

  /// No description provided for @appListSortPackageDesc.
  ///
  /// In zh, this message translates to:
  /// **'包名 Z-A'**
  String get appListSortPackageDesc;

  /// No description provided for @appListNotRegistered.
  ///
  /// In zh, this message translates to:
  /// **'未注册'**
  String get appListNotRegistered;

  /// No description provided for @appListChannelUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'应用列表通道不可用：{detail}'**
  String appListChannelUnavailable(Object detail);

  /// No description provided for @appListReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'读取应用列表失败：{detail}'**
  String appListReadFailed(Object detail);

  /// No description provided for @appListReadFailedCode.
  ///
  /// In zh, this message translates to:
  /// **'读取应用列表失败（{code}）'**
  String appListReadFailedCode(Object code);

  /// No description provided for @dbWriteUnhealthy.
  ///
  /// In zh, this message translates to:
  /// **'日志写入异常：已丢弃 {dropped} 条、打开失败 {failures} 次，可在「故障排查」查看详情'**
  String dbWriteUnhealthy(Object dropped, Object failures);

  /// No description provided for @agreementDeclinedTitle.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝使用须知'**
  String get agreementDeclinedTitle;

  /// No description provided for @agreementDeclinedMessage.
  ///
  /// In zh, this message translates to:
  /// **'未同意使用须知与免责声明，无法继续使用谛听。你可以直接退出应用，或重新查看条款后再决定。'**
  String get agreementDeclinedMessage;

  /// No description provided for @agreementReviewAgain.
  ///
  /// In zh, this message translates to:
  /// **'重新查看'**
  String get agreementReviewAgain;

  /// No description provided for @agreementTitle.
  ///
  /// In zh, this message translates to:
  /// **'使用须知与免责声明'**
  String get agreementTitle;

  /// No description provided for @agreementDecline.
  ///
  /// In zh, this message translates to:
  /// **'不同意并退出'**
  String get agreementDecline;

  /// No description provided for @agreementAccept.
  ///
  /// In zh, this message translates to:
  /// **'同意并继续'**
  String get agreementAccept;

  /// No description provided for @agreementMessage.
  ///
  /// In zh, this message translates to:
  /// **'软件说明\n谛听是一款专注于本地 DNS 解析优化与网络规则过滤的开源工具。提供三种工作模式：普通模式（全隧道深度管控）、极速模式（纯 Kotlin 原生轻量窄路由）与独立服务器模式（局域网免 VPN 服务）。本软件完全在设备本地闭环运行，无任何远程数据上传与隐私追踪。\n\n运行机制与注意事项\n普通模式与极速模式依赖 Android 本地 VPN 接口接管 DNS 解析，不连接任何远程 VPN 服务器；独立服务器模式无需 VPN 权限，直接监听本地 1053 端口供局域网设备接入。规则与日志完整保存在本机，启用高级扩展功能前请了解其具体影响。\n\n免责条款\n本软件按现状提供。使用者须遵守相关法律法规，自行确认规则与上游解析来源的合法性及安全性。严禁将本软件用于任何违法用途；使用者因自行配置或使用本软件所产生的后果由使用者自行承担。'**
  String get agreementMessage;

  /// No description provided for @homeProviderSingleLabel.
  ///
  /// In zh, this message translates to:
  /// **'解析服务商'**
  String get homeProviderSingleLabel;

  /// No description provided for @homeProviderRaceLabel.
  ///
  /// In zh, this message translates to:
  /// **'竞速服务商'**
  String get homeProviderRaceLabel;

  /// No description provided for @homeChartEmptyLabel.
  ///
  /// In zh, this message translates to:
  /// **'还没有采到样本'**
  String get homeChartEmptyLabel;

  /// No description provided for @durationHours.
  ///
  /// In zh, this message translates to:
  /// **'{hours} 小时'**
  String durationHours(Object hours);

  /// No description provided for @durationMinutes.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟'**
  String durationMinutes(Object minutes);

  /// No description provided for @durationSeconds.
  ///
  /// In zh, this message translates to:
  /// **'{seconds} 秒'**
  String durationSeconds(Object seconds);

  /// No description provided for @dashboardDetailTooltip.
  ///
  /// In zh, this message translates to:
  /// **'详情'**
  String get dashboardDetailTooltip;

  /// No description provided for @dashboardEmptyLabel.
  ///
  /// In zh, this message translates to:
  /// **'仪表盘还没有卡片'**
  String get dashboardEmptyLabel;

  /// No description provided for @dashboardEmptyDescription.
  ///
  /// In zh, this message translates to:
  /// **'进入编辑模式，从「添加卡片」里挑几个放上来。'**
  String get dashboardEmptyDescription;

  /// No description provided for @dashboardEnterEditMode.
  ///
  /// In zh, this message translates to:
  /// **'进入编辑模式'**
  String get dashboardEnterEditMode;

  /// No description provided for @dashboardEditHint.
  ///
  /// In zh, this message translates to:
  /// **'拖动手柄排序，点右上角移除；改完点右上角「完成」。'**
  String get dashboardEditHint;

  /// No description provided for @dashboardAllRemovedLabel.
  ///
  /// In zh, this message translates to:
  /// **'卡片都移除了'**
  String get dashboardAllRemovedLabel;

  /// No description provided for @dashboardAllRemovedDescription.
  ///
  /// In zh, this message translates to:
  /// **'点下面的「添加卡片」挑一个。'**
  String get dashboardAllRemovedDescription;

  /// No description provided for @dashboardAddCard.
  ///
  /// In zh, this message translates to:
  /// **'添加卡片'**
  String get dashboardAddCard;

  /// No description provided for @providerSheetSingleTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择解析服务商'**
  String get providerSheetSingleTitle;

  /// No description provided for @providerSheetRaceTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择竞速服务商'**
  String get providerSheetRaceTitle;

  /// No description provided for @providerSheetSingleOptions.
  ///
  /// In zh, this message translates to:
  /// **'可选服务商'**
  String get providerSheetSingleOptions;

  /// No description provided for @providerSheetRaceMinimum.
  ///
  /// In zh, this message translates to:
  /// **'至少选 2 个'**
  String get providerSheetRaceMinimum;

  /// No description provided for @providerSheetManage.
  ///
  /// In zh, this message translates to:
  /// **'管理服务...'**
  String get providerSheetManage;

  /// No description provided for @providerSheetVisibility.
  ///
  /// In zh, this message translates to:
  /// **'服务显示...'**
  String get providerSheetVisibility;

  /// No description provided for @providerSheetSingleFooter.
  ///
  /// In zh, this message translates to:
  /// **'延迟取自上一次解析的健康记录，不是实时值。'**
  String get providerSheetSingleFooter;

  /// No description provided for @providerSheetRaceFooter.
  ///
  /// In zh, this message translates to:
  /// **'竞速模式下每个查询会并发发往所有选中服务商。'**
  String get providerSheetRaceFooter;

  /// No description provided for @powerButtonStop.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get powerButtonStop;

  /// No description provided for @powerButtonStart.
  ///
  /// In zh, this message translates to:
  /// **'开启'**
  String get powerButtonStart;

  /// No description provided for @powerButtonStarting.
  ///
  /// In zh, this message translates to:
  /// **'启动中'**
  String get powerButtonStarting;

  /// No description provided for @homeEditDashboard.
  ///
  /// In zh, this message translates to:
  /// **'编辑仪表盘'**
  String get homeEditDashboard;

  /// No description provided for @homeDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get homeDone;

  /// No description provided for @homeSwitchWorkMode.
  ///
  /// In zh, this message translates to:
  /// **'切换工作模式'**
  String get homeSwitchWorkMode;

  /// No description provided for @homeTitleNormal.
  ///
  /// In zh, this message translates to:
  /// **'谛听 · 普通'**
  String get homeTitleNormal;

  /// No description provided for @homeTitleServer.
  ///
  /// In zh, this message translates to:
  /// **'谛听 · 服务器'**
  String get homeTitleServer;

  /// No description provided for @homeTitleExpress.
  ///
  /// In zh, this message translates to:
  /// **'谛听 · 极速'**
  String get homeTitleExpress;

  /// No description provided for @logRequestsOverview.
  ///
  /// In zh, this message translates to:
  /// **'请求概览'**
  String get logRequestsOverview;

  /// No description provided for @logTodayRequests.
  ///
  /// In zh, this message translates to:
  /// **'今日请求'**
  String get logTodayRequests;

  /// No description provided for @logPassed.
  ///
  /// In zh, this message translates to:
  /// **'通过'**
  String get logPassed;

  /// No description provided for @logFiltered.
  ///
  /// In zh, this message translates to:
  /// **'过滤'**
  String get logFiltered;

  /// No description provided for @logCacheHits.
  ///
  /// In zh, this message translates to:
  /// **'缓存命中'**
  String get logCacheHits;

  /// No description provided for @logHighlights.
  ///
  /// In zh, this message translates to:
  /// **'重点记录'**
  String get logHighlights;

  /// No description provided for @logBlocked.
  ///
  /// In zh, this message translates to:
  /// **'过滤拦截'**
  String get logBlocked;

  /// No description provided for @logFailed.
  ///
  /// In zh, this message translates to:
  /// **'异常失败'**
  String get logFailed;

  /// No description provided for @logBypassed.
  ///
  /// In zh, this message translates to:
  /// **'旁路直连'**
  String get logBypassed;

  /// No description provided for @logOffModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'解析服务概况'**
  String get logOffModeTitle;

  /// No description provided for @logCacheEntries.
  ///
  /// In zh, this message translates to:
  /// **'有效缓存'**
  String get logCacheEntries;

  /// No description provided for @logCacheHitsTotal.
  ///
  /// In zh, this message translates to:
  /// **'累计缓存命中'**
  String get logCacheHitsTotal;

  /// No description provided for @logRaceRequests.
  ///
  /// In zh, this message translates to:
  /// **'并发竞速请求'**
  String get logRaceRequests;

  /// No description provided for @logBootstrapAttempts.
  ///
  /// In zh, this message translates to:
  /// **'Bootstrap 尝试'**
  String get logBootstrapAttempts;

  /// No description provided for @logRecentRequests.
  ///
  /// In zh, this message translates to:
  /// **'最近请求'**
  String get logRecentRequests;

  /// No description provided for @logRecentRequestsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无请求日志'**
  String get logRecentRequestsEmpty;

  /// No description provided for @logRecentBlocked.
  ///
  /// In zh, this message translates to:
  /// **'最近拦截与错误'**
  String get logRecentBlocked;

  /// No description provided for @logRecentBlockedEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无拦截或错误记录'**
  String get logRecentBlockedEmpty;

  /// No description provided for @logCacheHotspots.
  ///
  /// In zh, this message translates to:
  /// **'缓存热点'**
  String get logCacheHotspots;

  /// No description provided for @logCacheHotspotsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无有效缓存'**
  String get logCacheHotspotsEmpty;

  /// No description provided for @logExpiresIn.
  ///
  /// In zh, this message translates to:
  /// **'{duration} 后过期'**
  String logExpiresIn(Object duration);

  /// No description provided for @logTimes.
  ///
  /// In zh, this message translates to:
  /// **'{count} 次'**
  String logTimes(Object count);

  /// No description provided for @logRaceWinners.
  ///
  /// In zh, this message translates to:
  /// **'竞速胜出'**
  String get logRaceWinners;

  /// No description provided for @logRaceWinnersEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无竞速数据'**
  String get logRaceWinnersEmpty;

  /// No description provided for @logAverageWinLatency.
  ///
  /// In zh, this message translates to:
  /// **'平均胜出耗时 {latency}'**
  String logAverageWinLatency(Object latency);

  /// No description provided for @logBootstrapDnsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无 Bootstrap 数据'**
  String get logBootstrapDnsEmpty;

  /// No description provided for @logBootstrapRow.
  ///
  /// In zh, this message translates to:
  /// **'{ip} · 成功 {percent} · {latency}'**
  String logBootstrapRow(Object ip, Object latency, Object percent);

  /// No description provided for @logRuleBlocks.
  ///
  /// In zh, this message translates to:
  /// **'规则拦截'**
  String get logRuleBlocks;

  /// No description provided for @logRuleBlocksEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无规则拦截数据'**
  String get logRuleBlocksEmpty;

  /// No description provided for @logShareRow.
  ///
  /// In zh, this message translates to:
  /// **'{status} · 占全部请求 {percent}'**
  String logShareRow(Object percent, Object status);

  /// No description provided for @logPrivacyMode.
  ///
  /// In zh, this message translates to:
  /// **'隐私模式保护中'**
  String get logPrivacyMode;

  /// No description provided for @logLoggingOff.
  ///
  /// In zh, this message translates to:
  /// **'日志已关闭'**
  String get logLoggingOff;

  /// No description provided for @logPrivacyModeBody.
  ///
  /// In zh, this message translates to:
  /// **'重新开启日志后，仪表盘将从新产生的请求开始统计。当前各类解析服务与缓存热点均正常工作。'**
  String get logPrivacyModeBody;

  /// No description provided for @logPerfTitle.
  ///
  /// In zh, this message translates to:
  /// **'解析效能概况'**
  String get logPerfTitle;

  /// No description provided for @logTodayStats.
  ///
  /// In zh, this message translates to:
  /// **'今日统计'**
  String get logTodayStats;

  /// No description provided for @logAverageLatency.
  ///
  /// In zh, this message translates to:
  /// **'平均解析耗时'**
  String get logAverageLatency;

  /// No description provided for @logNoTimingSamples.
  ///
  /// In zh, this message translates to:
  /// **'— · 今日暂无计时样本'**
  String get logNoTimingSamples;

  /// No description provided for @logSampleValue.
  ///
  /// In zh, this message translates to:
  /// **'{value} · {count} 个样本'**
  String logSampleValue(Object count, Object value);

  /// No description provided for @logCacheHitRate.
  ///
  /// In zh, this message translates to:
  /// **'缓存命中率'**
  String get logCacheHitRate;

  /// No description provided for @logCacheHitRateValue.
  ///
  /// In zh, this message translates to:
  /// **'{percent} · 分母为通过 + 失败'**
  String logCacheHitRateValue(Object percent);

  /// No description provided for @logRaceSuccessRate.
  ///
  /// In zh, this message translates to:
  /// **'竞速成功率'**
  String get logRaceSuccessRate;

  /// No description provided for @logBootstrapSuccessRate.
  ///
  /// In zh, this message translates to:
  /// **'Bootstrap 成功率'**
  String get logBootstrapSuccessRate;

  /// No description provided for @logRateValue.
  ///
  /// In zh, this message translates to:
  /// **'{percent} · {count} 次 · {latency}'**
  String logRateValue(Object count, Object latency, Object percent);

  /// No description provided for @dashboardRestoreDefaults.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get dashboardRestoreDefaults;

  /// No description provided for @dashboardAllCardsAdded.
  ///
  /// In zh, this message translates to:
  /// **'卡片都放上来了'**
  String get dashboardAllCardsAdded;

  /// No description provided for @dashboardAllCardsAddedDescription.
  ///
  /// In zh, this message translates to:
  /// **'想减少卡片，请回到编辑模式点卡片右上角的移除。'**
  String get dashboardAllCardsAddedDescription;

  /// No description provided for @dashboardAvailableCards.
  ///
  /// In zh, this message translates to:
  /// **'可添加的卡片'**
  String get dashboardAvailableCards;

  /// No description provided for @dashboardOrderHint.
  ///
  /// In zh, this message translates to:
  /// **'卡片顺序可在编辑模式下拖拽调整。'**
  String get dashboardOrderHint;

  /// No description provided for @dashboardCardProviderDescription.
  ///
  /// In zh, this message translates to:
  /// **'当前解析服务商，点开即可切换或调整竞速列表'**
  String get dashboardCardProviderDescription;

  /// No description provided for @dashboardCardResolutionDescription.
  ///
  /// In zh, this message translates to:
  /// **'解析模式选择、一句话说明与当前生效的 DNS 地址'**
  String get dashboardCardResolutionDescription;

  /// No description provided for @dashboardCardStatusDescription.
  ///
  /// In zh, this message translates to:
  /// **'内核状态、运行时长、当前服务商与今日查询'**
  String get dashboardCardStatusDescription;

  /// No description provided for @dashboardCardSpeedDescription.
  ///
  /// In zh, this message translates to:
  /// **'上下行实时速率曲线与今日累计流量'**
  String get dashboardCardSpeedDescription;

  /// No description provided for @dashboardCardSiteLatencyDescription.
  ///
  /// In zh, this message translates to:
  /// **'自定义 4 个站点的实测延迟，详情页可按分类测速'**
  String get dashboardCardSiteLatencyDescription;

  /// No description provided for @dashboardCardMemoryDescription.
  ///
  /// In zh, this message translates to:
  /// **'本进程 PSS 与 Java / 原生堆构成'**
  String get dashboardCardMemoryDescription;

  /// No description provided for @dashboardCardIntranetDescription.
  ///
  /// In zh, this message translates to:
  /// **'当前局域网地址、监听状态与复制入口'**
  String get dashboardCardIntranetDescription;

  /// No description provided for @intranetIpTitle.
  ///
  /// In zh, this message translates to:
  /// **'内网 IP'**
  String get intranetIpTitle;

  /// No description provided for @intranetCopyAddress.
  ///
  /// In zh, this message translates to:
  /// **'复制地址'**
  String get intranetCopyAddress;

  /// No description provided for @intranetReading.
  ///
  /// In zh, this message translates to:
  /// **'读取中…'**
  String get intranetReading;

  /// No description provided for @intranetNoActiveNetwork.
  ///
  /// In zh, this message translates to:
  /// **'无活动网络'**
  String get intranetNoActiveNetwork;

  /// No description provided for @intranetLanAccess.
  ///
  /// In zh, this message translates to:
  /// **'局域网接入'**
  String get intranetLanAccess;

  /// No description provided for @intranetConnectHint.
  ///
  /// In zh, this message translates to:
  /// **'连上 Wi-Fi 或以太网后这里会显示可用地址'**
  String get intranetConnectHint;

  /// No description provided for @memoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'内存信息'**
  String get memoryTitle;

  /// No description provided for @memoryJavaHeap.
  ///
  /// In zh, this message translates to:
  /// **'Java 堆'**
  String get memoryJavaHeap;

  /// No description provided for @memoryNativeHeap.
  ///
  /// In zh, this message translates to:
  /// **'原生堆'**
  String get memoryNativeHeap;

  /// No description provided for @memorySystemAvailable.
  ///
  /// In zh, this message translates to:
  /// **'整机可用'**
  String get memorySystemAvailable;

  /// No description provided for @speedTitle.
  ///
  /// In zh, this message translates to:
  /// **'网络速度'**
  String get speedTitle;

  /// No description provided for @speedUpload.
  ///
  /// In zh, this message translates to:
  /// **'上传'**
  String get speedUpload;

  /// No description provided for @speedDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get speedDownload;

  /// No description provided for @speedExpressNoStats.
  ///
  /// In zh, this message translates to:
  /// **'极速模式不统计'**
  String get speedExpressNoStats;

  /// No description provided for @speedNoChannel.
  ///
  /// In zh, this message translates to:
  /// **'当前环境无速率通道'**
  String get speedNoChannel;

  /// No description provided for @resolutionModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'解析模式'**
  String get resolutionModeTitle;

  /// No description provided for @resolutionNoProvider.
  ///
  /// In zh, this message translates to:
  /// **'未选择服务商'**
  String get resolutionNoProvider;

  /// No description provided for @resolutionSingleSummary.
  ///
  /// In zh, this message translates to:
  /// **'只用当前选中的服务商，最快但可用性取决于它。'**
  String get resolutionSingleSummary;

  /// No description provided for @resolutionSmartSummary.
  ///
  /// In zh, this message translates to:
  /// **'按历史成功率挑一个，失败后自动换下一个。'**
  String get resolutionSmartSummary;

  /// No description provided for @resolutionParallelSummary.
  ///
  /// In zh, this message translates to:
  /// **'同时向所有服务商发起，取最先返回的结果。'**
  String get resolutionParallelSummary;

  /// No description provided for @resolutionPrimaryBackupSummary.
  ///
  /// In zh, this message translates to:
  /// **'主服务商优先，超时后才动备用。'**
  String get resolutionPrimaryBackupSummary;

  /// No description provided for @siteLatencyTesting.
  ///
  /// In zh, this message translates to:
  /// **'测速中…'**
  String get siteLatencyTesting;

  /// No description provided for @siteLatencyNotTested.
  ///
  /// In zh, this message translates to:
  /// **'尚未测速'**
  String get siteLatencyNotTested;

  /// No description provided for @siteLatencyTitle.
  ///
  /// In zh, this message translates to:
  /// **'网络测速'**
  String get siteLatencyTitle;

  /// No description provided for @siteLatencyRetest.
  ///
  /// In zh, this message translates to:
  /// **'重新测速'**
  String get siteLatencyRetest;

  /// No description provided for @commonFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get commonFailed;

  /// No description provided for @siteLatencyNoReply.
  ///
  /// In zh, this message translates to:
  /// **'无回包'**
  String get siteLatencyNoReply;

  /// No description provided for @statusTitle.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get statusTitle;

  /// No description provided for @statusUptime.
  ///
  /// In zh, this message translates to:
  /// **'运行时长'**
  String get statusUptime;

  /// No description provided for @statusActiveProvider.
  ///
  /// In zh, this message translates to:
  /// **'当前服务商'**
  String get statusActiveProvider;

  /// No description provided for @statusNotSelected.
  ///
  /// In zh, this message translates to:
  /// **'未选择'**
  String get statusNotSelected;

  /// No description provided for @statusTodayQueries.
  ///
  /// In zh, this message translates to:
  /// **'今日查询'**
  String get statusTodayQueries;

  /// No description provided for @statusDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'状态详情'**
  String get statusDetailTitle;

  /// No description provided for @statusNotTiming.
  ///
  /// In zh, this message translates to:
  /// **'未计时'**
  String get statusNotTiming;

  /// No description provided for @statusCoreSection.
  ///
  /// In zh, this message translates to:
  /// **'内核'**
  String get statusCoreSection;

  /// No description provided for @statusWorkMode.
  ///
  /// In zh, this message translates to:
  /// **'工作模式'**
  String get statusWorkMode;

  /// No description provided for @statusCoreState.
  ///
  /// In zh, this message translates to:
  /// **'内核状态'**
  String get statusCoreState;

  /// No description provided for @statusListenPort.
  ///
  /// In zh, this message translates to:
  /// **'监听端口'**
  String get statusListenPort;

  /// No description provided for @statusNotListening.
  ///
  /// In zh, this message translates to:
  /// **'未监听'**
  String get statusNotListening;

  /// No description provided for @statusProviderFooter.
  ///
  /// In zh, this message translates to:
  /// **'延迟是该服务商的最近一次实测值，不是本机到目标的往返。'**
  String get statusProviderFooter;

  /// No description provided for @statusNoProviderHint.
  ///
  /// In zh, this message translates to:
  /// **'还没有选择服务商。在服务商管理里挑一个，解析才会走真实上游。'**
  String get statusNoProviderHint;

  /// No description provided for @statusTodayCounts.
  ///
  /// In zh, this message translates to:
  /// **'今日计数'**
  String get statusTodayCounts;

  /// No description provided for @statusCountsFooter.
  ///
  /// In zh, this message translates to:
  /// **'计数从本次内核启动开始累计，重启或切换工作模式后归零；已在服务器模式里做的重置也只清计数，不动规则与缓存。'**
  String get statusCountsFooter;

  /// No description provided for @statusQueries.
  ///
  /// In zh, this message translates to:
  /// **'查询'**
  String get statusQueries;

  /// No description provided for @statusBlocked.
  ///
  /// In zh, this message translates to:
  /// **'已拦截'**
  String get statusBlocked;

  /// No description provided for @statusAverageLatency.
  ///
  /// In zh, this message translates to:
  /// **'平均时延'**
  String get statusAverageLatency;

  /// No description provided for @statusCacheHitRate.
  ///
  /// In zh, this message translates to:
  /// **'缓存命中率'**
  String get statusCacheHitRate;

  /// No description provided for @statusServerPortReady.
  ///
  /// In zh, this message translates to:
  /// **'本机 DNS 端口可用，局域网设备可把它当作 DNS'**
  String get statusServerPortReady;

  /// No description provided for @statusTunnelActive.
  ///
  /// In zh, this message translates to:
  /// **'本机流量已经过谛听，解析与规则都在生效'**
  String get statusTunnelActive;

  /// No description provided for @statusServerPortClosed.
  ///
  /// In zh, this message translates to:
  /// **'DNS 端口未监听，服务器模式当前不提供解析'**
  String get statusServerPortClosed;

  /// No description provided for @statusCoreStopped.
  ///
  /// In zh, this message translates to:
  /// **'内核未运行，本机流量按系统默认网络走'**
  String get statusCoreStopped;

  /// No description provided for @siteLatencySheetLatency.
  ///
  /// In zh, this message translates to:
  /// **'延迟'**
  String get siteLatencySheetLatency;

  /// No description provided for @siteLatencySheetCategory.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get siteLatencySheetCategory;

  /// No description provided for @siteLatencySheetTarget.
  ///
  /// In zh, this message translates to:
  /// **'目标'**
  String get siteLatencySheetTarget;

  /// No description provided for @siteLatencySheetAverage.
  ///
  /// In zh, this message translates to:
  /// **'平均往返'**
  String get siteLatencySheetAverage;

  /// No description provided for @siteLatencySheetMinMax.
  ///
  /// In zh, this message translates to:
  /// **'最小 / 最大'**
  String get siteLatencySheetMinMax;

  /// No description provided for @siteLatencySheetJitter.
  ///
  /// In zh, this message translates to:
  /// **'抖动'**
  String get siteLatencySheetJitter;

  /// No description provided for @siteLatencySheetLoss.
  ///
  /// In zh, this message translates to:
  /// **'丢包'**
  String get siteLatencySheetLoss;

  /// No description provided for @siteLatencySheetDns.
  ///
  /// In zh, this message translates to:
  /// **'解析地址'**
  String get siteLatencySheetDns;

  /// No description provided for @siteLatencySheetLastRun.
  ///
  /// In zh, this message translates to:
  /// **'最近测速'**
  String get siteLatencySheetLastRun;

  /// No description provided for @siteLatencySheetNotTested.
  ///
  /// In zh, this message translates to:
  /// **'尚未测速。点测速按钮开始测量。'**
  String get siteLatencySheetNotTested;

  /// No description provided for @siteLatencySheetNoReply.
  ///
  /// In zh, this message translates to:
  /// **'三个回显请求都没有收到应答，可能是站点限流或当前网络不通。'**
  String get siteLatencySheetNoReply;

  /// No description provided for @siteLatencySheetFallbackFooter.
  ///
  /// In zh, this message translates to:
  /// **'系统 ping 不可用，这次数值来自 TCP 握手 / isReachable，衡量的是建连时延而不是 ICMP 回显，会略高于真实往返。'**
  String get siteLatencySheetFallbackFooter;

  /// No description provided for @siteLatencySheetIcmpFooter.
  ///
  /// In zh, this message translates to:
  /// **'数值来自系统 ping 的 ICMP 回显（3 次取平均）。本应用自身流量不经过 VPN，测的是物理网络。'**
  String get siteLatencySheetIcmpFooter;

  /// No description provided for @trafficStructureLive.
  ///
  /// In zh, this message translates to:
  /// **'实时汇总'**
  String get trafficStructureLive;

  /// No description provided for @trafficStructureFocused.
  ///
  /// In zh, this message translates to:
  /// **'重点流量结构'**
  String get trafficStructureFocused;

  /// No description provided for @trafficStructureToday.
  ///
  /// In zh, this message translates to:
  /// **'今日流量结构'**
  String get trafficStructureToday;

  /// No description provided for @trafficStructureBypass.
  ///
  /// In zh, this message translates to:
  /// **'旁路'**
  String get trafficStructureBypass;

  /// No description provided for @trafficStructureCache.
  ///
  /// In zh, this message translates to:
  /// **'缓存'**
  String get trafficStructureCache;

  /// No description provided for @trafficStructureRaceRate.
  ///
  /// In zh, this message translates to:
  /// **'竞速成功率'**
  String get trafficStructureRaceRate;

  /// No description provided for @trafficStructureBootstrapRate.
  ///
  /// In zh, this message translates to:
  /// **'Bootstrap 成功率'**
  String get trafficStructureBootstrapRate;

  /// No description provided for @trafficStructureBlockedShare.
  ///
  /// In zh, this message translates to:
  /// **'拦截占比'**
  String get trafficStructureBlockedShare;

  /// No description provided for @trafficStructureBlockRate.
  ///
  /// In zh, this message translates to:
  /// **'拦截率'**
  String get trafficStructureBlockRate;

  /// No description provided for @trafficStructureCacheRate.
  ///
  /// In zh, this message translates to:
  /// **'缓存率'**
  String get trafficStructureCacheRate;

  /// No description provided for @dashboardSitesTitle.
  ///
  /// In zh, this message translates to:
  /// **'仪表盘站点'**
  String get dashboardSitesTitle;

  /// No description provided for @dashboardSitesCardSection.
  ///
  /// In zh, this message translates to:
  /// **'仪表盘卡片'**
  String get dashboardSitesCardSection;

  /// No description provided for @dashboardSitesAtLeastOne.
  ///
  /// In zh, this message translates to:
  /// **'卡片至少保留 1 个站点'**
  String get dashboardSitesAtLeastOne;

  /// No description provided for @dashboardSitesFooter.
  ///
  /// In zh, this message translates to:
  /// **'这四张卡片用的是同一个仪表盘卡片，改动立刻生效；测速在详情页按分类手动触发。'**
  String get dashboardSitesFooter;

  /// No description provided for @trafficMonitorTitle.
  ///
  /// In zh, this message translates to:
  /// **'流量监控'**
  String get trafficMonitorTitle;

  /// No description provided for @trafficMonitorToday.
  ///
  /// In zh, this message translates to:
  /// **'今日代理流量'**
  String get trafficMonitorToday;

  /// No description provided for @trafficMonitorLiveRate.
  ///
  /// In zh, this message translates to:
  /// **'实时速率'**
  String get trafficMonitorLiveRate;

  /// No description provided for @trafficMonitorNoStats.
  ///
  /// In zh, this message translates to:
  /// **'本模式不统计'**
  String get trafficMonitorNoStats;

  /// No description provided for @memoryDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'内存详情'**
  String get memoryDetailTitle;

  /// No description provided for @memoryResample.
  ///
  /// In zh, this message translates to:
  /// **'重新采样'**
  String get memoryResample;

  /// No description provided for @memoryProcessPss.
  ///
  /// In zh, this message translates to:
  /// **'本进程 PSS'**
  String get memoryProcessPss;

  /// No description provided for @memoryUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'不可用'**
  String get memoryUnavailable;

  /// No description provided for @memoryOther.
  ///
  /// In zh, this message translates to:
  /// **'其它'**
  String get memoryOther;

  /// No description provided for @memoryComposition.
  ///
  /// In zh, this message translates to:
  /// **'进程构成'**
  String get memoryComposition;

  /// No description provided for @memoryCompositionFooter.
  ///
  /// In zh, this message translates to:
  /// **'PSS 按共享页的比例计入本进程，因此 Java 堆与原生堆之和小于 PSS，差额是代码、图形缓冲与共享库。'**
  String get memoryCompositionFooter;

  /// No description provided for @memoryOtherCode.
  ///
  /// In zh, this message translates to:
  /// **'其它（代码 / 共享库）'**
  String get memoryOtherCode;

  /// No description provided for @memorySystemSection.
  ///
  /// In zh, this message translates to:
  /// **'整机内存'**
  String get memorySystemSection;

  /// No description provided for @memorySystemFooter.
  ///
  /// In zh, this message translates to:
  /// **'整机占用 = 总量 - 可用量，包含系统与所有应用；本进程只是其中一份。'**
  String get memorySystemFooter;

  /// No description provided for @memorySystemUsed.
  ///
  /// In zh, this message translates to:
  /// **'整机已用'**
  String get memorySystemUsed;

  /// No description provided for @memoryRecentPss.
  ///
  /// In zh, this message translates to:
  /// **'最近 PSS'**
  String get memoryRecentPss;

  /// No description provided for @memorySampling.
  ///
  /// In zh, this message translates to:
  /// **'正在采样…'**
  String get memorySampling;

  /// No description provided for @memoryRecentPssCaption.
  ///
  /// In zh, this message translates to:
  /// **'打开本页后每 2 秒采样一次，最多保留 60 个点；曲线持续上扬说明有内存未释放。'**
  String get memoryRecentPssCaption;

  /// No description provided for @memorySourceFooter.
  ///
  /// In zh, this message translates to:
  /// **'数据来自 ActivityManager 的 MemoryInfo；切到后台或系统回收后数值会明显下降。'**
  String get memorySourceFooter;

  /// No description provided for @siteLatencyDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'测速详情'**
  String get siteLatencyDetailTitle;

  /// No description provided for @siteLatencyTestAll.
  ///
  /// In zh, this message translates to:
  /// **'测全部'**
  String get siteLatencyTestAll;

  /// No description provided for @siteLatencyCustomSites.
  ///
  /// In zh, this message translates to:
  /// **'自定义仪表盘站点'**
  String get siteLatencyCustomSites;

  /// No description provided for @siteLatencyConnectivity.
  ///
  /// In zh, this message translates to:
  /// **'站点连通性'**
  String get siteLatencyConnectivity;

  /// No description provided for @siteLatencyTestingShort.
  ///
  /// In zh, this message translates to:
  /// **'测速中'**
  String get siteLatencyTestingShort;

  /// No description provided for @siteLatencyNoTest.
  ///
  /// In zh, this message translates to:
  /// **'未测速'**
  String get siteLatencyNoTest;

  /// No description provided for @siteLatencyInProgress.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get siteLatencyInProgress;

  /// No description provided for @siteLatencyPending.
  ///
  /// In zh, this message translates to:
  /// **'待测'**
  String get siteLatencyPending;

  /// No description provided for @siteLatencyAllReachable.
  ///
  /// In zh, this message translates to:
  /// **'全部通畅'**
  String get siteLatencyAllReachable;

  /// No description provided for @siteLatencyTestingEach.
  ///
  /// In zh, this message translates to:
  /// **'正在逐个站点测速…'**
  String get siteLatencyTestingEach;

  /// No description provided for @siteLatencyPickCategory.
  ///
  /// In zh, this message translates to:
  /// **'选一个分类点测速，或点右上角测全部。'**
  String get siteLatencyPickCategory;

  /// No description provided for @siteLatencyThisRun.
  ///
  /// In zh, this message translates to:
  /// **'本次结果'**
  String get siteLatencyThisRun;

  /// No description provided for @siteLatencyReachable.
  ///
  /// In zh, this message translates to:
  /// **'通畅'**
  String get siteLatencyReachable;

  /// No description provided for @siteLatencyMeasuredSites.
  ///
  /// In zh, this message translates to:
  /// **'已测站点'**
  String get siteLatencyMeasuredSites;

  /// No description provided for @siteLatencyDetailFooter.
  ///
  /// In zh, this message translates to:
  /// **'每个站点发 3 个 ICMP 回显，取平均值；系统 ping 不可用时退回 TCP 握手，会标上 * 号，数值略高于真实往返。本应用自身流量不经过 VPN，测的是物理网络。'**
  String get siteLatencyDetailFooter;

  /// No description provided for @intranetDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'内网 IP 详情'**
  String get intranetDetailTitle;

  /// No description provided for @intranetRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新网络信息'**
  String get intranetRefresh;

  /// No description provided for @intranetLocalAddress.
  ///
  /// In zh, this message translates to:
  /// **'本机局域网地址'**
  String get intranetLocalAddress;

  /// No description provided for @intranetUsableAsDns.
  ///
  /// In zh, this message translates to:
  /// **'可作 DNS'**
  String get intranetUsableAsDns;

  /// No description provided for @intranetLocalOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅本机'**
  String get intranetLocalOnly;

  /// No description provided for @intranetSameSubnetHint.
  ///
  /// In zh, this message translates to:
  /// **'同网段设备把 DNS 指到这个地址即可走本机解析。'**
  String get intranetSameSubnetHint;

  /// No description provided for @intranetNetworkOverview.
  ///
  /// In zh, this message translates to:
  /// **'网络概况'**
  String get intranetNetworkOverview;

  /// No description provided for @commonEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已启用'**
  String get commonEnabled;

  /// No description provided for @commonDisabled.
  ///
  /// In zh, this message translates to:
  /// **'未启用'**
  String get commonDisabled;

  /// No description provided for @intranetDnsServers.
  ///
  /// In zh, this message translates to:
  /// **'DNS 服务器'**
  String get intranetDnsServers;

  /// No description provided for @intranetInterfaces.
  ///
  /// In zh, this message translates to:
  /// **'接口'**
  String get intranetInterfaces;

  /// No description provided for @intranetNoInterface.
  ///
  /// In zh, this message translates to:
  /// **'系统没有报告活动网络接口，可能是飞行模式或未联网。'**
  String get intranetNoInterface;

  /// No description provided for @intranetAdapter.
  ///
  /// In zh, this message translates to:
  /// **'网卡'**
  String get intranetAdapter;

  /// No description provided for @intranetGateway.
  ///
  /// In zh, this message translates to:
  /// **'网关'**
  String get intranetGateway;

  /// No description provided for @intranetPrivateDnsOff.
  ///
  /// In zh, this message translates to:
  /// **'系统私人 DNS 未开启，解析请求由本机与代理按模式处理。'**
  String get intranetPrivateDnsOff;

  /// No description provided for @intranetNoDnsServer.
  ///
  /// In zh, this message translates to:
  /// **'没有读到 DNS 服务器：接口未下发 DNS，或当前环境没有诊断通道。'**
  String get intranetNoDnsServer;

  /// No description provided for @intranetPrimaryDns.
  ///
  /// In zh, this message translates to:
  /// **'首选'**
  String get intranetPrimaryDns;

  /// No description provided for @intranetPrivateDns.
  ///
  /// In zh, this message translates to:
  /// **'私人 DNS'**
  String get intranetPrivateDns;

  /// No description provided for @intranetPortFooter.
  ///
  /// In zh, this message translates to:
  /// **'端口只在服务启动时绑定，改动端口后需要重启服务；把同网段设备的 DNS 指向上面的地址即可让它们走本机解析。'**
  String get intranetPortFooter;

  /// No description provided for @intranetCopyAddressWithPort.
  ///
  /// In zh, this message translates to:
  /// **'复制地址（含端口）'**
  String get intranetCopyAddressWithPort;

  /// No description provided for @speedDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'网速详情'**
  String get speedDetailTitle;

  /// No description provided for @speedCurrentDownload.
  ///
  /// In zh, this message translates to:
  /// **'当前下载'**
  String get speedCurrentDownload;

  /// No description provided for @speedSamplingPaused.
  ///
  /// In zh, this message translates to:
  /// **'暂停采样'**
  String get speedSamplingPaused;

  /// No description provided for @speedLive.
  ///
  /// In zh, this message translates to:
  /// **'实时'**
  String get speedLive;

  /// No description provided for @speedSamplingHint.
  ///
  /// In zh, this message translates to:
  /// **'每秒采样一次，下图是最近一分钟。'**
  String get speedSamplingHint;

  /// No description provided for @speedCurrentUpload.
  ///
  /// In zh, this message translates to:
  /// **'当前上传'**
  String get speedCurrentUpload;

  /// No description provided for @speedDownloadPeak.
  ///
  /// In zh, this message translates to:
  /// **'下行峰值'**
  String get speedDownloadPeak;

  /// No description provided for @speedUploadPeak.
  ///
  /// In zh, this message translates to:
  /// **'上行峰值'**
  String get speedUploadPeak;

  /// No description provided for @speedSamples.
  ///
  /// In zh, this message translates to:
  /// **'样本'**
  String get speedSamples;

  /// No description provided for @speedTodayTotal.
  ///
  /// In zh, this message translates to:
  /// **'今日累计'**
  String get speedTodayTotal;

  /// No description provided for @speedNoTrafficToday.
  ///
  /// In zh, this message translates to:
  /// **'流量库还没有今天的记录。'**
  String get speedNoTrafficToday;

  /// No description provided for @speedTotal.
  ///
  /// In zh, this message translates to:
  /// **'合计'**
  String get speedTotal;

  /// No description provided for @speedRateFooter.
  ///
  /// In zh, this message translates to:
  /// **'速率来自内核数据面的实时计数，只包含经过隧道转发的流量；本应用自身的探测与测速不计入。今日累计来自应用流量统计，与「流量统计」页同一份数据。'**
  String get speedRateFooter;

  /// No description provided for @speedExpressSource.
  ///
  /// In zh, this message translates to:
  /// **'极速模式不经过内核数据面，因此没有逐秒速率；切回普通模式后恢复。'**
  String get speedExpressSource;

  /// No description provided for @speedNoChannelSource.
  ///
  /// In zh, this message translates to:
  /// **'当前环境没有速率通道（桌面环境或纯 Dart 测试），读不到实时速率。'**
  String get speedNoChannelSource;

  /// No description provided for @speedNoDataInMode.
  ///
  /// In zh, this message translates to:
  /// **'当前模式下没有速率数据'**
  String get speedNoDataInMode;

  /// No description provided for @speedWaitingSample.
  ///
  /// In zh, this message translates to:
  /// **'正在等待第一个样本'**
  String get speedWaitingSample;

  /// No description provided for @commonNoData.
  ///
  /// In zh, this message translates to:
  /// **'无数据'**
  String get commonNoData;

  /// No description provided for @intranetModeNotListening.
  ///
  /// In zh, this message translates to:
  /// **'{mode}不监听局域网，其他设备无法把这里当 DNS'**
  String intranetModeNotListening(Object mode);

  /// No description provided for @intranetListeningOn.
  ///
  /// In zh, this message translates to:
  /// **'已监听 0.0.0.0:{port}，其他设备把 DNS 指到上面的地址'**
  String intranetListeningOn(Object port);

  /// No description provided for @intranetServiceStopped.
  ///
  /// In zh, this message translates to:
  /// **'服务未启动：启动后才会绑定 {port} 端口'**
  String intranetServiceStopped(Object port);

  /// No description provided for @commonCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制 {text}'**
  String commonCopied(Object text);

  /// No description provided for @intranetGatewaySuffix.
  ///
  /// In zh, this message translates to:
  /// **' · 网关 {gateway}'**
  String intranetGatewaySuffix(Object gateway);

  /// No description provided for @speedTotalDash.
  ///
  /// In zh, this message translates to:
  /// **'累计 —'**
  String get speedTotalDash;

  /// No description provided for @siteLatencyAliveRatio.
  ///
  /// In zh, this message translates to:
  /// **'{alive} / {total} 通畅'**
  String siteLatencyAliveRatio(Object alive, Object total);

  /// No description provided for @siteLatencyLastRun.
  ///
  /// In zh, this message translates to:
  /// **'最近测速 {ago}'**
  String siteLatencyLastRun(Object ago);

  /// No description provided for @siteLatencyProviderSuffix.
  ///
  /// In zh, this message translates to:
  /// **' · 解析服务商 {name}'**
  String siteLatencyProviderSuffix(Object name);

  /// No description provided for @siteLatencySitesCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个站点'**
  String siteLatencySitesCount(Object count);

  /// No description provided for @siteLatencyTestCategory.
  ///
  /// In zh, this message translates to:
  /// **'测速{category}'**
  String siteLatencyTestCategory(Object category);

  /// No description provided for @memorySystemShare.
  ///
  /// In zh, this message translates to:
  /// **'占整机 {percent}'**
  String memorySystemShare(Object percent);

  /// No description provided for @memorySystemUsedOf.
  ///
  /// In zh, this message translates to:
  /// **'整机已用 {used} / {total}'**
  String memorySystemUsedOf(Object total, Object used);

  /// No description provided for @memoryNoChannel.
  ///
  /// In zh, this message translates to:
  /// **'当前环境读不到内存数据（桌面环境或纯 Dart 测试）。'**
  String get memoryNoChannel;

  /// No description provided for @trafficStructureRateValue.
  ///
  /// In zh, this message translates to:
  /// **'{percent} · {count} 次 · {latency}'**
  String trafficStructureRateValue(
    Object count,
    Object latency,
    Object percent,
  );

  /// No description provided for @trafficStructureShareValue.
  ///
  /// In zh, this message translates to:
  /// **'{percent} · {count} 次'**
  String trafficStructureShareValue(Object count, Object percent);

  /// No description provided for @statusPausedSummary.
  ///
  /// In zh, this message translates to:
  /// **'{mode}{core}，计时已暂停'**
  String statusPausedSummary(Object core, Object mode);

  /// No description provided for @speedTotalsDown.
  ///
  /// In zh, this message translates to:
  /// **'下行 {percent}'**
  String speedTotalsDown(Object percent);

  /// No description provided for @speedTotalsUp.
  ///
  /// In zh, this message translates to:
  /// **'上行 {percent}'**
  String speedTotalsUp(Object percent);

  /// No description provided for @speedPeakAverage.
  ///
  /// In zh, this message translates to:
  /// **'峰值 {peak} · 平均 {average}'**
  String speedPeakAverage(Object average, Object peak);

  /// No description provided for @intranetConnectHintSentence.
  ///
  /// In zh, this message translates to:
  /// **'连上 Wi-Fi 或以太网后这里会显示可用地址。'**
  String get intranetConnectHintSentence;

  /// No description provided for @intranetModeNotListeningSentence.
  ///
  /// In zh, this message translates to:
  /// **'{mode}不监听局域网，其它设备无法把这里当 DNS。'**
  String intranetModeNotListeningSentence(Object mode);

  /// No description provided for @intranetPrivateDnsOn.
  ///
  /// In zh, this message translates to:
  /// **'系统开启了私人 DNS（{dns}），系统解析会走加密通道，可能绕过本地服务。'**
  String intranetPrivateDnsOn(Object dns);

  /// No description provided for @intranetSecondaryDns.
  ///
  /// In zh, this message translates to:
  /// **'备用 {index}'**
  String intranetSecondaryDns(Object index);

  /// No description provided for @intranetCopyAddressSemantics.
  ///
  /// In zh, this message translates to:
  /// **'复制地址 {address}'**
  String intranetCopyAddressSemantics(Object address);

  /// No description provided for @speedTotalAccumulated.
  ///
  /// In zh, this message translates to:
  /// **'累计 {value}'**
  String speedTotalAccumulated(Object value);

  /// No description provided for @dashboardSitesFull.
  ///
  /// In zh, this message translates to:
  /// **'卡片只能放 {count} 个站点，先点掉一个再换别的。'**
  String dashboardSitesFull(Object count);

  /// No description provided for @dashboardSitesRemaining.
  ///
  /// In zh, this message translates to:
  /// **'还可以再放 {count} 个站点。'**
  String dashboardSitesRemaining(Object count);

  /// No description provided for @dashboardSitesMax.
  ///
  /// In zh, this message translates to:
  /// **'卡片最多放 {count} 个站点，先取消一个再选。'**
  String dashboardSitesMax(Object count);

  /// No description provided for @dashboardSitesPosition.
  ///
  /// In zh, this message translates to:
  /// **'第 {index} 位'**
  String dashboardSitesPosition(Object index);

  /// No description provided for @siteLatencyFailedCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个失败'**
  String siteLatencyFailedCount(Object count);

  /// No description provided for @siteLatencyDetailFooterLong.
  ///
  /// In zh, this message translates to:
  /// **'每个站点发 3 个 ICMP 回显，取平均值；系统 ping 不可用时退回 TCP 握手，会标上 * 号，数值略高于真实往返。本应用自身流量不经过 VPN，测的是物理网络。'**
  String get siteLatencyDetailFooterLong;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'zh':
      return AppL10nZh();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

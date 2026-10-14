import type { WebSocketEvent } from './types';
import { HttpTransport } from './http';
import { EventChannel } from './ws';
import { CoreApi } from './core';
import { CacheApi } from './cache';
import { QueryLogApi } from './querylog';
import { FilterApi } from './filter';
import { NetworkApi } from './network';
import { WebAuthApi } from './web';
import { SecurityApi } from './security';
import { RewriteApi } from './rewrite';
import { nativeBridge, setCoreServiceStatusProvider } from './native';
import { isWebMode } from '../utils/env';

/**
 * IPC 服务聚合门面。
 * 统一组合传输、事件通道、平台桥接与各领域模块。
 */
class IPCService {
  private http = new HttpTransport();
  private events = new EventChannel(this.http);

  private core = new CoreApi(this.http);
  private cache = new CacheApi(this.http);
  private querylog = new QueryLogApi(this.http);
  private filter = new FilterApi(this.http);
  private network = new NetworkApi(this.http);
  private webAuth = new WebAuthApi(this.http, this.events);
  private security = new SecurityApi(this.http);
  private rewrite = new RewriteApi(this.http);

  constructor() {
    // Web 模式下原生桥接无 Wails 绑定，改由宿主机服务接口提供权威状态。
    setCoreServiceStatusProvider({ getCoreServiceStatus: () => this.core.getCoreServiceStatus() });
  }

  // --- 环境与连接 ---
  public isWebMode = () => isWebMode();
  public getMeta = () => this.core.getMeta();
  public onConnectionChange = (l: (c: boolean) => void) => this.http.onConnectionChange(l);
  public onAuthRequired = (l: (r: boolean) => void) => this.http.onAuthRequired(l);
  public onEvent = (l: (e: WebSocketEvent) => void) => this.events.subscribe(l);
  public connectWS = () => this.events.connect();
  public reconnectWS = () => this.events.reconnect();
  public disconnectWS = () => this.events.disconnect();
  public checkHealth = () => this.core.checkHealth();

  get isConnected(): boolean {
    return this.http.isConnected;
  }

  get token(): string {
    return this.http.token;
  }

  // --- 连接配置 ---
  public loadConfig = () => this.http.loadConfig();
  public saveConfig = (host: string, port: string, token: string) => this.http.saveConfig(host, port, token);
  public getConfig = () => this.http.getConfig();

  // --- 核心状态与 DNS 服务 ---
  public getStatus = () => this.core.getStatus();
  public startDNS = () => this.core.startDNS();
  public stopDNS = () => this.core.stopDNS();
  public enableTakeover = () => this.core.enableTakeover();
  public disableTakeover = () => this.core.disableTakeover();
  public getAdapters = () => this.core.getAdapters();
  public setAdapterTakeover = (id: string, enable: boolean) => this.core.setAdapterTakeover(id, enable);
  public checkPortConflicts = () => this.core.checkPortConflicts();
  public autofixPortConflicts = (startDNS = false) => this.core.autofixPortConflicts(startDNS);

  // --- 上游与 Bootstrap ---
  public getUpstreamConfig = () => this.core.getUpstreamConfig();
  public configureUpstream = (req: Parameters<CoreApi['configureUpstream']>[0]) => this.core.configureUpstream(req);
  public testUpstream = (req: Parameters<CoreApi['testUpstream']>[0]) => this.core.testUpstream(req);
  public configureBootstrap = (cfg: Parameters<CoreApi['configureBootstrap']>[0]) => this.core.configureBootstrap(cfg);

  // --- 智能缓存 ---
  public getCacheStats = () => this.cache.getStats();
  public getCacheEntries = (query = '', limit = 50) => this.cache.getEntries(query, limit);
  public getCacheTopDomains = (limit = 10) => this.cache.getTopDomains(limit);
  public clearCache = () => this.cache.clear();
  public getCacheConfig = () => this.cache.getConfig();
  public updateCacheConfig = (cfg: Parameters<CacheApi['updateConfig']>[0]) => this.cache.updateConfig(cfg);

  // --- 查询历史与统计中心 ---
  public searchQueryLog = (q: Parameters<QueryLogApi['search']>[0] = {}) => this.querylog.search(q);
  public getQueryStats = () => this.querylog.getStats();
  public clearQueryLog = () => this.querylog.clear();
  public getQueryLogConfig = () => this.querylog.getConfig();
  public updateQueryLogConfig = (cfg: Parameters<QueryLogApi['updateConfig']>[0]) => this.querylog.updateConfig(cfg);

  // --- 规则拦截 ---
  public getFilterStats = () => this.filter.getStats();
  public getFilterConfig = () => this.filter.getConfig();
  public updateFilterConfig = (cfg: Parameters<FilterApi['updateConfig']>[0]) => this.filter.updateConfig(cfg);
  public getFilterLists = () => this.filter.getLists();
  public addFilterList = (l: Parameters<FilterApi['addList']>[0]) => this.filter.addList(l);
  public updateFilterList = (l: Parameters<FilterApi['updateList']>[0]) => this.filter.updateList(l);
  public deleteFilterList = (id: string) => this.filter.deleteList(id);
  public refreshFilterLists = (id = '') => this.filter.refreshLists(id);
  public getCustomRules = () => this.filter.getCustomRules();
  public setCustomRules = (rules: string[]) => this.filter.setCustomRules(rules);
  public checkHost = (domain: string, qtype: string | number = 'A') => this.filter.checkHost(domain, qtype);
  public getBlockingSchedule = () => this.filter.getSchedule();
  public configureBlockingSchedule = (req: Parameters<FilterApi['configureSchedule']>[0]) => this.filter.configureSchedule(req);
  public getFilterPause = () => this.filter.getPause();
  public setFilterPause = (req: Parameters<FilterApi['setPause']>[0]) => this.filter.setPause(req);

  // --- 自定义重写与客户端管理 ---
  public getRewriteRules = () => this.rewrite.getRewriteRules();
  public addRewriteRule = (rule: Parameters<RewriteApi['addRewriteRule']>[0]) => this.rewrite.addRewriteRule(rule);
  public deleteRewriteRule = (domain: string) => this.rewrite.deleteRewriteRule(domain);
  public configureRewrite = (req: Parameters<RewriteApi['configureRewrite']>[0]) => this.rewrite.configureRewrite(req);
  public getClients = () => this.rewrite.getClients();
  public configureClientAlias = (req: Parameters<RewriteApi['configureClientAlias']>[0]) => this.rewrite.configureClientAlias(req);
  public getClientGroups = () => this.rewrite.getClientGroups();
  public configureClientGroups = (req: Parameters<RewriteApi['configureClientGroups']>[0]) => this.rewrite.configureClientGroups(req);

  // --- 安全访问、速率限制与协议隐私 ---
  public configureAccess = (req: Parameters<SecurityApi['configureAccess']>[0]) => this.security.configureAccess(req);
  public configureRateLimit = (req: Parameters<SecurityApi['configureRateLimit']>[0]) => this.security.configureRateLimit(req);
  public configureDNS64 = (req: Parameters<SecurityApi['configureDNS64']>[0]) => this.security.configureDNS64(req);
  public configureBlockUnqualified = (req: Parameters<SecurityApi['configureBlockUnqualified']>[0]) => this.security.configureBlockUnqualified(req);
  public configurePrivacy = (req: Parameters<SecurityApi['configurePrivacy']>[0]) => this.security.configurePrivacy(req);
  public configureECS = (req: Parameters<SecurityApi['configureECS']>[0]) => this.security.configureECS(req);
  public configureRebind = (req: Parameters<SecurityApi['configureRebind']>[0]) => this.security.configureRebind(req);
  public configureHosts = (req: Parameters<SecurityApi['configureHosts']>[0]) => this.security.configureHosts(req);
  public getSafeSearch = () => this.security.getSafeSearch();
  public configureSafeSearch = (req: Parameters<SecurityApi['configureSafeSearch']>[0]) => this.security.configureSafeSearch(req);

  // --- 局域网 DNS ---
  public getLANStatus = () => this.network.getLANStatus();
  public configureLAN = (req: Parameters<NetworkApi['configureLAN']>[0]) => this.network.configureLAN(req);
  public configureFirewall = (enable: boolean) => this.network.configureFirewall(enable);
  public configureWebFirewall = (enable: boolean) => this.network.configureWebFirewall(enable);

  // --- Web 远程管理认证 ---
  public getAuthStatus = () => this.webAuth.getAuthStatus();
  public login = (req: Parameters<WebAuthApi['login']>[0]) => this.webAuth.login(req);
  public logout = () => this.webAuth.logout();
  public setupAuth = (req: Parameters<WebAuthApi['setupAuth']>[0]) => this.webAuth.setupAuth(req);
  public changePassword = (req: Parameters<WebAuthApi['changePassword']>[0]) => this.webAuth.changePassword(req);
  public getWebStatus = () => this.webAuth.getWebStatus();
  public configureWeb = (req: Parameters<WebAuthApi['configureWeb']>[0]) => this.webAuth.configureWeb(req);
  public getLoginBackground = () => this.webAuth.getLoginBackground();
  public setLoginBackground = (req: Parameters<WebAuthApi['setLoginBackground']>[0]) => this.webAuth.setLoginBackground(req);
  public resetLoginBackground = (adminPassword?: string) => this.webAuth.resetLoginBackground(adminPassword);

  // --- Wails 原生平台委托 ---
  public runNativeEmergencyRestore = () => nativeBridge.runNativeEmergencyRestore();
  public isAutoStartEnabled = () => nativeBridge.isAutoStartEnabled();
  public getAutoStartStatus = () => nativeBridge.getAutoStartStatus();
  public setAutoStart = (enable: boolean) => nativeBridge.setAutoStart(enable);
  public getCoreServiceStatus = () => nativeBridge.getCoreServiceStatus();
  public startCoreService = () => nativeBridge.startCoreService();
  public stopCoreService = () => nativeBridge.stopCoreService();
  public restartCoreService = () => nativeBridge.restartCoreService();
  public installCoreService = () => nativeBridge.installCoreService();
  public installAndStartCoreService = () => nativeBridge.installAndStartCoreService();
  public uninstallCoreService = () => nativeBridge.uninstallCoreService();
}

export const ipc = new IPCService();

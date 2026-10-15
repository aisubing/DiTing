/** 谛听 (DITING) 核心与全模块类型定义 */

// 下列类型定义在子文件中，此处仅引入供 StatusResponse 等复合类型引用；
// 具体定义与拆分缘由见 ./types.network 与 ./types.dns。
import type {
  HostsConfig,
  RebindConfig,
  AccessControlConfig,
  RateLimitConfig,
  DNS64Config,
  ECSConfig,
} from './types.network';
import type { SafeSearchConfig } from './types.dns';

export interface ApiResponse<T = any> {
  success: boolean;
  message?: string;
  data?: T;
  error?: string;
  conflict?: PortCheckResult;
}

/** 宿主机平台元信息（GET /api/v1/meta，免鉴权） */
export interface MetaResponse {
  os: string;
}

export type UpstreamProtocol = 'PLAIN' | 'DOH' | 'DOH3' | 'DOT' | 'DOQ';

/** sdns:// 印章解析结果，字段可直接回填上游编辑表单 */
export interface ParseStampResponse {
  protocol: UpstreamProtocol;
  server: string;
  url?: string;
  providerName: string;
  path?: string;
  serverAddr?: string;
  bootstrapIps?: string[];
  /** SHA-256(RawTBSCertificate) 指纹，冒号分隔大写十六进制 */
  pin?: string;
  props: { dnssec: boolean; noLog: boolean; noFilter: boolean };
  protoName: string;
}

export interface UpstreamInfo {
  id: string;
  protocol: UpstreamProtocol;
  server: string;
  url?: string;
  weight?: number;
  active: boolean;
  /** 是否已启用证书固定（服务端仅暴露标志，不回传指纹） */
  pinSet?: boolean;
  successCount: number;
  failureCount: number;
  avgLatencyMs: number;
}

export interface BootstrapServer {
  id: string;
  name: string;
  address: string;
  weight?: number;
}

export interface BootstrapConfig {
  enabled: boolean;
  servers: BootstrapServer[];
}

export interface DNSStatus {
  running: boolean;
  listenAddresses: string[];
  allowLAN?: boolean;
  lanAddresses?: string[];
  mode: string;
  upstreams: UpstreamInfo[];
  bootstrap?: BootstrapConfig;
  conditionalRoutes?: Record<string, string>;
  enableEDE?: boolean;
  blockUnqualified?: boolean;
  blockPrivatePTR?: boolean;
  blockIPv6?: boolean;
  blockECH?: boolean;
  ednsPadding?: number;
  blockANY?: boolean;
  /** 最小化应答形式："notimp"（默认）或 "rfc8482" */
  blockANYMode?: string;
}

export interface AdapterState {
  id: string;
  name: string;
  index: number;
  description: string;
  ipv4DHCP: boolean;
  ipv6DHCP: boolean;
  ipv4DNS: string[];
  ipv6DNS: string[];
}

export interface TakeoverStatus {
  active: boolean;
  adapters: AdapterState[];
}

export interface MetricsStatus {
  totalQueries: number;
  successQueries: number;
  failedQueries: number;
  avgLatencyMs: number;
  qps: number;
}

export interface CacheStats {
  enabled: boolean;
  totalHits: number;
  totalMisses: number;
  staleHits: number;
  negativeHits: number;
  hitRatio: number;
  entryCount: number;
  maxEntries: number;
  evictionCount: number;
  prefetchCount: number;
}

export interface FilterStats {
  enabled: boolean;
  totalRules: number;
  activeLists: number;
  totalQueries: number;
  blockedQueries: number;
  allowedQueries: number;
  blockRate: number;
  scheduleActive: boolean;
  /** 定时暂停状态 */
  paused?: boolean;
  pausedRemainingSec?: number;
  pausedUntilMs?: number;
}

export interface StatusResponse {
  version: string;
  pid: number;
  uptimeSeconds: number;
  dns: DNSStatus;
  takeover: TakeoverStatus;
  metrics: MetricsStatus;
  cache?: CacheStats;
  filter?: FilterStats;
  hosts?: HostsConfig;
  rebind?: RebindConfig;
  access?: AccessControlConfig;
  rateLimit?: RateLimitConfig;
  dns64?: DNS64Config;
  rewrite?: RewriteConfig;
  ecs?: ECSConfig;
  clients?: ClientInfo[];
}

export type CacheMode = 'follow_dns_ttl' | 'limit_max_ttl' | 'fixed_ttl' | string;

export interface CacheConfig {
  enabled: boolean;
  maxEntries: number;
  mode: CacheMode;
  maxTtlSeconds: number;
  fixedTtlSeconds: number;
  minTtlEnabled: boolean;
  minTtlSeconds: number;
  staleFallbackEnabled: boolean;
  staleFallbackSeconds: number;
  negativeTtlEnabled: boolean;
  negativeTtlSeconds: number;
  optimistic: boolean;
  prefetchEnabled: boolean;
  prefetchThreshold: number;
  prefetchBeforeExpiryMs: number;
  /** 不参与缓存的域名正则（Go RE2，无回溯、免疫 ReDoS）；留空表示全部缓存 */
  excludePatterns?: string[];
  /** 是否把缓存落盘，重启后复用；默认关闭 */
  persistEnabled: boolean;
  /** 落盘文件路径；留空由后端按平台约定推导 */
  persistPath?: string;
  /** 定时落盘间隔（秒），取值范围 30–86400；缺省或 0 使用后端默认 300 */
  persistIntervalSeconds?: number;
}

/** 缓存落盘状态与操作结果 */
export interface CachePersistInfo {
  /** 生效的落盘文件路径 */
  path: string;
  /** 本次从文件恢复的条目数（仅「恢复」操作有意义） */
  restored?: number;
  /** 操作完成后内存中的条目总数 */
  entryCount: number;
  /** 是否开启定期落盘 */
  persistOn: boolean;
  /** 定时落盘间隔（秒） */
  intervalSec: number;
  /** 最近一次落盘失败的原因 */
  lastError?: string;
  /** 当前生效的排除正则 */
  excludeRules?: string[];
  /** 被排除规则拦下、绕过缓存的查询累计数 */
  excludeHits: number;
}

export interface CacheEntryItem {
  domain: string;
  qtype: string;
  ttl: number;
  originalTtl: number;
  remainingTtl: number;
  expiresAt: number;
  staleUntil: number;
  hitCount: number;
  lastHitAt: number;
  isNegative: boolean;
  status: 'fresh' | 'stale';
  ipList?: string[];
}

export interface CacheEntriesResponse {
  total: number;
  entries: CacheEntryItem[];
}

export interface CacheDomainStat {
  domain: string;
  qtype: string;
  hitCount: number;
  lastHitAt: number;
}

/** 查询历史与统计中心类型（定义见 ./types.querylog） */
export * from './types.querylog';
/** 强制安全搜索与定时暂停类型（定义见 ./types.dns） */
export * from './types.dns';
/** 网络/访问控制/协议隐私类型（定义见 ./types.network） */
export * from './types.network';
export interface AdapterInfo {
  id: string;
  name: string;
  description: string;
  index: number;
  status: string;
  gateway: string;
  ipv4DHCP: boolean;
  ipv6DHCP: boolean;
  ipv4DNS: string[];
  ipv6DNS: string[];
  isPhysical: boolean;
}

export interface PortConflictInfo {
  port?: number;
  protocol: string;
  localAddress: string;
  pid: number;
  processName: string;
  serviceName?: string;
  isICS: boolean;
  isSelf: boolean;
  diagnosis?: string;
}

export interface PortCheckResult {
  available: boolean;
  hasICS: boolean;
  canAutofix?: boolean;
  diagnostic: string;
  conflicts: PortConflictInfo[];
}

export interface QueryEventData {
  domain: string;
  qtype: string;
  clientIP: string;
  clientName?: string;
  durationMs: number;
  success: boolean;
  rcode?: string;
  cacheHit?: string;
  blocked?: boolean;
  filterRule?: string;
  filterReason?: string;
  errorMessage?: string;
}

export interface FilterList {
  id: string;
  name: string;
  url: string;
  enabled: boolean;
  rulesCount: number;
  lastUpdated: number;
  checksum?: string;
  /** 增量更新协商凭证（ETag / Last-Modified） */
  etag?: string;
  lastModified?: string;
  /** 最近一次拉取状态 */
  lastStatus?: 'ok' | 'unchanged' | 'cached' | 'failed' | string;
  lastError?: string;
}

export type BlockMode = 'null_ip' | 'nxdomain' | 'refused' | string;

export interface FilterConfig {
  enabled: boolean;
  blockMode: BlockMode;
  blockingIPv4: string;
  blockingIPv6: string;
  customRules: string[];
  lists: FilterList[];
  updateIntervalHours: number;
  dataDir?: string;
  scheduleEnabled: boolean;
  schedules: BlockingSchedule[];
  /** 响应侧别名链深度复检（深链拦截），默认关闭 */
  filterResponse?: boolean;
  /** 仅白名单模式：未命中放行规则一律阻断，默认关闭 */
  allowlistOnly?: boolean;
  /** 伪应答纠正：应答地址落在劫持地址集合内即改写为 NXDOMAIN，默认关闭 */
  bogusNxDomain?: boolean;
  /** 伪应答地址清单，接受单个 IP 与 CIDR 网段 */
  bogusNxDomainNetworks?: string[];
}

/** 单条分时拦截（时间计划） */
export interface BlockingSchedule {
  id: string;
  name: string;
  enabled: boolean;
  /** "mon".."sun"，空数组表示每天生效 */
  weekdays: string[];
  /** "HH:MM" */
  start: string;
  /** "HH:MM"，早于 start 表示跨夜窗口 */
  end: string;
}

/** 时间计划配置 + 实时生效状态 */
export interface ScheduleConfigResponse {
  enabled: boolean;
  schedules: BlockingSchedule[];
  /** 当前时刻拦截是否处于生效窗口 */
  active: boolean;
  /** 当前命中的计划 ID（无则空串） */
  activeId: string;
}

export interface UpdateScheduleRequest {
  enabled?: boolean;
  schedules?: BlockingSchedule[];
}

/** $dnsrewrite 规则给出的应答内容（仅 action === 'rewrite' 时存在） */
export interface RewriteResult {
  /** DNS 应答码数值，见 rcodeNames */
  rcode: number;
  /** 应答记录的展示形式，一条记录一项；为空表示权威 NODATA */
  summary?: string[];
}

export interface CheckHostResult {
  blocked: boolean;
  action: 'block' | 'allow' | 'pass' | 'rewrite' | string;
  matchedRule?: string;
  listName?: string;
  reason?: string;
  rewritten?: RewriteResult;
}

/** 应答码数值到可读名称的映射，与后端支持的 RCODE 关键字一致 */
export const RCODE_NAMES: Record<number, string> = {
  0: 'NOERROR',
  1: 'FORMERR',
  2: 'SERVFAIL',
  3: 'NXDOMAIN',
  4: 'NOTIMP',
  5: 'REFUSED',
};

export interface WebSocketEvent {
  type: 'query' | 'metrics' | 'takeover' | 'dns' | 'alert' | 'upstream' | 'background' | 'filter';
  timestamp: number;
  data: any;
}

export interface ProviderConfig {
  id: string;
  protocol: UpstreamProtocol;
  /** host:port；也可直接填写 sdns:// 印章 */
  server: string;
  url?: string;
  weight?: number;
  /**
   * 证书指纹（SHA-256(RawTBSCertificate)，冒号分隔十六进制）。
   * 填写后将替代系统 CA 链校验，仅用于自签/私有 CA 上游。
   */
  pin?: string;
}

export interface UpstreamConfigureRequest {
  mode: string;
  providers: ProviderConfig[];
  bootstrap?: BootstrapConfig;
  conditionalRoutes?: Record<string, string>;
  /**
   * 独立回退链。省略表示保持现状，传空数组表示关闭回退。
   * 与主链路是"两条链"而非"同一个列表的后续节点"：主链路有独立超时，
   * 超时或命中触发响应码后才整链切换。
   */
  fallbackProviders?: ProviderConfig[];
  /** 主链路独立超时（毫秒）；0 或省略表示采用服务端默认值（2000ms） */
  fallbackTimeoutMs?: number;
  /** 触发回退的响应码；省略表示保持现状，空数组表示恢复默认（SERVFAIL/REFUSED） */
  fallbackOnRcode?: number[];
  /** 传输层故障是否触发回退，默认 true */
  fallbackOnError?: boolean;
}

export interface TestUpstreamRequest {
  protocol: string;
  server: string;
  url?: string;
}

export interface TestUpstreamResponse {
  success: boolean;
  latencyMs: number;
  error?: string;
}

/** 开机自启托管机制：服务自启 / 登录自启 / 未配置 */
export type AutoStartMechanism = 'service' | 'login_item' | 'systemd' | 'xdg' | 'none' | string;

/** 宿主机开机自启托管状态（GET /api/v1/service/status） */
export interface AutoStartStatus {
  enabled: boolean;
  mechanism: AutoStartMechanism;
  detail: string;
}

export interface CoreServiceStatus {
  installed: boolean;
  running: boolean;
  state:
    | 'running'
    | 'stopped'
    | 'not_installed'
    | 'start_pending'
    | 'stop_pending'
    | 'foreground'
    | 'unknown'
    | string;
  stateText: string;
  executablePath: string;
  isElevated: boolean;
  canInstall: boolean;
  message?: string;
  /** 宿主机自启托管情况；旧版本服务不返回该字段 */
  autoStart?: AutoStartStatus;
}

export interface AuthStatusResponse {
  initialized: boolean;
  webEnabled: boolean;
  authenticated: boolean;
  username: string;
  locked: boolean;
  lockoutRemainingSec: number;
}

export interface LoginRequest {
  username: string;
  password: string;
}

export interface LoginResponse {
  token: string;
  username: string;
  expiresAt: number;
}

export interface SetupAuthRequest {
  username: string;
  password: string;
}

export interface ChangePasswordRequest {
  username: string;
  oldPassword?: string;
  newPassword: string;
}

export interface WebStatusResponse {
  enabled: boolean;
  port: number;
  listenAddress: string;
  lanAddresses: string[];
  webUrls: string[];
  firewallAllowed: boolean;
  /** 探测到的防火墙后端；"none" 表示未检测到任何管理器，端口本就对外开放 */
  firewallBackend: string;
  initialized: boolean;
  username: string;
}

export interface ConfigureWebRequest {
  enabled: boolean;
  port?: number;
  configureFirewall?: boolean;
}

export interface LoginBgConfig {
  type: 'none' | 'url' | 'custom';
  url: string;
  opacity: number;
  blur: number;
  updatedAt?: number;
}

export interface SetLoginBackgroundRequest {
  type?: 'none' | 'url' | 'custom';
  url: string;
  opacity: number;
  blur: number;
  adminPassword?: string;
}

export interface RewriteRule {
  domain: string;
  ips?: string[];
  cname?: string;
  txt?: string[];
  ttl?: number;
}

export interface RewriteConfig {
  enabled: boolean;
  ttl: number;
  rules: RewriteRule[];
}

export interface ConfigureRewriteRequest {
  enabled?: boolean;
  ttl?: number;
  rules?: RewriteRule[];
}

export interface ClientAlias {
  ip: string;
  name: string;
}

export interface ClientInfo {
  ip: string;
  name: string;
  queryCount: number;
  lastSeen: number;
}

export interface ConfigureClientAliasRequest {
  ip: string;
  name: string;
}

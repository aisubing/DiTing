/** 恶意网址库与家长控制类型定义（独立成文件以控制 types.ts 长度） */

/** 声誉查询配置；默认全部关闭 */
export interface SafeBrowsingConfig {
  enabled: boolean;
  parentalEnabled: boolean;
  /** 单次哈希前缀查询的超时（毫秒） */
  timeoutMs: number;
  /** 哈希前缀缓存条目数上限 */
  cacheSize: number;
  /** 缓存有效期（秒） */
  cacheTTLSeconds: number;
}

export interface SafeBrowsingStats {
  cacheHits: number;
  cacheMisses: number;
  lookups: number;
  /** 查询失败次数；失败一律放行，此计数用于观察第三方可用性 */
  failures: number;
  blocked: number;
}

export interface SafeBrowsingResponse {
  config: SafeBrowsingConfig;
  stats: SafeBrowsingStats;
  /** 命中后返回的阻断地址与方式，与规则拦截共用同一套策略 */
  blockingIPv4: string;
  blockingIPv6: string;
  blockMode: string;
}

/** 所有字段可选：省略表示沿用当前值 */
export interface ConfigureSafeBrowsingRequest {
  enabled?: boolean;
  parentalEnabled?: boolean;
  timeoutMs?: number;
  cacheSize?: number;
  cacheTTLSeconds?: number;
}

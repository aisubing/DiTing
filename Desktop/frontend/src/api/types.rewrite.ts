/** 自定义 DNS 重写与规则测试类型定义（独立成文件以控制 types.ts 长度） */

/** $dnsrewrite 规则给出的应答内容（仅 action === 'rewrite' 时存在） */
export interface RewriteResult {
  /** DNS 应答码数值，见 RCODE_NAMES */
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

/** 自定义重写记录单条；取值语法与 AdGuard $dnsrewrite 一致，由后端负责校验 */
export interface RewriteRecord {
  type: string;
  value: string;
}

export interface RewriteRule {
  domain: string;
  ips?: string[];
  cname?: string;
  txt?: string[];
  /** 快捷字段无法表达的记录类型（MX / SRV / NS / PTR / HTTPS / SVCB） */
  records?: RewriteRecord[];
  /** 应答码覆盖（NXDOMAIN / REFUSED 等），非空时不再返回任何记录 */
  rcode?: string;
  ttl?: number;
}

/** 重写规则可用的记录类型，与后端 rewriteRecordTypes 保持一致 */
export const REWRITE_RECORD_TYPES = [
  'A',
  'AAAA',
  'CNAME',
  'TXT',
  'MX',
  'SRV',
  'NS',
  'PTR',
  'HTTPS',
  'SVCB',
] as const;

/** 重写规则可覆盖的应答码 */
export const REWRITE_RCODES = [
  'NOERROR',
  'FORMERR',
  'SERVFAIL',
  'NXDOMAIN',
  'NOTIMP',
  'REFUSED',
] as const;

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

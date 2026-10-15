/** 网络访问控制、协议隐私与分组策略类型定义（从 types.ts 拆出以控制单文件长度） */

import type { BlockingSchedule } from './types';

export interface LANStatusResponse {
  allowLAN: boolean;
  listenAddresses: string[];
  lanAddresses: string[];
  firewallAllowed: boolean;
  /** 探测到的防火墙后端；"none" 表示未检测到任何管理器，端口本就对外开放 */
  firewallBackend: string;
}

export interface ConfigureLANRequest {
  allowLAN: boolean;
  configureFirewall?: boolean;
}

export interface AccessControlConfig {
  allowedClients: string[];
  blockedClients: string[];
}

export interface ConfigureAccessRequest {
  allowedClients: string[];
  blockedClients: string[];
}

export interface RateLimitConfig {
  enabled: boolean;
  rate: number;
  burst: number;
  ipv4Prefix: number;
  ipv6Prefix: number;
  exemptIPs: string[];
}

export interface ConfigureRateLimitRequest {
  enabled: boolean;
  rate: number;
  burst: number;
  ipv4Prefix: number;
  ipv6Prefix: number;
  exemptIPs: string[];
}

/** 客户端分组：一组 IP/CIDR 绑定专属规则集与拦截方式 */
export interface ClientGroup {
  id: string;
  name: string;
  enabled: boolean;
  /** IP 或 CIDR（支持 IPv4/IPv6） */
  clients: string[];
  /** 该组启用的订阅列表 ID；空数组表示继承全部 */
  ruleListIds?: string[];
  /** 组级拦截方式覆盖；空表示继承全局 */
  blockMode?: string;
  /** 组级时间计划：启用后该组按自身窗口拦截 */
  scheduleEnabled?: boolean;
  schedules?: BlockingSchedule[];
  /** 组级仅白名单模式 */
  allowlistOnly?: boolean;
  /**
   * 该组的专属上游节点 ID（空 = 沿用主链路）。
   * 命中该组的查询会直接由这些上游解析，不再经过默认上游。
   */
  upstreamIds?: string[];
}

/** 分组可绑定的订阅列表选项 */
export interface ClientGroupRuleListOption {
  id: string;
  name: string;
  enabled: boolean;
}

/** 分组可绑定的上游节点选项 */
export interface ClientGroupUpstreamOption {
  id: string;
  protocol: string;
  server: string;
}

export interface ClientGroupConfigResponse {
  enabled: boolean;
  groups: ClientGroup[];
  ruleLists: ClientGroupRuleListOption[];
  upstreams: ClientGroupUpstreamOption[];
}

export interface ConfigureClientGroupsRequest {
  enabled?: boolean;
  groups?: ClientGroup[];
}

export interface DNS64Config {
  enabled: boolean;
  prefixes: string[];
}

export interface ConfigureDNS64Request {
  enabled: boolean;
  prefixes: string[];
}

export interface ConfigureBlockUnqualifiedRequest {
  blockUnqualified: boolean;
}

export interface ConfigurePrivacyRequest {
  enableEDE?: boolean;
  blockPrivatePTR?: boolean;
  blockIPv6?: boolean;
  blockECH?: boolean;
  ednsPadding?: number;
  /** 对 ANY 查询返回最小化应答（RFC 8482） */
  blockANY?: boolean;
  /** 最小化应答形式："notimp"（默认）或 "rfc8482" */
  blockANYMode?: string;
}

export interface ECSConfig {
  enabled: boolean;
  stripECS: boolean;
  customSubnet: string;
}

export interface ConfigureECSRequest {
  enabled?: boolean;
  stripECS?: boolean;
  customSubnet?: string;
}

export interface HostsConfig {
  enabled: boolean;
  useSystemHost: boolean;
  customFiles: string[];
  ttl: number;
}

export interface RebindConfig {
  enabled: boolean;
  allowedDomains: string[];
}

export interface ConfigureRebindRequest {
  enabled?: boolean;
  allowedDomains?: string[];
}

export interface ConfigureHostsRequest {
  enabled?: boolean;
  useSystemHost?: boolean;
  customFiles?: string[];
  ttl?: number;
}

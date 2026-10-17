/** 服务端加密 DNS（DoT / DoH / DoQ）类型定义（独立成文件以控制 types.ts 长度） */

/** 服务端证书来源 */
export type CertSource = 'self_signed' | 'file' | 'pkcs12';

/** 服务端证书配置；不含任何私钥材料 */
export interface CertConfig {
  source: CertSource;
  /** 证书链 PEM 路径（file / pkcs12 时使用） */
  certFile: string;
  /** 私钥 PEM 路径（file 时使用） */
  keyFile: string;
  /** PKCS#12 口令（pkcs12 时使用） */
  pkcs12Password: string;
  keyType: 'ecdsa' | 'rsa' | string;
  commonName: string;
  dnsNames: string[];
  ipAddresses: string[];
  validDays: number;
}

export interface EncryptedDNSConfig {
  enabled: boolean;
  cert: CertConfig;
  dotEnabled: boolean;
  dohEnabled: boolean;
  doqEnabled: boolean;
  /** 空串表示监听全部网卡 */
  listenAddress: string;
  dotPort: number;
  dohPort: number;
  doqPort: number;
  dohPath: string;
  /** 客户端应使用的服务器名 */
  serverName: string;
  /**
   * 是否应答 `_dns.resolver.arpa.` 的 SVCB 探测（DDR，RFC 9462）。
   *
   * 默认关闭：开启后客户端会自动切到本机做加密解析，一旦证书不受信任，
   * 它会直接失去解析能力。
   */
  ddrEnabled: boolean;
  /**
   * 移动端配置描述文件的标识；首次生成后固定，避免设备重复安装。
   * 生成描述文件前为空串，界面不必感知它。
   */
  uuid?: string;
  /** 反向代理透传配置，默认关闭 */
  reverseProxy: ReverseProxyConfig;
}

/** 证书摘要；不含私钥与完整证书体 */
export interface CertInfo {
  source: CertSource | string;
  subject: string;
  issuer: string;
  serialNumber: string;
  notBefore: string;
  notAfter: string;
  dnsNames: string[];
  ipAddresses: string[];
  /** 距过期的天数，已过期为负 */
  daysRemaining: number;
  /** SHA-256 指纹（冒号分隔大写十六进制） */
  fingerprint: string;
  chainLength: number;
  loaded: boolean;
  error?: string;
  selfSigned: boolean;
}

export interface EncryptedDNSStatusResponse {
  config: EncryptedDNSConfig;
  cert: CertInfo;
  certDir: string;
  defaultDotPort: number;
  defaultDohPort: number;
  defaultDoqPort: number;
  defaultDohPath: string;
  /** 实际生效的 DoT 监听地址；未在监听时为空串 */
  dotListen: string;
  /** 实际生效的 DoH 监听地址；未在监听时为空串 */
  dohListen: string;
  /** 实际生效的 DoQ 监听地址；未在监听时为空串 */
  doqListen: string;
  /** 可直接交给终端使用的 DoH 地址列表（服务器名 + 各网卡地址） */
  dohUrls: string[];
  /** 可信来源里存在 0.0.0.0/0 或 ::/0，界面需给出显著警告 */
  unrestrictedTrust: boolean;
  /** 自签证书已进入续签窗口（30 天内到期） */
  certExpiresSoon: boolean;
  /** 自签证书已过期：客户端握手必然失败，界面必须显式提示 */
  certExpired: boolean;
}

/** 反向代理可信来源配置 */
export interface ReverseProxyConfig {
  enabled: boolean;
  trustedSources: string[];
  /** 自定义转发头名；空串表示按 X-Forwarded-For → X-Real-IP 依次尝试 */
  clientIpHeader: string;
}

/** 更新反向代理可信来源；字段省略表示沿用当前值 */
export interface ConfigureACLRequest {
  enabled?: boolean;
  trustedSources?: string[];
  clientIpHeader?: string;
  /** 显式确认接受 0.0.0.0/0 这类全放行配置 */
  confirmUnrestricted?: boolean;
}

/** 所有字段可选：省略表示沿用当前值 */
export interface ConfigureEncryptedDNSRequest {
  enabled?: boolean;
  dotEnabled?: boolean;
  dohEnabled?: boolean;
  doqEnabled?: boolean;
  ddrEnabled?: boolean;
  listenAddress?: string;
  dotPort?: number;
  dohPort?: number;
  doqPort?: number;
  dohPath?: string;
  serverName?: string;
  cert?: Partial<CertConfig>;
}

export interface GenerateCertRequest {
  keyType?: string;
  commonName?: string;
  dnsNames?: string[];
  ipAddresses?: string[];
  validDays?: number;
  /** 覆盖已存在的证书，会让已信任它的客户端全部失效 */
  force?: boolean;
}

export interface ImportCertRequest {
  mode: 'pem' | 'pkcs12';
  certPem?: string;
  keyPem?: string;
  /** PKCS#12 容器的 base64 编码 */
  data?: string;
  password?: string;
}

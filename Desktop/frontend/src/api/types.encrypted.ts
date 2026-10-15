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
  /** 可直接交给终端使用的 DoH 地址列表（服务器名 + 各网卡地址） */
  dohUrls: string[];
}

/** 所有字段可选：省略表示沿用当前值 */
export interface ConfigureEncryptedDNSRequest {
  enabled?: boolean;
  dotEnabled?: boolean;
  dohEnabled?: boolean;
  doqEnabled?: boolean;
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

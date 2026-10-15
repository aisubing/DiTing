import type {
  EncryptedDNSStatusResponse,
  ConfigureEncryptedDNSRequest,
  GenerateCertRequest,
  ImportCertRequest,
} from './types';
import type { HttpTransport } from './http';

/** 服务端加密 DNS（DoT / DoH / DoQ）证书与监听配置 API */
export class EncryptedDNSApi {
  constructor(private http: HttpTransport) {}

  /** 获取加密 DNS 配置、证书摘要与证书目录 */
  public getStatus(): Promise<EncryptedDNSStatusResponse> {
    return this.http.request<EncryptedDNSStatusResponse>('/api/v1/encrypted/dns/status');
  }

  /** 更新配置；返回归一化后的完整状态 */
  public configure(req: ConfigureEncryptedDNSRequest): Promise<EncryptedDNSStatusResponse> {
    return this.http.request<EncryptedDNSStatusResponse>('/api/v1/encrypted/dns/configure', {
      method: 'POST',
      body: JSON.stringify(req),
    });
  }

  /** 生成或重新签发自签证书 */
  public generateCert(req: GenerateCertRequest): Promise<EncryptedDNSStatusResponse> {
    return this.http.request<EncryptedDNSStatusResponse>('/api/v1/encrypted/dns/cert/generate', {
      method: 'POST',
      body: JSON.stringify(req),
    });
  }

  /** 导入一对 PEM 或一个 PKCS#12 容器作为服务端证书 */
  public importCert(req: ImportCertRequest): Promise<EncryptedDNSStatusResponse> {
    return this.http.request<EncryptedDNSStatusResponse>('/api/v1/encrypted/dns/cert/import', {
      method: 'POST',
      body: JSON.stringify(req),
    });
  }
}

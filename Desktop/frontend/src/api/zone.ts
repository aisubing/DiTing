import type {
  ZoneConfigResponse,
  ConfigureZoneRequest,
  ZoneTestResponse,
} from './types';
import type { HttpTransport } from './http';

/** 本地权威区（zone 文件）API */
export class ZoneApi {
  constructor(private http: HttpTransport) {}

  /** 获取本地权威区配置与各区构建结果 */
  public getZoneConfig(): Promise<ZoneConfigResponse> {
    return this.http.request<ZoneConfigResponse>('/api/v1/dns/zone/config');
  }

  /** 整体更新区配置并重建索引；返回重建后的完整状态 */
  public configureZone(req: ConfigureZoneRequest): Promise<ZoneConfigResponse> {
    return this.http.request<ZoneConfigResponse>('/api/v1/dns/zone/config', {
      method: 'POST',
      body: JSON.stringify(req),
    });
  }

  /** 保存前用同一套解析路径预演一次区文本 */
  public testZone(req: { origin: string; content: string; ttl?: number }): Promise<ZoneTestResponse> {
    return this.http.request<ZoneTestResponse>('/api/v1/dns/zone/test', {
      method: 'POST',
      body: JSON.stringify(req),
    });
  }
}

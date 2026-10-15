import type {
  StatusResponse,
  AdapterInfo,
  PortCheckResult,
  UpstreamConfigureRequest,
  ParseStampResponse,
  TestUpstreamRequest,
  TestUpstreamResponse,
  BootstrapConfig,
  MetaResponse,
  CoreServiceStatus,
} from './types';
import type { HttpTransport } from './http';

/** 核心网络与 DNS 状态、网卡接管、端口诊断与上游配置 */
export class CoreApi {
  constructor(private http: HttpTransport) {}

  public getStatus(): Promise<StatusResponse> {
    return this.http.request<StatusResponse>('/api/v1/status');
  }

  /** 获取宿主机运行平台信息（免鉴权，供平台自适应 UI 使用） */
  public getMeta(): Promise<MetaResponse> {
    return this.http.request<MetaResponse>('/api/v1/meta');
  }

  /**
   * 获取宿主机后台核心服务的真实状态。
   *
   * Web 控制台无 Wails 绑定，只能经此接口读取 SCM / systemd 的实际状态，
   * 以免退化为"未安装/未检测到"等与宿主机不符的占位展示。
   */
  public getCoreServiceStatus(): Promise<CoreServiceStatus> {
    return this.http.request<CoreServiceStatus>('/api/v1/service/status');
  }

  public async startDNS(): Promise<void> {
    await this.http.request<void>('/api/v1/dns/start', { method: 'POST' });
  }

  public async stopDNS(): Promise<void> {
    await this.http.request<void>('/api/v1/dns/stop', { method: 'POST' });
  }

  public async checkHealth(): Promise<boolean> {
    try {
      const res = await this.http.request<string>('/api/v1/health');
      return res === 'ok' || Boolean(res);
    } catch {
      return false;
    }
  }

  public async enableTakeover(): Promise<void> {
    await this.http.request<void>('/api/v1/takeover/enable', { method: 'POST' });
  }

  public async disableTakeover(): Promise<void> {
    await this.http.request<void>('/api/v1/takeover/disable', { method: 'POST' });
  }

  public getAdapters(): Promise<AdapterInfo[]> {
    return this.http.request<AdapterInfo[]>('/api/v1/adapters');
  }

  public async setAdapterTakeover(adapterId: string, enable: boolean): Promise<void> {
    await this.http.request<void>('/api/v1/takeover/adapter', {
      method: 'POST',
      body: JSON.stringify({ adapterId, enable }),
    });
  }

  public checkPortConflicts(): Promise<PortCheckResult> {
    return this.http.request<PortCheckResult>('/api/v1/portcheck');
  }

  public autofixPortConflicts(startDNS = false): Promise<PortCheckResult> {
    return this.http.request<PortCheckResult>('/api/v1/portcheck/autofix', {
      method: 'POST',
      body: JSON.stringify({ startDNS }),
    });
  }

  public getUpstreamConfig(): Promise<UpstreamConfigureRequest> {
    return this.http.request<UpstreamConfigureRequest>('/api/v1/upstream/configure');
  }

  public async configureUpstream(req: UpstreamConfigureRequest): Promise<void> {
    await this.http.request<void>('/api/v1/upstream/configure', {
      method: 'POST',
      body: JSON.stringify(req),
    });
  }

  public testUpstream(req: TestUpstreamRequest): Promise<TestUpstreamResponse> {
    return this.http.request<TestUpstreamResponse>('/api/v1/upstream/test', {
      method: 'POST',
      body: JSON.stringify(req),
    });
  }

  public parseStamp(stamp: string): Promise<ParseStampResponse> {
    return this.http.request<ParseStampResponse>('/api/v1/upstream/stamp', {
      method: 'POST',
      body: JSON.stringify({ stamp }),
    });
  }

  public async configureBootstrap(config: BootstrapConfig): Promise<void> {
    await this.http.request<void>('/api/v1/bootstrap/configure', {
      method: 'POST',
      body: JSON.stringify(config),
    });
  }
}

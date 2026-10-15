import type { FilterStats, FilterConfig, FilterList, CheckHostResult, ScheduleConfigResponse, UpdateScheduleRequest, FilterPauseResponse, FilterPauseRequest, BlockedServicesResponse, ConfigureBlockedServicesRequest, SafeBrowsingResponse, ConfigureSafeBrowsingRequest } from './types';
import type { HttpTransport } from './http';

/** 规则拦截（过滤引擎、订阅列表与自定义规则） */
export class FilterApi {
  constructor(private http: HttpTransport) {}

  public getStats(): Promise<FilterStats> {
    return this.http.request<FilterStats>('/api/v1/filter/stats');
  }

  public getConfig(): Promise<FilterConfig> {
    return this.http.request<FilterConfig>('/api/v1/filter/config');
  }

  public async updateConfig(config: Partial<FilterConfig>): Promise<void> {
    await this.http.request<void>('/api/v1/filter/config', {
      method: 'POST',
      body: JSON.stringify(config),
    });
  }

  public async getLists(): Promise<FilterList[]> {
    const res = await this.http.request<{ total: number; lists: FilterList[] }>('/api/v1/filter/lists');
    return res?.lists || [];
  }

  public async addList(list: Partial<FilterList>): Promise<void> {
    await this.http.request<void>('/api/v1/filter/lists/add', {
      method: 'POST',
      body: JSON.stringify(list),
    });
  }

  public async updateList(list: FilterList): Promise<void> {
    await this.http.request<void>('/api/v1/filter/lists/update', {
      method: 'POST',
      body: JSON.stringify(list),
    });
  }

  public async deleteList(id: string): Promise<void> {
    await this.http.request<void>('/api/v1/filter/lists/delete', {
      method: 'POST',
      body: JSON.stringify({ id }),
    });
  }

  public async refreshLists(id = ''): Promise<void> {
    await this.http.request<void>('/api/v1/filter/lists/refresh', {
      method: 'POST',
      body: JSON.stringify({ id }),
    });
  }

  public async getCustomRules(): Promise<string[]> {
    const res = await this.http.request<{ rules: string[] }>('/api/v1/filter/rules');
    return res?.rules || [];
  }

  public async setCustomRules(rules: string[]): Promise<void> {
    await this.http.request<void>('/api/v1/filter/rules', {
      method: 'POST',
      body: JSON.stringify({ rules }),
    });
  }

  public checkHost(domain: string, qtype: string | number = 'A'): Promise<CheckHostResult> {
    return this.http.request<CheckHostResult>('/api/v1/filter/check', {
      method: 'POST',
      body: JSON.stringify({ domain, qtype: String(qtype) }),
    });
  }

  public getSchedule(): Promise<ScheduleConfigResponse> {
    return this.http.request<ScheduleConfigResponse>('/api/v1/filter/schedule');
  }

  public async configureSchedule(req: UpdateScheduleRequest): Promise<void> {
    await this.http.request<void>('/api/v1/filter/schedule', {
      method: 'POST',
      body: JSON.stringify(req),
    });
  }

  /** 读取定时暂停拦截状态（含剩余秒数倒计时） */
  public getPause(): Promise<FilterPauseResponse> {
    return this.http.request<FilterPauseResponse>('/api/v1/filter/pause');
  }

  /** 暂停或恢复拦截；暂停需给出时长（秒） */
  public async setPause(req: FilterPauseRequest): Promise<void> {
    await this.http.request<void>('/api/v1/filter/pause', {
      method: 'POST',
      body: JSON.stringify(req),
    });
  }

  /** 读取内置阻断服务目录与当前勾选 */
  public getBlockedServices(): Promise<BlockedServicesResponse> {
    return this.http.request<BlockedServicesResponse>('/api/v1/filter/services');
  }

  /** 更新内置服务拦截勾选；省略的字段保持当前值 */
  public configureBlockedServices(req: ConfigureBlockedServicesRequest): Promise<BlockedServicesResponse> {
    return this.http.request<BlockedServicesResponse>('/api/v1/filter/services', {
      method: 'POST',
      body: JSON.stringify(req),
    });
  }

  /** 读取恶意网址库与家长控制的配置与统计 */
  public getSafeBrowsing(): Promise<SafeBrowsingResponse> {
    return this.http.request<SafeBrowsingResponse>('/api/v1/filter/safebrowsing');
  }

  /** 更新声誉查询配置；省略的字段保持当前值，返回归一化后的完整状态 */
  public configureSafeBrowsing(req: ConfigureSafeBrowsingRequest): Promise<SafeBrowsingResponse> {
    return this.http.request<SafeBrowsingResponse>('/api/v1/filter/safebrowsing', {
      method: 'POST',
      body: JSON.stringify(req),
    });
  }
}

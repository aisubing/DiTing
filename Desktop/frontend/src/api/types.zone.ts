/** 本地权威区（zone 文件）类型定义（独立成文件以控制 types.ts 长度） */

/** 单个本地权威区；origin 为该区的顶点，content 为 RFC 1035 区文件文本 */
export interface ZoneEntry {
  id: string;
  origin: string;
  content: string;
  enabled: boolean;
}

/** 单个区的构建结果；loaded 为 false 时 error 给出未加载原因 */
export interface ZoneState {
  id: string;
  origin: string;
  records: number;
  loaded: boolean;
  error?: string;
}

export interface ZoneConfigResponse {
  enabled: boolean;
  ttl: number;
  zones: ZoneEntry[];
  states: ZoneState[];
  /** 已加载的名字总数 */
  recordCount: number;
  /** 区数量上限，供界面提前提示 */
  maxZones: number;
  /** 记录总数上限 */
  maxRecords: number;
}

/** 三个字段均可选：省略表示沿用当前值，zones 传空数组表示清空全部区 */
export interface ConfigureZoneRequest {
  enabled?: boolean;
  ttl?: number;
  zones?: ZoneEntry[];
}

export interface ZoneTestRequest {
  origin: string;
  content: string;
  ttl?: number;
}

/** 保存前自检结果；success 为 false 时 error 给出解析失败原因 */
export interface ZoneTestResponse {
  success: boolean;
  records: string[];
  error?: string;
}

/**
 * 侧边导航与类别配置（App 与路由解析共用同一份定义）。
 *
 * 分类逻辑按「用户使用场景」而非实现模块划分：
 *   观测（总览） → 怎么解析（解析） → 拦什么（防护） → 管谁（设备） → 配本体（系统）
 */

export type NavTab = 'overview' | 'resolve' | 'protect' | 'devices' | 'system';

export interface NavItemDef {
  id: NavTab;
  label: string;
  icon: string;
  /** 顶栏语境说明 */
  hint: string;
}

export const NAV_ITEMS: readonly NavItemDef[] = [
  { id: 'overview', label: '总览', icon: 'dashboard', hint: '运行状态 · 实时查询 · 历史与统计' },
  { id: 'resolve', label: '解析', icon: 'upstream', hint: '上游调度 · 缓存加速 · 重写与 IPv6 过渡' },
  { id: 'protect', label: '防护', icon: 'shield', hint: '规则订阅 · 拦截策略与安全防护' },
  { id: 'devices', label: '设备', icon: 'devices', hint: '网卡接管 · 局域网服务 · 终端管控' },
  { id: 'system', label: '系统', icon: 'settings', hint: '外观 · 服务 · 远程控制台 · 诊断恢复' },
] as const;

export const VALID_TABS: readonly NavTab[] = NAV_ITEMS.map((item) => item.id);

export interface SubTabDef {
  id: string;
  label: string;
}

export const SUB_TABS: Record<NavTab, readonly SubTabDef[]> = {
  overview: [
    { id: 'status', label: '状态总览' },
    { id: 'queries', label: '实时查询' },
    { id: 'history', label: '查询历史' },
    { id: 'stats', label: '统计中心' },
  ],
  resolve: [
    { id: 'upstream', label: '上游解析' },
    { id: 'cache', label: '缓存加速' },
    { id: 'rewrite', label: 'DNS 重写' },
    { id: 'dns64', label: 'IPv6 / DNS64' },
  ],
  protect: [
    { id: 'lists', label: '规则订阅' },
    { id: 'services', label: '应用拦截' },
    { id: 'custom', label: '自定义规则' },
    { id: 'test', label: '规则检测' },
    { id: 'config', label: '拦截方式' },
    { id: 'advanced', label: '高级拦截' },
    { id: 'schedule', label: '时间计划' },
  ],
  devices: [
    { id: 'adapters', label: '网卡接管' },
    { id: 'lan', label: '局域网 DNS' },
    { id: 'clients', label: '设备管理' },
    { id: 'encrypted', label: '加密 DNS 服务' },
    { id: 'privacy', label: '安全隐私' },
  ],
  system: [
    { id: 'appearance', label: '外观主题' },
    { id: 'service', label: '服务与连接' },
    { id: 'lanweb', label: '局域网控制台' },
    { id: 'diagnostics', label: '诊断与修复' },
  ],
};

export function isValidTab(value: string): value is NavTab {
  return (VALID_TABS as readonly string[]).includes(value);
}

/** 取某大类的默认（首个）小类 */
export function defaultSub(tab: NavTab): string {
  return SUB_TABS[tab][0]?.id ?? '';
}

export function pickSub(tab: NavTab, sub: string): string {
  const subs = SUB_TABS[tab];
  return sub && subs.some((s) => s.id === sub) ? sub : defaultSub(tab);
}

/**
 * 校验并解析「大类 + 小类」路由，统一使用当前版本的导航配置结构。
 * 无法识别时返回 null（由调用方保留默认分类）。
 */
export function resolveRoute(rawTab: string, rawSub = ''): { tab: NavTab; sub: string } | null {
  const t = (rawTab || '').toLowerCase().trim().split(/[?#]/)[0];
  const s = (rawSub || '').toLowerCase().trim().split(/[?#]/)[0];
  if (!t || !isValidTab(t)) return null;

  return { tab: t, sub: pickSub(t, s) };
}

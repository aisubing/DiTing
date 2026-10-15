<script setup lang="ts">
import { ref, computed } from 'vue';
import { ipc } from '../../api/ipc';
import type { FilterStats, FilterConfig, FilterPauseResponse } from '../../api/types';
import StatusBadge from '../../components/StatusBadge.vue';
import M3Icon from '../../components/M3Icon.vue';
import AppCard from '../../components/ui/AppCard.vue';
import MetricStrip, { type StatEntry } from '../../components/ui/MetricStrip.vue';
import ToastBanner from '../../components/ToastBanner.vue';
import RuleListsPanel from '../../components/RuleListsPanel.vue';
import RuleTestPanel from '../../components/RuleTestPanel.vue';
import BogusNxDomainCard from './BogusNxDomainCard.vue';
import { revertSwitch, extractSwitchValue } from '../../utils/switch';
import { usePoller } from '../../composables/usePoller';
import { useToast } from '../../composables/useToast';

const stats = ref<FilterStats>({
  enabled: true,
  totalRules: 0,
  activeLists: 0,
  totalQueries: 0,
  blockedQueries: 0,
  allowedQueries: 0,
  blockRate: 0,
  scheduleActive: true,
});

const config = ref<FilterConfig>({
  enabled: true,
  blockMode: 'null_ip',
  blockingIPv4: '0.0.0.0',
  blockingIPv6: '::',
  customRules: [],
  lists: [],
  updateIntervalHours: 24,
  scheduleEnabled: false,
  schedules: [],
  filterResponse: false,
  allowlistOnly: false,
  bogusNxDomain: false,
  bogusNxDomainNetworks: [],
});

const listCount = ref(0);
const customRulesText = ref('');
/** 定时暂停拦截状态与倒计时 */
const pause = ref<FilterPauseResponse>({ paused: false, remainingSeconds: 0, pausedUntilMs: 0, blockingEnabled: true });
const pauseBusy = ref(false);
const pauseTarget = ref(30);
/** 子页签由上层 ProtectView 的分段控件驱动（hash 可直达） */
const activeTab = defineModel<string>('sub', { default: 'lists' });

const ruleStats = computed<StatEntry[]>(() => [
  { label: '已拦截请求', value: stats.value.blockedQueries.toLocaleString(), unit: '次', tone: 'seal' },
  { label: '拦截比例', value: stats.value.blockRate.toFixed(1), unit: '%' },
  { label: '有效防护规则', value: stats.value.totalRules.toLocaleString(), unit: '条' },
  { label: '已启用规则库', value: stats.value.activeLists, unit: '个' },
]);

const saving = ref(false);
const { toast, show: showToast, dismiss } = useToast();

async function fetchData() {
  try {
    const [st, cfg, l, rules, ps] = await Promise.all([
      ipc.getFilterStats(),
      ipc.getFilterConfig(),
      ipc.getFilterLists(),
      ipc.getCustomRules(),
      ipc.getFilterPause(),
    ]);
    if (st) stats.value = st;
    if (cfg) config.value = cfg;
    listCount.value = (l || []).length;
    customRulesText.value = (rules || []).join('\n');
    if (ps) pause.value = ps;
  } catch (err: any) {
    showToast(err?.message || '获取规则数据失败', true);
  }
}

/** 暂停剩余时间的人类可读文本 */
const pauseRemainingText = computed(() => {
  const sec = pause.value.remainingSeconds || 0;
  if (sec <= 0) return '';
  if (sec >= 86400) return `${Math.ceil(sec / 86400)} 天`;
  if (sec >= 3600) return `${Math.floor(sec / 3600)} 小时 ${Math.floor((sec % 3600) / 60)} 分`;
  if (sec >= 60) return `${Math.floor(sec / 60)} 分 ${sec % 60} 秒`;
  return `${sec} 秒`;
});

async function setPause(paused: boolean, durationSec?: number) {
  try {
    pauseBusy.value = true;
    await ipc.setFilterPause({ paused, durationSec });
    pause.value = await ipc.getFilterPause();
    showToast(paused ? `拦截已暂停（${pauseRemainingText.value}后自动恢复）` : '拦截已恢复');
  } catch (err: any) {
    showToast(err?.message || '操作拦截暂停状态失败', true);
  } finally {
    pauseBusy.value = false;
  }
}

async function toggleMasterSwitch(e: Event) {
  const nextVal = extractSwitchValue(e);
  try {
    saving.value = true;
    await ipc.updateFilterConfig({ enabled: nextVal });
    stats.value.enabled = nextVal;
    config.value.enabled = nextVal;
    showToast(`规则拦截防护已${nextVal ? '开启' : '关闭'}`);
  } catch (err: any) {
    revertSwitch(e, !nextVal);
    showToast(err?.message || '更新开关失败', true);
  } finally {
    saving.value = false;
  }
}

async function toggleResponseFilter(e: Event) {
  const next = extractSwitchValue(e);
  try {
    saving.value = true;
    await ipc.updateFilterConfig({ filterResponse: next });
    config.value.filterResponse = next;
    showToast(`响应侧别名链复检已${next ? '开启' : '关闭'}`);
  } catch (err: any) {
    revertSwitch(e, !next);
    showToast(err?.message || '更新深链拦截开关失败', true);
  } finally {
    saving.value = false;
  }
}

async function toggleAllowlistOnly(e: Event) {
  const next = extractSwitchValue(e);
  try {
    saving.value = true;
    await ipc.updateFilterConfig({ allowlistOnly: next });
    config.value.allowlistOnly = next;
    showToast(`仅白名单模式已${next ? '开启' : '关闭'}`);
  } catch (err: any) {
    revertSwitch(e, !next);
    showToast(err?.message || '更新仅白名单模式失败', true);
  } finally {
    saving.value = false;
  }
}

async function handleBogusToggle(next: boolean) {
  try {
    saving.value = true;
    await ipc.updateFilterConfig({ bogusNxDomain: next });
    config.value.bogusNxDomain = next;
    showToast(`伪应答纠正已${next ? '开启' : '关闭'}`);
  } catch (err: any) {
    showToast(err?.message || '更新伪应答纠正开关失败', true);
    await fetchData();
  } finally {
    saving.value = false;
  }
}

async function handleBogusNetworksSave(networks: string[]) {
  try {
    saving.value = true;
    await ipc.updateFilterConfig({ bogusNxDomainNetworks: networks });
    config.value.bogusNxDomainNetworks = networks;
    showToast(networks.length > 0 ? `已保存 ${networks.length} 条劫持地址` : '劫持地址清单已清空');
  } catch (err: any) {
    showToast(err?.message || '保存劫持地址清单失败', true);
    await fetchData();
  } finally {
    saving.value = false;
  }
}

async function saveCustomRules() {
  try {
    saving.value = true;
    const lines = customRulesText.value
      .split('\n')
      .map((l) => l.trim())
      .filter((l) => l.length > 0);
    await ipc.setCustomRules(lines);
    showToast(`自定义规则已保存生效 (共 ${lines.length} 条)`);
    await fetchData();
  } catch (err: any) {
    showToast(err?.message || '保存自定义规则失败', true);
  } finally {
    saving.value = false;
  }
}

async function saveConfig() {
  try {
    saving.value = true;
    await ipc.updateFilterConfig({
      blockMode: config.value.blockMode,
      blockingIPv4: config.value.blockingIPv4,
      blockingIPv6: config.value.blockingIPv6,
      updateIntervalHours: Number(config.value.updateIntervalHours) || 24,
    });
    showToast('拦截策略配置已保存');
    await fetchData();
  } catch (err: any) {
    showToast(err?.message || '保存策略失败', true);
  } finally {
    saving.value = false;
  }
}

usePoller(fetchData, 4000);
</script>

<template>
  <div class="space-y-6 max-w-7xl mx-auto pb-12 select-none">
    <!-- 顶部消息提示 -->
    <ToastBanner v-if="toast" :message="toast.message" :type="toast.isError ? 'error' : 'success'" dismissible @dismiss="dismiss" />

    <!-- 顶栏核心主控与指标卡片 -->
    <AppCard
      title="广告拦截与安全防护引擎"
      subtitle="毫秒级识别并阻断弹窗广告、隐私追踪与钓鱼恶意网址"
      icon="shield"
    >
      <template #badge>
        <StatusBadge
          :status="stats.enabled ? 'active' : 'inactive'"
          :text="stats.enabled ? '防护生效中' : '防护已暂停'"
          size="sm"
          :pulse="stats.enabled"
        />
      </template>

      <template #actions>
        <span class="text-[11px] font-semibold text-text-sub hidden sm:inline">
          {{ stats.enabled ? '规则拦截开启' : '拦截已关闭' }}
        </span>
        <md-switch
          :selected="stats.enabled"
          @change="toggleMasterSwitch"
          :disabled="saving"
        />
      </template>

      <!-- 拦截指标带 -->
      <div class="mt-3">
        <MetricStrip :stats="ruleStats" />
      </div>

      <!-- 定时暂停拦截快捷管控 -->
      <div class="mt-4 pt-4 border-t border-surface-border-sub">
        <div v-if="pause.paused" class="flex flex-wrap items-center justify-between gap-3 p-3 rounded-md border border-status-warning/40 bg-status-warning/10">
          <div class="flex items-center gap-2.5 min-w-0">
            <M3Icon name="schedule" :size="18" class="text-status-warning shrink-0" />
            <div class="min-w-0">
              <div class="text-[12.5px] font-bold text-text-main">拦截已暂停</div>
              <div class="text-[11px] text-text-sub">
                剩余 <span class="font-mono font-semibold">{{ pauseRemainingText }}</span> 后自动恢复拦截
              </div>
            </div>
          </div>
          <button type="button" class="app-btn-primary app-btn-compact" :disabled="pauseBusy" @click="setPause(false)">
            <M3Icon name="play_arrow" :size="14" />
            <span>立即恢复拦截</span>
          </button>
        </div>

        <div v-else class="flex flex-wrap items-center justify-between gap-3">
          <div class="min-w-0">
            <div class="text-[12.5px] font-semibold text-text-main">临时暂停拦截</div>
            <div class="text-[11px] text-text-sub">在指定时长内整体放行全部查询，到期自动恢复（重启服务亦恢复）</div>
          </div>
          <div class="flex items-center gap-2 shrink-0">
            <select
              v-model.number="pauseTarget"
              class="h-[32px] px-2.5 rounded-md border border-surface-border bg-surface-card text-xs text-text-main font-mono focus:outline-none focus:border-accent-seal"
            >
              <option :value="5">5 分钟</option>
              <option :value="30">30 分钟</option>
              <option :value="60">1 小时</option>
              <option :value="480">8 小时</option>
            </select>
            <button type="button" class="app-btn-secondary app-btn-compact" :disabled="pauseBusy" @click="setPause(true, pauseTarget * 60)">
              <M3Icon name="pause" :size="14" />
              <span>暂停</span>
            </button>
          </div>
        </div>
      </div>
    </AppCard>

    <!-- TAB 1: 订阅规则源列表 -->
    <RuleListsPanel
      v-if="activeTab === 'lists'"
      @error="(m) => showToast(m, true)"
      @success="(m) => showToast(m)"
      @changed="fetchData"
    />

    <!-- TAB 2: 自定义规则编辑器 (宽屏两列对等布局，窄屏单列) -->
    <div v-if="activeTab === 'custom'" class="grid grid-cols-1 lg:grid-cols-2 gap-5 items-stretch">
      <!-- 左侧：编写指南卡片 -->
      <AppCard
        title="AdGuard 语法速查指南"
        subtitle="主流广告过滤与信任规则编写格式"
        icon="help_outline"
        :iconSize="16"
      >
        <div class="space-y-2.5 mt-3 text-xs">
          <div class="app-card-sub p-2.5 space-y-1">
            <div class="flex items-center justify-between">
              <span class="font-semibold text-text-main">域名与子域名拦截</span>
              <span class="text-[10px] text-text-muted">常用格式</span>
            </div>
            <code class="font-mono text-accent-seal text-[12px] block">||example.com^</code>
            <p class="text-[11px] text-text-muted">匹配并拦截 example.com 及其所有子域名（如 ad.example.com）</p>
          </div>

          <div class="app-card-sub p-2.5 space-y-1">
            <div class="flex items-center justify-between">
              <span class="font-semibold text-text-main">白名单信任放行</span>
              <span class="text-[10px] text-text-muted">豁免放行</span>
            </div>
            <code class="font-mono text-status-success text-[12px] block">@@||safe.com^</code>
            <p class="text-[11px] text-text-muted">即便其他规则命中，也始终允许解析 safe.com</p>
          </div>

          <div class="app-card-sub p-2.5 space-y-1">
            <div class="flex items-center justify-between">
              <span class="font-semibold text-text-main">Hosts 文件格式</span>
              <span class="text-[10px] text-text-muted">传统兼容</span>
            </div>
            <code class="font-mono text-text-main text-[12px] block">0.0.0.0 bad.com</code>
            <p class="text-[11px] text-text-muted">兼容标准 Hosts 文件屏蔽特定恶意域名的语法</p>
          </div>

          <div class="app-card-sub p-2.5 space-y-1">
            <div class="flex items-center justify-between">
              <span class="font-semibold text-text-main">最高优先级强力拦截</span>
              <span class="text-[10px] text-text-muted">强制优先</span>
            </div>
            <code class="font-mono text-accent-seal text-[12px] block">||urgent.com^$important</code>
            <p class="text-[11px] text-text-muted">忽略所有白名单规则，强制拦截该域名</p>
          </div>

          <div class="app-card-sub p-2.5 space-y-1">
            <div class="flex items-center justify-between">
              <span class="font-semibold text-text-main">应答重写</span>
              <span class="text-[10px] text-text-muted">$dnsrewrite</span>
            </div>
            <code class="font-mono text-brand-primary text-[12px] block">||nas.lan^$dnsrewrite=10.0.0.5</code>
            <code class="font-mono text-brand-primary text-[12px] block">||old.com^$dnsrewrite=NXDOMAIN;;</code>
            <p class="text-[11px] text-text-muted">
              无需上游应答，直接按规则给出结果。支持 IPv4/IPv6 地址、域名（CNAME）、
              <code class="font-mono">NOERROR;A;1.2.3.4</code> 这类显式写法，以及
              <code class="font-mono">REFUSED</code>/<code class="font-mono">NXDOMAIN</code> 等应答码。
              优先级高于一切拦截与放行规则；用 <code class="font-mono">@@||nas.lan^$dnsrewrite</code>
              可取消该域名的全部重写。
            </p>
          </div>
        </div>

        <template #footer>
          <div class="text-[11px] text-text-muted">
            提示：每行一条规则，以 <code class="font-mono">!</code> 开头的行为注释。
          </div>
        </template>
      </AppCard>

      <!-- 右侧：编辑器卡片 -->
      <AppCard
        title="自定义规则文本编辑器"
        subtitle="编辑用户专属的过滤拦截或放行清单"
        icon="tune"
        :iconSize="16"
      >
        <template #actions>
          <button type="button" @click="saveCustomRules" :disabled="saving" class="app-btn-primary app-btn-compact">
            <M3Icon name="check" :size="14" />
            <span>{{ saving ? '保存中...' : '保存规则' }}</span>
          </button>
        </template>

        <div class="mt-3 flex-1 flex flex-col">
          <div class="app-card-sub p-2 focus-within:border-accent-seal flex-1 flex flex-col">
            <textarea
              v-model="customRulesText"
              rows="15"
              placeholder="在此输入自定义拦截或信任规则，每行一条...&#10;||ad.example.com^&#10;@@||mysite.com^"
              class="w-full h-full min-h-[280px] bg-transparent border-0 resize-y p-2 text-xs font-mono text-text-main focus:outline-none placeholder:text-text-muted"
            ></textarea>
          </div>
        </div>

        <template #footer>
          <div class="flex items-center justify-between text-[11px] text-text-muted">
            <span>行数统计: {{ customRulesText ? customRulesText.split('\n').filter(l => l.trim()).length : 0 }} 条规则</span>
            <span>修改后点击保存立即热重载生效</span>
          </div>
        </template>
      </AppCard>
    </div>

    <!-- TAB 3: 域名规则检测工具 -->
    <RuleTestPanel v-if="activeTab === 'test'" @error="(m) => showToast(m, true)" />

    <!-- TAB 4: 策略配置 (宽屏两列对等布局，窄屏单列) -->
    <div v-if="activeTab === 'config'" class="grid grid-cols-1 lg:grid-cols-2 gap-5 items-stretch">
      <!-- 左侧：响应动作卡片 -->
      <AppCard
        title="拦截响应处理方式"
        subtitle="当遇到被拦截网址时向客户端返回的行为"
        icon="shield"
        :iconSize="16"
      >
        <div class="space-y-3 mt-3.5 text-xs">
          <label
            class="flex items-start gap-3 cursor-pointer p-3 rounded-md border transition-all"
            :class="config.blockMode === 'null_ip' ? 'bg-brand-container/40 border-brand-primary/40' : 'border-surface-border-sub bg-surface-card-sub hover:bg-surface-hover'"
          >
            <input type="radio" v-model="config.blockMode" value="null_ip" class="accent-brand-primary mt-0.5" />
            <div>
              <div class="font-bold text-text-main text-[13px]">立即返回空地址 (0.0.0.0 / ::)</div>
              <div class="text-[11px] text-text-sub mt-0.5 leading-relaxed">
                强烈推荐。以极速终止广告和弹窗资源加载，不会引起浏览器反复重发请求。
              </div>
            </div>
          </label>

          <label
            class="flex items-start gap-3 cursor-pointer p-3 rounded-md border transition-all"
            :class="config.blockMode === 'nxdomain' ? 'bg-brand-container/40 border-brand-primary/40' : 'border-surface-border-sub bg-surface-card-sub hover:bg-surface-hover'"
          >
            <input type="radio" v-model="config.blockMode" value="nxdomain" class="accent-brand-primary mt-0.5" />
            <div>
              <div class="font-bold text-text-main text-[13px]">提示域名不存在 (NXDOMAIN)</div>
              <div class="text-[11px] text-text-sub mt-0.5 leading-relaxed">
                告知客户端该网址不存在，部分标准网络软件将放弃进一步连接探测。
              </div>
            </div>
          </label>

          <label
            class="flex items-start gap-3 cursor-pointer p-3 rounded-md border transition-all"
            :class="config.blockMode === 'refused' ? 'bg-brand-container/40 border-brand-primary/40' : 'border-surface-border-sub bg-surface-card-sub hover:bg-surface-hover'"
          >
            <input type="radio" v-model="config.blockMode" value="refused" class="accent-brand-primary mt-0.5" />
            <div>
              <div class="font-bold text-text-main text-[13px]">明确拒绝请求 (REFUSED)</div>
              <div class="text-[11px] text-text-sub mt-0.5 leading-relaxed">
                向客户端返回拒绝码，表示请求被 DNS 防火墙安全策略主动阻止。
              </div>
            </div>
          </label>
        </div>

        <template #footer>
          <div class="text-[11px] text-text-muted">
            当前模式: <span class="font-mono text-text-main font-semibold">{{ config.blockMode }}</span>
          </div>
        </template>
      </AppCard>

      <!-- 右侧：更新周期与参数卡片 -->
      <AppCard
        title="规则自动更新与网络参数"
        subtitle="订阅规则库同步周期与重定向 IP 设置"
        icon="sync"
        :iconSize="16"
      >
        <div class="space-y-3.5 mt-3 text-xs">
          <div>
            <label class="text-[11px] font-semibold text-text-muted block mb-1">规则库自动同步周期 (小时)</label>
            <input
              v-model="config.updateIntervalHours"
              type="number"
              min="1"
              class="w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card-sub text-xs focus:outline-none focus:border-accent-seal text-text-main font-mono"
            />
            <span class="text-[10px] text-text-muted mt-1 block">定时从远程规则源获取更新并增量载入，默认 24 小时</span>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1">
            <div>
              <label class="text-[11px] font-semibold text-text-muted block mb-1">阻断 IPv4 响应地址</label>
              <input
                v-model="config.blockingIPv4"
                type="text"
                class="w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card-sub text-xs focus:outline-none focus:border-accent-seal text-text-main font-mono"
              />
            </div>

            <div>
              <label class="text-[11px] font-semibold text-text-muted block mb-1">阻断 IPv6 响应地址</label>
              <input
                v-model="config.blockingIPv6"
                type="text"
                class="w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card-sub text-xs focus:outline-none focus:border-accent-seal text-text-main font-mono"
              />
            </div>
          </div>
        </div>

        <template #footer>
          <div class="flex justify-end">
            <button type="button" @click="saveConfig" :disabled="saving" class="app-btn-primary">
              <M3Icon name="check" :size="15" />
              <span>{{ saving ? '保存中...' : '保存策略与参数' }}</span>
            </button>
          </div>
        </template>
      </AppCard>
    </div>

    <!-- TAB 5: 高级拦截能力（深链复检 / 仅白名单，均为新增能力，默认关闭） -->
    <AppCard
      v-if="activeTab === 'advanced'"
      title="高级拦截能力"
      subtitle="针对绕过手法的增强拦截策略，默认关闭，按需开启"
      icon="shield"
      :iconSize="16"
    >
      <div class="space-y-3 mt-3 text-xs">
        <!-- 响应侧别名链复检 -->
        <div class="app-card-sub p-3 space-y-2">
          <div class="flex items-center justify-between gap-3">
            <div class="min-w-0">
              <span class="font-bold text-text-main text-[13px]">响应侧别名链深度复检</span>
              <span class="text-[10px] text-text-muted ml-2 font-mono">CNAME 深链拦截</span>
            </div>
            <md-switch :selected="!!config.filterResponse" :disabled="saving" @change="toggleResponseFilter" />
          </div>
          <p class="text-[11px] text-text-sub leading-relaxed">
            对上游应答中的 CNAME 目标与 A/AAAA 记录所属名二次匹配黑名单，拦截「查询域名合法但别名指向黑名单域」的
            CDN 换域或跳转器绕过。缓存命中的应答同样复检，命中后立即剔除被投毒的缓存条目。
          </p>
        </div>

        <!-- 仅白名单模式 -->
        <div class="app-card-sub p-3 space-y-2">
          <div class="flex items-center justify-between gap-3">
            <div class="min-w-0">
              <span class="font-bold text-text-main text-[13px]">仅白名单模式</span>
              <span class="text-[10px] text-text-muted ml-2 font-mono">Allowlist Only</span>
            </div>
            <md-switch :selected="!!config.allowlistOnly" :disabled="saving" @change="toggleAllowlistOnly" />
          </div>
          <p class="text-[11px] text-text-sub leading-relaxed">
            开启后仅命中放行规则（<code class="font-mono">@@</code> 例外）的查询才被放行，其余一律阻断（含未命中任何规则）。
            本地 Hosts / 重写 / 内网域名等本地权威应答不受影响。
          </p>
          <p v-if="config.allowlistOnly" class="text-[11px] text-status-warning leading-relaxed">
            注意：请先确保已配置充分的放行白名单，否则可能造成大面积域名解析失败。
          </p>
        </div>

        <!-- 伪应答纠正 -->
        <BogusNxDomainCard
          :enabled="!!config.bogusNxDomain"
          :networks="config.bogusNxDomainNetworks || []"
          :saving="saving"
          @toggle="handleBogusToggle"
          @save="handleBogusNetworksSave"
        />
      </div>
    </AppCard>
  </div>
</template>

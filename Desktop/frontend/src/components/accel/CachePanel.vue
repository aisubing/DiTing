<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { ipc } from '../../api/ipc';
import type {
  CacheStats,
  CacheConfig,
  CacheEntryItem,
  CacheDomainStat,
  CachePersistInfo,
} from '../../api/types';
import StatusBadge from '../StatusBadge.vue';
import M3Icon from '../M3Icon.vue';
import AppCard from '../ui/AppCard.vue';
import CardTile from '../ui/CardTile.vue';
import ConfirmModal from '../ConfirmModal.vue';
import ToastBanner from '../ToastBanner.vue';
import CacheTopDomains from './CacheTopDomains.vue';
import CacheConfigCard from './CacheConfigCard.vue';
import CacheEntriesTable from './CacheEntriesTable.vue';
import CachePersistCard from './CachePersistCard.vue';
import CacheExcludeCard from './CacheExcludeCard.vue';
import { revertSwitch, extractSwitchValue } from '../../utils/switch';
import { usePoller } from '../../composables/usePoller';
import { useToast } from '../../composables/useToast';

const stats = ref<CacheStats>({
  enabled: true,
  totalHits: 0,
  totalMisses: 0,
  staleHits: 0,
  negativeHits: 0,
  hitRatio: 0,
  entryCount: 0,
  maxEntries: 4096,
  evictionCount: 0,
  prefetchCount: 0,
});

const config = ref<CacheConfig>({
  enabled: true,
  maxEntries: 4096,
  mode: 'limit_max_ttl',
  maxTtlSeconds: 3600,
  fixedTtlSeconds: 3600,
  minTtlEnabled: true,
  minTtlSeconds: 60,
  staleFallbackEnabled: true,
  staleFallbackSeconds: 300,
  negativeTtlEnabled: true,
  negativeTtlSeconds: 30,
  optimistic: true,
  prefetchEnabled: false,
  prefetchThreshold: 5,
  prefetchBeforeExpiryMs: 30000,
  excludePatterns: [],
  persistEnabled: false,
  persistPath: '',
  persistIntervalSeconds: 300,
});

const persistInfo = ref<CachePersistInfo | null>(null);
const persistBusy = ref(false);

const entries = ref<CacheEntryItem[]>([]);
const topDomains = ref<CacheDomainStat[]>([]);
const totalEntriesCount = ref(0);
const currentSearch = ref('');

const loading = ref(false);
const saving = ref(false);
const clearing = ref(false);
const isClearDialogOpen = ref(false);
const { toast, show: showToast, dismiss } = useToast();

const hitRatioPercent = computed(() => {
  const ratio = (stats.value.hitRatio || 0) * 100;
  return `${ratio.toFixed(1)}%`;
});

async function loadData() {
  loading.value = true;
  try {
    const [st, cfg, entryRes, top, persist] = await Promise.all([
      ipc.getCacheStats(),
      ipc.getCacheConfig(),
      ipc.getCacheEntries(currentSearch.value, 100),
      ipc.getCacheTopDomains(10),
      // 落盘状态属于附加信息：接口不可用不应拖垮整个面板的加载
      ipc.getCachePersist().catch(() => null),
    ]);
    stats.value = st;
    config.value = cfg;
    entries.value = entryRes?.entries || [];
    totalEntriesCount.value = entryRes?.total || 0;
    topDomains.value = top || [];
    persistInfo.value = persist;
  } catch (err: any) {
    showToast(err.message || '加载缓存数据失败', true);
  } finally {
    loading.value = false;
  }
}

async function pollMetrics() {
  try {
    const [st, entryRes, top] = await Promise.all([
      ipc.getCacheStats(),
      ipc.getCacheEntries(currentSearch.value, 100),
      ipc.getCacheTopDomains(10),
    ]);
    stats.value = st;
    entries.value = entryRes?.entries || [];
    totalEntriesCount.value = entryRes?.total || 0;
    topDomains.value = top || [];
  } catch {
    // 忽略静默遥测异常
  }
}

async function handleSearch(query: string) {
  currentSearch.value = query;
  try {
    const entryRes = await ipc.getCacheEntries(query, 100);
    entries.value = entryRes?.entries || [];
    totalEntriesCount.value = entryRes?.total || 0;
  } catch (err: any) {
    showToast(err.message, true);
  }
}

async function handleToggleCache(e: Event) {
  const enable = extractSwitchValue(e);
  try {
    const updated = { ...config.value, enabled: enable };
    await ipc.updateCacheConfig(updated);
    config.value = updated;
    stats.value.enabled = enable;
    showToast(enable ? '解析加速已开启' : '解析加速已关闭');
  } catch (err: any) {
    showToast(`切换加速状态失败: ${err.message}`, true);
    revertSwitch(e, !enable);
  }
}

async function handleSaveConfig() {
  saving.value = true;
  try {
    await ipc.updateCacheConfig(config.value);
    showToast('加速策略配置已保存并即时生效！');
    await loadData();
  } catch (err: any) {
    showToast(`保存配置失败: ${err.message}`, true);
  } finally {
    saving.value = false;
  }
}

/** 统一的落盘配置保存：切换开关与调整间隔共用 */
async function savePersistConfig(patch: Partial<CacheConfig>, successMsg: string) {
  saving.value = true;
  try {
    const updated = { ...config.value, ...patch };
    await ipc.updateCacheConfig(updated);
    config.value = updated;
    showToast(successMsg);
    persistInfo.value = await ipc.getCachePersist().catch(() => persistInfo.value);
  } catch (err: any) {
    showToast(`保存落盘配置失败: ${err.message}`, true);
    // 失败后回读服务端配置，避免界面停留在未生效的状态
    await loadData();
  } finally {
    saving.value = false;
  }
}

async function handleTogglePersist(enabled: boolean) {
  await savePersistConfig(
    { persistEnabled: enabled },
    enabled ? '缓存落盘已开启' : '缓存落盘已关闭'
  );
}

async function handlePersistInterval(seconds: number) {
  await savePersistConfig({ persistIntervalSeconds: seconds }, '落盘间隔已更新');
}

async function handleExcludeSave(patterns: string[]) {
  saving.value = true;
  try {
    const updated = { ...config.value, excludePatterns: patterns };
    await ipc.updateCacheConfig(updated);
    config.value = updated;
    showToast(patterns.length > 0 ? `已保存 ${patterns.length} 条排除规则` : '已清空排除规则，全部域名重新参与缓存');
    persistInfo.value = await ipc.getCachePersist().catch(() => persistInfo.value);
  } catch (err: any) {
    showToast(`保存排除规则失败: ${err.message}`, true);
  } finally {
    saving.value = false;
  }
}

async function handleDumpCache() {
  persistBusy.value = true;
  try {
    const res = await ipc.dumpCache();
    persistInfo.value = res;
    showToast(`已落盘 ${res?.entryCount ?? 0} 条缓存记录`);
  } catch (err: any) {
    showToast(`落盘失败: ${err.message}`, true);
  } finally {
    persistBusy.value = false;
  }
}

async function handleLoadCache() {
  persistBusy.value = true;
  try {
    const res = await ipc.loadCache();
    persistInfo.value = res;
    showToast(`已从落盘文件恢复 ${res?.restored ?? 0} 条缓存记录`);
    await loadData();
  } catch (err: any) {
    showToast(`恢复失败: ${err.message}`, true);
  } finally {
    persistBusy.value = false;
  }
}

async function handleConfirmClear() {
  clearing.value = true;
  try {
    await ipc.clearCache();
    isClearDialogOpen.value = false;
    showToast('加速缓存已全部清空！');
    await loadData();
  } catch (err: any) {
    showToast(`清空缓存失败: ${err.message}`, true);
  } finally {
    clearing.value = false;
  }
}

onMounted(() => {
  loadData();
});

usePoller(pollMetrics, 4000);
</script>

<template>
  <div class="space-y-5 pb-12 select-none">
    <!-- 状态反馈提示 -->
    <ToastBanner
      v-if="toast"
      :message="toast.message"
      :type="toast.isError ? 'error' : 'success'"
      compact
      dismissible
      @dismiss="dismiss"
    />

    <!-- 顶层两列响应式卡片网格 (宽屏两列，窄屏单列) -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-5 items-stretch">
      <!-- 1. 智能加速引擎与命中率总控卡片 -->
      <AppCard
        title="智能解析加速引擎"
        subtitle="分片缓存与高频域名优先响应"
        icon="cache"
      >
        <template #badge>
          <StatusBadge
            :status="stats.enabled ? 'active' : 'inactive'"
            :text="stats.enabled ? '加速生效中' : '加速已停用'"
            size="sm"
          />
        </template>

        <template #actions>
          <span class="text-[11px] font-semibold text-text-sub hidden sm:inline">
            {{ stats.enabled ? '加速开启' : '已关闭' }}
          </span>
          <md-switch
            :selected="stats.enabled"
            @change="handleToggleCache"
          />
        </template>

        <!-- 命中率视觉焦点区块 -->
        <div class="mt-4 p-4 rounded-md bg-surface-card-sub border border-surface-border-sub">
          <div class="flex items-baseline justify-between mb-2">
            <span class="text-[12px] font-semibold text-text-muted">缓存命中率</span>
            <span class="font-mono text-[28px] font-bold leading-none text-text-main tabular-nums">
              {{ hitRatioPercent }}
            </span>
          </div>
          <div class="w-full bg-surface-card rounded-full h-2 overflow-hidden border border-surface-border-sub">
            <div
              class="bg-accent-seal h-full rounded-full transition-all duration-300"
              :style="{ width: `${Math.min((stats.hitRatio || 0) * 100, 100)}%` }"
            />
          </div>
        </div>

        <p class="text-[12px] text-text-sub leading-relaxed mt-3">
          自动缓存已访问过的网址解析结果，下次访问直接瞬间返回；在断网或网络卡顿时自动启用应急保障。
        </p>

        <!-- 底部操作按钮 -->
        <template #footer>
          <div class="flex items-center justify-between">
            <button
              type="button"
              @click="loadData"
              :disabled="loading"
              class="app-btn-secondary app-btn-compact"
            >
              <M3Icon name="refresh" :size="13" :class="loading ? 'animate-spin' : ''" />
              <span>刷新数据</span>
            </button>

            <button
              type="button"
              @click="isClearDialogOpen = true"
              :disabled="loading || stats.entryCount === 0"
              class="app-btn-danger app-btn-compact"
            >
              <M3Icon name="delete" :size="13" />
              <span>一键清空缓存</span>
            </button>
          </div>
        </template>
      </AppCard>

      <!-- 2. 核心加速遥测指标卡片 -->
      <AppCard
        title="缓存遥测指标"
        subtitle="多维度解析效率与命中统揽"
        icon="analytics"
      >
        <template #actions>
          <span class="text-[11px] font-mono text-text-muted">
            容量: {{ stats.entryCount }} / {{ stats.maxEntries }}
          </span>
        </template>

        <!-- 4 宫格遥测指标 -->
        <div class="grid grid-cols-2 gap-3 mt-3">
          <CardTile
            label="总命中数"
            :value="stats.totalHits.toLocaleString()"
            valueClass="text-[18px] font-bold text-text-main font-mono"
          />

          <CardTile
            label="实时联网解析"
            :value="stats.totalMisses.toLocaleString()"
            valueClass="text-[18px] font-bold text-text-main font-mono"
          />

          <CardTile
            label="弱网应急保障"
            :value="stats.staleHits.toLocaleString()"
            valueClass="text-[18px] font-bold text-status-warning font-mono"
          />

          <CardTile
            label="无效网址拦截"
            :value="stats.negativeHits.toLocaleString()"
            valueClass="text-[18px] font-bold text-accent-seal font-mono"
          />

          <CardTile
            label="热点预取刷新"
            :value="stats.prefetchCount.toLocaleString()"
            valueClass="text-[18px] font-bold text-brand-primary font-mono"
          />
        </div>

        <!-- 缓存记录使用容量比例条 -->
        <template #footer>
          <div class="space-y-1.5">
            <div class="flex items-center justify-between text-[11px] text-text-muted">
              <span>存储容量占用</span>
              <span class="font-mono">{{ ((stats.entryCount / Math.max(stats.maxEntries, 1)) * 100).toFixed(1) }}%</span>
            </div>
            <div class="w-full bg-surface-card-sub rounded-full h-1.5 overflow-hidden">
              <div
                class="bg-brand-primary h-full rounded-full transition-all duration-300"
                :style="{ width: `${Math.min((stats.entryCount / Math.max(stats.maxEntries, 1)) * 100, 100)}%` }"
              />
            </div>
          </div>
        </template>
      </AppCard>

      <!-- 3. 高频访问网址排行 -->
      <CacheTopDomains :topDomains="topDomains" />

      <!-- 4. 加速策略设置 -->
      <CacheConfigCard :config="config" :saving="saving" @save="handleSaveConfig" />

      <!-- 5. 落盘持久化 -->
      <CachePersistCard
        :enabled="config.persistEnabled"
        :intervalSeconds="config.persistIntervalSeconds || 0"
        :info="persistInfo"
        :saving="saving"
        :busy="persistBusy"
        @toggle="handleTogglePersist"
        @interval="handlePersistInterval"
        @dump="handleDumpCache"
        @load="handleLoadCache"
      />

      <!-- 6. 缓存排除规则 -->
      <CacheExcludeCard
        :patterns="config.excludePatterns || []"
        :hits="persistInfo?.excludeHits || 0"
        :saving="saving"
        @save="handleExcludeSave"
      />

      <!-- 7. 缓存条目明细表格 (双列网格跨列卡片) -->
      <CacheEntriesTable
        class="lg:col-span-2"
        :entries="entries"
        :totalCount="totalEntriesCount"
        @search="handleSearch"
      />
    </div>

    <!-- 一键清空确认弹窗 -->
    <ConfirmModal
      :open="isClearDialogOpen"
      title="确定清空所有加速缓存？"
      :message="`此操作将清空当前全部已缓存的网址记录（共 ${stats.entryCount} 条）。清空后后续访问网址将重新通过网络解析。`"
      danger
      confirmText="确认清空"
      :loading="clearing"
      @confirm="handleConfirmClear"
      @cancel="isClearDialogOpen = false"
    />
  </div>
</template>

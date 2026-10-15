<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { ipc } from '../../api/ipc';
import type { QueryStatsResponse, QueryNameCount } from '../../api/types';
import M3Icon from '../M3Icon.vue';
import AppCard from '../ui/AppCard.vue';
import MetricStrip, { type StatEntry } from '../ui/MetricStrip.vue';
import MetricChart from '../MetricChart.vue';
import ToastBanner from '../ToastBanner.vue';
import { usePoller } from '../../composables/usePoller';
import { useToast } from '../../composables/useToast';

const stats = ref<QueryStatsResponse>({
  summary: { queries: 0, blocked: 0, cached: 0, forwarded: 0, errors: 0, avgResponseMs: 0, cacheHitRate: 0 },
  perHour: [],
  topDomains: [],
  topBlocked: [],
  topClients: [],
});

const loading = ref(false);
const { toast, show: showToast, dismiss } = useToast();

const perHourSeries = computed(() => (stats.value.perHour || []).map((p) => p.queries));
const blockedSeries = computed(() => (stats.value.perHour || []).map((p) => p.blocked));

const summary = computed(() => stats.value.summary);

const kpis = computed<StatEntry[]>(() => [
  { label: '24 小时查询总数', value: summary.value.queries },
  { label: '已拦截', value: summary.value.blocked, tone: 'seal' },
  { label: '缓存命中', value: summary.value.cached },
  { label: '回源转发', value: summary.value.forwarded },
  { label: '解析失败', value: summary.value.errors },
  { label: '缓存命中率', value: `${(summary.value.cacheHitRate * 100).toFixed(1)}`, unit: '%' },
  { label: '平均耗时', value: summary.value.avgResponseMs.toFixed(1), unit: 'ms' },
]);

function topMax(list: QueryNameCount[] | null): number {
  if (!list || list.length === 0) return 1;
  return Math.max(...list.map((i) => i.count), 1);
}

async function loadStats() {
  loading.value = true;
  try {
    const res = await ipc.getQueryStats();
    if (res) stats.value = res;
  } catch (err: any) {
    showToast(err.message || '加载查询统计失败', true);
  } finally {
    loading.value = false;
  }
}

async function pollStats() {
  try {
    const res = await ipc.getQueryStats();
    if (res) stats.value = res;
  } catch {
    // 静默遥测异常
  }
}

onMounted(() => {
  void loadStats();
});
usePoller(pollStats, 5000);
</script>

<template>
  <div class="space-y-5 select-none">
    <ToastBanner
      v-if="toast"
      :message="toast.message"
      :type="toast.isError ? 'error' : 'success'"
      dismissible
      @dismiss="dismiss"
    />

    <!-- KPI 指标带 -->
    <div class="space-y-2">
      <div class="flex items-center justify-between">
        <h3 class="section-title text-[14px]">近 24 小时运行概览</h3>
        <button type="button" @click="loadStats" :disabled="loading" class="app-btn-secondary app-btn-compact">
          <M3Icon :name="loading ? 'refresh' : 'autorenew'" :size="14" :class="loading ? 'animate-spin' : ''" />
          <span>刷新</span>
        </button>
      </div>
      <MetricStrip :stats="kpis" />
    </div>

    <!-- 分时趋势 -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
      <MetricChart
        label="每小时查询量趋势"
        :data="perHourSeries"
        :maxPoints="24"
        unit="次/小时"
        icon="timeline"
        :height="120"
      />
      <MetricChart
        label="每小时拦截量趋势"
        :data="blockedSeries"
        :maxPoints="24"
        strokeColor="var(--app-accent-seal)"
        unit="次/小时"
        icon="shield"
        :height="120"
      />
    </div>

    <!-- Top-N 三列排行 -->
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-5">
      <!-- 高频域名 -->
      <AppCard title="高频访问域名" subtitle="查询次数排行 Top 10" icon="public" iconBoxClass="w-7 h-7" :iconSize="16">
        <div v-if="!stats.topDomains || stats.topDomains.length === 0" class="py-10 text-center text-xs text-text-muted">
          暂无数据
        </div>
        <div v-else class="space-y-2 mt-3 text-xs">
          <div
            v-for="(item, idx) in stats.topDomains"
            :key="item.name"
            class="app-card-sub p-2.5 flex items-center justify-between gap-2"
          >
            <div class="flex items-center gap-2 min-w-0">
              <span
                class="w-5 h-5 rounded-md flex items-center justify-center font-bold font-mono text-[10px] shrink-0"
                :class="idx < 3 ? 'bg-brand-primary text-brand-on-primary' : 'bg-surface-hover text-text-sub'"
              >
                {{ idx + 1 }}
              </span>
              <span class="font-mono text-text-main truncate text-[12px]" :title="item.name">{{ item.name }}</span>
            </div>
            <span class="font-mono font-bold text-text-main text-[12px] shrink-0">{{ item.count }}</span>
          </div>
        </div>
      </AppCard>

      <!-- 拦截排行 -->
      <AppCard title="拦截命中排行" subtitle="被规则拦截最多的域名 Top 10" icon="block" iconBoxClass="w-7 h-7" :iconSize="16">
        <div v-if="!stats.topBlocked || stats.topBlocked.length === 0" class="py-10 text-center text-xs text-text-muted">
          暂无拦截记录
        </div>
        <div v-else class="space-y-2 mt-3 text-xs">
          <div
            v-for="(item, idx) in stats.topBlocked"
            :key="item.name"
            class="app-card-sub p-2.5 flex items-center justify-between gap-2"
          >
            <div class="flex items-center gap-2 min-w-0">
              <span class="w-5 h-5 rounded-md flex items-center justify-center font-bold font-mono text-[10px] shrink-0 bg-accent-seal text-white">
                {{ idx + 1 }}
              </span>
              <span class="font-mono text-text-main truncate text-[12px]" :title="item.name">{{ item.name }}</span>
            </div>
            <span class="font-mono font-bold text-accent-seal text-[12px] shrink-0">{{ item.count }}</span>
          </div>
        </div>
      </AppCard>

      <!-- 活跃客户端 -->
      <AppCard title="活跃客户端" subtitle="发起查询最多的设备 Top 10" icon="devices" iconBoxClass="w-7 h-7" :iconSize="16">
        <div v-if="!stats.topClients || stats.topClients.length === 0" class="py-10 text-center text-xs text-text-muted">
          暂无数据
        </div>
        <div v-else class="space-y-2 mt-3 text-xs">
          <div
            v-for="item in stats.topClients"
            :key="item.name"
            class="app-card-sub p-2.5 space-y-1.5"
          >
            <div class="flex items-center justify-between gap-2">
              <span class="font-mono text-text-main truncate text-[12px]" :title="item.name">{{ item.name }}</span>
              <span class="font-mono font-bold text-text-main text-[12px] shrink-0">{{ item.count }}</span>
            </div>
            <div class="bg-surface-card border border-surface-border-sub rounded-full h-1.5 overflow-hidden">
              <div
                class="bg-brand-primary h-full rounded-full"
                :style="{ width: `${(item.count / topMax(stats.topClients)) * 100}%` }"
              ></div>
            </div>
          </div>
        </div>
      </AppCard>
    </div>
  </div>
</template>

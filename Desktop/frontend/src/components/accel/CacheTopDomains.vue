<script setup lang="ts">
import { computed } from 'vue';
import type { CacheDomainStat } from '../../api/types';
import { formatClockTime } from '../../utils/format';
import AppCard from '../ui/AppCard.vue';

const props = defineProps<{
  topDomains: CacheDomainStat[];
}>();

const maxTopHits = computed(() => {
  if (props.topDomains.length === 0) return 1;
  return Math.max(...props.topDomains.map((d) => d.hitCount), 1);
});
</script>

<template>
  <AppCard
    title="高频访问网址排行"
    subtitle="本地缓存命中次数最高的前 10 个域名"
    icon="analytics"
    iconBoxClass="w-7 h-7"
    :iconSize="16"
  >
    <template #actions>
      <span class="text-[11px] font-mono text-text-muted">Top 10</span>
    </template>

    <div v-if="topDomains.length === 0" class="py-12 text-center text-xs text-text-muted">
      暂无高频网址访问记录
    </div>

    <div v-else class="space-y-2 mt-3 text-xs">
      <div
        v-for="(item, idx) in topDomains"
        :key="item.domain + item.qtype"
        class="app-card-sub p-2.5 flex items-center justify-between gap-3 hover:border-surface-border transition-colors"
      >
        <!-- 排名与域名 -->
        <div class="flex items-center gap-2.5 min-w-0">
          <span
            class="w-5 h-5 rounded-md flex items-center justify-center font-bold font-mono text-[10px] shrink-0"
            :class="idx < 3 ? 'bg-brand-primary text-brand-on-primary' : 'bg-surface-hover text-text-sub'"
          >
            {{ idx + 1 }}
          </span>
          <span class="font-mono font-medium text-text-main truncate text-[12px]" :title="item.domain">
            {{ item.domain }}
          </span>
          <span class="px-1.5 py-0.5 rounded text-[10px] font-mono bg-surface-card border border-surface-border-sub text-text-muted shrink-0">
            {{ item.qtype }}
          </span>
        </div>

        <!-- 频次柱状进度与命中数 -->
        <div class="flex items-center gap-2.5 shrink-0">
          <div class="w-16 md:w-24 bg-surface-card border border-surface-border-sub rounded-full h-1.5 overflow-hidden hidden sm:block">
            <div
              class="bg-accent-seal h-full rounded-full"
              :style="{ width: `${(item.hitCount / maxTopHits) * 100}%` }"
            ></div>
          </div>
          <span class="font-mono font-bold text-text-main text-[12px] min-w-8 text-right">
            {{ item.hitCount }} 次
          </span>
          <span class="text-[10px] font-mono text-text-muted min-w-12 text-right">
            {{ item.lastHitAt > 0 ? formatClockTime(item.lastHitAt) : '近期' }}
          </span>
        </div>
      </div>
    </div>
  </AppCard>
</template>

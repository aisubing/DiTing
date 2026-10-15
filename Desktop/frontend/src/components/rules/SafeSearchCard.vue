<script setup lang="ts">
import { ref, computed } from 'vue';
import { ipc } from '../../api/ipc';
import type { SafeSearchConfig, SafeSearchService } from '../../api/types';
import { SAFE_SEARCH_SERVICES } from '../../api/types';
import AppCard from '../ui/AppCard.vue';
import StatusBadge from '../StatusBadge.vue';
import M3Icon from '../M3Icon.vue';
import { extractSwitchValue, revertSwitch } from '../../utils/switch';

const emit = defineEmits<{ (e: 'error', message: string): void; (e: 'success', message: string): void }>();

const config = ref<SafeSearchConfig>({ enabled: false, disabled: [], ttl: 300 });
const saving = ref(false);
const loaded = ref(false);

const services = SAFE_SEARCH_SERVICES;

const enabledCount = computed(() => services.length - config.value.disabled.length);

async function fetchData() {
  try {
    const cfg = await ipc.getSafeSearch();
    if (cfg) config.value = { ...cfg, disabled: cfg.disabled || [] };
    loaded.value = true;
  } catch (err: any) {
    emit('error', err?.message || '获取安全搜索配置失败');
  }
}

function isServiceEnabled(id: SafeSearchService): boolean {
  return !config.value.disabled.includes(id);
}

async function toggleMaster(e: Event) {
  const next = extractSwitchValue(e);
  try {
    saving.value = true;
    await ipc.configureSafeSearch({ enabled: next, disabled: config.value.disabled });
    config.value.enabled = next;
    emit('success', `强制安全搜索已${next ? '开启' : '关闭'}`);
  } catch (err: any) {
    revertSwitch(e, !next);
    emit('error', err?.message || '更新安全搜索开关失败');
  } finally {
    saving.value = false;
  }
}

async function toggleService(id: SafeSearchService, enable: boolean) {
  const prev = config.value.disabled;
  const next = enable ? prev.filter((s) => s !== id) : [...prev, id];
  config.value.disabled = next;
  try {
    saving.value = true;
    await ipc.configureSafeSearch({ disabled: next });
  } catch (err: any) {
    config.value.disabled = prev;
    emit('error', err?.message || '更新服务商开关失败');
  } finally {
    saving.value = false;
  }
}

async function saveTtl() {
  try {
    saving.value = true;
    await ipc.configureSafeSearch({ ttl: Number(config.value.ttl) || 300 });
    emit('success', '应答 TTL 已保存');
  } catch (err: any) {
    emit('error', err?.message || '保存 TTL 失败');
  } finally {
    saving.value = false;
  }
}

defineExpose({ fetchData });
fetchData();
</script>

<template>
  <AppCard
    title="强制安全搜索"
    subtitle="将主流搜索引擎重写为强制过滤入口，从 DNS 层确保无法关闭安全搜索"
    icon="shield"
    :iconSize="16"
  >
    <template #badge>
      <StatusBadge
        :status="config.enabled ? 'active' : 'inactive'"
        :text="config.enabled ? `已生效 · ${enabledCount} 家` : '未启用'"
        size="sm"
      />
    </template>

    <template #actions>
      <md-switch :selected="config.enabled" :disabled="saving || !loaded" @change="toggleMaster" />
    </template>

    <div class="space-y-3 mt-3 text-xs">
      <p class="text-[11px] text-text-sub leading-relaxed">
        开启后，对命中搜索引擎域名的 A / AAAA / HTTPS 查询，直接返回提供商的强制安全搜索入口。
        属新增拦截能力，<span class="text-accent-seal font-semibold">默认关闭</span>。
      </p>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
        <label
          v-for="svc in services"
          :key="svc.id"
          class="flex items-start gap-2.5 p-2.5 rounded-md border transition-colors cursor-pointer app-interactive-card"
          :class="isServiceEnabled(svc.id) ? 'bg-brand-container/30 border-brand-primary/30' : 'border-surface-border-sub bg-surface-card-sub hover:bg-surface-hover'"
        >
          <input
            type="checkbox"
            class="accent-brand-primary mt-0.5"
            :checked="isServiceEnabled(svc.id)"
            :disabled="saving || !config.enabled"
            @change="toggleService(svc.id, ($event.target as HTMLInputElement).checked)"
          />
          <div class="min-w-0">
            <div class="font-semibold text-text-main text-[12px]">{{ svc.label }}</div>
            <div class="text-[10px] text-text-muted font-mono truncate" :title="svc.hint">{{ svc.hint }}</div>
          </div>
        </label>
      </div>

      <div class="flex items-end gap-3 pt-1">
        <div class="flex-1">
          <label class="text-[11px] font-semibold text-text-muted block mb-1">重写应答 TTL (秒)</label>
          <input
            v-model.number="config.ttl"
            type="number"
            min="30"
            class="w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card-sub text-xs focus:outline-none focus:border-accent-seal text-text-main font-mono"
          />
        </div>
        <button type="button" class="app-btn-primary app-btn-compact" :disabled="saving" @click="saveTtl">
          <M3Icon name="check" :size="14" />
          <span>保存</span>
        </button>
      </div>
    </div>

    <template #footer>
      <div class="text-[11px] text-text-muted">
        规则表转录自 AdGuard Home SafeSearch；未勾选的服务商将直接透传正常解析。
      </div>
    </template>
  </AppCard>
</template>

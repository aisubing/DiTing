<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { ipc } from '../../api/ipc';
import type { AdapterInfo, StatusResponse } from '../../api/types';
import { revertSwitch, extractSwitchValue } from '../../utils/switch';
import StatusBadge from '../StatusBadge.vue';
import ToastBanner from '../ToastBanner.vue';
import AppCard from '../ui/AppCard.vue';
import M3Icon from '../M3Icon.vue';

const adapters = ref<AdapterInfo[]>([]);
const status = ref<StatusResponse | null>(null);
const loading = ref(false);
const operatingId = ref<string | null>(null);
const errorMessage = ref('');

const takenOverAdapterIds = computed(() => {
  const set = new Set<string>();
  if (status.value?.takeover?.adapters) {
    status.value.takeover.adapters.forEach((a) => {
      set.add(a.id);
      set.add(a.name);
    });
  }
  return set;
});

async function loadData() {
  loading.value = true;
  errorMessage.value = '';
  try {
    const [adapterList, statusRes] = await Promise.all([
      ipc.getAdapters(),
      ipc.getStatus(),
    ]);
    adapters.value = adapterList;
    status.value = statusRes;
  } catch (err: any) {
    errorMessage.value = err.message || '加载网卡信息失败';
  } finally {
    loading.value = false;
  }
}

function isAdapterTakenOver(adapter: AdapterInfo): boolean {
  return takenOverAdapterIds.value.has(adapter.id) || takenOverAdapterIds.value.has(adapter.name);
}

async function handleToggleAdapter(adapter: AdapterInfo, e: Event) {
  const enable = extractSwitchValue(e);
  operatingId.value = adapter.id;
  try {
    await ipc.setAdapterTakeover(adapter.id, enable);
    await loadData();
  } catch (err: any) {
    errorMessage.value = `操作网卡 [${adapter.name}] 失败: ${err.message}`;
    revertSwitch(e, !enable);
  } finally {
    operatingId.value = null;
  }
}

async function handleTakeoverAll() {
  loading.value = true;
  try {
    await ipc.enableTakeover();
    await loadData();
  } catch (err: any) {
    errorMessage.value = err.message || '全部接管失败';
  } finally {
    loading.value = false;
  }
}

async function handleRestoreAll() {
  loading.value = true;
  try {
    await ipc.disableTakeover();
    await loadData();
  } catch (err: any) {
    errorMessage.value = err.message || '恢复默认设置失败';
  } finally {
    loading.value = false;
  }
}

onMounted(() => {
  loadData();
});
</script>

<template>
  <div class="space-y-5 select-none">
    <!-- 头部操作栏 -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div>
        <h2 class="section-title">网络连接与保护接管</h2>
        <p class="text-[12px] text-text-sub mt-1">
          已自动排除虚拟与离线网络，仅显示当前正在使用的网络连接（如 Wi-Fi 或有线网络）。
        </p>
      </div>

      <div class="flex items-center gap-3">
        <button
          type="button"
          @click="loadData"
          :disabled="loading"
          class="app-btn-secondary"
        >
          <M3Icon name="refresh" :size="16" :class="loading ? 'animate-spin' : ''" />
          <span>刷新列表</span>
        </button>
        <button
          v-if="!status?.takeover?.active"
          type="button"
          @click="handleTakeoverAll"
          :disabled="loading"
          class="app-btn-primary"
        >
          <M3Icon name="shield" :size="16" />
          <span>全部开启保护</span>
        </button>
        <button
          v-else
          type="button"
          @click="handleRestoreAll"
          :disabled="loading"
          class="app-btn-secondary"
        >
          <M3Icon name="refresh" :size="16" />
          <span>恢复系统默认</span>
        </button>
      </div>
    </div>

    <!-- 错误横幅 -->
    <ToastBanner
      v-if="errorMessage"
      :message="errorMessage"
      type="error"
      dismissible
      @dismiss="errorMessage = ''"
    />

    <!-- 加载中状态 -->
    <div v-if="loading && adapters.length === 0" class="flex flex-col items-center justify-center p-16 gap-4">
      <md-circular-progress indeterminate />
      <span class="text-sm text-text-sub">正在检测网络连接...</span>
    </div>

    <!-- 空网卡状态 -->
    <div v-else-if="adapters.length === 0" class="rounded-md border border-dashed border-surface-border p-12 text-center bg-surface-card">
      <M3Icon name="adapters" :size="48" class="text-text-muted mx-auto mb-3" />
      <h3 class="font-semibold text-text-main">未发现可用的网络连接</h3>
      <p class="text-sm text-text-sub mt-1">请检查 Wi-Fi 或网线是否已正常连接至网络。</p>
      <div class="mt-4">
        <button
          type="button"
          @click="loadData"
          class="app-btn-primary"
        >
          <M3Icon name="refresh" :size="16" />
          <span>重新检测</span>
        </button>
      </div>
    </div>

    <!-- 网卡列表展示：宽屏两列网格，窄屏单列 -->
    <div v-else class="grid grid-cols-1 lg:grid-cols-2 gap-5 items-stretch">
      <AppCard
        v-for="adapter in adapters"
        :key="adapter.id"
        :title="adapter.name"
        :subtitle="adapter.description"
        icon="adapters"
      >
        <template #badge>
          <StatusBadge
            :status="adapter.status === 'Up' ? 'active' : 'inactive'"
            :text="adapter.status === 'Up' ? '已连接' : (adapter.status === 'Down' ? '未连接' : (adapter.status || '未连接'))"
            size="sm"
          />
          <StatusBadge
            v-if="isAdapterTakenOver(adapter)"
            status="active"
            text="保护中"
            size="sm"
            pulse
          />
        </template>

        <template #actions>
          <span class="text-[11px] font-semibold text-text-sub hidden sm:inline">
            {{ isAdapterTakenOver(adapter) ? '保护开启' : '未开启' }}
          </span>
          <md-switch
            :selected="isAdapterTakenOver(adapter)"
            :disabled="operatingId === adapter.id"
            @change="(e: Event) => handleToggleAdapter(adapter, e)"
          />
        </template>

        <!-- 网关与 IP 分配模式信息 -->
        <div class="mt-2.5 flex items-center justify-between gap-2 text-[11px] text-text-sub">
          <div class="flex items-center gap-1.5 truncate">
            <span class="text-text-muted">默认网关:</span>
            <span class="font-mono text-text-main font-medium">{{ adapter.gateway || '无' }}</span>
          </div>
          <div class="flex items-center gap-1.5 shrink-0">
            <span class="text-text-muted">IP 模式:</span>
            <span class="px-1.5 py-0.5 rounded text-[10px] font-semibold bg-surface-card-sub border border-surface-border-sub text-text-main">
              {{ adapter.ipv4DHCP ? '自动 (DHCP)' : '固定静态 IP' }}
            </span>
          </div>
        </div>

        <!-- DNS 配置对比详情磁贴 (双列对比，空间充足无截断) -->
        <template #footer>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-2.5 text-xs">
            <div class="app-card-sub p-2.5 space-y-1">
              <span class="text-text-muted text-[11px] block">原始系统 DNS</span>
              <span class="font-mono text-text-main text-[12px] block truncate font-medium" :title="adapter.ipv4DNS?.join(', ') || '自动获取 (系统默认)'">
                {{ adapter.ipv4DNS?.join(', ') || '自动获取 (系统默认)' }}
              </span>
            </div>

            <div class="app-card-sub p-2.5 space-y-1">
              <span class="text-text-muted text-[11px] block">当前生效 DNS</span>
              <span
                class="font-mono font-bold text-[12px] block truncate"
                :class="isAdapterTakenOver(adapter) ? 'text-status-success' : 'text-text-sub'"
              >
                {{ isAdapterTakenOver(adapter) ? '127.0.0.1 (本机保护)' : '系统默认未接管' }}
              </span>
            </div>
          </div>
        </template>
      </AppCard>
    </div>
  </div>
</template>

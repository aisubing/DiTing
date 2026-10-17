<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { ipc } from '../../api/ipc';
import type { StatusResponse, ProviderConfig, UpstreamInfo, BootstrapConfig } from '../../api/types';
import StatusBadge from '../StatusBadge.vue';
import ToastBanner from '../ToastBanner.vue';
import AppCard from '../ui/AppCard.vue';
import M3Icon from '../M3Icon.vue';
import BootstrapConfigCard from '../BootstrapConfigCard.vue';
import ConditionalRoutesCard from './ConditionalRoutesCard.vue';
import FallbackUpstreamCard, { type FallbackConfig } from './FallbackUpstreamCard.vue';
import UpstreamEditModal from './UpstreamEditModal.vue';
import ConfirmModal from '../ConfirmModal.vue';
import { useConfirmModal } from '../../composables/useConfirmModal';
import { protocolMeta, isHttpsStyleProtocol } from '../../constants/dnsPresets';

const status = ref<StatusResponse | null>(null);
const currentMode = ref('primary_backup');
const providers = ref<ProviderConfig[]>([]);
const upstreams = ref<UpstreamInfo[]>([]);
const conditionalRoutes = ref<Record<string, string>>({});
const bootstrapConfig = ref<BootstrapConfig>({
  enabled: true,
  servers: [
    { id: 'bs-ali', name: 'AliDNS', address: '223.5.5.5:53', weight: 1.0 },
    { id: 'bs-dnspod', name: 'DNSPod', address: '119.29.29.29:53', weight: 1.0 },
  ],
});
const fallbackConfig = ref<FallbackConfig>({ providers: [], timeoutMs: 2000, onError: true, onRcode: [] });
const loading = ref(false);
const saving = ref(false);
const errorMessage = ref('');
const successMessage = ref('');

// 延迟测试状态
const probingId = ref<string | null>(null);
const probeResults = ref<Record<string, number>>({});

/**
 * 卡片列表与编辑/删除共用 providers 这一份源数据。
 * 旧实现用 getStatus 的 upstreams 渲染，却按同一 index 操作 providers：
 * 任一次保存失败后两数组错位，「编辑」「删除」会命中错误条目。
 * upstreams 只用来补充运行态（active / pinSet）。
 */
const displayNodes = computed(() => {
  const runtime = new Map(upstreams.value.map((u) => [u.id, u]));
  return providers.value.map((p, index) => {
    const rt = runtime.get(p.id);
    return {
      index,
      id: p.id,
      protocol: p.protocol,
      server: p.server,
      url: p.url,
      weight: p.weight ?? rt?.weight ?? 1,
      active: rt?.active ?? true,
      // 配置里有指纹即视为已固定；运行态回包可覆盖
      pinSet: rt?.pinSet ?? Boolean(p.pin),
    };
  });
});

// 成功横幅定时器：新调度先取消旧调度，卸载时清理
let successTimer: ReturnType<typeof setTimeout> | null = null;

function flashSuccess(message: string) {
  successMessage.value = message;
  if (successTimer) clearTimeout(successTimer);
  successTimer = setTimeout(() => {
    successMessage.value = '';
    successTimer = null;
  }, 3000);
}

// 编辑弹窗状态
const isDialogOpen = ref(false);
const editingItem = ref<ProviderConfig | null>(null);
const editingIndex = ref<number>(-1);

const {
  isOpen: isConfirmOpen,
  options: confirmOptions,
  ask: askConfirm,
  handleConfirm: handleConfirmAction,
  handleCancel: handleCancelAction,
} = useConfirmModal();

const schedulingModes = [
  { id: 'single', name: '单服务器模式', desc: '始终固定使用列表中的首选服务器进行解析' },
  { id: 'primary_backup', name: '主备自动容灾', desc: '平时优先使用主服务器，超时或故障时自动切换至备用服务器' },
  { id: 'parallel_race', name: '并发极速响应', desc: '同时向全部服务器发送查询，自动采用最快返回的结果，解析延迟最低' },
  { id: 'smart_prediction', name: '智能延迟优选', desc: '根据各服务器近期响应速度与稳定性动态评分，智能选用最优质服务器' },
];

async function loadData(forceSyncProviders = false) {
  loading.value = true;
  errorMessage.value = '';
  try {
    const res = await ipc.getStatus();
    status.value = res;
    currentMode.value = res.dns.mode.toLowerCase() || 'primary_backup';
    upstreams.value = res.dns.upstreams || [];

    // 优先从权威上游配置端点读取 providers 与策略
    try {
      const upCfg = await ipc.getUpstreamConfig();
      if (upCfg) {
        if (upCfg.mode) {
          currentMode.value = upCfg.mode.toLowerCase();
        }
        if ((providers.value.length === 0 || forceSyncProviders) && upCfg.providers) {
          providers.value = upCfg.providers.map((u: ProviderConfig) => ({
            id: u.id,
            protocol: u.protocol,
            server: u.server,
            url: u.url || (isHttpsStyleProtocol(u.protocol) ? `https://${u.server}/dns-query` : ''),
            weight: u.weight ?? 1,
            pin: u.pin,
          }));
        }
        if (upCfg.bootstrap) {
          bootstrapConfig.value = {
            enabled: upCfg.bootstrap.enabled,
            servers: upCfg.bootstrap.servers || [],
          };
        }
        if (upCfg.conditionalRoutes) {
          conditionalRoutes.value = { ...upCfg.conditionalRoutes };
        }
        fallbackConfig.value = {
          providers: (upCfg.fallbackProviders || []).map((u: ProviderConfig) => ({
            id: u.id,
            protocol: u.protocol,
            server: u.server,
            url: u.url || (isHttpsStyleProtocol(u.protocol) ? `https://${u.server}/dns-query` : ''),
            weight: u.weight ?? 1,
            pin: u.pin,
          })),
          // 服务端 0 表示"用默认值"，界面统一显示为默认的 2000ms
          timeoutMs: upCfg.fallbackTimeoutMs && upCfg.fallbackTimeoutMs > 0 ? upCfg.fallbackTimeoutMs : 2000,
          onError: upCfg.fallbackOnError !== false,
          // 服务端字段缺失（undefined）才回落默认；显式空数组表示"不按响应码回退"
          onRcode: upCfg.fallbackOnRcode ?? [2, 5],
        };
      }
    } catch {
      // 若权威端点不可达，回退至 status 视图
      if ((providers.value.length === 0 || forceSyncProviders) && res.dns.upstreams) {
        providers.value = res.dns.upstreams.map((u) => ({
          id: u.id,
          protocol: u.protocol,
          server: u.server,
          url: u.url || (isHttpsStyleProtocol(u.protocol) ? `https://${u.server}/dns-query` : ''),
          weight: u.weight ?? 1,
        }));
      }
      if (res.dns.bootstrap) {
        bootstrapConfig.value = {
          enabled: res.dns.bootstrap.enabled,
          servers: res.dns.bootstrap.servers || [],
        };
      }
      if (res.dns.conditionalRoutes) {
        conditionalRoutes.value = { ...res.dns.conditionalRoutes };
      } else {
        conditionalRoutes.value = {};
      }
    }
  } catch (err: any) {
    errorMessage.value = err.message || '获取 DNS 配置失败';
  } finally {
    loading.value = false;
  }
}

async function handleModeChange(mode: string) {
  currentMode.value = mode;
  await saveConfig();
}

async function handleBootstrapSave(updated: BootstrapConfig) {
  bootstrapConfig.value = updated;
  await saveConfig();
}

async function handleConditionalRoutesSave(updated: Record<string, string>) {
  conditionalRoutes.value = updated;
  await saveConfig();
}

async function handleFallbackSave(updated: FallbackConfig) {
  fallbackConfig.value = updated;
  await saveConfig();
}

async function saveConfig() {
  saving.value = true;
  errorMessage.value = '';
  successMessage.value = '';
  if (successTimer) {
    clearTimeout(successTimer);
    successTimer = null;
  }
  try {
    await ipc.configureUpstream({
      mode: currentMode.value.toUpperCase(),
      providers: providers.value,
      bootstrap: bootstrapConfig.value,
      conditionalRoutes: conditionalRoutes.value,
      // 显式传空数组以关闭回退；服务端以 nil 表示"保持现状"，故此处必须回传
      fallbackProviders: fallbackConfig.value.providers,
      fallbackTimeoutMs: fallbackConfig.value.timeoutMs,
      fallbackOnRcode: fallbackConfig.value.onRcode,
      fallbackOnError: fallbackConfig.value.onError,
    });
    await loadData(true);
    flashSuccess('DNS 服务器配置已更新并即时生效！');
  } catch (err: any) {
    errorMessage.value = err.message || '更新 DNS 配置失败';
  } finally {
    saving.value = false;
  }
}

async function handleTestNode(p: ProviderConfig) {
  probingId.value = p.id;
  try {
    const res = await ipc.testUpstream({
      protocol: p.protocol,
      server: p.server,
      url: p.url,
    });
    if (res.success) {
      probeResults.value[p.id] = res.latencyMs;
    } else {
      errorMessage.value = `服务器 [${p.id}] 测试失败: ${res.error}`;
    }
  } catch (err: any) {
    errorMessage.value = `测试失败: ${err.message}`;
  } finally {
    probingId.value = null;
  }
}

function openAddDialog() {
  editingIndex.value = -1;
  editingItem.value = null;
  isDialogOpen.value = true;
}

function openEditDialog(index: number) {
  editingIndex.value = index;
  editingItem.value = providers.value[index] || null;
  isDialogOpen.value = true;
}

async function handleDeleteNode(index: number) {
  if (providers.value.length <= 1) {
    await askConfirm({
      title: '提示',
      message: '请至少保留一个 DNS 服务器以维持正常的域名解析服务。',
      confirmText: '知道了',
      showCancel: false,
    });
    return;
  }
  const target = providers.value[index];
  const confirmed = await askConfirm({
    title: '确认删除',
    message: `确定删除上游 DNS 服务器 [${target?.id || target?.server}] 吗？`,
    danger: true,
    confirmText: '确定删除',
  });
  if (!confirmed) return;
  providers.value.splice(index, 1);
  saveConfig();
}

function handleSaveDialog(item: ProviderConfig) {
  if (editingIndex.value >= 0) {
    providers.value[editingIndex.value] = item;
  } else {
    providers.value.push(item);
  }
  isDialogOpen.value = false;
  saveConfig();
}

onUnmounted(() => {
  if (successTimer) {
    clearTimeout(successTimer);
    successTimer = null;
  }
});

onMounted(() => {
  loadData();
});
</script>

<template>
  <div class="space-y-5 select-none">
    <!-- 消息横幅 -->
    <ToastBanner
      v-if="successMessage"
      :message="successMessage"
      type="success"
      dismissible
      @dismiss="successMessage = ''"
    />

    <ToastBanner
      v-if="errorMessage"
      :message="errorMessage"
      type="error"
      dismissible
      @dismiss="errorMessage = ''"
    />

    <!-- 顶层卡片双列响应式网格：调度策略 (左) 与 Bootstrap 引导 (右) 并排对齐 -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-5 items-stretch">
      <!-- 1. 上游调度策略卡片 -->
      <AppCard
        title="上游调度策略"
        subtitle="选择多服务器协同工作与容灾模式"
        icon="tune"
      >
        <template #actions>
          <span class="text-[11px] font-mono text-text-muted">
            4 种模式
          </span>
        </template>

        <!-- 4 种调度模式网格 (内部 2x2) -->
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-2.5 mt-3.5">
          <div
            v-for="mode in schedulingModes"
            :key="mode.id"
            role="button"
            tabindex="0"
            class="flex items-start gap-2.5 p-2.5 rounded-md border transition-colors duration-150 cursor-pointer app-interactive-card"
            :class="[
              currentMode === mode.id
                ? 'border-brand-primary bg-brand-container/40 dark:bg-brand-container/20'
                : 'border-surface-border bg-surface-card-sub hover:bg-surface-hover',
            ]"
            @click="handleModeChange(mode.id)"
          >
            <md-radio
              :checked="currentMode === mode.id"
              :value="mode.id"
              name="scheduling-mode"
              class="mt-0.5 scale-90"
            />
            <div class="space-y-0.5 min-w-0">
              <span class="text-[12px] font-bold text-text-main block truncate">
                {{ mode.name }}
              </span>
              <p class="text-[10px] text-text-sub leading-tight line-clamp-2">
                {{ mode.desc }}
              </p>
            </div>
          </div>
        </div>

        <template #footer>
          <div class="text-[11px] text-text-muted">
            当前策略: <span class="font-semibold text-text-main">{{ schedulingModes.find(m => m.id === currentMode)?.name }}</span>
          </div>
        </template>
      </AppCard>

      <!-- 2. Bootstrap DNS 引导解析卡片 (并排右侧) -->
      <BootstrapConfigCard
        :config="bootstrapConfig"
        :saving="saving"
        @update:config="bootstrapConfig = $event"
        @save="handleBootstrapSave"
      />
    </div>

    <!-- 上游节点服务器独立模块 (双列响应式卡片流) -->
    <div class="space-y-4">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div class="min-w-0">
          <div class="flex items-center gap-2">
            <h3 class="section-title">已配置的 DNS 服务器</h3>
            <span class="px-2 py-0.5 rounded-full text-[11px] font-mono font-semibold bg-surface-card-sub border border-surface-border text-text-main">
              {{ upstreams.length }} 个节点
            </span>
          </div>
          <p class="text-[12px] text-text-sub mt-0.5">
            管理用于解析域名的 DNS 服务器，支持加密传输（DoH / DoT）与智能容灾测速。
          </p>
        </div>

        <div class="flex items-center gap-2 shrink-0">
          <button
            type="button"
            @click="loadData(true)"
            :disabled="loading"
            class="app-btn-secondary app-btn-compact"
          >
            <M3Icon name="refresh" :size="14" :class="loading ? 'animate-spin' : ''" />
            <span>刷新状态</span>
          </button>
          <button
            type="button"
            @click="openAddDialog"
            :disabled="saving"
            class="app-btn-primary app-btn-compact"
          >
            <M3Icon name="add" :size="14" />
            <span>添加 DNS 服务器</span>
          </button>
        </div>
      </div>

      <div v-if="displayNodes.length === 0" class="app-card p-10 text-center border-dashed">
        <M3Icon name="router" :size="36" class="text-text-muted mx-auto mb-2 opacity-50" />
        <p class="text-[13px] font-medium text-text-main mb-1">暂无配置 DNS 服务器</p>
        <p class="text-[12px] text-text-sub mb-4">请点击右上角按钮添加主备 DNS 服务器</p>
        <button type="button" @click="openAddDialog" class="app-btn-primary app-btn-compact mx-auto">
          <M3Icon name="add" :size="14" />
          <span>添加预设服务器</span>
        </button>
      </div>

      <!-- 宽屏两列网格，窄屏单列 -->
      <div v-else class="grid grid-cols-1 lg:grid-cols-2 gap-5 items-stretch">
        <AppCard
          v-for="node in displayNodes"
          :key="node.index + ':' + node.id"
          :title="node.id"
          :subtitle="'权重: ' + (node.weight ?? 1)"
          icon="dns"
        >
          <template #badge>
            <span
              class="px-2 py-0.5 rounded-full text-[10px] font-semibold font-mono border"
              :class="[
                protocolMeta(node.protocol).encrypted
                  ? 'border-accent-seal/50 text-accent-seal'
                  : 'border-surface-border text-text-sub'
              ]"
            >
              {{ protocolMeta(node.protocol).label }}
            </span>
            <span
              v-if="node.pinSet"
              class="px-2 py-0.5 rounded-full text-[10px] font-semibold border border-status-success/40 text-status-success"
              title="已启用证书指纹固定：该校验替代系统 CA 链校验"
            >
              🔒 指纹固定
            </span>
            <StatusBadge
              :status="node.active ? 'active' : 'inactive'"
              :text="node.active ? '运行中' : '已暂停'"
              size="sm"
            />
          </template>

          <template #actions>
            <div v-if="probeResults[node.id] !== undefined" class="shrink-0">
              <span class="h-7 px-2.5 rounded-md bg-status-success-bg text-status-success border border-status-success/30 font-mono text-[11px] font-bold inline-flex items-center">
                {{ probeResults[node.id].toFixed(1) }} ms
              </span>
            </div>
          </template>

          <!-- 服务器信息磁贴 -->
          <div class="space-y-2 mt-3 text-xs">
            <div class="app-card-sub p-2.5">
              <span class="text-[11px] text-text-muted block">服务器连接地址</span>
              <span class="font-mono text-text-main font-medium text-[12px] block truncate select-all">
                {{ node.server }}
              </span>
            </div>
            <div v-if="node.url" class="app-card-sub p-2.5">
              <span class="text-[11px] text-text-muted block">加密查询 URL (DoH)</span>
              <span class="font-mono text-text-sub text-[11px] block truncate select-all" :title="node.url">
                {{ node.url }}
              </span>
            </div>
          </div>

          <!-- 底部操作按钮栏 -->
          <template #footer>
            <div class="flex items-center justify-between">
              <button
                type="button"
                class="app-btn-secondary app-btn-compact"
                @click="handleTestNode({ id: node.id, protocol: node.protocol, server: node.server, url: node.url })"
                :disabled="probingId === node.id"
              >
                <M3Icon v-if="probingId === node.id" name="refresh" class="animate-spin" :size="13" />
                <M3Icon v-else name="bolt" :size="13" />
                <span>测试延迟</span>
              </button>

              <div class="flex items-center gap-1.5">
                <button
                  type="button"
                  @click="openEditDialog(node.index)"
                  class="app-btn-icon"
                  title="编辑服务器"
                >
                  <M3Icon name="settings" :size="15" />
                </button>

                <button
                  type="button"
                  @click="handleDeleteNode(node.index)"
                  :disabled="displayNodes.length <= 1"
                  class="app-btn-icon app-btn-icon-danger"
                  title="删除服务器"
                >
                  <M3Icon name="delete" :size="15" />
                </button>
              </div>
            </div>
          </template>
        </AppCard>
      </div>
    </div>

    <!-- 3. 独立回退上游链路 -->
    <FallbackUpstreamCard
      :config="fallbackConfig"
      :saving="saving"
      @save="handleFallbackSave"
    />

    <!-- 4. 条件分流路由 (Split DNS) 独立模块 -->
    <ConditionalRoutesCard
      :routes="conditionalRoutes"
      :saving="saving"
      @update:routes="(r) => (conditionalRoutes = r)"
      @save="handleConditionalRoutesSave"
    />

    <!-- 新增 / 编辑节点弹窗 -->
    <UpstreamEditModal
      :open="isDialogOpen"
      :editingItem="editingItem"
      @close="isDialogOpen = false"
      @save="handleSaveDialog"
    />

    <!-- 删除确认弹窗 -->
    <ConfirmModal
      :open="isConfirmOpen"
      :title="confirmOptions.title"
      :message="confirmOptions.message"
      :danger="confirmOptions.danger"
      :confirmText="confirmOptions.confirmText"
      :cancelText="confirmOptions.cancelText"
      :showCancel="confirmOptions.showCancel"
      @confirm="handleConfirmAction"
      @cancel="handleCancelAction"
    />
  </div>
</template>

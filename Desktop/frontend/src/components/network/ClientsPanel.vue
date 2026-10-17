<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { ipc } from '../../api/ipc';
import type { ClientInfo, AccessControlConfig, RateLimitConfig } from '../../api/types';
import M3Icon from '../M3Icon.vue';
import AppCard from '../ui/AppCard.vue';
import AppModal from '../AppModal.vue';
import ToastBanner from '../ToastBanner.vue';
import StatusBadge from '../StatusBadge.vue';
import ClientGroupsCard from './ClientGroupsCard.vue';
import { formatClockTimeMs } from '../../utils/format';
import { extractSwitchValue } from '../../utils/switch';
import { useToast } from '../../composables/useToast';

const clients = ref<ClientInfo[]>([]);
const accessConfig = ref<AccessControlConfig>({
  allowedClients: [],
  blockedClients: [],
});
const rateLimitConfig = ref<RateLimitConfig>({
  enabled: false,
  rate: 50,
  burst: 100,
  ipv4Prefix: 32,
  ipv6Prefix: 128,
  exemptIPs: ['127.0.0.1', '::1'],
});

const loading = ref(false);
const savingAccess = ref(false);
const savingRateLimit = ref(false);
const savingAlias = ref(false);
const { toast, show: showToast, dismiss } = useToast();

// 别名编辑弹窗状态
const isAliasModalOpen = ref(false);
const editingClientIP = ref('');
const editingClientName = ref('');

// 访问控制文本输入
const allowedText = ref('');
const blockedText = ref('');
const exemptText = ref('');

/**
 * 黑白名单 textarea 是否有未保存的改动。
 * 行内「加入白名单/黑名单」按钮也走同一份名单，必须保留用户已输入但未保存的行，
 * 旧实现直接用服务器列表重写 textarea，草稿被清空且请求体也不含它。
 */
const accessDraftDirty = ref(false);

function markAccessDraftDirty() {
  accessDraftDirty.value = true;
}

function splitList(text: string): string[] {
  return text
    .split('\n')
    .map((s) => s.trim())
    .filter(Boolean);
}

/** 当前生效的名单：有未保存草稿时以草稿为准，否则用服务器配置 */
function currentDraftLists(): { allowed: string[]; blocked: string[] } {
  if (accessDraftDirty.value) {
    return { allowed: splitList(allowedText.value), blocked: splitList(blockedText.value) };
  }
  return {
    allowed: [...(accessConfig.value.allowedClients || [])],
    blocked: [...(accessConfig.value.blockedClients || [])],
  };
}

function applyAccessLists(allowed: string[], blocked: string[]) {
  accessConfig.value.allowedClients = allowed;
  accessConfig.value.blockedClients = blocked;
  allowedText.value = allowed.join('\n');
  blockedText.value = blocked.join('\n');
  accessDraftDirty.value = false;
}

function formatTime(sec: number) {
  if (!sec) return '从未';
  return formatClockTimeMs(sec * 1000);
}

async function loadData() {
  loading.value = true;
  try {
    const [cList, st] = await Promise.all([
      ipc.getClients().catch(() => []),
      ipc.getStatus().catch(() => null),
    ]);

    clients.value = cList || [];
    if (st) {
      if (st.access) {
        accessConfig.value = st.access;
        if (!accessDraftDirty.value) {
          allowedText.value = (st.access.allowedClients || []).join('\n');
          blockedText.value = (st.access.blockedClients || []).join('\n');
        }
      }
      if (st.rateLimit) {
        rateLimitConfig.value = st.rateLimit;
        exemptText.value = (st.rateLimit.exemptIPs || []).join('\n');
      }
    }
  } catch (err: any) {
    showToast(err.message || '加载设备与访问控制数据失败', true);
  } finally {
    loading.value = false;
  }
}

function openAliasModal(client: ClientInfo) {
  editingClientIP.value = client.ip;
  editingClientName.value = client.name || '';
  isAliasModalOpen.value = true;
}

async function saveAlias() {
  savingAlias.value = true;
  try {
    await ipc.configureClientAlias({
      ip: editingClientIP.value,
      name: editingClientName.value.trim(),
    });
    showToast(`客户端 [${editingClientIP.value}] 别名已更新`);
    isAliasModalOpen.value = false;
    await loadData();
  } catch (err: any) {
    showToast(err.message || '更新客户端别名失败', true);
  } finally {
    savingAlias.value = false;
  }
}

async function saveAccessControl() {
  savingAccess.value = true;
  try {
    const allowed = splitList(allowedText.value);
    const blocked = splitList(blockedText.value);

    await ipc.configureAccess({
      allowedClients: allowed,
      blockedClients: blocked,
    });
    applyAccessLists(allowed, blocked);
    showToast('客户端黑白名单访问控制配置已成功保存！');
  } catch (err: any) {
    showToast(err.message || '保存访问控制失败', true);
  } finally {
    savingAccess.value = false;
  }
}

function isClientAllowed(ip: string): boolean {
  return (accessConfig.value.allowedClients || []).includes(ip);
}

function isClientBlocked(ip: string): boolean {
  return (accessConfig.value.blockedClients || []).includes(ip);
}

async function toggleClientAllowed(ip: string) {
  const lists = currentDraftLists();
  const allowed = lists.allowed;
  const blocked = lists.blocked.filter((item) => item !== ip);
  const idx = allowed.indexOf(ip);
  if (idx >= 0) {
    allowed.splice(idx, 1);
  } else {
    allowed.push(ip);
  }

  savingAccess.value = true;
  try {
    await ipc.configureAccess({
      allowedClients: allowed,
      blockedClients: blocked,
    });
    applyAccessLists(allowed, blocked);
    showToast(`客户端 [${ip}] 已${idx >= 0 ? '移出白名单' : '加入白名单'}`);
  } catch (err: any) {
    showToast(err.message || '更新客户端白名单失败', true);
  } finally {
    savingAccess.value = false;
  }
}

async function toggleClientBlocked(ip: string) {
  const lists = currentDraftLists();
  const blocked = lists.blocked;
  const allowed = lists.allowed.filter((item) => item !== ip);
  const idx = blocked.indexOf(ip);
  if (idx >= 0) {
    blocked.splice(idx, 1);
  } else {
    blocked.push(ip);
  }

  savingAccess.value = true;
  try {
    await ipc.configureAccess({
      allowedClients: allowed,
      blockedClients: blocked,
    });
    applyAccessLists(allowed, blocked);
    showToast(`客户端 [${ip}] 已${idx >= 0 ? '移出黑名单' : '加入黑名单阻断'}`);
  } catch (err: any) {
    showToast(err.message || '更新客户端黑名单失败', true);
  } finally {
    savingAccess.value = false;
  }
}

async function toggleRateLimitSwitch(e: Event) {
  const nextVal = extractSwitchValue(e);
  rateLimitConfig.value.enabled = nextVal;
  await saveRateLimit();
}

async function saveRateLimit() {
  savingRateLimit.value = true;
  try {
    const exempt = exemptText.value
      .split('\n')
      .map((s) => s.trim())
      .filter(Boolean);

    await ipc.configureRateLimit({
      enabled: rateLimitConfig.value.enabled,
      rate: Number(rateLimitConfig.value.rate) || 50,
      burst: Number(rateLimitConfig.value.burst) || 100,
      ipv4Prefix: Number(rateLimitConfig.value.ipv4Prefix) || 32,
      ipv6Prefix: Number(rateLimitConfig.value.ipv6Prefix) || 128,
      exemptIPs: exempt,
    });
    rateLimitConfig.value.exemptIPs = exempt;
    showToast(`客户端请求速率限制配置已更新 (状态: ${rateLimitConfig.value.enabled ? '已开启' : '已关闭'})`);
  } catch (err: any) {
    showToast(err.message || '更新速率限制配置失败', true);
  } finally {
    savingRateLimit.value = false;
  }
}

onMounted(() => {
  loadData();
});
</script>

<template>
  <div class="space-y-5 select-none">
    <ToastBanner v-if="toast" :message="toast.message" :type="toast.isError ? 'error' : 'success'" dismissible @dismiss="dismiss" />

    <!-- 1. 活跃客户端识别与主机名别名卡片 -->
    <AppCard
      title="已识别的局域网客户端"
      subtitle="自动通过 rDNS 探测或自定义别名绑定局域网连接设备"
      icon="devices"
    >
      <template #badge>
        <span class="px-2 py-0.5 rounded-full text-[11px] font-mono font-semibold bg-surface-card-sub border border-surface-border text-text-main">
          {{ clients.length }} 个活跃设备
        </span>
      </template>

      <template #actions>
        <button
          type="button"
          @click="loadData"
          :disabled="loading"
          class="app-btn-secondary app-btn-compact"
          title="刷新设备列表"
        >
          <M3Icon name="refresh" :size="13" :class="loading ? 'animate-spin' : ''" />
          <span>刷新</span>
        </button>
      </template>

      <div class="mt-3">
        <div v-if="clients.length > 0" class="overflow-x-auto rounded-md border border-surface-border">
          <table class="w-full text-left text-xs border-collapse">
            <thead>
              <tr class="bg-surface-card-sub border-b border-surface-border text-text-muted">
                <th class="py-2.5 px-3 font-semibold">客户端 IP</th>
                <th class="py-2.5 px-3 font-semibold">友好名称 / 识别主机名</th>
                <th class="py-2.5 px-3 font-semibold text-center">访问控制状态</th>
                <th class="py-2.5 px-3 font-semibold text-center">累计查询次数</th>
                <th class="py-2.5 px-3 font-semibold">最近活跃</th>
                <th class="py-2.5 px-3 font-semibold text-right">操作</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-surface-border-sub">
              <tr
                v-for="c in clients"
                :key="c.ip"
                class="hover:bg-surface-hover/60 transition-colors"
              >
                <td class="py-2 px-3 font-mono font-bold text-text-main">
                  {{ c.ip }}
                </td>
                <td class="py-2 px-3">
                  <span v-if="c.name" class="font-semibold text-accent-seal">
                    {{ c.name }}
                  </span>
                  <span v-else class="text-text-muted italic text-[11px]">
                    未设置（未知设备）
                  </span>
                </td>
                <td class="py-2 px-3 text-center">
                  <span
                    v-if="isClientBlocked(c.ip)"
                    class="px-2 py-0.5 rounded text-[10px] font-semibold bg-state-error/15 text-state-error border border-state-error/30"
                  >
                    已阻断
                  </span>
                  <span
                    v-else-if="isClientAllowed(c.ip)"
                    class="px-2 py-0.5 rounded text-[10px] font-semibold bg-state-success/15 text-state-success border border-state-success/30"
                  >
                    白名单
                  </span>
                  <span
                    v-else-if="(accessConfig.allowedClients || []).length > 0"
                    class="px-2 py-0.5 rounded text-[10px] font-semibold bg-state-warning/15 text-state-warning border border-state-warning/30"
                    title="白名单模式下未放行的客户端"
                  >
                    未在白名单
                  </span>
                  <span
                    v-else
                    class="text-text-muted text-[11px]"
                  >
                    正常放行
                  </span>
                </td>
                <td class="py-2 px-3 font-mono text-center text-text-main tabular-nums">
                  {{ c.queryCount.toLocaleString() }}
                </td>
                <td class="py-2 px-3 text-text-sub font-mono text-[11px]">
                  {{ formatTime(c.lastSeen) }}
                </td>
                <td class="py-2 px-3 text-right">
                  <div class="flex items-center justify-end gap-1.5">
                    <button
                      type="button"
                      @click="openAliasModal(c)"
                      class="app-btn-secondary app-btn-compact !px-2"
                      title="设置别名"
                    >
                      <M3Icon name="edit" :size="12" />
                      <span>别名</span>
                    </button>
                    <button
                      type="button"
                      @click="toggleClientAllowed(c.ip)"
                      :disabled="savingAccess"
                      :class="isClientAllowed(c.ip) ? 'bg-state-success/15 text-state-success border border-state-success/30 hover:bg-state-success/25' : 'app-btn-secondary'"
                      class="app-btn-compact !px-2"
                      :title="isClientAllowed(c.ip) ? '移出白名单' : '加入白名单'"
                    >
                      <M3Icon name="check" :size="12" />
                      <span>{{ isClientAllowed(c.ip) ? '已放行' : '白名单' }}</span>
                    </button>
                    <button
                      type="button"
                      @click="toggleClientBlocked(c.ip)"
                      :disabled="savingAccess"
                      :class="isClientBlocked(c.ip) ? 'bg-state-error/15 text-state-error border border-state-error/30 hover:bg-state-error/25' : 'app-btn-secondary'"
                      class="app-btn-compact !px-2"
                      :title="isClientBlocked(c.ip) ? '移出黑名单' : '加入阻断黑名单'"
                    >
                      <M3Icon name="block" :size="12" />
                      <span>{{ isClientBlocked(c.ip) ? '已阻断' : '阻断' }}</span>
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div
          v-else
          class="p-6 rounded-md border border-dashed border-surface-border-sub text-center text-text-muted text-xs flex flex-col items-center justify-center gap-2"
        >
          <M3Icon name="devices" :size="28" class="opacity-40" />
          <span>暂未识别到来自外部或局域网的 DNS 查询设备。</span>
        </div>
      </div>
    </AppCard>

    <!-- 宽屏两列：客户端访问控制 & 请求限流 -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-5 items-stretch">
      <!-- 2. 客户端访问控制 (白名单 / 黑名单) -->
      <AppCard
        title="客户端访问控制 (ACL)"
        subtitle="限制特定 IP 或 CIDR 网段设备的 DNS 查询权限"
        icon="shield"
        :iconSize="16"
      >
        <template #actions>
          <button
            type="button"
            @click="saveAccessControl"
            :disabled="savingAccess"
            class="app-btn-primary app-btn-compact"
          >
            <M3Icon name="check" :size="14" />
            <span>{{ savingAccess ? '保存中...' : '保存名单' }}</span>
          </button>
        </template>

        <div class="space-y-4 mt-3 text-xs">
          <div>
            <label class="font-semibold text-text-main block mb-1">
              允许访问白名单 (Allowed Clients)
            </label>
            <p class="text-[11px] text-text-muted mb-1.5">
              若填写，则<strong>仅允许名单内的客户端 IP/网段</strong>进行解析；留空表示不限制。每行一个 IP 或 CIDR。
            </p>
            <textarea
              v-model="allowedText"
              @input="markAccessDraftDirty"
              rows="3"
              placeholder="例如: 192.168.1.0/24 或 192.168.1.50"
              class="w-full rounded-md border border-surface-border bg-surface-card-sub p-2 font-mono text-xs text-text-main focus:outline-none focus:border-accent-seal"
            ></textarea>
          </div>

          <div>
            <label class="font-semibold text-text-main block mb-1">
              显式阻断黑名单 (Blocked Clients)
            </label>
            <p class="text-[11px] text-text-muted mb-1.5">
              命中该名单的客户端将被直接拒绝 DNS 查询请求。每行一个 IP 或 CIDR。
            </p>
            <textarea
              v-model="blockedText"
              @input="markAccessDraftDirty"
              rows="3"
              placeholder="例如: 192.168.1.199 或 10.0.0.0/8"
              class="w-full rounded-md border border-surface-border bg-surface-card-sub p-2 font-mono text-xs text-text-main focus:outline-none focus:border-accent-seal"
            ></textarea>
          </div>
        </div>

        <template #footer>
          <div class="text-[11px] text-text-muted">
            支持标准 IPv4/IPv6 单机地址与 CIDR 网段掩码表示法。
          </div>
        </template>
      </AppCard>

      <!-- 3. 客户端速率限制 (Rate Limiting) -->
      <AppCard
        title="客户端请求速率限制"
        subtitle="基于令牌桶算法防范局域网 DoS 泛洪与 DNS 放大攻击"
        icon="speed"
        :iconSize="16"
      >
        <template #badge>
          <StatusBadge
            :status="rateLimitConfig.enabled ? 'active' : 'inactive'"
            :text="rateLimitConfig.enabled ? '限流生效中' : '限流已停用'"
            size="sm"
          />
        </template>

        <template #actions>
          <md-switch
            :selected="rateLimitConfig.enabled"
            :disabled="savingRateLimit"
            @change="toggleRateLimitSwitch"
          />
        </template>

        <div class="space-y-3.5 mt-3 text-xs">
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="font-semibold text-text-muted block mb-1">速率 (令牌/秒)</label>
              <input
                v-model.number="rateLimitConfig.rate"
                type="number"
                min="1"
                class="w-full h-[32px] px-2.5 rounded-md border border-surface-border bg-surface-card-sub text-xs text-text-main font-mono focus:outline-none focus:border-accent-seal"
              />
              <span class="text-[10px] text-text-muted mt-0.5 block">平稳查询上限 (默认 50)</span>
            </div>

            <div>
              <label class="font-semibold text-text-muted block mb-1">突发容量上限 (次)</label>
              <input
                v-model.number="rateLimitConfig.burst"
                type="number"
                min="1"
                class="w-full h-[32px] px-2.5 rounded-md border border-surface-border bg-surface-card-sub text-xs text-text-main font-mono focus:outline-none focus:border-accent-seal"
              />
              <span class="text-[10px] text-text-muted mt-0.5 block">允许短时突发峰值 (默认 100)</span>
            </div>
          </div>

          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="font-semibold text-text-muted block mb-1">IPv4 聚合前缀掩码</label>
              <input
                v-model.number="rateLimitConfig.ipv4Prefix"
                type="number"
                min="1"
                max="32"
                class="w-full h-[32px] px-2.5 rounded-md border border-surface-border bg-surface-card-sub text-xs text-text-main font-mono focus:outline-none focus:border-accent-seal"
              />
              <span class="text-[10px] text-text-muted mt-0.5 block">单 IP 为 32，局域网可设 24</span>
            </div>

            <div>
              <label class="font-semibold text-text-muted block mb-1">IPv6 聚合前缀掩码</label>
              <input
                v-model.number="rateLimitConfig.ipv6Prefix"
                type="number"
                min="1"
                max="128"
                class="w-full h-[32px] px-2.5 rounded-md border border-surface-border bg-surface-card-sub text-xs text-text-main font-mono focus:outline-none focus:border-accent-seal"
              />
              <span class="text-[10px] text-text-muted mt-0.5 block">单 IP 为 128，网段可设 64</span>
            </div>
          </div>

          <div>
            <label class="font-semibold text-text-muted block mb-1">豁免白名单 IP / 网段</label>
            <textarea
              v-model="exemptText"
              rows="2"
              placeholder="127.0.0.1&#10;::1"
              class="w-full rounded-md border border-surface-border bg-surface-card-sub p-2 font-mono text-xs text-text-main focus:outline-none focus:border-accent-seal"
            ></textarea>
            <span class="text-[10px] text-text-muted mt-0.5 block">回环与受信任网段不计入限流统计</span>
          </div>
        </div>

        <template #footer>
          <div class="flex items-center justify-end">
            <button
              type="button"
              @click="saveRateLimit"
              :disabled="savingRateLimit"
              class="app-btn-primary"
            >
              <M3Icon name="check" :size="14" />
              <span>{{ savingRateLimit ? '保存中...' : '保存速率限制' }}</span>
            </button>
          </div>
        </template>
      </AppCard>
    </div>

    <!-- 客户端分组与分组级精细策略 -->
    <ClientGroupsCard />

    <!-- 弹窗：编辑客户端友好别名 -->
    <AppModal      :open="isAliasModalOpen"
      title="配置客户端设备别名"
      @close="isAliasModalOpen = false"
    >
      <div class="space-y-4 text-xs">
        <div>
          <label class="font-semibold text-text-muted block mb-1">客户端 IP</label>
          <input
            :value="editingClientIP"
            readonly
            disabled
            class="w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card/60 text-xs text-text-muted font-mono"
          />
        </div>

        <div>
          <label class="font-semibold text-text-main block mb-1">自定义友好设备名称</label>
          <input
            v-model="editingClientName"
            type="text"
            placeholder="如 客厅电视、工作用笔记本、NAS存储"
            class="w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card-sub text-xs text-text-main font-sans focus:outline-none focus:border-accent-seal"
          />
          <span class="text-[10px] text-text-muted mt-1 block">留空保存将清除自定义别名</span>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-2 w-full">
          <button type="button" @click="isAliasModalOpen = false" class="app-btn-secondary">
            取消
          </button>
          <button type="button" @click="saveAlias" :disabled="savingAlias" class="app-btn-primary">
            {{ savingAlias ? '保存中...' : '保存别名' }}
          </button>
        </div>
      </template>
    </AppModal>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import type { ProviderConfig } from '../../api/types';
import AppCard from '../ui/AppCard.vue';
import M3Icon from '../M3Icon.vue';
import UpstreamEditModal from './UpstreamEditModal.vue';
import { protocolMeta } from '../../constants/dnsPresets';

/** 回退链配置（与主链路相互独立） */
export interface FallbackConfig {
  providers: ProviderConfig[];
  timeoutMs: number;
  onError: boolean;
  onRcode: number[];
}

const props = defineProps<{
  config: FallbackConfig;
  saving?: boolean;
}>();

const emit = defineEmits<{
  (e: 'save', value: FallbackConfig): void;
}>();

// 可选的触发响应码：不含 NOERROR 与 NXDOMAIN —— 二者都是有效判定
const RCODE_CHOICES = [
  { value: 2, label: 'SERVFAIL', desc: '上游内部故障' },
  { value: 5, label: 'REFUSED', desc: '上游拒绝服务' },
  { value: 4, label: 'NOTIMP', desc: '上游不支持该查询' },
  { value: 3, label: 'NXDOMAIN', desc: '域名不存在（通常不应触发）' },
];

const isDialogOpen = ref(false);
const editingItem = ref<ProviderConfig | null>(null);
const editingIndex = ref(-1);

const enabled = () => props.config.providers.length > 0;

function commit(patch: Partial<FallbackConfig>) {
  emit('save', { ...props.config, ...patch });
}

function toggleEnabled() {
  if (enabled()) {
    // 关闭即清空回退链：空的回退链在服务端就是"未启用"
    commit({ providers: [] });
    return;
  }
  commit({
    providers: [{ id: 'fallback-1', protocol: 'DOT', server: 'dns.alidns.com:853', weight: 1 }],
  });
}

function toggleRcode(value: number) {
  const set = new Set(props.config.onRcode);
  if (set.has(value)) set.delete(value);
  else set.add(value);
  commit({ onRcode: Array.from(set).sort((a, b) => a - b) });
}

function openAddDialog() {
  editingIndex.value = -1;
  editingItem.value = null;
  isDialogOpen.value = true;
}

function openEditDialog(index: number) {
  editingIndex.value = index;
  editingItem.value = props.config.providers[index] || null;
  isDialogOpen.value = true;
}

function handleSaveItem(item: ProviderConfig) {
  const list = [...props.config.providers];
  if (editingIndex.value >= 0) list[editingIndex.value] = item;
  else list.push(item);
  isDialogOpen.value = false;
  commit({ providers: list });
}

function handleDelete(index: number) {
  const list = [...props.config.providers];
  list.splice(index, 1);
  commit({ providers: list });
}

function handleTimeoutInput(e: Event) {
  const raw = Number((e.target as HTMLInputElement).value);
  // 夹到 [100, 30000]：低于 100ms 等于没给主链路机会，高于 30s 则失去回退意义。
  // 空值或非法输入回落为服务端默认的 2000ms。
  const clamped = Number.isFinite(raw) ? Math.min(30000, Math.max(100, Math.round(raw))) : 2000;
  commit({ timeoutMs: clamped });
}
</script>

<template>
  <AppCard
    title="独立回退上游"
    subtitle="主链路整体失效后整链切换的备用解析链路"
    icon="shield"
  >
    <template #badge>
      <span
        class="px-2 py-0.5 rounded-full text-[10px] font-semibold"
        :class="enabled() ? 'bg-status-success-bg text-status-success' : 'bg-surface-card-sub text-text-sub'"
      >
        {{ enabled() ? `${config.providers.length} 个回退节点` : '未启用' }}
      </span>
    </template>

    <template #actions>
      <md-switch
        :selected="enabled()"
        @change="toggleEnabled"
        :disabled="saving"
        title="开启或关闭独立回退链路"
      />
    </template>

    <p class="text-[12px] text-text-sub leading-relaxed mt-3">
      与主链路是<b>两条独立链路</b>：主链路先以独立超时尝试整条链，
      失败或命中下列响应码后，才整链切换到回退上游。回退链自身不会再回退，避免查询放大。
    </p>

    <!-- 未启用时仅展示说明 -->
    <div v-if="!enabled()" class="mt-3.5 py-6 text-center text-xs text-text-muted">
      未配置回退上游，DNS 查询量不会因此增加。
    </div>

    <template v-else>
      <!-- 回退节点列表 -->
      <div class="mt-3.5 space-y-2">
        <div
          v-for="(p, idx) in config.providers"
          :key="p.id"
          class="app-card-sub p-2.5 flex items-center justify-between gap-2"
        >
          <div class="flex items-center gap-2 min-w-0">
            <span class="px-2 py-0.5 rounded-full text-[10px] font-semibold font-mono border border-surface-border text-text-sub shrink-0">
              {{ protocolMeta(p.protocol).label }}
            </span>
            <span class="text-[12px] font-semibold text-text-main truncate">{{ p.id }}</span>
            <span class="text-[11px] font-mono text-text-sub truncate select-all">
              {{ p.url || p.server }}
            </span>
          </div>
          <div class="flex items-center gap-1.5 shrink-0">
            <button type="button" @click="openEditDialog(idx)" class="app-btn-icon" title="编辑回退节点">
              <M3Icon name="settings" :size="14" />
            </button>
            <button type="button" @click="handleDelete(idx)" class="app-btn-icon app-btn-icon-danger" title="删除回退节点">
              <M3Icon name="delete" :size="14" />
            </button>
          </div>
        </div>

        <button type="button" @click="openAddDialog" :disabled="saving" class="app-btn-secondary app-btn-compact w-full">
          <M3Icon name="add" :size="14" />
          <span>添加回退节点</span>
        </button>
      </div>

      <!-- 主链路独立超时 -->
      <div class="mt-4 pt-3 border-t border-surface-border-sub/60">
        <md-outlined-text-field
          type="number"
          label="主链路独立超时（毫秒）"
          :value="String(config.timeoutMs)"
          @change="handleTimeoutInput"
          class="w-full font-mono"
          placeholder="2000"
        ></md-outlined-text-field>
        <p class="text-[10px] text-text-muted mt-1 leading-relaxed">
          超过该时长即认为主链路失效并切换。留空或 0 时使用服务端默认值 2000ms，取值范围 100–30000。
        </p>
      </div>

      <!-- 触发响应码 -->
      <div class="mt-3.5">
        <label class="text-[11px] text-text-muted block mb-1.5">触发回退的响应码</label>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="rc in RCODE_CHOICES"
            :key="rc.value"
            type="button"
            :title="rc.desc"
            @click="toggleRcode(rc.value)"
            class="px-2.5 py-1 rounded-md text-[11px] font-mono font-semibold border transition-colors"
            :class="[
              config.onRcode.includes(rc.value)
                ? 'border-brand-primary text-brand-primary bg-brand-container/40'
                : 'border-surface-border text-text-sub hover:bg-surface-hover',
            ]"
          >
            {{ rc.label }}
          </button>
        </div>
        <p class="text-[10px] text-text-muted mt-1 leading-relaxed">
          默认仅 SERVFAIL 与 REFUSED。NXDOMAIN 是权威有效判定，勾选它会让"域名不存在"也去问备用上游。
        </p>
      </div>

      <!-- 传输层故障开关 -->
      <label class="mt-3.5 flex items-center gap-1.5 cursor-pointer text-[11px] text-text-sub">
        <input
          type="checkbox"
          :checked="config.onError"
          :disabled="saving"
          @change="commit({ onError: !config.onError })"
          class="rounded text-accent-seal focus:ring-0"
        />
        <span>超时、连接失败等链路故障同样触发回退（推荐开启）</span>
      </label>
    </template>

    <template #footer>
      <div class="text-[11px] text-text-muted">
        提示：回退节点建议选择与主链路不同厂商，避免同一故障域内一起失效。
      </div>
    </template>
  </AppCard>

  <UpstreamEditModal
    :open="isDialogOpen"
    :editingItem="editingItem"
    @close="isDialogOpen = false"
    @save="handleSaveItem"
  />
</template>

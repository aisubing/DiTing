<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { ipc } from '../../api/ipc';
import type { ZoneEntry, ZoneState } from '../../api/types';
import M3Icon from '../M3Icon.vue';
import AppCard from '../ui/AppCard.vue';
import InlineAlert from '../ui/InlineAlert.vue';
import ToastBanner from '../ToastBanner.vue';
import { extractSwitchValue } from '../../utils/switch';
import { useToast } from '../../composables/useToast';

/**
 * 本地权威区（zone 文件）配置卡片。
 *
 * 与「自定义重写」同属本地权威应答，只是表达方式不同：重写是逐条域名映射，
 * 区文件是整个名字空间的声明。因此它嵌在重写页里而不是另开页签 ——
 * 用户面对的是同一个问题（这个域名不要问上游），不该先去猜该进哪个页。
 */

const enabled = ref(false);
const ttl = ref(300);
const zones = ref<ZoneEntry[]>([]);
const states = ref<Record<string, ZoneState>>({});
const recordCount = ref(0);
const maxZones = ref(32);
const maxRecords = ref(10000);

const loading = ref(false);
const saving = ref(false);
const expandedId = ref('');
/** 各区最近一次预演结果：null 表示尚未预演 */
const previews = ref<Record<string, { ok: boolean; text: string }>>({});

const { toast, show: showToast, dismiss } = useToast();

/** 构建失败的区在列表上的提示文案 */
function stateOf(id: string): ZoneState | undefined {
  return states.value[id];
}

/** 删除某区后清掉它的预演结果，避免同一 ID 复用时显示陈旧输出 */
function dropPreview(id: string) {
  const next = { ...previews.value };
  delete next[id];
  previews.value = next;
}

function stateBadge(zone: ZoneEntry): { text: string; cls: string } {
  const st = stateOf(zone.id);
  if (!zone.enabled) {
    return { text: '已停用', cls: 'bg-surface-card-sub text-text-muted border-surface-border' };
  }
  if (!st) return { text: '待构建', cls: 'bg-surface-card-sub text-text-muted border-surface-border' };
  if (!st.loaded) {
    return { text: '解析失败', cls: 'bg-status-error-bg text-status-error border-status-error/20' };
  }
  if (st.error) {
    return { text: `已加载 ${st.records} 条（截断）`, cls: 'bg-status-warning-bg text-status-warning border-status-warning/20' };
  }
  return { text: `已加载 ${st.records} 条`, cls: 'bg-status-success-bg text-status-success border-status-success/20' };
}

function applyState(res: {
  enabled?: boolean;
  ttl?: number;
  zones?: ZoneEntry[];
  states?: ZoneState[];
  recordCount?: number;
  maxZones?: number;
  maxRecords?: number;
}) {
  if (res.enabled !== undefined) enabled.value = res.enabled;
  if (res.ttl !== undefined) ttl.value = res.ttl;
  if (res.zones) zones.value = res.zones;
  if (res.recordCount !== undefined) recordCount.value = res.recordCount;
  if (res.maxZones !== undefined) maxZones.value = res.maxZones;
  if (res.maxRecords !== undefined) maxRecords.value = res.maxRecords;
  const map: Record<string, ZoneState> = {};
  for (const s of res.states || []) map[s.id] = s;
  states.value = map;
}

async function loadData() {
  loading.value = true;
  try {
    applyState(await ipc.getZoneConfig());
  } catch (err: any) {
    showToast(err.message || '加载本地权威区配置失败', true);
  } finally {
    loading.value = false;
  }
}

/** 提交全部区配置；失败时回滚，避免界面显示与后端不一致 */
async function persist(prev: ZoneEntry[], applyRes = true) {
  saving.value = true;
  try {
    const res = await ipc.configureZone({ zones: zones.value });
    if (applyRes) {
      applyState(res);
    } else {
      applyState({ ...res, zones: zones.value });
    }
    previews.value = {};
  } catch (err: any) {
    zones.value = prev;
    showToast(err.message || '保存本地权威区失败', true);
  } finally {
    saving.value = false;
  }
}

function newZoneId(): string {
  return `zone-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
}

function addZone() {
  if (zones.value.length >= maxZones.value) {
    showToast(`最多支持 ${maxZones.value} 个区，请先删除不再使用的区`, true);
    return;
  }
  const zone: ZoneEntry = {
    id: newZoneId(),
    origin: '',
    content: '$ORIGIN example.lan.\n@   IN SOA ns.example.lan. admin.example.lan. (1 7200 3600 1209600 300)\nwww IN A 192.168.1.10\n',
    enabled: true,
  };
  zones.value = [...zones.value, zone];
  expandedId.value = zone.id;
}

async function removeZone(zone: ZoneEntry) {
  const prev = [...zones.value];
  zones.value = zones.value.filter((z) => z.id !== zone.id);
  if (expandedId.value === zone.id) expandedId.value = '';
  dropPreview(zone.id);
  await persist(prev);
  showToast(`区 ${zone.origin || '(未命名)'} 已删除`);
}

/** 编辑期内只改本地状态，「保存全部」才提交：区文本动辄几十行，逐字提交不现实 */
function touchZone(zone: ZoneEntry, patch: Partial<ZoneEntry>) {
  const idx = zones.value.findIndex((z) => z.id === zone.id);
  if (idx < 0) return;
  zones.value[idx] = { ...zones.value[idx], ...patch };
  dropPreview(zone.id);
}

async function saveZones() {
  const prev = [...zones.value];
  await persist(prev);
  showToast('本地权威区配置已保存并生效');
}

async function handleToggleEnabled(e: Event) {
  const next = extractSwitchValue(e);
  const prev = enabled.value;
  enabled.value = next;
  saving.value = true;
  try {
    applyState(await ipc.configureZone({ enabled: next }));
    showToast(`本地权威区已${next ? '启用' : '停用'}`);
  } catch (err: any) {
    enabled.value = prev;
    showToast(err.message || '切换本地权威区状态失败', true);
  } finally {
    saving.value = false;
  }
}

async function saveTTL() {
  saving.value = true;
  try {
    applyState(await ipc.configureZone({ ttl: Number(ttl.value) || 300 }));
    showToast('默认 TTL 已保存');
  } catch (err: any) {
    showToast(err.message || '保存 TTL 失败', true);
  } finally {
    saving.value = false;
  }
}

/** 保存前预演：用与后端相同的解析路径跑一次，把错误挡在写配置之前 */
async function runPreview(zone: ZoneEntry) {
  try {
    const res = await ipc.testZone({ origin: zone.origin, content: zone.content, ttl: Number(ttl.value) || 300 });
    if (res.success) {
      const lines = res.records.slice(0, 20);
      if (res.records.length > lines.length) {
        lines.push(`… 其余 ${res.records.length - lines.length} 条已省略`);
      }
      previews.value = { ...previews.value, [zone.id]: { ok: true, text: lines.join('\n') || '（空区，无记录）' } };
    } else {
      previews.value = { ...previews.value, [zone.id]: { ok: false, text: res.error || '解析失败' } };
    }
  } catch (err: any) {
    previews.value = { ...previews.value, [zone.id]: { ok: false, text: err.message || '预演失败' } };
  }
}

function toggleExpand(id: string) {
  expandedId.value = expandedId.value === id ? '' : id;
}

/** 未加载区的失败原因需要直接可见，否则用户只能看到一个红点 */
function hasFailure(zone: ZoneEntry): boolean {
  const st = stateOf(zone.id);
  return !!st && zone.enabled && (!st.loaded || !!st.error);
}

onMounted(loadData);
</script>

<template>
  <div class="space-y-5">
    <ToastBanner
      v-if="toast"
      :message="toast.message"
      :type="toast.isError ? 'error' : 'success'"
      dismissible
      @dismiss="dismiss"
    />

    <AppCard
      title="本地权威区（zone 文件）"
      subtitle="整段声明一个名字空间由本机负责，区内未收录的名字返回权威 NODATA 而非转发上游；适合内网域名与局域网服务发现"
      icon="dns"
    >
      <template #badge>
        <span class="px-2 py-0.5 rounded-full text-[11px] font-mono font-semibold bg-surface-card-sub border border-surface-border text-text-main">
          {{ zones.length }} / {{ maxZones }} 区 · {{ recordCount }} 个名字
        </span>
      </template>

      <template #actions>
        <md-switch
          :selected="enabled"
          :disabled="saving || loading"
          @change="handleToggleEnabled"
        />
      </template>

      <div class="mt-3.5 space-y-3">
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <p class="text-[11px] text-text-muted leading-relaxed max-w-2xl">
            区顶点及其以下<strong class="text-text-sub">所有</strong>名字都由本地负责：区里没有的名字会被权威地判为「不存在」，
            不会漏到公网，同名时也优先于 hosts 条目。因此顶点要写成完整后缀（如
            <code class="font-mono bg-surface-card-sub px-1 py-0.5 rounded text-accent-seal">lan.</code>），
            而不是单条域名。区文件语法遵循 RFC 1035，
            <code class="font-mono bg-surface-card-sub px-1 py-0.5 rounded text-status-warning">$INCLUDE</code>
            出于安全考虑一律拒绝。
          </p>

          <div class="flex items-center gap-2 shrink-0">
            <label class="text-[11px] text-text-muted font-semibold">默认 TTL:</label>
            <input
              v-model.number="ttl"
              type="number"
              min="1"
              class="w-20 h-[30px] px-2 rounded-md border border-surface-border bg-surface-card-sub text-xs text-text-main font-mono text-center focus:outline-none focus:border-accent-seal"
            />
            <button type="button" class="app-btn-secondary app-btn-compact" :disabled="saving" @click="saveTTL">
              保存
            </button>
          </div>
        </div>

        <div class="flex items-center justify-between gap-2">
          <span class="text-[11px] text-text-muted">
            合计上限 {{ maxRecords }} 条记录；超出部分会被截断并在区上标注。
          </span>
          <div class="flex items-center gap-2">
            <button type="button" class="app-btn-primary app-btn-compact" :disabled="saving" @click="addZone">
              <M3Icon name="add" :size="14" />
              <span>添加区</span>
            </button>
            <button type="button" class="app-btn-secondary app-btn-compact" :disabled="saving || zones.length === 0" @click="saveZones">
              保存全部
            </button>
          </div>
        </div>

        <div v-if="loading" class="p-8 text-center text-text-muted text-xs">正在加载本地权威区配置...</div>

        <div v-else-if="zones.length > 0" class="space-y-2">
          <div
            v-for="zone in zones"
            :key="zone.id"
            class="rounded-md border transition-colors"
            :class="zone.enabled ? 'border-surface-border bg-surface-card-sub' : 'border-surface-border-sub bg-surface-card-sub/40'"
          >
            <div class="flex items-center gap-2 p-2.5">
              <button
                type="button"
                class="app-btn-secondary app-btn-compact !px-1.5"
                :title="expandedId === zone.id ? '收起' : '展开编辑'"
                @click="toggleExpand(zone.id)"
              >
                <M3Icon :name="expandedId === zone.id ? 'visibility_off' : 'visibility'" :size="13" />
              </button>

              <input
                :value="zone.origin"
                type="text"
                placeholder="区顶点，如 lan."
                class="flex-1 min-w-0 h-[30px] px-2 rounded-md border border-surface-border bg-surface-card text-xs text-text-main font-mono placeholder:text-text-muted focus:outline-none focus:border-accent-seal"
                @input="touchZone(zone, { origin: ($event.target as HTMLInputElement).value })"
              />

              <span
                class="px-1.5 py-0.5 rounded text-[10px] font-semibold border shrink-0"
                :class="stateBadge(zone).cls"
              >
                {{ stateBadge(zone).text }}
              </span>

              <md-switch
                :selected="zone.enabled"
                :disabled="saving"
                @change="touchZone(zone, { enabled: extractSwitchValue($event) })"
              />

              <button
                type="button"
                class="app-btn-secondary app-btn-compact !px-2 !text-status-error hover:!bg-status-error/10"
                title="删除该区"
                :disabled="saving"
                @click="removeZone(zone)"
              >
                <M3Icon name="delete" :size="13" />
              </button>
            </div>

            <div v-if="hasFailure(zone)" class="px-2.5 pb-2.5">
              <InlineAlert type="error" :message="stateOf(zone.id)?.error || '该区未被加载'" />
            </div>

            <div v-if="expandedId === zone.id" class="px-2.5 pb-2.5 space-y-2">
              <textarea
                :value="zone.content"
                rows="10"
                spellcheck="false"
                placeholder="$ORIGIN lan.&#10;@   IN SOA ns.lan. admin.lan. (1 7200 3600 1209600 300)&#10;www IN A 192.168.1.10"
                class="w-full p-2 rounded-md border border-surface-border bg-surface-card text-[11px] text-text-main font-mono leading-relaxed focus:outline-none focus:border-accent-seal resize-y"
                @input="touchZone(zone, { content: ($event.target as HTMLTextAreaElement).value })"
              ></textarea>

              <div class="flex items-center gap-2">
                <button type="button" class="app-btn-secondary app-btn-compact" @click="runPreview(zone)">
                  <M3Icon name="check" :size="13" />
                  <span>预演解析</span>
                </button>
                <span class="text-[10px] text-text-muted">
                  用与后端一致的解析路径试跑一次；改动需点「保存全部」才会生效。
                </span>
              </div>

              <pre
                v-if="previews[zone.id]"
                class="p-2 rounded-md border text-[10px] font-mono whitespace-pre-wrap break-all max-h-56 overflow-auto"
                :class="previews[zone.id].ok
                  ? 'border-surface-border bg-surface-card text-text-muted'
                  : 'border-status-error/30 bg-status-error-bg text-status-error'"
              >{{ previews[zone.id].text }}</pre>
            </div>
          </div>
        </div>

        <div
          v-else
          class="p-8 rounded-md border border-dashed border-surface-border-sub text-center text-text-muted text-xs flex flex-col items-center justify-center gap-2"
        >
          <M3Icon name="dns" :size="28" class="opacity-40" />
          <span>尚未配置任何本地权威区</span>
        </div>
      </div>
    </AppCard>
  </div>
</template>

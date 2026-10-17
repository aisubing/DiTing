<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { ipc } from '../../api/ipc';
import type {
  QueryLogRecord,
  QueryLogSearchQuery,
  QueryStatus,
  WebSocketEvent,
  QueryEventData,
} from '../../api/types';
import M3Icon from '../M3Icon.vue';
import AppCard from '../ui/AppCard.vue';
import ConfirmModal from '../ConfirmModal.vue';
import ToastBanner from '../ToastBanner.vue';
import { useToast } from '../../composables/useToast';
import { useConfirmModal } from '../../composables/useConfirmModal';
import { formatMonthDayTime } from '../../utils/format';

const PAGE_SIZE = 50;

const entries = ref<QueryLogRecord[]>([]);
const total = ref(0);
const page = ref(0);
const loading = ref(false);
const clearing = ref(false);
const live = ref(true);

const fDomain = ref('');
const fClient = ref('');
const fQType = ref('');
const fStatus = ref('');

const { toast, show: showToast, dismiss } = useToast();
const confirm = useConfirmModal();

let unsubEvents: (() => void) | null = null;
// 必须是响应式引用：模板里展示「暂停期间新增 N 条」，普通 let 数组 push 不触发重渲染
const liveBuffer = ref<QueryLogRecord[]>([]);
// 检索请求代次：慢回包不能覆盖后发出的新检索结果
let fetchSeq = 0;

const qTypes = ['', 'A', 'AAAA', 'HTTPS', 'CNAME', 'PTR', 'TXT'] as const;
const statusOptions: { value: string; label: string }[] = [
  { value: '', label: '全部状态' },
  { value: 'allowed', label: '放行' },
  { value: 'blocked', label: '已拦截' },
  { value: 'cached', label: '命中缓存' },
  { value: 'error', label: '解析失败' },
];

const pageCount = computed(() => Math.max(1, Math.ceil(total.value / PAGE_SIZE)));
const canPrev = computed(() => page.value > 0);
const canNext = computed(() => page.value + 1 < pageCount.value);

const hasFilter = computed(
  () => !!(fDomain.value || fClient.value || fQType.value || fStatus.value)
);

function statusMeta(status: QueryStatus): { label: string; cls: string } {
  switch (status) {
    case 'blocked':
      return { label: '已拦截', cls: 'bg-accent-seal text-white' };
    case 'cached':
      return { label: '缓存命中', cls: 'bg-status-success-bg text-status-success' };
    case 'stale':
      return { label: '容灾复用', cls: 'bg-status-warning-bg text-status-warning' };
    case 'error':
      return { label: '解析失败', cls: 'bg-status-error-bg text-status-error' };
    default:
      return { label: '放行', cls: 'bg-surface-hover text-text-sub' };
  }
}

function currentQuery(offset: number): QueryLogSearchQuery {
  return {
    domain: fDomain.value.trim(),
    client: fClient.value.trim(),
    qtype: fQType.value,
    status: fStatus.value,
    limit: PAGE_SIZE,
    offset,
    includeFile: true,
  };
}

async function fetchPage(resetPage = false) {
  if (resetPage) page.value = 0;
  const seq = ++fetchSeq;
  // 在发请求前清空缓冲：请求期间到达的事件属于「本次快照之后」，
  // 若等回包再清就会把它们一起丢掉，与提示语的承诺不符。
  liveBuffer.value = [];
  loading.value = true;
  try {
    const res = await ipc.searchQueryLog(currentQuery(page.value * PAGE_SIZE));
    if (seq !== fetchSeq) return;
    entries.value = res?.entries || [];
    total.value = res?.total || 0;
  } catch (err: any) {
    if (seq !== fetchSeq) return;
    showToast(err.message || '加载查询历史失败', true);
  } finally {
    if (seq === fetchSeq) loading.value = false;
  }
}

function applyFilters() {
  void fetchPage(true);
}

function resetFilters() {
  fDomain.value = '';
  fClient.value = '';
  fQType.value = '';
  fStatus.value = '';
  void fetchPage(true);
}

function gotoPage(next: number) {
  if (next < 0 || next >= pageCount.value) return;
  page.value = next;
  void fetchPage(false);
}

function recordFromEvent(data: QueryEventData, ts: number): QueryLogRecord {
  const status: QueryStatus =
    data.errorMessage || !data.success
      ? 'error'
      : data.blocked
        ? 'blocked'
        : data.cacheHit === 'stale'
          ? 'stale'
          : data.cacheHit
            ? 'cached'
            : 'allowed';
  return {
    ts: ts || Date.now(),
    domain: data.domain,
    qtype: data.qtype,
    clientIP: data.clientIP,
    clientName: data.clientName,
    durationMs: data.durationMs,
    rcode: data.rcode,
    status,
    cached: !!data.cacheHit,
    cacheHit: data.cacheHit,
    blocked: data.blocked,
    filterRule: data.filterRule,
    filterReason: data.filterReason,
  };
}

/** 实时事件仅在「停留在第一页且未启用筛选」时插入，避免破坏分页语义 */
function handleLiveQuery(data: QueryEventData, ts: number) {
  if (!live.value || page.value !== 0 || hasFilter.value) {
    liveBuffer.value.push(recordFromEvent(data, ts));
    return;
  }
  entries.value = [recordFromEvent(data, ts), ...entries.value].slice(0, PAGE_SIZE);
  total.value += 1;
}

async function handleClear() {
  const ok = await confirm.ask({
    title: '清空查询历史',
    message: '将删除全部内存记录与已落盘的历史日志文件，此操作不可撤销。',
    confirmText: '确认清空',
    danger: true,
  });
  if (!ok) return;
  clearing.value = true;
  try {
    await ipc.clearQueryLog();
    entries.value = [];
    total.value = 0;
    page.value = 0;
    liveBuffer.value = [];
    showToast('查询历史与统计已清空');
  } catch (err: any) {
    showToast(`清空失败: ${err.message}`, true);
  } finally {
    clearing.value = false;
  }
}

onMounted(() => {
  void fetchPage(true);
  unsubEvents = ipc.onEvent((event: WebSocketEvent) => {
    if (event.type === 'query') {
      handleLiveQuery(event.data as QueryEventData, event.timestamp);
    }
  });
});

onUnmounted(() => {
  if (unsubEvents) unsubEvents();
});
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

    <!-- 筛选与检索 -->
    <AppCard
      title="查询历史检索"
      subtitle="按域名、客户端、记录类型与状态精确回溯历史解析请求"
      icon="history"
      iconBoxClass="w-7 h-7"
      :iconSize="16"
    >
      <template #actions>
        <div class="flex items-center gap-2">
          <button
            type="button"
            @click="live = !live"
            class="app-btn-chip"
            :class="live ? 'active' : ''"
            :title="live ? '暂停实时刷新' : '恢复实时刷新'"
          >
            <M3Icon :name="live ? 'pause' : 'play_arrow'" :size="13" />
            <span>{{ live ? '实时刷新中' : '已暂停' }}</span>
          </button>
          <button type="button" @click="handleClear" :disabled="clearing" class="app-btn-secondary app-btn-compact">
            <M3Icon name="delete_sweep" :size="14" />
            <span>{{ clearing ? '清空中...' : '清空历史' }}</span>
          </button>
        </div>
      </template>

      <div class="space-y-3 mt-3 text-xs">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <md-outlined-text-field
            label="域名包含"
            :value="fDomain"
            @input="fDomain = ($event.target as any).value"
            @keyup.enter="applyFilters"
          ></md-outlined-text-field>
          <md-outlined-text-field
            label="客户端 IP 或主机名"
            :value="fClient"
            @input="fClient = ($event.target as any).value"
            @keyup.enter="applyFilters"
          ></md-outlined-text-field>
        </div>

        <div>
          <label class="text-[11px] font-semibold text-text-muted block mb-1.5">记录类型</label>
          <div class="flex flex-wrap gap-1.5">
            <button
              v-for="t in qTypes"
              :key="t || 'ALL'"
              type="button"
              @click="fQType = t"
              class="app-btn-chip font-mono text-[11px]"
              :class="{ active: fQType === t }"
            >
              {{ t === '' ? '全部类型' : t }}
            </button>
          </div>
        </div>

        <div>
          <label class="text-[11px] font-semibold text-text-muted block mb-1.5">解析状态</label>
          <div class="flex flex-wrap gap-1.5">
            <button
              v-for="s in statusOptions"
              :key="s.value || 'ALL'"
              type="button"
              @click="fStatus = s.value"
              class="app-btn-chip text-[11px]"
              :class="{ active: fStatus === s.value }"
            >
              {{ s.label }}
            </button>
          </div>
        </div>

        <div class="flex items-center gap-2 pt-1">
          <button type="button" @click="applyFilters" :disabled="loading" class="app-btn-primary app-btn-compact">
            <M3Icon :name="loading ? 'refresh' : 'search'" :size="14" :class="loading ? 'animate-spin' : ''" />
            <span>检索</span>
          </button>
          <button type="button" @click="resetFilters" class="app-btn-secondary app-btn-compact">
            <M3Icon name="restart_alt" :size="14" />
            <span>重置</span>
          </button>
          <span v-if="liveBuffer.length > 0" class="text-[11px] text-text-muted ml-auto">
            暂停期间新增 {{ liveBuffer.length }} 条，检索后可见
          </span>
        </div>
      </div>
    </AppCard>

    <!-- 结果表格 -->
    <AppCard
      title="历史解析记录"
      subtitle="命中结果按时间倒序排列，超出内存缓冲的部分将回溯落盘日志"
      icon="list_alt"
      iconBoxClass="w-7 h-7"
      :iconSize="16"
    >
      <template #actions>
        <span class="text-[11px] font-mono text-text-muted">共 {{ total }} 条</span>
      </template>

      <div v-if="entries.length === 0" class="py-12 text-center text-xs text-text-muted">
        {{ loading ? '正在检索…' : '暂无符合条件的查询历史' }}
      </div>

      <div v-else class="mt-3 overflow-x-auto">
        <table class="w-full text-left text-[12px]">
          <thead>
            <tr class="text-[11px] text-text-muted border-b border-surface-border-sub">
              <th class="py-2 pr-3 font-medium whitespace-nowrap">时间</th>
              <th class="py-2 pr-3 font-medium">域名</th>
              <th class="py-2 pr-3 font-medium whitespace-nowrap">类型</th>
              <th class="py-2 pr-3 font-medium">客户端</th>
              <th class="py-2 pr-3 font-medium whitespace-nowrap">状态</th>
              <th class="py-2 pr-3 font-medium whitespace-nowrap">应答</th>
              <th class="py-2 font-medium whitespace-nowrap text-right">耗时</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="(item, idx) in entries"
              :key="`${item.ts}-${item.domain}-${idx}`"
              class="border-b border-surface-border-sub/40 hover:bg-surface-hover/50 transition-colors"
            >
              <td class="py-2 pr-3 font-mono text-text-muted whitespace-nowrap">
                {{ formatMonthDayTime(item.ts) }}
              </td>
              <td class="py-2 pr-3 font-mono text-text-main max-w-[22rem] truncate" :title="item.domain">
                {{ item.domain }}
                <span v-if="item.filterRule" class="ml-1 text-[10px] text-accent-seal" :title="item.filterRule">
                  [{{ item.filterReason || item.filterRule }}]
                </span>
              </td>
              <td class="py-2 pr-3 font-mono text-text-sub whitespace-nowrap">{{ item.qtype || 'A' }}</td>
              <td class="py-2 pr-3 font-mono text-text-muted max-w-[14rem] truncate" :title="item.clientIP">
                <span v-if="item.clientName" class="text-text-main">{{ item.clientName }} </span>
                <span>{{ item.clientIP || '127.0.0.1' }}</span>
              </td>
              <td class="py-2 pr-3 whitespace-nowrap">
                <span class="px-1.5 py-0.5 rounded text-[10px] font-semibold" :class="statusMeta(item.status).cls">
                  {{ statusMeta(item.status).label }}
                </span>
              </td>
              <td class="py-2 pr-3 font-mono text-text-muted whitespace-nowrap">{{ item.rcode || '-' }}</td>
              <td
                class="py-2 font-mono text-right whitespace-nowrap"
                :class="item.durationMs > 100 ? 'text-status-warning' : 'text-text-sub'"
              >
                {{ item.durationMs.toFixed(1) }} ms
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <template #footer>
        <div class="flex items-center justify-between text-[11px] text-text-muted">
          <span>第 {{ page + 1 }} / {{ pageCount }} 页</span>
          <div class="flex items-center gap-2">
            <button
              type="button"
              @click="gotoPage(page - 1)"
              :disabled="!canPrev || loading"
              class="app-btn-secondary app-btn-compact"
            >
              <M3Icon name="chevron_left" :size="14" />
              <span>上一页</span>
            </button>
            <button
              type="button"
              @click="gotoPage(page + 1)"
              :disabled="!canNext || loading"
              class="app-btn-secondary app-btn-compact"
            >
              <span>下一页</span>
              <M3Icon name="chevron_right" :size="14" />
            </button>
          </div>
        </div>
      </template>
    </AppCard>

    <ConfirmModal
      :open="confirm.isOpen.value"
      :title="confirm.options.value.title"
      :message="confirm.options.value.message"
      :confirm-text="confirm.options.value.confirmText"
      :cancel-text="confirm.options.value.cancelText"
      :danger="confirm.options.value.danger"
      :loading="clearing"
      @confirm="confirm.handleConfirm"
      @cancel="confirm.handleCancel"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { ipc } from '../../api/ipc';
import type { BlockedService, BlockedServiceGroup } from '../../api/types';
import M3Icon from '../M3Icon.vue';
import AppCard from '../ui/AppCard.vue';
import ToastBanner from '../ToastBanner.vue';
import { useToast } from '../../composables/useToast';

const services = ref<BlockedService[]>([]);
const groups = ref<BlockedServiceGroup[]>([]);
const blockedIds = ref<Set<string>>(new Set());
const blockedGroups = ref<Set<string>>(new Set());
const activeRules = ref(0);

const loading = ref(false);
const saving = ref(false);
const searchFilter = ref('');
const activeGroup = ref('');
const expandedId = ref('');

const { toast, show: showToast, dismiss } = useToast();

/** 分组名查表，用于给搜索结果标注归属 */
const groupNames = computed(() => {
  const map: Record<string, string> = {};
  for (const g of groups.value) map[g.id] = g.name;
  return map;
});

const filteredServices = computed(() => {
  const q = searchFilter.value.trim().toLowerCase();
  return services.value.filter((s) => {
    if (activeGroup.value && s.group !== activeGroup.value) return false;
    if (!q) return true;
    if (s.name.toLowerCase().includes(q) || s.id.toLowerCase().includes(q)) return true;
    return s.rules.some((r) => r.toLowerCase().includes(q));
  });
});

/** 该服务是否因所属分组被勾选而被动生效 */
function blockedByGroup(svc: BlockedService): boolean {
  return !blockedIds.value.has(svc.id) && blockedGroups.value.has(svc.group);
}

function isBlocked(svc: BlockedService): boolean {
  return blockedIds.value.has(svc.id) || blockedByGroup(svc);
}

const blockedCount = computed(() => services.value.filter(isBlocked).length);

async function loadData() {
  loading.value = true;
  try {
    const res = await ipc.getBlockedServices();
    services.value = res.services || [];
    groups.value = res.groups || [];
    blockedIds.value = new Set(res.blockedIds || []);
    blockedGroups.value = new Set(res.blockedGroups || []);
    activeRules.value = res.activeRules || 0;
  } catch (err: any) {
    showToast(err.message || '加载内置服务目录失败', true);
  } finally {
    loading.value = false;
  }
}

/** 提交勾选；失败时回滚本地状态，避免界面显示与后端不一致 */
async function persist(prevIds: Set<string>, prevGroups: Set<string>) {
  saving.value = true;
  try {
    const res = await ipc.configureBlockedServices({
      ids: Array.from(blockedIds.value),
      groups: Array.from(blockedGroups.value),
    });
    services.value = res.services || services.value;
    groups.value = res.groups || groups.value;
    blockedIds.value = new Set(res.blockedIds || []);
    blockedGroups.value = new Set(res.blockedGroups || []);
    activeRules.value = res.activeRules || 0;
  } catch (err: any) {
    blockedIds.value = prevIds;
    blockedGroups.value = prevGroups;
    showToast(err.message || '保存应用拦截配置失败', true);
  } finally {
    saving.value = false;
  }
}

async function toggleService(svc: BlockedService) {
  // 随分组拦截的服务由 template 侧禁用开关，此处只作兜底防御，
  // 避免任何遗漏的调用点把「随分组」误写成「单独勾选」
  if (blockedByGroup(svc)) return;

  const prevIds = new Set(blockedIds.value);
  const prevGroups = new Set(blockedGroups.value);
  const next = new Set(blockedIds.value);
  if (next.has(svc.id)) {
    next.delete(svc.id);
  } else {
    next.add(svc.id);
  }
  blockedIds.value = next;
  await persist(prevIds, prevGroups);
}

async function toggleGroup(group: BlockedServiceGroup) {
  const prevIds = new Set(blockedIds.value);
  const prevGroups = new Set(blockedGroups.value);
  const next = new Set(blockedGroups.value);
  if (next.has(group.id)) {
    next.delete(group.id);
  } else {
    // 整组拦截时把该组下已单独勾选的服务去掉：
    // 留着它们，之后取消分组时这些服务会意外地继续被拦
    next.add(group.id);
    const inGroup = new Set(services.value.filter((s) => s.group === group.id).map((s) => s.id));
    blockedIds.value = new Set(Array.from(blockedIds.value).filter((id) => !inGroup.has(id)));
  }
  blockedGroups.value = next;
  await persist(prevIds, prevGroups);
}

function clearAll() {
  if (blockedIds.value.size === 0 && blockedGroups.value.size === 0) return;
  const prevIds = new Set(blockedIds.value);
  const prevGroups = new Set(blockedGroups.value);
  blockedIds.value = new Set();
  blockedGroups.value = new Set();
  persist(prevIds, prevGroups);
}

function toggleExpand(id: string) {
  expandedId.value = expandedId.value === id ? '' : id;
}

onMounted(loadData);
</script>

<template>
  <div class="space-y-6 select-none max-w-7xl mx-auto">
    <ToastBanner
      v-if="toast"
      :message="toast.message"
      :type="toast.isError ? 'error' : 'success'"
      dismissible
      @dismiss="dismiss"
    />

    <AppCard
      title="应用与网站拦截"
      subtitle="一键拦截常见应用与网站，规则随程序内置、无需联网拉取；可与订阅规则、自定义规则叠加生效"
      icon="shield"
    >
      <template #badge>
        <span class="px-2 py-0.5 rounded-full text-[11px] font-mono font-semibold bg-surface-card-sub border border-surface-border text-text-main">
          {{ blockedCount }} / {{ services.length }} 项已拦截
        </span>
      </template>

      <template #actions>
        <span class="text-[11px] text-text-muted hidden sm:inline">
          展开 {{ activeRules }} 条规则
        </span>
        <button
          type="button"
          class="app-btn-secondary app-btn-compact"
          :disabled="saving || (blockedCount === 0)"
          @click="clearAll"
        >
          全部取消
        </button>
      </template>

      <div class="mt-3.5 space-y-3">
        <!-- 检索与筛选 -->
        <div class="flex flex-col sm:flex-row gap-2">
          <div class="relative flex-1 max-w-md">
            <M3Icon name="search" :size="15" class="absolute left-3 top-1/2 -translate-y-1/2 text-text-muted" />
            <input
              v-model="searchFilter"
              type="text"
              placeholder="搜索应用名称、域名或规则..."
              class="w-full pl-9 pr-3 h-[32px] rounded-md border border-surface-border bg-surface-card-sub text-xs text-text-main font-mono placeholder:text-text-muted focus:outline-none focus:border-accent-seal"
            />
          </div>
          <select
            v-model="activeGroup"
            class="h-[32px] px-2.5 rounded-md border border-surface-border bg-surface-card-sub text-xs text-text-main focus:outline-none focus:border-accent-seal sm:w-48"
          >
            <option value="">全部分组</option>
            <option v-for="g in groups" :key="g.id" :value="g.id">{{ g.name }} ({{ g.count }})</option>
          </select>
        </div>

        <!-- 分组快捷开关 -->
        <div class="flex flex-wrap gap-2">
          <button
            v-for="g in groups"
            :key="g.id"
            type="button"
            :disabled="saving"
            class="px-2.5 py-1 rounded-full text-[11px] font-semibold border transition-colors disabled:opacity-60"
            :class="blockedGroups.has(g.id)
              ? 'bg-status-error/10 border-status-error/40 text-status-error'
              : 'bg-surface-card-sub border-surface-border text-text-sub hover:border-accent-seal'"
            @click="toggleGroup(g)"
          >
            {{ g.name }} · {{ g.count }}
          </button>
        </div>

        <!-- 服务列表 -->
        <div v-if="loading" class="p-8 text-center text-text-muted text-xs">正在加载内置服务目录...</div>

        <div v-else-if="filteredServices.length > 0" class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-2">
          <div
            v-for="svc in filteredServices"
            :key="svc.id"
            class="rounded-md border transition-colors"
            :class="isBlocked(svc) ? 'border-status-error/40 bg-status-error/5' : 'border-surface-border bg-surface-card-sub'"
          >
            <div class="flex items-center gap-2 p-2.5">
              <button
                type="button"
                class="flex-1 min-w-0 text-left"
                :disabled="saving"
                @click="toggleService(svc)"
              >
                <div class="flex items-center gap-1.5">
                  <span class="text-xs font-semibold text-text-main truncate">{{ svc.name }}</span>
                  <span
                    v-if="blockedByGroup(svc)"
                    class="px-1.5 py-0.5 rounded text-[9px] font-semibold bg-status-warning-bg text-status-warning shrink-0"
                  >
                    随分组
                  </span>
                </div>
                <span class="text-[10px] text-text-muted font-mono truncate block">
                  {{ groupNames[svc.group] || svc.group }} · {{ svc.ruleCount }} 条规则
                </span>
              </button>

              <!-- 随分组拦截的服务禁用开关：此时点开关不会有任何持久化效果，
                   禁用比让它翻转后再回弹更清楚 -->
              <md-switch
                :selected="isBlocked(svc)"
                :disabled="saving || blockedByGroup(svc)"
                @change="toggleService(svc)"
              />
              <button
                type="button"
                class="app-btn-secondary app-btn-compact !px-1.5"
                :title="expandedId === svc.id ? '收起规则' : '查看规则'"
                @click="toggleExpand(svc.id)"
              >
                <M3Icon :name="expandedId === svc.id ? 'visibility_off' : 'visibility'" :size="13" />
              </button>
            </div>

            <div v-if="expandedId === svc.id" class="px-2.5 pb-2.5 space-y-0.5">
              <code
                v-for="rule in svc.rules"
                :key="rule"
                class="block font-mono text-[10px] text-text-muted truncate"
              >
                {{ rule }}
              </code>
            </div>
          </div>
        </div>

        <div
          v-else
          class="p-8 rounded-md border border-dashed border-surface-border-sub text-center text-text-muted text-xs flex flex-col items-center justify-center gap-2"
        >
          <M3Icon name="shield" :size="28" class="opacity-40" />
          <span>{{ searchFilter || activeGroup ? '未找到符合条件的应用' : '内置服务目录为空' }}</span>
        </div>
      </div>
    </AppCard>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { ipc } from '../../api/ipc';
import type { ScheduleConfigResponse } from '../../api/types';
import M3Icon from '../M3Icon.vue';
import AppCard from '../ui/AppCard.vue';
import StatusBadge from '../StatusBadge.vue';
import ToastBanner from '../ToastBanner.vue';
import ScheduleEditor from './ScheduleEditor.vue';
import { extractSwitchValue } from '../../utils/switch';
import { usePoller } from '../../composables/usePoller';
import { useToast } from '../../composables/useToast';

const config = ref<ScheduleConfigResponse>({
  enabled: false,
  schedules: [],
  active: true,
  activeId: '',
});

const saving = ref(false);
const { toast, show: showToast, dismiss } = useToast();

const enabledCount = computed(() => config.value.schedules.filter((s) => s.enabled).length);

/** 顶部生效状态徽标：区分「常开」「窗口内生效」「已暂停」三态 */
const stateBadge = computed(() => {
  if (!config.value.enabled || enabledCount.value === 0) {
    return { status: 'inactive' as const, text: '未启用 · 拦截常开' };
  }
  if (config.value.active) {
    return { status: 'active' as const, text: '拦截生效中' };
  }
  return { status: 'warning' as const, text: '计划暂停 · 放行全部' };
});

async function fetchData() {
  try {
    const res = await ipc.getBlockingSchedule();
    if (res) config.value = res;
  } catch {
    // 轮询失败静默，避免打扰用户操作
  }
}

async function saveConfig() {
  try {
    saving.value = true;
    // 过滤掉完全空白的行，避免落库无意义的计划
    const schedules = config.value.schedules
      .filter((s) => s.start && s.end)
      .map((s) => ({ ...s, weekdays: [...s.weekdays] }));
    await ipc.configureBlockingSchedule({
      enabled: config.value.enabled,
      schedules,
    });
    showToast('时间计划已保存并生效');
    await fetchData();
  } catch (err: any) {
    showToast(err?.message || '保存时间计划失败', true);
  } finally {
    saving.value = false;
  }
}

usePoller(fetchData, 5000);
</script>

<template>
  <div class="space-y-5">
    <ToastBanner v-if="toast" :message="toast.message" :type="toast.isError ? 'error' : 'success'" dismissible @dismiss="dismiss" />

    <AppCard
      title="分时拦截 · 时间计划"
      subtitle="仅在指定时段内执行广告拦截，其余时间自动放行"
      icon="alarm"
    >
      <template #actions>
        <StatusBadge :status="stateBadge.status" :text="stateBadge.text" pulse size="sm" />
        <button
          type="button"
          @click="saveConfig"
          :disabled="saving"
          class="app-btn-primary app-btn-compact ml-2"
        >
          <M3Icon :name="saving ? 'refresh' : 'check'" :size="14" :class="saving ? 'animate-spin' : ''" />
          <span>{{ saving ? '保存中...' : '保存计划' }}</span>
        </button>
      </template>

      <div class="space-y-4 mt-3 text-xs">
        <!-- 总开关 -->
        <div class="app-card-sub p-3 flex items-center justify-between gap-3">
          <div class="min-w-0">
            <span class="text-[12px] font-bold text-text-main block">启用分时拦截</span>
            <p class="text-[11px] text-text-muted">
              关闭时拦截始终生效；开启后仅在下列时间窗口内执行拦截。
            </p>
          </div>
          <md-switch
            :selected="config.enabled"
            @change="config.enabled = extractSwitchValue($event)"
            class="shrink-0"
          />
        </div>

        <!-- 计划列表（编辑组件与客户端分组计划共用） -->
        <div v-if="config.enabled" class="space-y-3">
          <ScheduleEditor v-model="config.schedules" />

          <p v-if="enabledCount === 0" class="text-[11px] text-status-warning">
            当前无已启用计划，拦截将保持常开。请至少启用一条计划以限制拦截时段。
          </p>
        </div>
      </div>
    </AppCard>
  </div>
</template>

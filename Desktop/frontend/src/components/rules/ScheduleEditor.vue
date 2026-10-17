<script setup lang="ts">
import type { BlockingSchedule } from '../../api/types';
import M3Icon from '../M3Icon.vue';
import ConfirmModal from '../ConfirmModal.vue';
import { ref } from 'vue';
import { extractSwitchValue } from '../../utils/switch';

/** 时间计划编辑组件：全局分时拦截与客户端分组计划复用同一套 UI。 */

const rows = defineModel<BlockingSchedule[]>({ required: true });
const props = withDefaults(defineProps<{ disabled?: boolean }>(), { disabled: false });

/** 星期选择项（键值与后端 BlockingSchedule.Weekdays 一致） */
const WEEKDAYS = [
  { key: 'mon', label: '一' },
  { key: 'tue', label: '二' },
  { key: 'wed', label: '三' },
  { key: 'thu', label: '四' },
  { key: 'fri', label: '五' },
  { key: 'sat', label: '六' },
  { key: 'sun', label: '日' },
] as const;

const deleteIndex = ref(-1);

function toggleWeekday(row: BlockingSchedule, key: string) {
  const idx = row.weekdays.indexOf(key);
  if (idx >= 0) {
    row.weekdays.splice(idx, 1);
  } else {
    row.weekdays.push(key);
  }
}

function addSchedule() {
  rows.value.push({
    id: '',
    name: '',
    enabled: true,
    weekdays: [],
    start: '08:00',
    end: '18:00',
  });
}

function confirmDelete() {
  if (deleteIndex.value >= 0) {
    rows.value.splice(deleteIndex.value, 1);
  }
  deleteIndex.value = -1;
}
</script>

<template>
  <div class="space-y-3">
    <!-- 用行对象本身作 key：删除中间行后 DOM 不会原位复用，焦点与输入不会串到上移的行 -->
    <div v-for="(row, index) in rows" :key="row" class="app-card-sub p-3 space-y-3">
      <div class="flex items-center justify-between gap-2">
        <div class="flex items-center gap-2 min-w-0 flex-1">
          <md-outlined-text-field
            label="计划名称"
            class="flex-1 min-w-0"
            :value="row.name"
            :disabled="props.disabled"
            @input="row.name = ($event.target as any).value"
          ></md-outlined-text-field>
          <md-switch
            :selected="row.enabled"
            :disabled="props.disabled"
            @change="row.enabled = extractSwitchValue($event)"
            class="shrink-0"
          />
        </div>
        <button
          type="button"
          class="app-btn-icon shrink-0"
          :disabled="props.disabled"
          title="删除该计划"
          @click="deleteIndex = index"
        >
          <M3Icon name="delete" :size="15" />
        </button>
      </div>

      <div class="grid grid-cols-2 gap-3">
        <div class="space-y-1">
          <label class="text-[11px] font-semibold text-text-muted block">生效开始时刻</label>
          <input
            type="time"
            class="w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card-sub text-xs text-text-main font-mono focus:outline-none focus:border-accent-seal"
            :value="row.start"
            :disabled="props.disabled"
            @input="row.start = ($event.target as HTMLInputElement).value"
          />
        </div>
        <div class="space-y-1">
          <label class="text-[11px] font-semibold text-text-muted block">
            生效结束时刻
            <span class="text-text-muted/70 font-normal">(早于开始即跨夜)</span>
          </label>
          <input
            type="time"
            class="w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card-sub text-xs text-text-main font-mono focus:outline-none focus:border-accent-seal"
            :value="row.end"
            :disabled="props.disabled"
            @input="row.end = ($event.target as HTMLInputElement).value"
          />
        </div>
      </div>

      <div class="space-y-1.5">
        <div class="flex items-center justify-between">
          <label class="text-[11px] font-semibold text-text-muted">生效星期</label>
          <button
            type="button"
            class="text-[11px] text-brand-primary hover:underline"
            :disabled="props.disabled"
            @click="row.weekdays = []"
          >
            每天
          </button>
        </div>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="day in WEEKDAYS"
            :key="day.key"
            type="button"
            class="w-8 h-8 rounded-full text-[11px] font-semibold border transition-colors"
            :disabled="props.disabled"
            :class="row.weekdays.includes(day.key)
              ? 'bg-brand-primary text-white border-brand-primary'
              : 'bg-surface-card text-text-muted border-surface-border-sub hover:border-brand-primary/60'"
            @click="toggleWeekday(row, day.key)"
          >
            {{ day.label }}
          </button>
        </div>
      </div>
    </div>

    <button
      type="button"
      class="w-full py-2 rounded-lg border border-dashed border-surface-border-sub text-text-muted hover:text-brand-primary hover:border-brand-primary/60 transition-colors flex items-center justify-center gap-1.5"
      :disabled="props.disabled"
      @click="addSchedule"
    >
      <M3Icon name="add" :size="15" />
      <span>新增时间计划</span>
    </button>

    <ConfirmModal
      :open="deleteIndex >= 0"
      title="删除时间计划"
      message="确定要删除该时间计划吗？保存后不再生效。"
      confirm-text="删除"
      danger
      @confirm="confirmDelete"
      @cancel="deleteIndex = -1"
    />
  </div>
</template>

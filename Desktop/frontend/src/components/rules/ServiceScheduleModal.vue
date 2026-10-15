<script setup lang="ts">
import { ref, watch } from 'vue';
import type { BlockingSchedule, BlockedService } from '../../api/types';
import AppModal from '../AppModal.vue';
import ScheduleEditor from './ScheduleEditor.vue';

/**
 * 单个内置服务的每周生效计划编辑弹窗。
 *
 * 与「时间计划」页的全局分时拦截共用一个编辑器组件，但语义不同：
 * 全局计划决定「什么时候整体拦截」，这里决定「某个应用什么时候可以被访问」。
 */

const props = defineProps<{
  open: boolean;
  service: BlockedService | null;
  schedules: BlockingSchedule[];
}>();

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'save', schedules: BlockingSchedule[]): void;
}>();

const rows = ref<BlockingSchedule[]>([]);

watch(
  () => props.open,
  (isOpen) => {
    if (!isOpen) return;
    // 深拷贝一份再编辑，取消时不会污染父组件的状态
    rows.value = (props.schedules || []).map((s) => ({ ...s, weekdays: [...(s.weekdays || [])] }));
  }
);

function handleSave() {
  emit('save', rows.value.map((s) => ({ ...s, weekdays: [...(s.weekdays || [])] })));
}
</script>

<template>
  <AppModal
    :open="open"
    :title="`${service?.name || ''} 的每周生效计划`"
    @close="emit('close')"
  >
    <div class="space-y-4 text-xs">
      <p class="text-[11px] text-text-muted leading-relaxed">
        仅在命中的时间窗口内拦截该应用，其余时间正常放行。
        <span class="font-semibold">未配置任何计划时恒为拦截</span>；
        需要某段时间完全不限制时，取消勾选该服务比清空计划更直观。
      </p>

      <ScheduleEditor v-model="rows" />
    </div>

    <template #footer>
      <div class="flex items-center justify-end gap-2 w-full">
        <button type="button" @click="emit('close')" class="app-btn-secondary">取消</button>
        <button type="button" @click="handleSave" class="app-btn-primary">保存计划</button>
      </div>
    </template>
  </AppModal>
</template>

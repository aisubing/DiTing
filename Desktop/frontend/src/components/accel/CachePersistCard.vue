<script setup lang="ts">
import { ref } from 'vue';
import type { CachePersistInfo } from '../../api/types';
import M3Icon from '../M3Icon.vue';
import AppCard from '../ui/AppCard.vue';
import ConfirmModal from '../ConfirmModal.vue';
import { extractSwitchValue } from '../../utils/switch';

const props = defineProps<{
  /** 已开启落盘 */
  enabled: boolean;
  /** 定时落盘间隔（秒）；0 表示仅在退出时落盘 */
  intervalSeconds: number;
  /** 后端上报的落盘运行状态；未取到时为 null */
  info: CachePersistInfo | null;
  saving?: boolean;
  busy?: boolean;
}>();

const emit = defineEmits<{
  (e: 'toggle', enabled: boolean): void;
  (e: 'interval', seconds: number): void;
  (e: 'dump'): void;
  (e: 'load'): void;
}>();

const isLoadDialogOpen = ref(false);

const MIN_INTERVAL = 30;
const MAX_INTERVAL = 86400;

function handleIntervalInput(e: Event) {
  const raw = Number((e.target as HTMLInputElement).value);
  // 空值或非法输入回落为服务端默认 300s；否则钳制到 [30, 86400]。
  // 后端把 0 与缺省视作同一件事，故这里不把 0 当作"不落盘"。
  if (!Number.isFinite(raw) || raw <= 0) {
    emit('interval', 300);
    return;
  }
  emit('interval', Math.min(MAX_INTERVAL, Math.max(MIN_INTERVAL, Math.round(raw))));
}

function handleLoadConfirm() {
  isLoadDialogOpen.value = false;
  emit('load');
}
</script>

<template>
  <AppCard
    title="缓存落盘持久化"
    subtitle="重启后直接复用热缓存，避免冷启动回源高峰"
    icon="sync"
    iconBoxClass="w-7 h-7"
    :iconSize="16"
  >
    <template #badge>
      <span
        class="px-2 py-0.5 rounded-full text-[10px] font-semibold"
        :class="enabled ? 'bg-status-success-bg text-status-success' : 'bg-surface-card-sub text-text-sub'"
      >
        {{ enabled ? '已开启' : '未开启' }}
      </span>
    </template>

    <template #actions>
      <md-switch
        :selected="enabled"
        :disabled="saving"
        @change="emit('toggle', extractSwitchValue($event))"
        title="开启或关闭缓存落盘"
      />
    </template>

    <p class="text-[12px] text-text-sub leading-relaxed mt-3">
      把内存中的解析结果定期写入磁盘，服务重启后可直接读回。
      默认关闭：读取上次的应答会让「上游已变更但仍命中旧记录」这类问题更难察觉。
    </p>

    <template v-if="enabled">
      <div class="mt-3.5">
        <md-outlined-text-field
          type="number"
          label="定时落盘间隔（秒）"
          :value="String(intervalSeconds)"
          @change="handleIntervalInput"
          class="w-full font-mono"
          supporting-text="取值范围 30–86400；留空或 0 使用默认值 300。服务退出时总会额外写一次。"
        ></md-outlined-text-field>
      </div>

      <!-- 落盘文件路径 -->
      <div v-if="info?.path" class="mt-3 p-2.5 rounded-md bg-surface-card-sub border border-surface-border-sub">
        <span class="text-[10px] font-semibold text-text-muted block mb-0.5">落盘文件</span>
        <span class="text-[11px] font-mono text-text-sub break-all select-all">{{ info.path }}</span>
      </div>

      <!-- 最近一次失败原因 -->
      <div
        v-if="info?.lastError"
        class="mt-2.5 p-2.5 rounded-md bg-status-error-bg border border-status-error/30"
      >
        <div class="flex items-start gap-1.5">
          <M3Icon name="warning" :size="13" class="text-status-error mt-0.5 shrink-0" />
          <span class="text-[11px] text-status-error leading-relaxed break-all">
            最近一次落盘失败：{{ info.lastError }}
          </span>
        </div>
      </div>
    </template>

    <template #footer>
      <div class="flex items-center justify-between gap-2">
        <span class="text-[11px] text-text-muted">
          当前 <span class="font-mono font-semibold text-text-main">{{ (info?.entryCount ?? 0).toLocaleString() }}</span> 条可落盘记录
        </span>
        <div class="flex items-center gap-1.5">
          <button
            type="button"
            @click="isLoadDialogOpen = true"
            :disabled="busy || !enabled"
            class="app-btn-secondary app-btn-compact"
            title="从上次落盘的文件恢复缓存"
          >
            <M3Icon name="upload" :size="13" />
            <span>从文件恢复</span>
          </button>
          <button
            type="button"
            @click="emit('dump')"
            :disabled="busy || !enabled"
            class="app-btn-secondary app-btn-compact"
            title="立即把内存缓存写入磁盘"
          >
            <M3Icon name="bolt" :size="13" />
            <span>立即落盘</span>
          </button>
        </div>
      </div>
    </template>
  </AppCard>

  <!-- 从文件恢复会覆盖当前内存缓存 -->
  <ConfirmModal
    :open="isLoadDialogOpen"
    title="确定从落盘文件恢复缓存？"
    message="文件中仍有效的记录会被读入当前缓存，覆盖同名的现有条目；已过期的记录会被自动忽略。"
    confirmText="确认恢复"
    :loading="busy"
    @confirm="handleLoadConfirm"
    @cancel="isLoadDialogOpen = false"
  />
</template>

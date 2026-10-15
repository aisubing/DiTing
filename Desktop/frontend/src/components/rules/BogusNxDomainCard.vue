<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import M3Icon from '../M3Icon.vue';
import { extractSwitchValue } from '../../utils/switch';

const props = defineProps<{
  /** 伪应答纠正总开关 */
  enabled: boolean;
  /** 伪应答地址清单（IP 或 CIDR） */
  networks: string[];
  saving?: boolean;
}>();

const emit = defineEmits<{
  (e: 'toggle', enabled: boolean): void;
  (e: 'save', networks: string[]): void;
}>();

const draft = ref('');

watch(
  () => props.networks,
  (next) => {
    draft.value = (next || []).join('\n');
  },
  { immediate: true, deep: true }
);

const parsed = computed(() =>
  draft.value
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
);

const dirty = computed(() => parsed.value.join('\n') !== (props.networks || []).join('\n'));

/** 前端只做明显笔误的提示，权威校验在后端编译匹配器时完成 */
const suspicious = computed(() =>
  parsed.value.filter((entry) => !/^[0-9a-fA-F:.]+(\/\d{1,3})?$/.test(entry))
);

const PRESETS = [
  { label: 'IPv4 未指定段', value: '0.0.0.0/8' },
  { label: 'IPv4 环回段', value: '127.0.0.0/8' },
  { label: 'IPv6 未指定', value: '::/128' },
  { label: 'IPv6 环回', value: '::1/128' },
];

function addPreset(value: string) {
  if (parsed.value.includes(value)) return;
  draft.value = [...parsed.value, value].join('\n');
}

function handleReset() {
  draft.value = (props.networks || []).join('\n');
}
</script>

<template>
  <div class="app-card-sub p-3 space-y-2">
    <div class="flex items-center justify-between gap-3">
      <div class="min-w-0">
        <span class="font-bold text-text-main text-[13px]">伪应答纠正</span>
        <span class="text-[10px] text-text-muted ml-2 font-mono">Bogus NXDOMAIN</span>
      </div>
      <md-switch
        :selected="!!enabled"
        :disabled="saving"
        @change="emit('toggle', extractSwitchValue($event))"
      />
    </div>

    <p class="text-[11px] text-text-sub leading-relaxed">
      部分网络在域名不存在时不返回 NXDOMAIN，而是返回一个固定的导航或广告页地址。
      开启后，应答中的地址一旦落在下方清单内即判定为上游劫持，就地改写为 NXDOMAIN，
      使客户端与缓存都不会把这个结果当成一次成功的解析。
    </p>

    <div v-if="enabled" class="space-y-2 pt-2 border-t border-surface-border-sub/60">
      <label class="text-[11px] font-semibold text-text-muted block">
        劫持地址清单（一行一条，支持 IP 与 CIDR 网段）
      </label>
      <textarea
        v-model="draft"
        rows="4"
        :disabled="saving"
        spellcheck="false"
        placeholder="0.0.0.0/8&#10;127.0.0.0/8"
        class="w-full rounded-md border border-surface-border bg-surface-card px-2.5 py-2 text-[11px] font-mono text-text-main resize-y focus:outline-none focus:border-brand-primary disabled:opacity-60"
      ></textarea>

      <p v-if="suspicious.length" class="text-[10px] text-status-warning leading-relaxed">
        以下条目格式可疑，保存时若无法解析将被忽略：{{ suspicious.join('、') }}
      </p>

      <div class="flex flex-wrap items-center gap-1.5">
        <span class="text-[10px] text-text-muted">快捷填入：</span>
        <button
          v-for="preset in PRESETS"
          :key="preset.value"
          type="button"
          :disabled="saving"
          @click="addPreset(preset.value)"
          class="px-2 py-0.5 rounded border border-surface-border text-[10px] text-text-sub hover:bg-surface-hover transition-colors"
        >
          {{ preset.label }}
        </button>
      </div>

      <div class="flex items-center justify-end gap-1.5 pt-1">
        <button
          v-if="dirty"
          type="button"
          @click="handleReset"
          :disabled="saving"
          class="app-btn-secondary app-btn-compact"
        >
          <M3Icon name="undo" :size="12" />
          <span>撤销修改</span>
        </button>
        <button
          type="button"
          @click="emit('save', parsed)"
          :disabled="saving || !dirty"
          class="app-btn-primary app-btn-compact"
        >
          <M3Icon :name="saving ? 'refresh' : 'check'" :size="13" :class="saving ? 'animate-spin' : ''" />
          <span>保存清单</span>
        </button>
      </div>
    </div>

    <p v-if="enabled" class="text-[11px] text-status-warning leading-relaxed">
      注意：内网服务常使用私网地址应答，若把私网网段列入清单会导致这些域名解析失败。
      清单中不要包含任何你在局域网内实际使用的地址段。
    </p>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { extractSwitchValue } from '../../utils/switch';

const props = defineProps<{
  /** ANY 查询最小化总开关 */
  enabled: boolean;
  /** 最小化应答形式："notimp" | "rfc8482" */
  mode: string;
  saving?: boolean;
}>();

const emit = defineEmits<{
  (e: 'toggle', enabled: boolean): void;
  (e: 'mode', mode: string): void;
}>();

/** 后端未回传或取值异常时一律按 notimp 展示，与后端归一化行为一致 */
const currentMode = computed(() => (props.mode === 'rfc8482' ? 'rfc8482' : 'notimp'));

const MODES = [
  {
    value: 'notimp',
    label: 'NOTIMP（推荐）',
    hint: '明确回应"不支持该查询"。更保守，客户端不会把它误当成一次有效解析。',
  },
  {
    value: 'rfc8482',
    label: 'RFC 8482 最小应答',
    hint: '返回 NOERROR + 一条 HINFO("RFC8482")，语义更准确，但需要客户端理解这一约定。',
  },
];
</script>

<template>
  <div class="app-card-sub p-3 space-y-2">
    <div class="flex items-center justify-between gap-3">
      <div class="min-w-0">
        <span class="font-bold text-text-main text-[13px]">ANY 查询最小化</span>
        <span class="text-[10px] text-text-muted ml-2 font-mono">RFC 8482</span>
      </div>
      <md-switch
        :selected="!!enabled"
        :disabled="saving"
        @change="emit('toggle', extractSwitchValue($event))"
      />
    </div>

    <p class="text-[11px] text-text-sub leading-relaxed">
      <code class="font-mono">ANY</code> 查询按定义要求返回该名字下的全部记录，因此常被用于 DNS
      放大攻击；它也会让按记录类型下发的拦截策略失效——客户端只查一次 ANY
      就能同时拿到 A 与 AAAA，绕过针对其中一种类型的阻断。
      开启后，本机不再向上游转发 ANY 查询，而是直接给出一个不含实际记录的最小化应答。
    </p>

    <div v-if="enabled" class="space-y-2 pt-2 border-t border-surface-border-sub/60">
      <label class="text-[11px] font-semibold text-text-muted block">应答形式</label>
      <div class="space-y-1.5">
        <button
          v-for="item in MODES"
          :key="item.value"
          type="button"
          :disabled="saving"
          @click="emit('mode', item.value)"
          class="w-full text-left px-2.5 py-2 rounded-md border transition-colors disabled:opacity-60"
          :class="
            currentMode === item.value
              ? 'border-brand-primary bg-surface-hover'
              : 'border-surface-border hover:bg-surface-hover'
          "
        >
          <span class="flex items-center gap-1.5">
            <span
              class="w-3 h-3 rounded-full border-2 shrink-0"
              :class="currentMode === item.value ? 'border-brand-primary bg-brand-primary' : 'border-surface-border'"
            ></span>
            <span class="text-[12px] font-semibold text-text-main">{{ item.label }}</span>
          </span>
          <span class="block text-[10px] text-text-sub leading-relaxed mt-1 pl-[18px]">
            {{ item.hint }}
          </span>
        </button>
      </div>

      <p class="text-[10px] text-text-muted leading-relaxed">
        本地 Hosts / 自定义重写已给出权威应答的名字不受影响，只有会外泄到上游的 ANY
        查询才会被最小化。
      </p>
    </div>
  </div>
</template>

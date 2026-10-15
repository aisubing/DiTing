<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import M3Icon from '../M3Icon.vue';
import AppCard from '../ui/AppCard.vue';

const props = defineProps<{
  /** 当前生效的排除正则 */
  patterns: string[];
  /** 被排除规则拦下、绕过缓存的查询累计数 */
  hits: number;
  saving?: boolean;
}>();

const emit = defineEmits<{
  (e: 'save', patterns: string[]): void;
}>();

/** 与后端保持一致的条数与长度上限，避免用户写完整页才发现被截断 */
const MAX_PATTERNS = 256;
const MAX_PATTERN_LEN = 512;

/** 编辑中的多行文本：一行一条正则 */
const draft = ref('');

watch(
  () => props.patterns,
  (next) => {
    draft.value = (next || []).join('\n');
  },
  { immediate: true, deep: true }
);

/** 解析出的规则（忽略空行） */
const parsed = computed(() =>
  draft.value
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
);

const enabled = computed(() => parsed.value.length > 0);

const problems = computed(() => {
  const issues: string[] = [];
  if (parsed.value.length > MAX_PATTERNS) {
    issues.push(`规则超过 ${MAX_PATTERNS} 条，超出部分不会被保存`);
  }
  const tooLong = parsed.value.filter((p) => p.length > MAX_PATTERN_LEN).length;
  if (tooLong > 0) {
    issues.push(`${tooLong} 条规则超过 ${MAX_PATTERN_LEN} 字符，保存时会被忽略`);
  }
  return issues;
});

const dirty = computed(() => parsed.value.join('\n') !== (props.patterns || []).join('\n'));

const PRESETS = [
  { label: '内网单标签域', pattern: '\\.local$' },
  { label: 'PTR 反查', pattern: '^\\d+\\.\\d+\\.\\d+\\.\\d+\\.in-addr\\.arpa$' },
  { label: '临时探测域', pattern: '^time\\.|^connectivity-check\\.' },
];

function addPreset(pattern: string) {
  if (parsed.value.includes(pattern)) return;
  draft.value = [...parsed.value, pattern].join('\n');
}

function handleSave() {
  emit('save', parsed.value);
}

function handleReset() {
  draft.value = (props.patterns || []).join('\n');
}
</script>

<template>
  <AppCard
    title="缓存排除规则"
    subtitle="指定哪些域名不参与缓存"
    icon="block"
    iconBoxClass="w-7 h-7"
    :iconSize="16"
  >
    <template #badge>
      <span
        class="px-2 py-0.5 rounded-full text-[10px] font-semibold"
        :class="enabled ? 'bg-status-success-bg text-status-success' : 'bg-surface-card-sub text-text-sub'"
      >
        {{ enabled ? `${parsed.length} 条规则` : '未启用' }}
      </span>
    </template>

    <template #actions>
      <button
        type="button"
        @click="handleSave"
        :disabled="saving || !dirty"
        class="app-btn-primary app-btn-compact"
      >
        <M3Icon :name="saving ? 'refresh' : 'check'" :size="14" :class="saving ? 'animate-spin' : ''" />
        <span>{{ saving ? '保存中...' : '保存规则' }}</span>
      </button>
    </template>

    <p class="text-[12px] text-text-sub leading-relaxed mt-3">
      命中规则的域名<b>既不读取也不写入</b>缓存，每次都实时回源。
      适用于内网域名、动态 IP 探测等"缓存反而出错"的场景。
    </p>

    <!-- 规则编辑区 -->
    <div class="mt-3.5">
      <label class="text-[11px] font-semibold text-text-muted block mb-1">
        正则表达式（一行一条，Go RE2 语法）
      </label>
      <textarea
        v-model="draft"
        rows="5"
        :disabled="saving"
        spellcheck="false"
        placeholder="\.local$&#10;^\d+\.\d+\.\d+\.\d+\.in-addr\.arpa$"
        class="w-full rounded-md border border-surface-border bg-surface-card-sub px-2.5 py-2 text-[11px] font-mono text-text-main resize-y focus:outline-none focus:border-brand-primary disabled:opacity-60"
      ></textarea>

      <div v-if="problems.length" class="mt-1.5 space-y-0.5">
        <p v-for="p in problems" :key="p" class="text-[10px] text-status-warning leading-relaxed">
          {{ p }}
        </p>
      </div>

      <!-- 常用规则快捷填入 -->
      <div class="mt-2 flex flex-wrap items-center gap-1.5">
        <span class="text-[10px] text-text-muted">快捷填入：</span>
        <button
          v-for="preset in PRESETS"
          :key="preset.label"
          type="button"
          :disabled="saving"
          @click="addPreset(preset.pattern)"
          class="px-2 py-0.5 rounded border border-surface-border text-[10px] text-text-sub hover:bg-surface-hover transition-colors"
        >
          {{ preset.label }}
        </button>
      </div>
    </div>

    <template #footer>
      <div class="flex items-center justify-between gap-2 text-[11px]">
        <span class="text-text-muted">
          已拦截 <span class="font-mono font-semibold text-text-main">{{ hits.toLocaleString() }}</span> 次缓存读写
        </span>
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
      </div>
    </template>
  </AppCard>
</template>
